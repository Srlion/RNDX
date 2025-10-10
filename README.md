# 🎨 RNDX

**Draw rounded shapes with ease.**
RNDX is a lightweight and efficient library designed to make drawing rounded shapes simple, fast, and visually stunning.

Using Shader Model 3.0, RNDX provides near-perfect anti-aliasing with no performance hit, allowing you to create beautiful interfaces and visuals with ease.

![Screenshot](thumbnail.png)
![Screenshot](thumbnail2.png)
![Screenshot](sbot.png)

---

## ✨ Why RNDX?

- **Blazing Fast Performance**: Optimized for speed, RNDX is incredibly lightweight and efficient. _(It will get even faster once we [get `mat:SetFloat4()`](https://github.com/Facepunch/garrysmod-requests/issues/2606)!)_
- **Perfect Anti-Aliasing**: Enjoy smooth, pixel-perfect corners with no performance hit.
- **Simple & Intuitive**: No complex objects or states—just call a function and draw!
- **Seamless Integration**: Works flawlessly inside `3D2D` and `Panel:Paint*` functions without any hacks.

---

## 🛠️ Get Started

1. Download `rndx.lua` from [GitHub releases](https://github.com/Srlion/RNDX/releases/latest).
2. Add `rndx.lua` to your project.
3. Run `include` on `rndx.lua`. (It's already calls `AddCSLuaFile` for you!)
4. Voilà! You're ready to draw rounded shapes with ease. 🎉

---

## 📐 Usage

### Simple Rounded Rect

```lua
RNDX().Rect(50, 50, 300, 100)
    :Rad(12)
    :Color(30, 30, 30, 220)
:Draw()
```

### Material Rect

```lua
local mat = Material("vgui/gradient-r")
RNDX().Rect(100, 100, 256, 128)
    :Material(mat)
    :Rad(16)
:Draw()
```

### Blur

```lua
RNDX().Rect(200, 200, 200, 100)
    :Rad(8)
    :Blur(1.5)
    :Color(255, 255, 255)
:Draw()
```

### Circles

```lua
RNDX().Circle(200, 200, 80)
    :Color(100, 160, 255)
:Draw()

RNDX().Circle(400, 200, 80)
    :Color(255, 80, 120, 180)
    :Outline(5)
:Draw()
```

### Per-corner Radii

```lua
RNDX().Rect(10, 10, 200, 100)
    :Radii(10, 20, 30, 40)
    :Color(0, 120, 200)
:Draw()
```

---

## 📚 Documentation

### Flags

- **`RNDX.NO_TL`** – Disable top-left corner.
- **`RNDX.NO_TR`** – Disable top-right corner.
- **`RNDX.NO_BL`** – Disable bottom-left corner.
- **`RNDX.NO_BR`** – Disable bottom-right corner.
- **`RNDX.BLUR`** – Enable blur rendering.

---

### Shapes

- **`RNDX.SHAPE_CIRCLE`**
- **`RNDX.SHAPE_FIGMA`** _(Default)_
- **`RNDX.SHAPE_IOS`**

![Screenshot](shapes.jpg)

---

### Chain API Reference

| Method                                    | Description                                             |
| ----------------------------------------- | ------------------------------------------------------- |
| `:Rad(radius)`                            | Set a uniform corner radius.                            |
| `:Radii(tl, tr, bl, br)`                  | Set per-corner radii.                                   |
| `:Color(r, g, b, a)`                      | Set the color.                                          |
| `:Texture(texture)`                       | Use a texture.                                          |
| `:Material(material)`                     | Extracts the base texture from a Material.              |
| `:Outline(thickness)`                     | Draw as outline with given thickness.                   |
| `:Blur(intensity)`                        | Apply two-pass blur.                                    |
| `:Shadow(spread, intensity)`              | Draw soft shadow under the shape.                       |
| `:Shape(shape)`                           | Choose shape algorithm (`SHAPE_CIRCLE`, etc).           |
| `:Rotation(angle)`                        | Rotate shape by given angle.                            |
| `:StartAngle(angle)` / `:EndAngle(angle)` | Render only arc segment of circle/rect.                 |
| `:Flags(flags)`                           | Apply bitwise flag combinations.                        |
| `:Draw()`                                 | Render the shape.                                       |
| `:GetMaterial()`                          | Return internal material (error if blur/shadow active). |
| `:Clip(panel)`                            | Clip rendering within a specific panel.                 |

---

### Legacy Function API

```lua
local RNDX = include("rndx.lua")
hook.Add("HUDPaint", "RNDX Example", function()
    local flags = RNDX.NO_TL + RNDX.NO_TR + RNDX.SHAPE_IOS
    RNDX.Draw(10, 100, 100, 200, 200, nil, flags + RNDX.BLUR)
    RNDX.Draw(10, 100, 100, 200, 200, Color(255, 0, 0, 150), flags)
    RNDX.DrawOutlined(10, 100, 100, 200, 200, Color(0, 255, 0), 10, flags)
end)
```

---

## 🚀 Why Choose RNDX Over Alternatives?

| Feature           | RNDX                            | [Circles](https://github.com/SneakySquid/Circles) | [paint](https://github.com/Jaffies/paint) | [melonstuff](https://github.com/melonstuff) |
| ----------------- | ------------------------------- | ------------------------------------------------- | ----------------------------------------- | ------------------------------------------- |
| **Speed**         | ⚡ Extremely Fast               | 🐌 Slow with many circles                         | ⚡ Fast                                   | 🐌 Slow                                     |
| **Anti-Aliasing** | ✅ Perfect, no performance cost | ❌ None                                           | ❌ Poor (Source Engine AA)                | ❌ None                                     |
| **Ease of Use**   | 🎯 Simple & Minimal             | 🎯 Simple                                         | 🧩 Complex & Bloated                      | 🎯 Easy                                     |
| **Documentation** | 📖 Clear & Concise              | 📖 Good                                           | ❌ Overwhelming & Undocumented            | 📖 Good                                     |

---

## Benchmarks

Benchmarking has to be done with FPS meter, not checking how long CPU takes to draw.

#### Rounded Shapes

```lua
local RNDX = include("rndx.lua")
local draw_RoundedBox = draw.RoundedBox
local col = Color(0, 0, 0, 255)
hook.Add("HUDPaint", "my_shader_draw", function()
    for i = 1, 3000 do
        RNDX.Draw(20, 20, 20, 200, 200, col)
        -- draw_RoundedBox(20, 20, 20, 200, 200, col)
    end
end)
```

- `RNDX`: 140 FPS
- `draw.RoundedBox`: 43 FPS

#### Blur

150 Calls
`x y w h` of `10, 10, 700, 700`

- `Current RNDX`: 107 fps
- `Previous RNDX`: 73 fps
- https://pastebin.com/urx4Qvez : 59 fps

---

## 📜 License

RNDX is open-source and free to use. Feel free to contribute or report issues on GitHub!

Make sure to give credits!

---

## 🌟 Credits

- [ficool2](https://github.com/ficool2) - For [sdk_screenspace_shaders](https://github.com/ficool2/sdk_screenspace_shaders) & finding out that we can use shaders in source engine games!
- [Rubat](https://github.com/robotboy655) - For allowing us to use shaders in Garry's Mod!
- [Svetov/Jaffies/FriendlyStealer](https://github.com/Jaffies) - For lots of help throughout the development of RNDX! Also suggested multiple stuff to improve the performance!
- [Shadertoy Rounded Code](https://www.shadertoy.com/view/fsdyzB)
- [Shadertoy Blur Code](https://www.shadertoy.com/view/Xd33Rf)
- And AI because I don't understand how shaders work!

**RNDX**: Because drawing rounded shapes should be simple, fast, and beautiful. 🎉
