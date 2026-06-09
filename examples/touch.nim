## Touch input: a dot follows each finger and a ring ripples out where you press.
## On a desktop with no touchscreen the trackpad usually acts as a touch device,
## so resting fingers on it shows up here. ESC quits.

import std/[os, math]
import nim2d

const
  W = 800
  H = 600

let n2d = newNim2d("nim2d - touch", 120, 80, W.cint, H.cint, (14'u8, 16'u8, 24'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 20)
let fontSmall = newFont(getAppDir() / "font.ttf", 15)

type Ripple = object
  x, y, t: float
  color: Color

var ripples: seq[Ripple]

proc colorFor(id: int64): Color =
  ## A stable bright color derived from the finger id.
  let h = (id and 0xff).int
  (uint8(80 + (h * 7) mod 175), uint8(80 + (h * 13) mod 175),
   uint8(80 + (h * 29) mod 175), 255'u8)

n2d.touchpressed = proc(nim2d: Nim2d, id: int64, x, y, pressure: float) =
  ripples.add Ripple(x: x, y: y, t: 0, color: colorFor(id))

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  var i = 0
  while i < ripples.len:
    ripples[i].t += dt
    if ripples[i].t > 1.1: ripples.del(i) else: inc i

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setFont(font)
  nim2d.setColor(225, 230, 245)
  nim2d.print("touch the screen or the trackpad, a dot follows each finger", 24, 24)

  let touches = nim2d.getTouches()
  nim2d.setBlendMode("add")
  for r in ripples:
    let f = 1.0 - r.t / 1.1
    nim2d.setColor(uint8(r.color.r.float * f), uint8(r.color.g.float * f),
                   uint8(r.color.b.float * f))
    nim2d.circle(r.x, r.y, 20 + r.t * 130, filled = false, segments = 36)
  for t in touches:
    let c = colorFor(t.id)
    nim2d.setColor(c.r, c.g, c.b)
    nim2d.circle(t.x, t.y, 18 + t.pressure * 44, filled = true, segments = 28)
    nim2d.setColor(255, 255, 255)
    nim2d.circle(t.x, t.y, 4, filled = true, segments = 10)
  nim2d.setBlendMode("blend")

  nim2d.setFont(fontSmall)
  nim2d.setColor(140, 150, 180)
  nim2d.print("active touches: " & $touches.len & "    ESC quits", 24, H - 30)

n2d.play()
