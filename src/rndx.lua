--[[
Copyright (c) 2025 Srlion (https://github.com/Srlion)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

if SERVER then
	AddCSLuaFile()
	return
end

local bit_band = bit.band
local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRectUV = surface.DrawTexturedRectUV
local surface_DrawTexturedRect = surface.DrawTexturedRect
local render_CopyRenderTargetToTexture = render.CopyRenderTargetToTexture
local math_min = math.min
local math_max = math.max
local DisableClipping = DisableClipping

local BLUR_RT = GetRenderTargetEx("DownsampledSceneRT" .. SysTime(),
	512, 512,
	RT_SIZE_LITERAL,
	MATERIAL_RT_DEPTH_SEPARATE,
	bit.bor(2, 256, 4, 8 --[[4, 8 is clamp_s + clamp-t]]),
	0,
	IMAGE_FORMAT_BGRA8888
)

local SHADERS_VERSION = "SHADERS_VERSION_PLACEHOLDER"
local SHADERS_GMA = [========[SHADERS_GMA_PLACEHOLDER]========]
do
	local DECODED_SHADERS_GMA = util.Base64Decode(SHADERS_GMA)
	if not DECODED_SHADERS_GMA or #DECODED_SHADERS_GMA == 0 then
		print("Failed to load shaders!") -- this shouldn't happen
		return
	end

	file.Write("rndx_shaders_" .. SHADERS_VERSION .. ".gma", DECODED_SHADERS_GMA)
	game.MountGMA("data/rndx_shaders_" .. SHADERS_VERSION .. ".gma")
end

local function GET_SHADER(name)
	return SHADERS_VERSION:gsub("%.", "_") .. "_" .. name
end

-- I know it exists in gmod, but I want to have math.min and math.max localized
local function math_clamp(val, min, max)
	return (math_min(math_max(val, min), max))
end

local NEW_FLAG; do
	local flags_n = -1
	function NEW_FLAG()
		flags_n = flags_n + 1
		return 2 ^ flags_n
	end
end

local NO_TL, NO_TR, NO_BL, NO_BR           = NEW_FLAG(), NEW_FLAG(), NEW_FLAG(), NEW_FLAG()

-- Svetov/Jaffies's great idea!
local SHAPE_CIRCLE, SHAPE_FIGMA, SHAPE_IOS = NEW_FLAG(), NEW_FLAG(), NEW_FLAG()

local BLUR                                 = NEW_FLAG()

local RNDX                                 = {}

local shader_mat                           = [==[
screenspace_general
{
	$pixshader ""
	$vertexshader ""

	$basetexture ""
	$texture1    ""
	$texture2    ""
	$texture3    ""

	// Mandatory, don't touch
	$ignorez            1
	$vertexcolor        1
	$vertextransform    1
	"<dx90"
	{
		$no_draw 1
	}

	$copyalpha                 0
	$alpha_blend_color_overlay 0
	$alpha_blend               1 // for AA
	$linearwrite               1 // to disable broken gamma correction for colors
	$linearread_basetexture    1 // to disable broken gamma correction for textures
	$linearread_texture1       1 // to disable broken gamma correction for textures
	$linearread_texture2       1 // to disable broken gamma correction for textures
	$linearread_texture3       1 // to disable broken gamma correction for textures
}
]==]

local MATRIXES                             = {}

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

	MATRIXES[mat] = Matrix()

	return mat
end

local ROUNDED_MAT = create_shader_mat("rounded", {
	["$pixshader"] = GET_SHADER("rndx_rounded_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
})
local ROUNDED_TEXTURE_MAT = create_shader_mat("rounded_texture", {
	["$pixshader"] = GET_SHADER("rndx_rounded_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
	["$basetexture"] = "loveyoumom", -- if there is no base texture, you can't change it later
})

local BLUR_VERTICAL = "$c0_x"
local ROUNDED_BLUR_MAT = create_shader_mat("blur_horizontal", {
	["$pixshader"] = GET_SHADER("rndx_rounded_blur_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
	["$basetexture"] = BLUR_RT:GetName(),
	["$texture1"] = "_rt_FullFrameFB",
})

local SHADOWS_MAT = create_shader_mat("rounded_shadows", {
	["$pixshader"] = GET_SHADER("rndx_shadows_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
})

local SHADOWS_BLUR_MAT = create_shader_mat("shadows_blur_horizontal", {
	["$pixshader"] = GET_SHADER("rndx_shadows_blur_ps30"),
	["$vertexshader"] = GET_SHADER("rndx_vertex_vs30"),
	["$basetexture"] = "_rt_PowerOfTwoFB",
	["$texture1"] = "_rt_FullFrameFB",
})

local SHAPES = {
	[SHAPE_CIRCLE] = 2,
	[SHAPE_FIGMA] = 2.2,
	[SHAPE_IOS] = 4,
}

local MATERIAL_SetTexture = ROUNDED_MAT.SetTexture
local MATERIAL_SetMatrix = ROUNDED_MAT.SetMatrix
local MATERIAL_SetFloat = ROUNDED_MAT.SetFloat
local MATRIX_SetUnpacked = Matrix().SetUnpacked

local function SetParams(
	mat,
	tl, tr, bl, br,
	w, h,
	power,
	use_texture,
	outline_thickness,
	aa
)
	local matrix = MATRIXES[mat]
	MATRIX_SetUnpacked(
		matrix,

		bl, w, outline_thickness, 0,
		br, h, aa, 0,
		tr, power, 0, 0,
		tl, use_texture, 0, 0
	)
	MATERIAL_SetMatrix(mat, "$viewprojmat", matrix)
end

local MANUAL_COLOR = NEW_FLAG()
local DEFAULT_DRAW_FLAGS = SHAPE_FIGMA

local function draw_rounded(x, y, w, h, col, flags, tl, tr, bl, br, texture, thickness)
	if col and col.a == 0 then
		return
	end

	if not flags then
		flags = DEFAULT_DRAW_FLAGS
	end

	local using_blur = bit_band(flags, BLUR) ~= 0
	if using_blur then
		RNDX.DrawBlur(x, y, w, h, flags, tl, tr, bl, br, thickness)
		return
	end

	local mat = ROUNDED_MAT; if texture then
		mat = ROUNDED_TEXTURE_MAT
		MATERIAL_SetTexture(mat, "$basetexture", texture)
	end
	local max_rad = math_min(w, h) / 2
	local shape_value = SHAPES[bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)]
	SetParams(
		mat,
		bit_band(flags, NO_TL) == 0 and math_clamp(tl, 0, max_rad) or 0,
		bit_band(flags, NO_TR) == 0 and math_clamp(tr, 0, max_rad) or 0,
		bit_band(flags, NO_BL) == 0 and math_clamp(bl, 0, max_rad) or 0,
		bit_band(flags, NO_BR) == 0 and math_clamp(br, 0, max_rad) or 0,
		w, h,
		shape_value or 2.2,
		texture and 1 or 0,
		thickness or -1,
		0
	)

	if bit_band(flags, MANUAL_COLOR) == 0 then
		if col then
			surface_SetDrawColor(col.r, col.g, col.b, col.a)
		else
			surface_SetDrawColor(255, 255, 255, 255)
		end
	end

	surface_SetMaterial(mat)
	-- https://github.com/Jaffies/rboxes/blob/main/rboxes.lua
	-- fixes setting $basetexture to ""(none) not working correctly
	surface_DrawTexturedRectUV(x, y, w, h, -0.015625, -0.015625, 1.015625, 1.015625)
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

function RNDX.DrawCircleTexture(x, y, r, col, texture, flags)
	RNDX.DrawTexture(r / 2, x - r / 2, y - r / 2, r, r, col, texture, (flags or 0) + SHAPE_CIRCLE)
end

function RNDX.DrawCircleMaterial(x, y, r, col, mat, flags)
	RNDX.DrawMaterial(r / 2, x - r / 2, y - r / 2, r, r, col, mat, (flags or 0) + SHAPE_CIRCLE)
end

local USE_SHADOWS_BLUR = false
local SHADOWS_AA = 0
function RNDX.DrawBlur(x, y, w, h, flags, tl, tr, bl, br, thickness)
	if not flags then
		flags = DEFAULT_DRAW_FLAGS
	end

	local aa = 0
	local mat; if USE_SHADOWS_BLUR then
		mat = SHADOWS_BLUR_MAT
		aa = SHADOWS_AA
	else
		mat = ROUNDED_BLUR_MAT
	end

	local max_rad = math_min(w, h) / 2
	local shape_value = SHAPES[bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)]
	SetParams(
		mat,
		bit_band(flags, NO_TL) == 0 and math_clamp(tl, 0, max_rad) or 0,
		bit_band(flags, NO_TR) == 0 and math_clamp(tr, 0, max_rad) or 0,
		bit_band(flags, NO_BL) == 0 and math_clamp(bl, 0, max_rad) or 0,
		bit_band(flags, NO_BR) == 0 and math_clamp(br, 0, max_rad) or 0,
		w, h,
		shape_value or 2.2,
		0,
		thickness or -1,
		aa
	)

	surface_SetDrawColor(255, 255, 255, 255)
	surface_SetMaterial(mat)

	render_CopyRenderTargetToTexture(BLUR_RT)
	MATERIAL_SetFloat(mat, BLUR_VERTICAL, 0)
	surface_DrawTexturedRect(x, y, w, h)

	render_CopyRenderTargetToTexture(BLUR_RT)
	MATERIAL_SetFloat(mat, BLUR_VERTICAL, 1)
	surface_DrawTexturedRect(x, y, w, h)
end

function RNDX.DrawShadowsEx(x, y, w, h, col, flags, tl, tr, bl, br, spread, intensity, thickness)
	if col and col.a == 0 then
		return
	end

	if not flags then
		flags = DEFAULT_DRAW_FLAGS
	end

	local using_blur = bit_band(flags, BLUR) ~= 0

	-- Shadows are a bit bigger than the actual box
	spread = spread or 30
	intensity = intensity or spread * 1.2

	x = x - spread
	y = y - spread
	w = w + (spread * 2)
	h = h + (spread * 2)

	tl = tl + (spread * 2)
	tr = tr + (spread * 2)
	bl = bl + (spread * 2)
	br = br + (spread * 2)
	--

	local mat = SHADOWS_MAT
	local max_rad = math_min(w, h) / 2
	local shape_value = SHAPES[bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)]
	SetParams(
		mat,
		bit_band(flags, NO_TL) == 0 and math_clamp(tl, 0, max_rad) or 0,
		bit_band(flags, NO_TR) == 0 and math_clamp(tr, 0, max_rad) or 0,
		bit_band(flags, NO_BL) == 0 and math_clamp(bl, 0, max_rad) or 0,
		bit_band(flags, NO_BR) == 0 and math_clamp(br, 0, max_rad) or 0,
		w, h,
		shape_value or 2.2,
		0,
		thickness or -1,
		intensity
	)

	-- if we are inside a panel, we need to draw outside of it
	local old_clipping_state = DisableClipping(true)

	if using_blur then
		SHADOWS_AA = intensity
		USE_SHADOWS_BLUR = true
		RNDX.DrawBlur(x, y, w, h, flags, tl, tr, bl, br, thickness)
		USE_SHADOWS_BLUR = false
	end

	if bit_band(flags, MANUAL_COLOR) == 0 then
		if col then
			surface_SetDrawColor(col.r, col.g, col.b, col.a)
		else
			surface_SetDrawColor(0, 0, 0, 255)
		end
	end

	surface_SetMaterial(mat)
	-- https://github.com/Jaffies/rboxes/blob/main/rboxes.lua
	-- fixes having no $basetexture causing uv to be broken
	surface_DrawTexturedRectUV(x, y, w, h, -0.015625, -0.015625, 1.015625, 1.015625)

	DisableClipping(old_clipping_state)
end

function RNDX.DrawShadows(r, x, y, w, h, col, spread, intensity, flags)
	RNDX.DrawShadowsEx(x, y, w, h, col, flags, r, r, r, r, spread, intensity)
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
RNDX.MANUAL_COLOR = MANUAL_COLOR

function RNDX.SetFlag(flags, flag, bool)
	flag = RNDX[flag] or flag
	if tobool(bool) then
		return bit.bor(flags, flag)
	else
		return bit.band(flags, bit.bnot(flag))
	end
end

return RNDX
