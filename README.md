# 🇵🇸 RNDX 🇵🇸

**Draw rounded shapes with ease.**

Shader-powered drawing library for Garry's Mod. Rounded boxes, circles, outlines, blur and CSS-style shadows — with near-perfect anti-aliasing and no performance hit.

![Screenshot](.github/images/thumbnail.png)
![Screenshot](.github/images/thumbnail2.png)
![Screenshot](.github/images/sbot.png)

## Install

1. Download `rndx.lua` from [releases](https://github.com/Srlion/RNDX/releases/latest).
2. Put it in your project.
3. `local RNDX = include("rndx.lua")` — `AddCSLuaFile` is called for you.

## Usage

```lua
local RNDX = include("rndx.lua")

hook.Add("HUDPaint", "RNDX Example", function()
    RNDX.Rect(100, 100, 200, 100)
        :Rad(16)
        :Color(30, 30, 30)
        :Draw()

    -- shadow: blur, spread, offset x, offset y (like css box-shadow)
    RNDX.Rect(350, 100, 200, 100)
        :Rad(16)
        :Color(40, 40, 45)
        :Shadow(24, 0, 0, 8)
        :Draw()

    -- frosted glass
    RNDX.Rect(600, 100, 200, 100)
        :Rad(16)
        :Blur(2)
        :Draw()

    RNDX.Circle(200, 400, 80)
        :Color(255, 100, 100)
        :Outline(4)
        :Draw()
end)
```

## API

`RNDX.Rect(x, y, w, h)` and `RNDX.Circle(x, y, radius)` return a builder. Chain methods, end with `:Draw()`.

> [!NOTE]
> Chaining is free — no objects are created, the builder writes to shared state. So build and `:Draw()` in one go, don't store builders for later.

| Method | Description |
| --- | --- |
| `:Rad(r)` | Corner radius (Rect only) |
| `:Radii(tl = 0, tr = 0, bl = 0, br = 0)` | Per-corner radii (Rect only) |
| `:Color(col)` / `:Color(r, g, b, a = 255)` | Fill color |
| `:ManualColor()` | Skip color setting, use your own `surface.SetDrawColor` |
| `:Outline(thickness = 1)` | Outline instead of fill |
| `:Texture(tex)` | Textured fill |
| `:Material(mat)` | Textured fill from a material |
| `:Blur(intensity = 1)` | Backdrop blur |
| `:Shadow(blur = 20, spread = 0, ox = 0, oy = 0)` | CSS-style shadow, defaults to black |
| `:Shape(shape)` | `RNDX.SHAPE_CIRCLE` / `RNDX.SHAPE_FIGMA` (default) / `RNDX.SHAPE_IOS` |
| `:Rotation(deg = 0)` | Rotate the shape |
| `:Angles(start_deg = 0, end_deg = 360)` | Draw an arc/pie segment |
| `:Clip(panel)` | Clip to a panel |
| `:Draw()` | Draw it |

![Screenshot](.github/images/shapes.jpg)

Defaults:

```lua
RNDX.SetDefaultShape(RNDX.SHAPE_IOS)
RNDX.SetDefaultBlurIntensity(3)
RNDX.SetLegacyGamma(true) -- match gmod's default (broken) gamma, so colors look the same as draw.RoundedBox & other addons
```

## Showcase

![Showcase](.github/images/showcase.webm)

```lua
surface.CreateFont("RNDX_Label", {
    font = "Roboto",
    size = 18,
    weight = 500,
})

local function label(text, x, w, y)
    draw.SimpleText(text, "RNDX_Label", x + w / 2, y, color_white, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "RNDX_Showcase", function()
    local t = CurTime()

    -- row 1: radii
    RNDX.Rect(50, 50, 150, 100):Rad(0):Color(60, 60, 70):Draw()
    label("Rad(0)", 50, 150, 158)

    RNDX.Rect(230, 50, 150, 100):Rad(16):Color(80, 120, 200):Draw()
    label("Rad(16)", 230, 150, 158)

    RNDX.Rect(410, 50, 150, 100):Rad(math.huge):Color(200, 80, 120):Draw()
    label("Rad(math.huge)", 410, 150, 158)

    RNDX.Rect(590, 50, 150, 100):Radii(40, 0, 0, 40):Color(80, 200, 140):Draw()
    label("Radii(40, 0, 0, 40)", 590, 150, 158)

    RNDX.Rect(770, 50, 150, 100):Rad(20):Color(255, 255, 255):Outline(3):Draw()
    label("Outline(3)", 770, 150, 158)

    -- row 2: corner shapes, same radius
    RNDX.Rect(50, 210, 150, 100):Rad(40):Shape(RNDX.SHAPE_CIRCLE):Color(220, 160, 60):Draw()
    label("SHAPE_CIRCLE", 50, 150, 318)

    RNDX.Rect(230, 210, 150, 100):Rad(40):Shape(RNDX.SHAPE_FIGMA):Color(220, 160, 60):Draw()
    label("SHAPE_FIGMA", 230, 150, 318)

    RNDX.Rect(410, 210, 150, 100):Rad(40):Shape(RNDX.SHAPE_IOS):Color(220, 160, 60):Draw()
    label("SHAPE_IOS", 410, 150, 318)

    -- row 3: shadows
    RNDX.Rect(50, 380, 180, 120):Rad(16):Shadow(40):Draw()
    RNDX.Rect(50, 380, 180, 120):Rad(16):Color(40, 40, 48):Draw()
    label("Shadow(40)", 50, 180, 530)

    RNDX.Rect(280, 380, 180, 120):Rad(16):Shadow(8, 0, 6, 6):Draw()
    RNDX.Rect(280, 380, 180, 120):Rad(16):Color(40, 40, 48):Draw()
    label("Shadow(8, 0, 6, 6)", 280, 180, 530)

    RNDX.Rect(510, 380, 180, 120):Rad(16):Color(0, 0, 0, 100):Shadow(15, -3, 0, 10):Draw()
    RNDX.Rect(510, 380, 180, 120):Rad(16):Color(40, 40, 48):Draw()
    label("Shadow(15, -3, 0, 10)", 510, 180, 530)

    RNDX.Rect(740, 380, 180, 120):Rad(16):Color(255, 60, 60, 180):Shadow(30):Draw()
    RNDX.Rect(740, 380, 180, 120):Rad(16):Color(50, 30, 30):Draw()
    label("Colored glow", 740, 180, 530)

    local pulse = 15 + math.sin(t * 2) * 10
    RNDX.Rect(970, 380, 180, 120):Rad(16):Color(100, 200, 255, 200):Shadow(pulse):Draw()
    RNDX.Rect(970, 380, 180, 120):Rad(16):Color(30, 40, 50):Draw()
    label("Animated shadow", 970, 180, 530)

    -- row 4: blur
    RNDX.Rect(50, 590, 200, 120):Rad(20):Blur():Draw()
    label("Blur()", 50, 200, 718)

    RNDX.Rect(280, 590, 200, 120):Rad(20):Blur(3):Draw()
    label("Blur(3)", 280, 200, 718)

    RNDX.Rect(510, 590, 200, 120):Rad(20):Blur(2):Draw()
    RNDX.Rect(510, 590, 200, 120):Rad(20):Color(255, 255, 255, 30):Outline(1):Draw()
    label("Glass card", 510, 200, 718)

    -- row 5: circles & animation
    RNDX.Circle(830, 650, 50):Color(120, 180, 255):Draw()
    label("Circle", 780, 100, 718)

    RNDX.Circle(950, 650, 50):Color(255, 255, 255):Outline(6):Draw()
    label("Outline", 900, 100, 718)

    RNDX.Circle(200, 810, 40)
        :Color(255, 255, 255)
        :Outline(6)
        :Angles(0, 270)
        :Rotation(t * 360 % 360)
        :Draw()
    label("Spinner", 160, 80, 868)

    RNDX.Rect(320, 770, 80, 80)
        :Rad(24)
        :Shape(RNDX.SHAPE_IOS)
        :Color(200, 120, 255)
        :Rotation(t * 60 % 360)
        :Draw()
    label("Rotation", 320, 80, 868)

    -- pacman
    local chomp = math.abs(math.sin(t * 6)) * 40 + 5
    RNDX.Circle(520, 810, 45)
        :Color(255, 220, 40)
        :Angles(chomp, 360 - chomp)
        :Draw()

    local px = (t * 80) % 200
    for i = 0, 3 do
        local dot_x = 580 + i * 50 - px
        if dot_x > 535 then
            RNDX.Circle(dot_x, 810, 8):Color(255, 255, 255):Draw()
        end
    end
    label("pacman", 480, 80, 868)
end)
```

## Benchmarks (OLD)

Benchmark with an FPS meter, not CPU frame time.

3000 rounded boxes per frame:

- RNDX: 140 FPS
- draw.RoundedBox: 43 FPS

150 blur panels (700x700):

- Current RNDX: 107 FPS
- Previous RNDX: 73 FPS
- <https://pastebin.com/urx4Qvez>: 59 FPS

## Credits

- [ficool2](https://github.com/ficool2) - [sdk_screenspace_shaders](https://github.com/ficool2/sdk_screenspace_shaders) & finding out we can use shaders in source games
- [Rubat](https://github.com/robotboy655) - for allowing shaders in Garry's Mod
- [Svetov/Jaffies](https://github.com/Jaffies) - lots of help & performance ideas
- [Shadertoy rounded box](https://www.shadertoy.com/view/fsdyzB), [Shadertoy blur](https://www.shadertoy.com/view/Xd33Rf), [Evan Wallace's shadow math](https://madebyevan.com/shaders/fast-rounded-rectangle-shadows/)
- And AI because I don't understand how shaders work!

## License

MIT. Make sure to give credits!
