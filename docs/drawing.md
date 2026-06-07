# Drawing

All drawing happens inside the `draw` callback. The window has already cleared to the background color by the time `draw` runs, so you just paint on top.

## Color

`setColor` sets the color used by every shape and by text until you change it. The alpha argument is optional and defaults to fully opaque.

```nim
nim2d.setColor(255, 120, 60)        # opaque orange
nim2d.setColor(255, 120, 60, 128)   # half transparent
```

`setBackgroundColor` changes the color the window clears to each frame.

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

Curved shapes take an optional `segments` count if you want them smoother or cheaper. The fill for `polygon` works for convex shapes. A concave polygon will not fill correctly yet.

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
