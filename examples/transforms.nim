## Transform stack demo: nested push and pop with translate, rotate and scale.
## ESC quits.

import std/[math, os]
import nim2d

const
  W = 800
  H = 640

let n2d = newNim2d("nim2d - transforms", 130, 80, W.cint, H.cint, (16'u8, 18'u8, 26'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
n2d.setFont(font)

var t = 0.0

n2d.keydown = proc(nim2d: Nim2d, scancode: Key) =
  if scancode == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt

proc square(nim2d: Nim2d, s: float) =
  ## A square centered on the origin, so transforms turn it about its middle.
  nim2d.rectangle(-s / 2, -s / 2, s, s, true, 6)

n2d.draw = proc(nim2d: Nim2d) =
  # Satellites orbiting the center, each also spinning about itself.
  nim2d.push()
  nim2d.translate(W / 2, H / 2)
  nim2d.rotate(t * 0.5)
  for i in 0 ..< 8:
    nim2d.push()
    nim2d.rotate(i.float / 8 * TAU)
    nim2d.translate(180, 0)
    nim2d.rotate(t * 2)
    nim2d.setColor(uint8(120 + i * 15), 180, 255)
    nim2d.square(50)
    nim2d.pop()
  nim2d.rotate(t)
  nim2d.setColor(255, 200, 90)
  nim2d.square(90)
  nim2d.pop()

  # A row of squares pulsing in size, showing scale under the stack.
  nim2d.push()
  nim2d.translate(90, H - 90)
  for i in 0 ..< 6:
    nim2d.push()
    let p = 0.6 + 0.4 * sin(t * 3 + i.float)
    nim2d.scale(p, p)
    nim2d.setColor(255, 120, 120)
    nim2d.square(44)
    nim2d.pop()
    nim2d.translate(72, 0)
  nim2d.pop()

  nim2d.setColor(230, 235, 245)
  nim2d.print("transform stack: push / pop / translate / rotate / scale", 16, 14)

n2d.play()
