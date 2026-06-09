## Scrolling Perlin noise drawn as a grid of squares, a concave star filled by
## ear clipping, and a Bezier curve. ESC quits.

import std/[os, math]
import nim2d

const
  W = 800
  H = 600
  cell = 20

let n2d = newNim2d("nim2d - noise", 120, 80, W.cint, H.cint, (12'u8, 12'u8, 16'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 20)
n2d.setFont(font)
var t = 0.0

proc starPoints(cx, cy, outer, inner: float): (seq[float], seq[float]) =
  ## A five-point star, which is concave, so its fill needs triangulation.
  var xs, ys: seq[float]
  for i in 0 ..< 10:
    let r = if i mod 2 == 0: outer else: inner
    let a = -PI / 2 + i.float * (PI / 5)
    xs.add cx + cos(a) * r
    ys.add cy + sin(a) * r
  (xs, ys)

let (starX, starY) = starPoints(650, 450, 95, 40)
let curve = newBezierCurve(@[(40.0, 540.0), (220.0, 360.0), (380.0, 580.0), (560.0, 380.0)])
let curvePts = curve.render(48)

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt

n2d.draw = proc(nim2d: Nim2d) =
  let cols = W div cell
  let rows = H div cell
  for gy in 0 ..< rows:
    for gx in 0 ..< cols:
      let v = noise(gx.float * 0.12 + t * 0.6, gy.float * 0.12)
      nim2d.setColor(uint8(v * 200.0), uint8(v * 200.0), uint8(150.0 + v * 90.0))
      nim2d.rectangle((gx * cell).float, (gy * cell).float, cell.float, cell.float, filled = true)

  nim2d.setColor(255, 210, 80)
  nim2d.polygon(starX, starY, filled = true)
  nim2d.setColor(120, 80, 0)
  nim2d.polygon(starX, starY)

  nim2d.setColor(120, 230, 255)
  nim2d.line(curvePts, 3)

  nim2d.setColor(240, 240, 250)
  nim2d.print("perlin noise, a concave star (ear-clipped fill) and a bezier curve", 14, 12)

n2d.play()
