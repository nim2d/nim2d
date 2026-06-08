# Drawing

All drawing happens inside the `draw` callback. The window has already cleared to the background color by the time `draw` runs, so you just paint on top.

## Color

`setColor` sets the color used by every shape and by text until you change it. The alpha argument is optional and defaults to fully opaque.

```nim
nim2d.setColor(255, 120, 60)        # opaque orange
nim2d.setColor(255, 120, 60, 128)   # half transparent
```

`setBackgroundColor` changes the color the window clears to each frame.

## Transforms

Every shape, image and bit of text you draw goes through the current transform, so instead of working out rotated or scaled coordinates yourself you move the coordinate system and draw at simple positions. `translate` shifts the origin, `rotate` turns it by an angle in radians, `scale` stretches it, and `shear` slants it. `origin` resets back to no transform.

`push` saves the current transform and `pop` restores it, so you can change things locally and undo them. They nest, which is what makes it easy to build a thing out of parts that each have their own position and spin.

```nim
n2d.draw = proc(nim2d: Nim2d) =
  nim2d.push()
  nim2d.translate(400, 300)   # move to the center
  nim2d.rotate(angle)         # everything below is rotated
  nim2d.setColor(255, 200, 90)
  nim2d.rectangle(-40, -40, 80, 80, true)   # drawn around the new origin
  nim2d.pop()                 # back to where we were
```

The transform resets to the identity at the start of every frame, so you always begin `draw` in plain screen coordinates.

## Shapes

There is a small set of shape calls. Each one takes a `filled` flag that defaults to false, so by default you get an outline and with `true` you get a solid fill.

```nim
nim2d.circle(x, y, radius, filled = true)
nim2d.ellipse(x, y, radiusX, radiusY, filled = true)
nim2d.rectangle(x, y, width, height, filled = true)
nim2d.rectangle(x, y, width, height, filled = true, roundness = 12)
nim2d.triangle(x1, y1, x2, y2, x3, y3, filled = true)
nim2d.polygon([x0, x1, x2], [y0, y1, y2], filled = true)
nim2d.line(@[(x0, y0), (x1, y1), (x2, y2)], width = 2)
nim2d.points(@[(x0, y0), (x1, y1)], size = 3)
```

`arc` draws part of a circle outline between two angles, and `pie` does the same as a filled wedge. Angles are in radians, measured clockwise from the right because y points down.

```nim
nim2d.arc(x, y, radius, startAngle, endAngle)
nim2d.pie(x, y, radius, startAngle, endAngle, filled = true)
```

Curved shapes take an optional `segments` count if you want them smoother or cheaper. The fill for `polygon` works for any simple outline. Concave shapes are split into triangles by ear clipping, so a star or an arrow fills correctly, not just convex ones.

## Blend modes

`setBlendMode` controls how what you draw mixes with what is already there. The default is normal alpha blending. Passing `"add"` makes overlapping colors brighter, which is what you want for glow, fire and sparks. `"multiply"` darkens. Passing anything else turns blending off.

```nim
nim2d.setBlendMode("add")
# draw glowing things
nim2d.setBlendMode("blend")   # back to normal
```

## Images

Load an image once, usually before the loop or in `load`, and draw it many times.

```nim
let sprite = n2d.newImage("player.png")

n2d.draw = proc(nim2d: Nim2d) =
  sprite.draw(nim2d, 100, 80)
```

`draw` takes a position and a few optional arguments for rotation, scale and origin. The angle is in radians. The scale is separate for x and y. The origin is the point inside the image that sits at the position you gave and that rotation turns around, so passing half the width and height spins the image about its center.

```nim
let (w, h) = sprite.getDimensions
sprite.draw(nim2d, x, y, angle, 0.5, 0.5, w.float / 2, h.float / 2)
```

You can tint an image with `setColorMod` and fade it with `setAlphaMod`. There are also `getWidth`, `getHeight` and `getDimensions`.

By default an image is sampled smoothly, which is right for photos and high-resolution art but blurs pixel art when you scale it up. Call `setFilter(filNearest)` for sharp, blocky sampling that keeps pixel art crisp, or `setFilter(filLinear)` to go back. `setWrap` controls what happens when texcoords run outside the image, which comes up when you draw a quad larger than the texture: `wrapClamp` holds the edge pixel (the default), `wrapRepeat` tiles the image, and `wrapMirror` tiles it flipping every other copy. Both settings apply to canvases as well.

## Pixel data

Most of the time you load images from files, but you can also build one in memory a pixel at a time. An `ImageData` is a buffer of RGBA bytes on the CPU. Make one blank, filled with a color, or loaded from a file, read and write single pixels with `getPixel` and `setPixel`, and use `mapPixel` to set every pixel from its position. When it is ready, `newImage` uploads it to a drawable image, and `encode` saves it to a PNG.

```nim
let data = newImageData(64, 64)
data.mapPixel(proc(x, y: int32, c: Color): Color =
  (uint8(x * 4), uint8(y * 4), 128'u8, 255'u8))

let tex = n2d.newImage(data)         # upload to the GPU
data.encode("gradient.png")          # or save it to disk

n2d.draw = proc(nim2d: Nim2d) =
  tex.draw(nim2d, 100, 100, 0, 4, 4)
```

Pixels are `Color` values like everywhere else, so `getPixel` hands back the four bytes and `setPixel` takes them. Reading or writing outside the image raises. There are `getWidth`, `getHeight` and `getDimensions` as well.

## Quads

A quad is a rectangle inside a texture, which is how you draw one frame out of a sprite sheet. Make one with `newQuad`, giving the region and the texture's full size, then pass it to `draw`.

```nim
let frame = newQuad(64, 0, 64, 64, sheet.getWidth.float, sheet.getHeight.float)
sheet.draw(nim2d, frame, x, y)
```

## Sprite batches

When you draw the same texture many times, a sprite batch lets you build the whole lot up and draw it in one call. Make one with `newSpriteBatch`, `add` each copy with a position and optional rotation, scale and origin, then `draw` the batch. `clear` empties it, and `setColor` tints whatever you add after it. You can add a quad instead of the whole texture.

```nim
let batch = newSpriteBatch(tileset)
batch.add(quad, x, y)
batch.add(x2, y2, angle)
batch.draw(nim2d)
```

The batch draws through the current transform, so you can translate or rotate before drawing it.

## Meshes

A mesh is a list of vertices you control, each with a position, texture coordinates and a color, drawn as triangles, a fan, or a strip. Build vertices with `meshVertex`, make the mesh with `newMesh`, and draw it. Without a texture the vertex colors show through directly, which is how you make gradients.

```nim
let red = (255'u8, 0'u8, 0'u8, 255'u8)
let green = (0'u8, 255'u8, 0'u8, 255'u8)
let blue = (0'u8, 0'u8, 255'u8, 255'u8)
let tri = newMesh(@[
  meshVertex(0, 0, color = red),
  meshVertex(100, 0, color = green),
  meshVertex(50, 90, color = blue),
])
tri.draw(nim2d, x, y)
```

Pass a texture to `newMesh` and give each vertex texture coordinates to draw a textured shape.

## Particle systems

A particle system spawns lots of short-lived particles and animates them for you, which is how you get smoke, fire, sparks and so on. Make one with `newParticleSystem`, configure it with the setters, then call `update` every frame and `draw` to show it. With no texture the particles are colored squares, and with a texture they are textured quads.

The setters cover the usual things. `setEmissionRate` is how many particles per second, `setParticleLifetime` is how long each one lives, `setSpeed`, `setDirection` and `setSpread` control how they fly out, `setLinearAcceleration` is a constant pull like gravity, and `setSizes` and `setColors` fade each particle from a start value to an end value over its life. `setPosition` moves the emitter. `emit` spawns a batch right now, which is handy for one-off bursts.

```nim
let ps = newParticleSystem()
ps.setEmissionRate(200)
ps.setParticleLifetime(0.5, 1.2)
ps.setSpeed(100, 260)
ps.setDirection(-PI / 2)
ps.setSpread(0.6)
ps.setLinearAcceleration(0, 300)
ps.setSizes(8, 1)
ps.setColors((255'u8, 200'u8, 80'u8, 255'u8), (255'u8, 60'u8, 40'u8, 0'u8))

n2d.update = proc(nim2d: Nim2d, dt: float) =
  ps.setPosition(mouseX(), mouseY())
  ps.update(dt)

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setBlendMode("add")
  ps.draw(nim2d)
  nim2d.setBlendMode("blend")
```

## Canvas

A canvas is an off-screen image you draw into and then draw from, which is handy for building something once and reusing it, or for effects. Make one with `newCanvas`, switch the target to it with `setCanvas`, draw, then switch back to the screen by calling `setCanvas` with no argument. Do this inside `draw`.

```nim
let canvas = n2d.newCanvas(256, 256)

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setCanvas(canvas)
  nim2d.clear(40, 40, 60)
  nim2d.setColor(255, 220, 90)
  nim2d.circle(128, 128, 60, true)
  nim2d.setCanvas()              # back to the screen
  canvas.draw(nim2d, 50, 50)     # draw the canvas like any image
```

`clear` fills the current target with a color, and called with no color it uses the background.

## Scissor

`setScissor` clips drawing to a rectangle, so anything outside it is dropped. Call it again with no arguments to stop clipping. It applies to everything drawn while it's on.

```nim
nim2d.setScissor(100, 100, 200, 150)
nim2d.circle(200, 175, 120, true)   # only the part inside the rectangle shows
nim2d.setScissor()
```

## Shaders

You can replace the fragment stage with your own shader for effects. This part is Metal only at the moment, so the source is Metal Shading Language, and a cross-platform path is still to come. Make a shader with `newShader`, set it before drawing, and unset it after. While it's set, every draw runs your fragment function. A uniform you fill with `send` lets you pass in things like time.

The fragment function is named `frag` and a preamble is added for you, so you write just the function. It receives `in.uv` and `in.color` from the vertex, `in.position.xy` as the pixel position, the current texture as `tex` (a white pixel when you're drawing shapes), and the uniform as `u`.

```nim
const fragSrc = """
fragment float4 frag(VSOutput in [[stage_in]],
                     texture2d<float> tex [[texture(0)]],
                     sampler smp [[sampler(0)]],
                     constant float4& u [[buffer(0)]]) {
  float t = u.x;
  return float4(0.5 + 0.5 * sin(t), in.uv.x, in.uv.y, 1.0) * in.color;
}
"""

let effect = n2d.newShader(fragSrc, uniformFloats = 4)

n2d.draw = proc(nim2d: Nim2d) =
  effect.send([time.float32, 0, 0, 0])
  nim2d.setShader(effect)
  sprite.draw(nim2d, 100, 100)
  nim2d.setShader()
```

## Text

Load a font from a `.ttf` file with a size, set it as the current font, and print strings. Text comes out in the current color, so set the color before you print. Input is UTF-8, so accented characters and other scripts work without any extra steps.

```nim
let font = newFont("font.ttf", 28)

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setFont(font)
  nim2d.setColor(230, 240, 255)
  nim2d.print("Hej!", 40, 40)
```

`print` also takes an optional angle and scale. A font can tell you its `getAscent`, `getDescent` and `getHeight`, and `getSize` gives the pixel width and height a string would take.
