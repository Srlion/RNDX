--[[
Copyright (c) 2025 Srlion (https://github.com/Srlion)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local bit_band = bit.band
local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRectUV = surface.DrawTexturedRectUV
local surface_DrawTexturedRect = surface.DrawTexturedRect
local render_UpdateScreenEffectTexture = render.UpdateScreenEffectTexture

local NEW_FLAG; do
    local flags_n = -1
    function NEW_FLAG()
        flags_n = flags_n + 1
        return 2 ^ flags_n
    end
end

local NO_TL  = NEW_FLAG()
local NO_TR  = NEW_FLAG()
local NO_BL  = NEW_FLAG()
local NO_BR  = NEW_FLAG()

-- Svetov/Jaffies's great idea!
local SHAPE_CIRCLE  = NEW_FLAG()
local SHAPE_FIGMA   = NEW_FLAG()
local SHAPE_IOS     = NEW_FLAG()

local BLUR = NEW_FLAG()

local RNDX = {}

local FIX_UV = {}
local shader_mat = [==[
screenspace_general
{
    $pixshader ""
    $vertexshader ""

    $basetexture ""
    $texture1    ""
    $texture2    ""
    $texture3    ""

    $ignorez        1
    "<dx90"
    {
        $no_draw 1
    }

    $copyalpha                 0
    $alpha_blend_color_overlay 0
    $alpha_blend               1 // for AA
    $linearwrite               1 // to disable broken gamma correction for colors
    $linearread_basetexture    1 // to disable broken gamma correction for textures
    $vertexcolor 1
    $vertextransform 1

    // Anti-aliasing smoothness
    // I recommend keeping it at 2.0, going higher will be noticeable
    $c2_y 2.0
}
]==]

local function create_shader_mat(name, opts)
    assert(name and isstring(name), "create_shader_mat: tex must be a string")

    local key_values = util.KeyValuesToTable(shader_mat, false, true)

    if opts then
        for k, v in pairs(opts) do
            key_values[k] = v
        end
    end

    local mat = CreateMaterial(
        "rndx_shaders1" .. name .. SysTime(),
        "screenspace_general",
        key_values
    )

    if opts and opts.FixUV then
        FIX_UV[mat] = true
    end

    return mat
end

local ROUNDED_MAT = create_shader_mat("rounded", {
    ["$pixshader"] = "rndx_r_shaders1_ps20",
    ["$basetexture"] = "loveyoumom", -- if there is no base texture, you can't change it later
    FixUV = true
})

local BLUR_H_MAT = create_shader_mat("blur_horizontal", {
    ["$pixshader"] = "rndx_bh_shaders1_ps30",
    ["$vertexshader"] = "rndx_vertex_shaders1_vs30",
    ["$basetexture"] = "_rt_FullFrameFB",
})
local BLUR_V_MAT = create_shader_mat("blur_vertical", {
    ["$pixshader"] = "rndx_bv_shaders1_ps30",
    ["$vertexshader"] = "rndx_vertex_shaders1_vs30",
    ["$basetexture"] = "_rt_FullFrameFB",
})

local SHAPES = {
    [SHAPE_CIRCLE] = 2,
    [SHAPE_FIGMA] = 2.2,
    [SHAPE_IOS] = 4,
}

local SetMatFloat = ROUNDED_MAT.SetFloat
local SetMatTexture = ROUNDED_MAT.SetTexture

local DEFAULT_DRAW_FLAGS = SHAPE_FIGMA

local DRAW_SECOND_BLUR = false
local function draw_rounded(x, y, w, h, col, flags, tl, tr, bl, br, texture, thickness)
    if col and col.a == 0 then
        return
    end

    if not flags then
        flags = DEFAULT_DRAW_FLAGS
    end

    local mat = ROUNDED_MAT

    local using_blur = bit_band(flags, BLUR) ~= 0
    if using_blur then
        mat = DRAW_SECOND_BLUR and BLUR_H_MAT or BLUR_V_MAT
        render_UpdateScreenEffectTexture()
    end

    SetMatFloat(mat, "$c1_x", w)
    SetMatFloat(mat, "$c1_y", h)

    -- Roundness
    SetMatFloat(mat, "$c0_w", bit_band(flags, NO_TL) == 0 and tl or 0)
    SetMatFloat(mat, "$c0_z", bit_band(flags, NO_TR) == 0 and tr or 0)
    SetMatFloat(mat, "$c0_x", bit_band(flags, NO_BL) == 0 and bl or 0)
    SetMatFloat(mat, "$c0_y", bit_band(flags, NO_BR) == 0 and br or 0)
    --

    if not using_blur then
        SetMatFloat(mat, "$c1_w", texture and 1 or 0)
        SetMatTexture(mat, "$basetexture", texture or "loveyoumom")
    end

    if thickness then
        SetMatFloat(mat, "$c2_x", thickness)
    else
        SetMatFloat(mat, "$c2_x", 3.402823466e+38) -- max outline value for filled boxes
    end

    local shape_value = SHAPES[bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)]
    SetMatFloat(mat, "$c1_z", shape_value or 2.2)

    if col then
        surface_SetDrawColor(col)
    else
        surface_SetDrawColor(255, 255, 255, 255)
    end

    surface_SetMaterial(mat)
    if FIX_UV[mat] then
        -- https://github.com/Jaffies/rboxes/blob/main/rboxes.lua
        -- fixes setting $basetexture to ""(none) not working correctly
        surface_DrawTexturedRectUV(x, y, w, h, -0.015625, -0.015625, 1.015625, 1.015625)
    else
        surface_DrawTexturedRect(x, y, w, h)
    end

    if using_blur and not DRAW_SECOND_BLUR then
        DRAW_SECOND_BLUR = true
        draw_rounded(x, y, w, h, col, flags, tl, tr, bl, br, texture, thickness)
        DRAW_SECOND_BLUR = false
    end
end

function RNDX.Draw(r, x, y, w, h, col, flags)
    draw_rounded(x, y, w, h, col, flags, r, r, r, r)
end

function RNDX.DrawOutlined(r, x, y, w, h, col, thickness, flags)
    draw_rounded(x, y, w, h, col, flags, r, r, r, r, nil, thickness or 1)
end

function RNDX.DrawTexture(r, x, y, w, h, col, texture, flags)
    draw_rounded(x, y, w, h, col, flags, r, r, r, r, texture)
end

function RNDX.DrawMaterial(r, x, y, w, h, col, mat, flags)
    local tex = mat:GetTexture("$basetexture")
    if tex then
        RNDX.DrawTexture(r, x, y, w, h, col, tex, flags)
    end
end

function RNDX.DrawCircle(x, y, r, col, flags)
    RNDX.Draw(r / 2, x - r / 2, y - r / 2, r, r, col, (flags or 0) + SHAPE_CIRCLE)
end

function RNDX.DrawCircleOutlined(x, y, r, col, thickness, flags)
    RNDX.DrawOutlined(r / 2, x - r / 2, y - r / 2, r, r, col, thickness, (flags or 0) + SHAPE_CIRCLE)
end

-- Flags
RNDX.NO_TL = NO_TL
RNDX.NO_TR = NO_TR
RNDX.NO_BL = NO_BL
RNDX.NO_BR = NO_BR

RNDX.SHAPE_CIRCLE = SHAPE_CIRCLE
RNDX.SHAPE_FIGMA = SHAPE_FIGMA
RNDX.SHAPE_IOS = SHAPE_IOS

RNDX.BLUR = BLUR

function RNDX.SetFlag(flags, flag, bool)
    if tobool(bool) then
        return bit.bor(flags, flag)
    else
        return bit.band(flags, bit.bnot(flag))
    end
end

return RNDX
