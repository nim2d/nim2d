## Particle fountain with additive (glow) blending.
## The fountain follows the mouse; click for a firework burst.

import std/[random, os, math]
import nim2d

const
  W = 900
  H = 640
  Gravity = 260.0

type Particle = object
  x, y, vx, vy, life, maxLife, size: float
  col: Color

var
  parts: seq[Particle]
  ex, ey: float         # emitter (mouse)

randomize()
let n2d = newNim2d("nim2d - particles", 130, 80, W.cint, H.cint, (8'u8, 8'u8, 14'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
n2d.setFont(font)
ex = W / 2
ey = H.float - 60

proc warmColor(): Color =
  (uint8 rand(200..255), uint8 rand(90..200), uint8 rand(20..90), 255'u8)

proc emit(x, y, vx, vy: float, col: Color, life: float) =
  parts.add Particle(x: x, y: y, vx: vx, vy: vy, life: life, maxLife: life,
                     size: rand(2.0..5.0), col: col)

n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  ex = x
  ey = y

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button, clicks: uint8) =
  # firework: radial burst
  let col = (uint8 rand(120..255), uint8 rand(120..255), uint8 rand(160..255), 255'u8)
  for i in 0 ..< 120:
    let a = rand(0.0..TAU)
    let s = rand(80.0..320.0)
    emit(x, y, cos(a) * s, sin(a) * s, col, rand(0.6..1.4))

n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  if scancode == SDL_SCANCODE_ESCAPE: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  # fountain stream from the emitter
  for _ in 0 ..< 6:
    let a = -PI / 2 + rand(-0.5..0.5)
    let s = rand(160.0..300.0)
    emit(ex, ey, cos(a) * s, sin(a) * s, warmColor(), rand(0.7..1.3))

  var i = 0
  while i < parts.len:
    parts[i].vy += Gravity * dt
    parts[i].x += parts[i].vx * dt
    parts[i].y += parts[i].vy * dt
    parts[i].life -= dt
    if parts[i].life <= 0:
      parts[i] = parts[^1]
      parts.setLen(parts.len - 1)
    else:
      inc i

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setBlendMode("add")
  for p in parts:
    let a = uint8(max(0.0, min(1.0, p.life / p.maxLife)) * 255)
    nim2d.setColor(p.col.r, p.col.g, p.col.b, a)
    nim2d.circle(p.x, p.y, p.size, true, 10)
  nim2d.setBlendMode("blend")
  nim2d.setColor(235, 240, 255)
  nim2d.print("particles: " & $parts.len & "   move=aim  click=firework", 16, 14)

n2d.play()
