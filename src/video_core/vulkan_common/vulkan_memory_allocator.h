// SPDX-FileCopyrightText: Copyright 2019 yuzu Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later
// SDPX-FileCopyrightText: Copyright 2025 EDEN Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <memory>
#include <span>
#include <vector>
#include "common/common_types.h"
#include "video_core/vulkan_common/vulkan_device.h"
#include "video_core/vulkan_common/vulkan_wrapper.h"
#include "video_core/vulkan_common/vulkan_raii.h"

VK_DEFINE_HANDLE(VmaAllocator)

namespace Vulkan {

class Device;
class MemoryMap;
class MemoryAllocation;

/// Hints and requirements for the backing memory type of a commit
enum class MemoryUsage {
    DeviceLocal, ///< Requests device local host visible buffer, falling back to device local
                 ///< memory.
    Upload,      ///< Requires a host visible memory type optimized for CPU to GPU uploads
    Download,    ///< Requires a host visible memory type optimized for GPU to CPU readbacks
    Stream,      ///< Requests device local host visible buffer, falling back host memory.
};

template <typename F>
void ForEachDeviceLocalHostVisibleHeap(const Device& device, F&& f) {
    auto memory_props = device.GetPhysical().GetMemoryProperties().memoryProperties;
    for (size_t i = 0; i < memory_props.memoryTypeCount; i++) {
        auto& memory_type = memory_props.memoryTypes[i];
        if ((memory_type.propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) &&
            (memory_type.propertyFlags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)) {
            f(memory_type.heapIndex, memory_props.memoryHeaps[memory_type.heapIndex]);
        }
    }
}

/// Ownership handle of a memory commitment.
/// Points to a subregion of a memory allocation.
class MemoryCommit {
public:
    explicit MemoryCommit() noexcept = default;
    explicit MemoryCommit(MemoryAllocation* allocation_, VkDeviceMemory memory_, u64 begin_,
                          u64 end_) noexcept;
    ~MemoryCommit();

    MemoryCommit& operator=(MemoryCommit&&) noexcept;
    MemoryCommit(MemoryCommit&&) noexcept;

    MemoryCommit& operator=(const MemoryCommit&) = delete;
    MemoryCommit(const MemoryCommit&) = delete;

    /// Returns a host visible memory map.
    /// It will map the backing allocation if it hasn't been mapped before.
    std::span<u8> Map();

    /// Returns the Vulkan memory handler.
    VkDeviceMemory Memory() const {
        return memory;
    }

    /// Returns the start position of the commit relative to the allocation.
    VkDeviceSize Offset() const {
        return static_cast<VkDeviceSize>(begin);
    }

private:
    void Release();

    MemoryAllocation* allocation{}; ///< Pointer to the large memory allocation.
    VkDeviceMemory memory{};        ///< Vulkan device memory handler.
    u64 begin{};                    ///< Beginning offset in bytes to where the commit exists.
    u64 end{};                      ///< Offset in bytes where the commit ends.
    std::span<u8> span;             ///< Host visible memory span. Empty if not queried before.
};

/// Memory allocator container.
/// Allocates and releases memory allocations on demand.
class MemoryAllocator {
    friend MemoryAllocation;

public:
    /**
     * Construct memory allocator
     *
     * @param device_             Device to allocate from
     *
     * @throw vk::Exception on failure
     */
    explicit MemoryAllocator(const Device& device_)
        : device(device_), allocator(device_.GetMemoryAllocator()) {}
    ~MemoryAllocator();

    MemoryAllocator& operator=(const MemoryAllocator&) = delete;
    MemoryAllocator(const MemoryAllocator&) = delete;

    vk::Image CreateImage(const VkImageCreateInfo& ci) const;

    VulkanImage CreateImage(const VkImageCreateInfo& ci) const {
        if (ci.extent.width == 0 || ci.extent.height == 0) {
            throw std::invalid_argument("Image extent must have non-zero width and height");
        }

        const VmaAllocationCreateInfo alloc_ci = {
            .flags = VMA_ALLOCATION_CREATE_WITHIN_BUDGET_BIT,
            .usage = VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE,
            .requiredFlags = 0,
            .preferredFlags = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            .memoryTypeBits = 0,
            .pool = VK_NULL_HANDLE,
            .pUserData = nullptr,
            .priority = 0.f,
        };

        VkImage handle{};
        VmaAllocation allocation{};
        vk::Check(vmaCreateImage(allocator, &ci, &alloc_ci, &handle, &allocation, nullptr));

        return VulkanImage(device, handle, allocation, ci.extent);
    }

    vk::Buffer CreateBuffer(const VkBufferCreateInfo& ci, MemoryUsage usage) const;

    VulkanBuffer CreateBuffer(const VkBufferCreateInfo& ci, MemoryUsage usage) const {
        if (ci.size == 0) {
            throw std::invalid_argument("Buffer size must be greater than 0");
        }

        const VmaAllocationCreateInfo alloc_ci = {
            .flags = VMA_ALLOCATION_CREATE_WITHIN_BUDGET_BIT | MemoryUsageVmaFlags(usage),
            .usage = MemoryUsageVma(usage),
            .requiredFlags = 0,
            .preferredFlags = MemoryUsagePreferredVmaFlags(usage),
            .memoryTypeBits = usage == MemoryUsage::Stream ? 0u : valid_memory_types,
            .pool = VK_NULL_HANDLE,
            .pUserData = nullptr,
            .priority = 0.f,
        };

        VkBuffer handle{};
        VmaAllocation allocation{};
        vk::Check(vmaCreateBuffer(allocator, &ci, &alloc_ci, &handle, &allocation, nullptr));

        return VulkanBuffer(device, handle, allocation, ci.size);
    }

    /**
     * Commits a memory with the specified requirements.
     *
     * @param requirements Requirements returned from a Vulkan call.
     * @param usage        Indicates how the memory will be used.
     *
     * @returns A memory commit.
     */
    MemoryCommit Commit(const VkMemoryRequirements& requirements, MemoryUsage usage);

    /// Commits memory required by the buffer and binds it.
    MemoryCommit Commit(const vk::Buffer& buffer, MemoryUsage usage);

private:
    /// Tries to allocate a chunk of memory.
    bool TryAllocMemory(VkMemoryPropertyFlags flags, u32 type_mask, u64 size);

    /// Releases a chunk of memory.
    void ReleaseMemory(MemoryAllocation* alloc);

    /// Tries to allocate a memory commit.
    std::optional<MemoryCommit> TryCommit(const VkMemoryRequirements& requirements,
                                          VkMemoryPropertyFlags flags);

    /// Returns the fastest compatible memory property flags from the wanted flags.
    VkMemoryPropertyFlags MemoryPropertyFlags(u32 type_mask, VkMemoryPropertyFlags flags) const;

    /// Returns index to the fastest memory type compatible with the passed requirements.
    std::optional<u32> FindType(VkMemoryPropertyFlags flags, u32 type_mask) const;

    const Device& device;                                       ///< Device handle.
    VmaAllocator allocator;                                     ///< Vma allocator.
    const VkPhysicalDeviceMemoryProperties properties;          ///< Physical device properties.
    std::vector<std::unique_ptr<MemoryAllocation>> allocations; ///< Current allocations.
    VkDeviceSize buffer_image_granularity; // The granularity for adjacent offsets between buffers
                                           // and optimal images
    u32 valid_memory_types{~0u};
};

} // namespace Vulkan
