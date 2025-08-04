// SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

// SPDX-FileCopyrightText: Copyright 2021 yuzu Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "common/bit_field.h"
#include "common/common_types.h"
#include "shader_recompiler/frontend/maxwell/translate/impl/impl.h"

namespace Shader::Maxwell {
namespace {

enum class Mode : u64 {
    Default,
    Patch,
    Prim,
    Attr,
};

enum class Shift : u64 {
    Default,
    U16,
    B32,
};

} // Anonymous namespace

// Valid only for GS, TI, VS and trap
void TranslatorVisitor::ISBERD(u64 insn) {
    union {
        u64 raw;
        BitField<0, 8, IR::Reg> dest_reg;
        BitField<8, 8, IR::Reg> src_reg;
        BitField<8, 8, u32> src_reg_num;
        BitField<24, 8, u32> imm;
        BitField<31, 1, u64> skew;
        BitField<32, 1, u64> o;
        BitField<33, 2, Mode> mode;
        BitField<47, 2, Shift> shift;
    } const isberd{insn};

    bool is_only_skew_op = true;
    auto apply_shift = [&](IR::U32 result) -> IR::U32 {
        switch (isberd.shift.Value()) {
        case Shift::U16:
        case Shift::B32:
            return ir.ShiftLeftLogical(result, ir.Imm32(1));
        default:
            return result;
        }
    };

    if (isberd.o != 0) {
        IR::U32 address{};
        if (isberd.src_reg_num == 0xFF) {
            address = ir.Imm32(isberd.imm);
        } else {
            IR::U32 offset = ir.Imm32(isberd.imm);
            address = ir.IAdd(X(isberd.src_reg), offset);
            if (isberd.skew != 0) {
                address = ir.IAdd(address, ir.LaneId());
            }
        }

        IR::U32 result = ir.BitCast<IR::U32>(ir.GetAttributeIndexed(address));
        if (isberd.shift != Shift::Default) {
            result = apply_shift(result);
        }

        is_only_skew_op = false;
        X(isberd.dest_reg, result);
    }

    else if (isberd.mode != Mode::Default) {
        IR::U32 index{};
        if (isberd.src_reg_num == 0xFF) {
            index = ir.Imm32(isberd.imm);
        } else {
            index = ir.IAdd(X(isberd.src_reg), ir.Imm32(isberd.imm));
            if (isberd.skew != 0) {
                index = ir.IAdd(index, ir.LaneId());
            }
        }

        IR::F32 result_f32{};
        switch (isberd.mode.Value()) {
        case Mode::Patch:
            result_f32 = ir.GetPatch(index.Patch());
            break;
        case Mode::Prim:
            result_f32 = ir.GetAttribute(index.Attribute());
            break;
        case Mode::Attr:
            result_f32 = ir.GetAttributeIndexed(index);
            break;
        default:
            break;
        }

        IR::U32 result_u32 = ir.BitCast<IR::U32>(result_f32);
        if (isberd.shift != Shift::Default) {
            result_u32 = apply_shift(result_u32);
        }

        is_only_skew_op = false;
        X(isberd.dest_reg, result_u32);
    }

    if (isberd.skew != 0 && is_only_skew_op) {
        IR::U32 result = ir.IAdd(X(isberd.src_reg), ir.LaneId());
        X(isberd.dest_reg, result);
    } else {
         X(isberd.dest_reg, X(isberd.src_reg));
    }  
}

} // namespace Shader::Maxwell
