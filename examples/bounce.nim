## Bouncing balls with gravity and damped wall collisions.
## Click to spawn a ball, SPACE for a burst, C to clear.
## Loosely based on the classic love2d bouncing ball tutorial.

import std/[random, os]
import nim2d

const
  W = 900
  H = 640
  Gravity = 900.0
  Damp = 0.82

type Ball = object
  x, y, vx, vy, r: float
  col: Color

var balls: seq[Ball]
randomize()

let n2d = newNim2d("nim2d - bounce", 120, 80, W.cint, H.cint, (18'u8, 18'u8, 26'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
n2d.setFont(font)

proc spawn(x, y: float) =
  balls.add Ball(
    x: x, y: y,
    vx: rand(-280.0..280.0),
    vy: rand(-260.0 .. -40.0),
    r: rand(12.0..34.0),
    col: (uint8 rand(80..255), uint8 rand(80..255), uint8 rand(80..255), 255'u8))

for _ in 0 ..< 18:
  spawn(rand(60.0 .. (W - 60).float), rand(60.0 .. (H / 2)))

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  spawn(x, y)

n2d.keydown = proc(nim2d: Nim2d, scancode: Key) =
  case scancode
  of Key.space:
    for _ in 0 ..< 12: spawn(W / 2, H / 2)
  of Key.c: balls.setLen(0)
  of Key.escape: nim2d.running = false
  else: discard

n2d.update = proc(nim2d: Nim2d, dt: float) =
  for b in balls.mitems:
    b.vy += Gravity * dt
    b.x += b.vx * dt
    b.y += b.vy * dt
    if b.x - b.r < 0:          b.x = b.r;            b.vx = -b.vx * Damp
    if b.x + b.r > W.float:     b.x = W.float - b.r;  b.vx = -b.vx * Damp
    if b.y + b.r > H.float:
      b.y = H.float - b.r
      b.vy = -b.vy * Damp
      b.vx *= 0.98
    if b.y - b.r < 0:          b.y = b.r;            b.vy = -b.vy * Damp

n2d.draw = proc(nim2d: Nim2d) =
  for b in balls:
    nim2d.setColor(b.col.r, b.col.g, b.col.b)
    nim2d.circle(b.x, b.y, b.r, true)
    nim2d.setColor(255, 255, 255, 60)
    nim2d.circle(b.x, b.y, b.r, false)
  nim2d.setColor(235, 240, 255)
  nim2d.print("balls: " & $balls.len & "   click=spawn  space=burst  c=clear", 16, 14)
  nim2d.print("fps: " & $int(nim2d.getFPS), 16, 44)

n2d.play()
