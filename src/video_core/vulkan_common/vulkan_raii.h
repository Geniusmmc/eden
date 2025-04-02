#pragma once

#include <vulkan/vulkan.h>
#include <stdexcept>  
#include <cstdint>   
#include <vector>          
#include "video_core/vulkan_common/vulkan_device.h"
#include "video_core/vulkan_common/vulkan.h"
#include "video_core/vulkan_common/vma.h"

// VulkanBuffer is an RAII wrapper for a Vulkan buffer
class VulkanBuffer {
public:
    VulkanBuffer(const Device& device, VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags properties)
        : device_(device.GetLogical()) {
        if (size == 0) {
            throw std::invalid_argument("Buffer size must be greater than 0");
        }

        // Create Vulkan buffer
        VkBufferCreateInfo buffer_info{};
        buffer_info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        buffer_info.size = size;
        buffer_info.usage = usage;
        buffer_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

        if (vkCreateBuffer(device_, &buffer_info, nullptr, &buffer_) != VK_SUCCESS) {
            throw std::runtime_error("Failed to create Vulkan buffer");
        }

        // Allocate memory for the buffer
        VkMemoryRequirements mem_requirements;
        vkGetBufferMemoryRequirements(device_, buffer_, &mem_requirements);

        VkMemoryAllocateInfo alloc_info{};
        alloc_info.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        alloc_info.allocationSize = mem_requirements.size;
        alloc_info.memoryTypeIndex = device.FindMemoryType(mem_requirements.memoryTypeBits, properties);

        if (vkAllocateMemory(device_, &alloc_info, nullptr, &buffer_memory_) != VK_SUCCESS) {
            throw std::runtime_error("Failed to allocate Vulkan buffer memory");
        }

        if (vkBindBufferMemory(device_, buffer_, buffer_memory_, 0) != VK_SUCCESS) {
            throw std::runtime_error("Failed to bind Vulkan buffer memory");
        }
    }

    ~VulkanBuffer() {
        if (buffer_) {
            vkDestroyBuffer(device_, buffer_, nullptr);
        }
        if (buffer_memory_) {
            vkFreeMemory(device_, buffer_memory_, nullptr);
        }
    }

    VulkanBuffer(const VulkanBuffer&) = delete; // Copy semantics are disabled
    VulkanBuffer& operator=(const VulkanBuffer&) = delete;

    // Move Constructor
    VulkanBuffer(VulkanBuffer&& other) noexcept
        : device_(other.device_), buffer_(other.buffer_), buffer_memory_(other.buffer_memory_) {
        other.buffer_ = VK_NULL_HANDLE;
        other.buffer_memory_ = VK_NULL_HANDLE;
    }

    // Move Assignment Operator
    VulkanBuffer& operator=(VulkanBuffer&& other) noexcept {
        if (this != &other) { // Check for self-assignment
            // Clean up existing resources
            if (buffer_) {
                vkDestroyBuffer(device_, buffer_, nullptr);
            }
            if (buffer_memory_) {
                vkFreeMemory(device_, buffer_memory_, nullptr);
            }

            // Move resources
            device_ = other.device_;
            buffer_ = other.buffer_;
            buffer_memory_ = other.buffer_memory_;

            other.buffer_ = VK_NULL_HANDLE;
            other.buffer_memory_ = VK_NULL_HANDLE;
        }
        return *this;
    }

    VkBuffer Get() const { return buffer_; }

private:
    VkDevice device_;
    VkBuffer buffer_ = VK_NULL_HANDLE;
    VkDeviceMemory buffer_memory_ = VK_NULL_HANDLE;
};

class VulkanImage {
public:
    VulkanImage(const Device& device, VkExtent2D extent, VkFormat format, VkImageUsageFlags usage)
        : device_(device.GetLogical()) {
        // Create Vulkan image
        VkImageCreateInfo image_info{};
        image_info.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        image_info.pNext = nullptr;
        image_info.flags = 0; // Default to no flags
        image_info.imageType = VK_IMAGE_TYPE_2D;
        image_info.extent = {extent.width, extent.height, 1};
        image_info.mipLevels = 1;
        image_info.arrayLayers = 1;
        image_info.format = format;
        image_info.tiling = VK_IMAGE_TILING_OPTIMAL;
        image_info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        image_info.usage = usage;
        image_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        image_info.samples = VK_SAMPLE_COUNT_1_BIT;
        image_info.queueFamilyIndexCount = 0;
        image_info.pQueueFamilyIndices = nullptr;

        if (vkCreateImage(device_, &image_info, nullptr, &image_) != VK_SUCCESS) {
            throw std::runtime_error("Failed to create Vulkan image");
        }

        // Allocate memory for the image
        VkMemoryRequirements mem_requirements;
        vkGetImageMemoryRequirements(device_, image_, &mem_requirements);

        VkMemoryAllocateInfo alloc_info{};
        alloc_info.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        alloc_info.allocationSize = mem_requirements.size;
        alloc_info.memoryTypeIndex = device.FindMemoryType(mem_requirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        if (vkAllocateMemory(device_, &alloc_info, nullptr, &image_memory_) != VK_SUCCESS) {
            throw std::runtime_error("Failed to allocate Vulkan image memory");
        }

        if (vkBindImageMemory(device_, image_, image_memory_, 0) != VK_SUCCESS) {
            throw std::runtime_error("Failed to bind Vulkan image memory");
        }
    }

    ~VulkanImage() {
        if (image_) {
            vkDestroyImage(device_, image_, nullptr);
        }
        if (image_memory_) {
            vkFreeMemory(device_, image_memory_, nullptr);
        }
    }

    VkImage Get() const { return image_; }

private:
    VkDevice device_;
    VkImage image_ = VK_NULL_HANDLE;
    VkDeviceMemory image_memory_ = VK_NULL_HANDLE;
};

typedef struct VkBufferCreateInfo {
    VkStructureType sType;
    const void* pNext;
    VkBufferCreateFlags flags;
    VkDeviceSize size;
    VkBufferUsageFlags usage;
    VkSharingMode sharingMode;
    uint32_t queueFamilyIndexCount;
    const uint32_t* pQueueFamilyIndices;
} VkBufferCreateInfo;

typedef struct VkMemoryRequirements {
    VkDeviceSize size;
    VkDeviceSize alignment;
    uint32_t memoryTypeBits;
} VkMemoryRequirements;

typedef struct VkMemoryAllocateInfo {
    VkStructureType sType;
    const void* pNext;
    VkDeviceSize allocationSize;
    uint32_t memoryTypeIndex;
} VkMemoryAllocateInfo;

typedef struct VkImageCreateInfo {
    VkStructureType sType;
    const void* pNext;
    VkImageCreateFlags flags;
    VkImageType imageType;
    VkFormat format;
    VkExtent3D extent;
    uint32_t mipLevels;
    uint32_t arrayLayers;
    VkSampleCountFlagBits samples;
    VkImageTiling tiling;
    VkImageUsageFlags usage;
    VkSharingMode sharingMode;
    uint32_t queueFamilyIndexCount;
    const uint32_t* pQueueFamilyIndices;
    VkImageLayout initialLayout;
} VkImageCreateInfo;

VkResult vkCreateBuffer(
    VkDevice device,
    const VkBufferCreateInfo* pCreateInfo,
    const VkAllocationCallbacks* pAllocator,
    VkBuffer* pBuffer
);

void vkGetBufferMemoryRequirements(
    VkDevice device,
    VkBuffer buffer,
    VkMemoryRequirements* pMemoryRequirements
);

VkResult vkAllocateMemory(
    VkDevice device,
    const VkMemoryAllocateInfo* pAllocateInfo,
    const VkAllocationCallbacks* pAllocator,
    VkDeviceMemory* pMemory
);

VkResult vkBindBufferMemory(
    VkDevice device,
    VkBuffer buffer,
    VkDeviceMemory memory,
    VkDeviceSize memoryOffset
);

void vkDestroyBuffer(
    VkDevice device,
    VkBuffer buffer,
    const VkAllocationCallbacks* pAllocator
);

void vkFreeMemory(
    VkDevice device,
    VkDeviceMemory memory,
    const VkAllocationCallbacks* pAllocator
);

VkResult vkCreateImage(
    VkDevice device,
    const VkImageCreateInfo* pCreateInfo,
    const VkAllocationCallbacks* pAllocator,
    VkImage* pImage
);

void vkDestroyImage(
    VkDevice device,
    VkImage image,
    const VkAllocationCallbacks* pAllocator
);

void vkGetImageMemoryRequirements(
    VkDevice device,
    VkImage image,
    VkMemoryRequirements* pMemoryRequirements
);

VkResult vkBindImageMemory(
    VkDevice device,
    VkImage image,
    VkDeviceMemory memory,
    VkDeviceSize memoryOffset
);

class Device {
public:
    VkDevice GetLogical() const {
        return logical_device_;
    }

    uint32_t FindMemoryType(uint32_t type_filter, VkMemoryPropertyFlags properties) const {
        for (uint32_t i = 0; i < memory_properties_.memoryTypeCount; i++) {
            if ((type_filter & (1 << i)) &&
                (memory_properties_.memoryTypes[i].propertyFlags & properties) == properties) {
                return i;
            }
        }
        throw std::runtime_error("Failed to find suitable memory type");
    }

private:
    VkDevice logical_device_;
    VkPhysicalDeviceMemoryProperties memory_properties_;
};

VkDevice Device::GetLogical() const {
    return logical_device_;
}

uint32_t Device::FindMemoryType(uint32_t type_filter, VkMemoryPropertyFlags properties) const {
    for (uint32_t i = 0; i < memory_properties_.memoryTypeCount; i++) {
        if ((type_filter & (1 << i)) &&
            (memory_properties_.memoryTypes[i].propertyFlags & properties) == properties) {
            return i;
        }
    }
    throw std::runtime_error("Failed to find suitable memory type");
}

class VulkanMemoryAllocator {
public:
    VulkanMemoryAllocator(const VmaAllocatorCreateInfo& allocator_info) {
        if (vmaCreateAllocator(&allocator_info, &allocator_) != VK_SUCCESS) {
            throw std::runtime_error("Failed to create Vulkan Memory Allocator");
        }
    }

    ~VulkanMemoryAllocator() {
        if (allocator_) {
            vmaDestroyAllocator(allocator_);
        }
    }

    // Disable copy semantics
    VulkanMemoryAllocator(const VulkanMemoryAllocator&) = delete;
    VulkanMemoryAllocator& operator=(const VulkanMemoryAllocator&) = delete;

    // Enable move semantics
    VulkanMemoryAllocator(VulkanMemoryAllocator&& other) noexcept
        : allocator_(other.allocator_) {
        other.allocator_ = nullptr;
    }

    VulkanMemoryAllocator& operator=(VulkanMemoryAllocator&& other) noexcept {
        if (this != &other) {
            if (allocator_) {
                vmaDestroyAllocator(allocator_);
            }
            allocator_ = other.allocator_;
            other.allocator_ = nullptr;
        }
        return *this;
    }

    VmaAllocator Get() const {
        return allocator_;
    }

private:
    VmaAllocator allocator_ = nullptr;
};