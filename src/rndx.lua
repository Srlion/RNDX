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
local math_ceil = math.ceil
local DisableClipping = DisableClipping
local type = type
local tobool = tobool

local RNDX = {}

---------------------------------------------------------------------------
-- SHADERS
---------------------------------------------------------------------------

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

local BLUR_RT = GetRenderTargetEx("RNDX" .. SHADERS_VERSION .. SysTime(),
	1024, 1024,
	RT_SIZE_LITERAL,
	MATERIAL_RT_DEPTH_SEPARATE,
	bit.bor(2, 256, 4, 8 --[[4, 8 is clamp_s + clamp-t]]),
	0,
	IMAGE_FORMAT_BGRA8888
)

---------------------------------------------------------------------------
-- FLAGS & CONSTANTS
---------------------------------------------------------------------------

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
local MANUAL_COLOR                         = NEW_FLAG()

local SHAPES                               = {
	[SHAPE_CIRCLE] = 2,
	[SHAPE_FIGMA] = 2.2,
	[SHAPE_IOS] = 4,
}

local DEFAULT_SHAPE                        = SHAPE_FIGMA
local DEFAULT_BLUR_INTENSITY               = 1.0

local BLUR_VERTICAL                        = "$c0_x"
local SHADOW_OX_C, SHADOW_OY_C             = "$c0_y", "$c0_z"

---------------------------------------------------------------------------
-- MATERIALS
---------------------------------------------------------------------------

local BASE_VMT                             = [==[
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
}
]==]

-- correct gamma mode only: disables gmod's broken gamma correction
local LINEAR_KVS                           = {
	["$linearwrite"] = 1,
	["$linearread_basetexture"] = 1,
	["$linearread_texture1"] = 1,
	["$linearread_texture2"] = 1,
	["$linearread_texture3"] = 1,
}

local MATRIXES                             = {}

local function create_shader_mat(name, opts)
	assert(name and isstring(name), "create_shader_mat: tex must be a string")
	local key_values = util.KeyValuesToTable(BASE_VMT, false, true)
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

-- legacy gamma: emulate gmod's normal (broken) gamma so colors match
-- draw.RoundedBox & other addons; gamma is applied in the vertex shader instead
local LEGACY_GAMMA = false

local ROUNDED_MAT, ROUNDED_TEXTURE_MAT, ROUNDED_BLUR_MAT, SHADOWS_MAT, SHADOWS_BLUR_MAT

local function create_materials()
	local vs = GET_SHADER(LEGACY_GAMMA and "rndx_vertex_gamma_vs30" or "rndx_vertex_vs30")
	local suffix = LEGACY_GAMMA and "_gamma" or ""

	local function make(name, opts)
		if not LEGACY_GAMMA then
			for k, v in pairs(LINEAR_KVS) do
				opts[k] = v
			end
		end
		opts["$vertexshader"] = vs
		return create_shader_mat(name .. suffix, opts)
	end

	ROUNDED_MAT = make("rounded", {
		["$pixshader"] = GET_SHADER("rndx_rounded_ps30"),
	})
	ROUNDED_TEXTURE_MAT = make("rounded_texture", {
		["$pixshader"] = GET_SHADER("rndx_rounded_ps30"),
		["$basetexture"] = "loveyoumom", -- if there is no base texture, you can't change it later
	})
	ROUNDED_BLUR_MAT = make("blur_horizontal", {
		["$pixshader"] = GET_SHADER("rndx_rounded_blur_ps30"),
		["$basetexture"] = BLUR_RT:GetName(),
		["$texture1"] = "_rt_FullFrameFB",
	})
	SHADOWS_MAT = make("rounded_shadows", {
		["$pixshader"] = GET_SHADER("rndx_shadows_ps30"),
	})
	SHADOWS_BLUR_MAT = make("shadows_blur_horizontal", {
		["$pixshader"] = GET_SHADER("rndx_shadows_blur_ps30"),
		["$basetexture"] = BLUR_RT:GetName(),
		["$texture1"] = "_rt_FullFrameFB",
	})
end

create_materials()

local MATERIAL_SetTexture = ROUNDED_MAT.SetTexture
local MATERIAL_SetMatrix = ROUNDED_MAT.SetMatrix
local MATERIAL_SetFloat = ROUNDED_MAT.SetFloat
local MATRIX_SetUnpacked = Matrix().SetUnpacked

---------------------------------------------------------------------------
-- DRAW STATE
---------------------------------------------------------------------------

local MAT
local X, Y, W, H
local TL, TR, BL, BR
local TEXTURE
local USING_BLUR, BLUR_INTENSITY
local COL_SET, COL_R, COL_G, COL_B, COL_A
local SHAPE, OUTLINE_THICKNESS
local START_ANGLE, END_ANGLE, ROTATION
local CLIP_PANEL
local SHADOW_ENABLED, SHADOW_BLUR, SHADOW_SPREAD, SHADOW_OX, SHADOW_OY
local SHADOW_SIGMA, PAD
local RADII_NORMALIZED

local function RESET_PARAMS()
	MAT = nil
	X, Y, W, H = 0, 0, 0, 0
	TL, TR, BL, BR = 0, 0, 0, 0
	TEXTURE = nil
	USING_BLUR, BLUR_INTENSITY = false, DEFAULT_BLUR_INTENSITY
	COL_SET, COL_R, COL_G, COL_B, COL_A = false, 255, 255, 255, 255
	SHAPE, OUTLINE_THICKNESS = SHAPES[DEFAULT_SHAPE], -1
	START_ANGLE, END_ANGLE, ROTATION = 0, 360, 0
	CLIP_PANEL = nil
	SHADOW_ENABLED = false
	SHADOW_BLUR, SHADOW_SPREAD, SHADOW_OX, SHADOW_OY = 0, 0, 0, 0
	SHADOW_SIGMA, PAD = 0, 0
	RADII_NORMALIZED = false
end

---------------------------------------------------------------------------
-- INTERNAL DRAWING
---------------------------------------------------------------------------

local normalize_corner_radii; do
	local HUGE = math.huge

	local function nzr(x)
		if x ~= x or x < 0 then return 0 end
		local lim = math_min(W, H)
		if x == HUGE then return lim end
		return x
	end

	function normalize_corner_radii()
		local TL, TR, BL, BR = nzr(TL), nzr(TR), nzr(BL), nzr(BR)

		local k = math_max(
			1,
			(TL + TR) / W,
			(BL + BR) / W,
			(TL + BL) / H,
			(TR + BR) / H
		)

		if k > 1 then
			local inv = 1 / k
			TL, TR, BL, BR = TL * inv, TR * inv, BL * inv, BR * inv
		end

		return math_max(TL, 0), math_max(TR, 0), math_max(BL, 0), math_max(BR, 0)
	end
end

local function SetupDraw()
	local TL, TR, BL, BR = TL, TR, BL, BR
	if not RADII_NORMALIZED then
		TL, TR, BL, BR = normalize_corner_radii()
	end

	local flags_f = 0
	if TEXTURE then flags_f = flags_f + 1 end -- FLAG_USE_TEXTURE

	local start_rad, sweep_rad
	local sweep = END_ANGLE - START_ANGLE
	if sweep >= 360 then
		start_rad, sweep_rad = 0, -1 -- full circle, shaders skip arc math
	else
		if sweep < 0 then sweep = sweep + 360 end
		start_rad = (START_ANGLE % 360) * 0.017453292519943295
		sweep_rad = sweep * 0.017453292519943295
	end

	local slot_3z = SHADOW_ENABLED and SHADOW_SPREAD or 0

	local matrix = MATRIXES[MAT]
	MATRIX_SetUnpacked(
		matrix,

		BL, W, OUTLINE_THICKNESS or -1, sweep_rad,
		BR, H, SHADOW_SIGMA, ROTATION,
		TR, SHAPE, BLUR_INTENSITY or 1.0, slot_3z,
		TL, flags_f, start_rad, PAD
	)
	MATERIAL_SetMatrix(MAT, "$viewprojmat", matrix)

	if SHADOW_ENABLED then
		MATERIAL_SetFloat(MAT, SHADOW_OX_C, SHADOW_OX)
		MATERIAL_SetFloat(MAT, SHADOW_OY_C, SHADOW_OY)
	end

	if COL_R then
		surface_SetDrawColor(COL_R, COL_G, COL_B, COL_A)
	end

	surface_SetMaterial(MAT)
end

local function draw_blur(shadow)
	MAT = shadow and SHADOWS_BLUR_MAT or ROUNDED_BLUR_MAT

	COL_R, COL_G, COL_B, COL_A = 255, 255, 255, 255
	SetupDraw()

	render_CopyRenderTargetToTexture(BLUR_RT)
	MATERIAL_SetFloat(MAT, BLUR_VERTICAL, 0)
	surface_DrawTexturedRect(X, Y, W, H)

	render_CopyRenderTargetToTexture(BLUR_RT)
	MATERIAL_SetFloat(MAT, BLUR_VERTICAL, 1)
	surface_DrawTexturedRect(X, Y, W, H)
end

local function setup_shadows()
	TL, TR, BL, BR = normalize_corner_radii()
	RADII_NORMALIZED = true

	-- css: negative spread shrinks the box to zero at most, never inverts it
	if SHADOW_SPREAD < 0 then
		local min_half = math_min(W, H) * 0.5
		if -SHADOW_SPREAD > min_half then SHADOW_SPREAD = -min_half end
	end

	-- css-style spread: grow the quad; radii growth happens IN THE SHADER now
	if SHADOW_SPREAD ~= 0 then
		X = X - SHADOW_SPREAD
		Y = Y - SHADOW_SPREAD
		W = W + SHADOW_SPREAD * 2
		H = H + SHADOW_SPREAD * 2
	end

	-- css-style offset
	X = X + SHADOW_OX
	Y = Y + SHADOW_OY
end

local function setup_pad()
	local pad = 0

	if SHADOW_ENABLED then
		local sigma = SHADOW_BLUR * 0.5
		if sigma < 0.0001 then sigma = 0.0001 end
		SHADOW_SIGMA = sigma
		pad = math_ceil(sigma * 3)
	end

	if ROTATION ~= 0 then
		local c = math.abs(math.cos(ROTATION))
		local si = math.abs(math.sin(ROTATION))
		local hw, hh = W * 0.5, H * 0.5
		local extra = math_max(hw * c + hh * si - hw, hw * si + hh * c - hh)
		if extra > 0 then pad = pad + math_ceil(extra) + 2 end
	end

	if pad > 0 then
		X = X - pad
		Y = Y - pad
		W = W + pad * 2
		H = H + pad * 2
	end
	PAD = pad
end

---------------------------------------------------------------------------
-- BUILDER
---------------------------------------------------------------------------

local BASE_FUNCS; BASE_FUNCS = {
	Rad = function(self, rad)
		TL, TR, BL, BR = rad, rad, rad, rad
		return self
	end,
	Radii = function(self, tl, tr, bl, br)
		TL, TR, BL, BR = tl or 0, tr or 0, bl or 0, br or 0
		return self
	end,
	Texture = function(self, texture)
		TEXTURE = texture
		return self
	end,
	Material = function(self, mat)
		local tex = mat:GetTexture("$basetexture")
		if tex then
			TEXTURE = tex
		end
		return self
	end,
	Outline = function(self, thickness)
		OUTLINE_THICKNESS = thickness or 1
		return self
	end,
	Shape = function(self, shape)
		SHAPE = SHAPES[shape] or SHAPES[DEFAULT_SHAPE]
		return self
	end,
	Color = function(self, col_or_r, g, b, a)
		COL_SET = true
		if type(col_or_r) == "number" then
			COL_R, COL_G, COL_B, COL_A = col_or_r, g or 255, b or 255, a or 255
		else
			COL_R, COL_G, COL_B, COL_A = col_or_r.r, col_or_r.g, col_or_r.b, col_or_r.a
		end
		return self
	end,
	ManualColor = function(self)
		COL_SET, COL_R = true, nil
		return self
	end,
	Blur = function(self, intensity)
		if not intensity then
			intensity = DEFAULT_BLUR_INTENSITY
		end
		USING_BLUR, BLUR_INTENSITY = true, math_max(intensity, 0)
		return self
	end,
	Rotation = function(self, angle)
		ROTATION = math.rad(angle or 0)
		return self
	end,
	Angles = function(self, start_angle, end_angle)
		START_ANGLE = start_angle or 0
		END_ANGLE = end_angle or 360
		return self
	end,
	---@deprecated Use Angles(start_angle, end_angle) instead.
	StartAngle = function(self, angle)
		START_ANGLE = angle or 0
		return self
	end,
	---@deprecated Use Angles(start_angle, end_angle) instead.
	EndAngle = function(self, angle)
		END_ANGLE = angle or 360
		return self
	end,
	Shadow = function(self, blur, spread, offset_x, offset_y)
		SHADOW_ENABLED = true
		SHADOW_BLUR = math_max(blur or 20, 0)
		SHADOW_SPREAD = spread or 0
		SHADOW_OX = offset_x or 0
		SHADOW_OY = offset_y or 0
		return self
	end,
	Clip = function(self, pnl)
		CLIP_PANEL = pnl
		return self
	end,
	Flags = function(self, flags)
		flags = flags or 0

		-- Corner flags
		if bit_band(flags, NO_TL) ~= 0 then TL = 0 end
		if bit_band(flags, NO_TR) ~= 0 then TR = 0 end
		if bit_band(flags, NO_BL) ~= 0 then BL = 0 end
		if bit_band(flags, NO_BR) ~= 0 then BR = 0 end

		-- Shape flags
		local shape_flag = bit_band(flags, SHAPE_CIRCLE + SHAPE_FIGMA + SHAPE_IOS)
		if shape_flag ~= 0 then
			SHAPE = SHAPES[shape_flag] or SHAPES[DEFAULT_SHAPE]
		end

		-- Blur flag
		if bit_band(flags, BLUR) ~= 0 then
			BASE_FUNCS.Blur(self)
		end

		-- Manual color flag
		if bit_band(flags, MANUAL_COLOR) ~= 0 then
			COL_R = nil
		end

		return self
	end,

	Draw = function(self)
		if END_ANGLE == START_ANGLE then
			return -- nothing to draw
		end

		local OLD_CLIPPING_STATE
		if SHADOW_ENABLED or CLIP_PANEL then
			-- if we are inside a panel, we need to draw outside of it
			OLD_CLIPPING_STATE = DisableClipping(true)
		end

		if CLIP_PANEL then
			local sx, sy = CLIP_PANEL:LocalToScreen(0, 0)
			local sw, sh = CLIP_PANEL:GetSize()
			render.SetScissorRect(sx, sy, sx + sw, sy + sh, true)
		end

		if SHADOW_ENABLED then
			if not COL_SET then
				COL_R, COL_G, COL_B, COL_A = 0, 0, 0, 255 -- shadows default to black
			end
			setup_shadows()
			setup_pad()

			if USING_BLUR then
				local r, g, b, a = COL_R, COL_G, COL_B, COL_A
				draw_blur(true)
				COL_R, COL_G, COL_B, COL_A = r, g, b, a
			end

			MAT = SHADOWS_MAT
			SetupDraw()
			surface_DrawTexturedRectUV(X, Y, W, H, -0.015625, -0.015625, 1.015625, 1.015625)
		elseif USING_BLUR then
			setup_pad()
			draw_blur()
		else
			setup_pad()
			if TEXTURE then
				MAT = ROUNDED_TEXTURE_MAT
				MATERIAL_SetTexture(MAT, "$basetexture", TEXTURE)
			end

			SetupDraw()
			-- https://github.com/Jaffies/rboxes/blob/main/rboxes.lua
			-- fixes setting $basetexture to ""(none) not working correctly
			surface_DrawTexturedRectUV(X, Y, W, H, -0.015625, -0.015625, 1.015625, 1.015625)
		end

		if CLIP_PANEL then
			render.SetScissorRect(0, 0, 0, 0, false)
		end

		if SHADOW_ENABLED or CLIP_PANEL then
			DisableClipping(OLD_CLIPPING_STATE)
		end
	end,

	GetMaterial = function(self)
		if SHADOW_ENABLED or USING_BLUR then
			error("You can't get the material of a shadowed or blurred rectangle!")
		end

		setup_pad()

		if TEXTURE then
			MAT = ROUNDED_TEXTURE_MAT
			MATERIAL_SetTexture(MAT, "$basetexture", TEXTURE)
		end
		SetupDraw()

		return MAT, X, Y, W, H
	end,
}

local RECT, CIRCLE = {}, {}
for k, v in pairs(BASE_FUNCS) do
	RECT[k] = v
	-- circles don't have corner radii
	if k ~= "Rad" and k ~= "Radii" then
		CIRCLE[k] = v
	end
end

---------------------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------------------

function RNDX.Rect(x, y, w, h)
	RESET_PARAMS()
	MAT = ROUNDED_MAT
	X, Y, W, H = x, y, w, h
	return RECT
end

function RNDX.Circle(x, y, radius)
	RESET_PARAMS()
	MAT = ROUNDED_MAT
	SHAPE = SHAPES[SHAPE_CIRCLE]
	local d = radius * 2
	X, Y, W, H = x - radius, y - radius, d, d
	TL, TR, BL, BR = radius, radius, radius, radius
	return CIRCLE
end

-- match gmod's default (broken) gamma so colors look the same as
-- draw.RoundedBox & other addons
function RNDX.SetLegacyGamma(enabled)
	enabled = tobool(enabled)
	if enabled == LEGACY_GAMMA then return end
	LEGACY_GAMMA = enabled
	create_materials()
end

function RNDX.SetDefaultShape(shape)
	DEFAULT_SHAPE = shape or SHAPE_FIGMA
end

function RNDX.SetDefaultBlurIntensity(val)
	DEFAULT_BLUR_INTENSITY = math_max(0, tonumber(val) or 1.0)
end

function RNDX.GetDefaultBlurIntensity()
	return DEFAULT_BLUR_INTENSITY
end

-- Flags for :Flags()
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

---------------------------------------------------------------------------
-- LEGACY API (deprecated, kept for backwards compatibility)
---------------------------------------------------------------------------

---@deprecated Use RNDX.Rect(x, y, w, h):Rad(r):Color(col):Draw() instead.
function RNDX.Draw(r, x, y, w, h, col, flags)
	if col and col.a == 0 then return end
	local rect = RNDX.Rect(x, y, w, h):Rad(r)
	if col then rect:Color(col) end
	if flags then rect:Flags(flags) end
	rect:Draw()
end

---@deprecated Use RNDX.Rect(...):Rad(r):Outline(thickness):Draw() instead.
function RNDX.DrawOutlined(r, x, y, w, h, col, thickness, flags)
	if col and col.a == 0 then return end
	local rect = RNDX.Rect(x, y, w, h):Rad(r):Outline(thickness or 1)
	if col then rect:Color(col) end
	if flags then rect:Flags(flags) end
	rect:Draw()
end

---@deprecated Use RNDX.Rect(...):Rad(r):Texture(texture):Draw() instead.
function RNDX.DrawTexture(r, x, y, w, h, col, texture, flags)
	if col and col.a == 0 then return end
	local rect = RNDX.Rect(x, y, w, h):Rad(r):Texture(texture)
	if col then rect:Color(col) end
	if flags then rect:Flags(flags) end
	rect:Draw()
end

---@deprecated Use RNDX.Rect(...):Rad(r):Material(mat):Draw() instead.
function RNDX.DrawMaterial(r, x, y, w, h, col, mat, flags)
	local tex = mat:GetTexture("$basetexture")
	if tex then
		return RNDX.DrawTexture(r, x, y, w, h, col, tex, flags)
	end
end

---@deprecated Use RNDX.Circle(x, y, radius):Draw() instead. NOTE: legacy `r` is a DIAMETER, new API takes a RADIUS.
function RNDX.DrawCircle(x, y, r, col, flags)
	if col and col.a == 0 then return end
	local c = RNDX.Circle(x, y, r / 2)
	if col then c:Color(col) end
	if flags then c:Flags(flags) end
	c:Draw()
end

---@deprecated Use RNDX.Circle(x, y, radius):Outline(thickness):Draw() instead. Legacy `r` is a DIAMETER.
function RNDX.DrawCircleOutlined(x, y, r, col, thickness, flags)
	if col and col.a == 0 then return end
	local c = RNDX.Circle(x, y, r / 2):Outline(thickness or 1)
	if col then c:Color(col) end
	if flags then c:Flags(flags) end
	c:Draw()
end

---@deprecated Use RNDX.Circle(x, y, radius):Texture(texture):Draw() instead. Legacy `r` is a DIAMETER.
function RNDX.DrawCircleTexture(x, y, r, col, texture, flags)
	if col and col.a == 0 then return end
	local c = RNDX.Circle(x, y, r / 2):Texture(texture)
	if col then c:Color(col) end
	if flags then c:Flags(flags) end
	c:Draw()
end

---@deprecated Use RNDX.Circle(x, y, radius):Material(mat):Draw() instead. Legacy `r` is a DIAMETER.
function RNDX.DrawCircleMaterial(x, y, r, col, mat, flags)
	if col and col.a == 0 then return end
	local c = RNDX.Circle(x, y, r / 2):Material(mat)
	if col then c:Color(col) end
	if flags then c:Flags(flags) end
	c:Draw()
end

---@deprecated Use RNDX.Rect(...):Radii(tl, tr, bl, br):Blur(intensity):Draw() instead.
function RNDX.DrawBlur(x, y, w, h, flags, tl, tr, bl, br, thickness)
	local rect = RNDX.Rect(x, y, w, h):Radii(tl, tr, bl, br):Blur()
	if thickness then rect:Outline(thickness) end
	if flags then rect:Flags(flags) end
	rect:Draw()
end

---@deprecated Use RNDX.Rect(...):Radii(...):Shadow(blur, spread, ox, oy):Draw() instead. Visuals are approximated, not identical.
function RNDX.DrawShadowsEx(x, y, w, h, col, flags, tl, tr, bl, br, spread, intensity, thickness)
	if col and col.a == 0 then return end
	spread = spread or 30
	local rect = RNDX.Rect(x, y, w, h)
		:Radii(tl, tr, bl, br)
		:Shadow(intensity or (spread * 1.2), spread)
	if thickness then rect:Outline(thickness) end
	if col then rect:Color(col) end
	if flags then rect:Flags(flags) end
	rect:Draw()
end

---@deprecated Use RNDX.Rect(...):Rad(r):Shadow(blur, spread, ox, oy):Draw() instead. Visuals are approximated, not identical.
function RNDX.DrawShadows(r, x, y, w, h, col, spread, intensity, flags)
	return RNDX.DrawShadowsEx(x, y, w, h, col, flags, r, r, r, r, spread, intensity)
end

---@deprecated Use RNDX.Rect(...):Rad(r):Outline(thickness):Shadow(...):Draw() instead. Visuals are approximated, not identical.
function RNDX.DrawShadowsOutlined(r, x, y, w, h, col, thickness, spread, intensity, flags)
	return RNDX.DrawShadowsEx(x, y, w, h, col, flags, r, r, r, r, spread, intensity, thickness or 1)
end

-- Legacy RNDX() call style
local LEGACY_TYPES = {
	Rect = RNDX.Rect,
	---@deprecated Legacy Circle(x, y, size) treats `size` as a DIAMETER; RNDX.Circle takes a radius.
	Circle = function(x, y, r)
		return RNDX.Circle(x, y, r / 2)
	end,
}

setmetatable(RNDX, {
	---@deprecated Use RNDX.Rect(...) / RNDX.Circle(...) directly instead of RNDX().Rect(...).
	__call = function()
		return LEGACY_TYPES
	end
})

return RNDX
