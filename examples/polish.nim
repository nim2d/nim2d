## A tour of the graphics-polish features: nearest vs linear filtering, texture
## wrap, mipmaps, point size, round joins on thick lines, supersampled
## anti-aliasing (the window is made with aa = 2), and stencil masking (made with
## stencil = true). ESC quits.

import std/[os, math]
import nim2d

const
  W = 820
  H = 540

let n2d = newNim2d("nim2d - polish", 100, 70, W.cint, H.cint,
                   (16'u8, 18'u8, 26'u8, 255'u8), aa = 2, stencil = true)
let font = newFont(getAppDir() / "font.ttf", 16)

proc checker(size, cells: int32): ImageData =
  ## A simple checkerboard pixel buffer.
  result = newImageData(size, size)
  let cs = size div cells
  for y in 0'i32 ..< size:
    for x in 0'i32 ..< size:
      let on = ((x div cs) + (y div cs)) mod 2 == 0
      result.setPixel(x, y, (if on: (235'u8, 235'u8, 235'u8, 255'u8)
                             else: (70'u8, 100'u8, 165'u8, 255'u8)))

let small = checker(4, 2)
let sharp = n2d.newImage(small); sharp.setFilter(filNearest)
let smooth = n2d.newImage(small)
let tiled = n2d.newImage(small); tiled.setFilter(filNearest); tiled.setWrap(wrapRepeat)
let mip = n2d.newImage(checker(64, 16), mipmaps = true)

var t = 0.0

proc label(g: Nim2d, s: string, x, y: float) =
  g.setFont(font)
  g.setColor(170, 182, 205)
  g.print(s, x, y)

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt

n2d.draw = proc(nim2d: Nim2d) =
  # filtering and wrap: a 4x4 checker blown up
  nim2d.setColor(255, 255, 255)
  sharp.draw(nim2d, 20, 40, 0, 22, 22)
  smooth.draw(nim2d, 130, 40, 0, 22, 22)
  let q = newQuad(0, 0, 16, 16, 4, 4)            # texcoords run 0..4, so it tiles
  tiled.draw(nim2d, q, 240, 40, 0, 5.5, 5.5)
  # mipmaps: the same texture at shrinking scales stays clean instead of fuzzing
  mip.draw(nim2d, 360, 40, 0, 0.9, 0.9)
  mip.draw(nim2d, 430, 60, 0, 0.45, 0.45)
  mip.draw(nim2d, 470, 72, 0, 0.22, 0.22)
  nim2d.label("nearest", 24, 138)
  nim2d.label("linear", 138, 138)
  nim2d.label("wrap repeat", 240, 138)
  nim2d.label("mipmaps", 360, 138)

  # point size: a row of growing points
  for i in 0 ..< 12:
    nim2d.setColor(120, 200, 255)
    nim2d.points(@[(40.0 + i.float * 42, 200.0)], 2.0 + i.float * 2.2)
  nim2d.label("point size", 24, 222)

  # thick line with round joins, wiggling so the corners show
  var pts: seq[Vec2]
  for i in 0 .. 14:
    pts.add (40.0 + i.float * 52, 290.0 + sin(t * 2 + i.float * 0.55) * 26)
  nim2d.setColor(255, 165, 90)
  nim2d.line(pts, 11)
  nim2d.label("thick line, round joins", 24, 330)

  # stencil: stripes clipped to a moving circle
  let mx = 200.0 + sin(t) * 70
  nim2d.stencil(proc(m: Nim2d) =
    m.circle(mx, 445, 72, filled = true))
  for i in 0 ..< 44:
    nim2d.setColor(uint8(120 + i * 3), 110, uint8(250 - i * 3))
    nim2d.rectangle(110, 376 + i.float * 4, 180, 4, filled = true)
  nim2d.stencilStop()
  nim2d.label("stencil mask", 110, 524)

  nim2d.label("anti-aliasing on (aa = 2): edges above are smoothed", 360, 300)
  nim2d.label("ESC to quit", 360, 324)

n2d.play()
