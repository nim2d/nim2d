## Input demo: held-key polling, mouse position and buttons, the wheel, and
## text input. WASD or arrows move the square, the wheel resizes it, type to
## append text, backspace deletes, ESC quits.

import std/os
import nim2d

const
  W = 800
  H = 600

let n2d = newNim2d("nim2d - input", 130, 80, W.cint, H.cint, (18'u8, 20'u8, 28'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 24)
n2d.setFont(font)

var px = W / 2.0
var py = H / 2.0
var size = 40.0
var typed = ""

n2d.load = proc(nim2d: Nim2d) =
  nim2d.startTextInput()

n2d.keydown = proc(nim2d: Nim2d, scancode: Key) =
  if scancode == Key.escape:
    nim2d.running = false
  elif scancode == Key.backspace and typed.len > 0:
    typed.setLen(typed.len - 1)

n2d.textinput = proc(nim2d: Nim2d, text: string) =
  typed.add text

n2d.mousewheel = proc(nim2d: Nim2d, x, y: float) =
  size = clamp(size + y * 4, 10.0, 200.0)

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let speed = 320.0 * dt
  if isDown(Key.left) or isDown(Key.a): px -= speed
  if isDown(Key.right) or isDown(Key.d): px += speed
  if isDown(Key.up) or isDown(Key.w): py -= speed
  if isDown(Key.down) or isDown(Key.s): py += speed

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setColor(120, 200, 255)
  nim2d.rectangle(px - size / 2, py - size / 2, size, size, true, 6)

  let m = mousePosition()
  if isMouseDown(1): nim2d.setColor(255, 90, 90)
  else: nim2d.setColor(230, 230, 240)
  nim2d.circle(m.x, m.y, 10, true)

  nim2d.setColor(230, 235, 245)
  nim2d.print("WASD or arrows move, wheel resizes, click, and type:", 16, 16)
  nim2d.setColor(255, 220, 120)
  nim2d.print("> " & typed, 16, 52)

n2d.play()
