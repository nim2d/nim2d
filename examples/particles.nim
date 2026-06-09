## Particle system demo. A fountain follows the mouse, and clicking sets off a
## firework burst. Drawn with additive blending for the glow. ESC quits.

import std/[os, math, random]
import nim2d

const
  W = 900
  H = 640

randomize()
let n2d = newNim2d("nim2d - particles", 130, 80, W.cint, H.cint, (8'u8, 8'u8, 14'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
n2d.setFont(font)

let ps = newParticleSystem()
ps.setEmissionRate(240)
ps.setParticleLifetime(0.6, 1.4)
ps.setSpeed(120, 300)
ps.setDirection(-PI / 2)
ps.setSpread(0.7)
ps.setLinearAcceleration(0, 280)
ps.setSizes(7, 1)
ps.setColors((255'u8, 200'u8, 90'u8, 255'u8), (255'u8, 60'u8, 40'u8, 0'u8))
ps.setSpin(-4, 4)

var ex = W / 2.0
var ey = H - 60.0
ps.setPosition(ex, ey)

n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  ex = x
  ey = y
  ps.setPosition(x, y)

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  # A firework: a one-off radial burst from the click point.
  ps.setPosition(x, y)
  ps.setSpread(TAU)
  ps.emit(160)
  ps.setSpread(0.7)
  ps.setPosition(ex, ey)

n2d.keydown = proc(nim2d: Nim2d, scancode: Key) =
  if scancode == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  ps.update(dt)

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setBlendMode("add")
  ps.draw(nim2d)
  nim2d.setBlendMode("blend")
  nim2d.setColor(235, 240, 255)
  nim2d.print("particles: " & $ps.count & "   move=aim  click=firework", 16, 14)

n2d.play()
