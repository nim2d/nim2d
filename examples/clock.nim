## Analog clock driven by the system time.

import std/[math, os, times, strformat]
import nim2d

const
  W = 560
  H = 560

let n2d = newNim2d("nim2d - clock", 200, 120, W.cint, H.cint, (24'u8, 26'u8, 34'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 28)
n2d.setFont(font)

let cx = W / 2
let cy = H / 2
let R = 240.0

n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  if scancode == SDL_SCANCODE_ESCAPE: nim2d.running = false

proc hand(nim2d: Nim2d, frac, len, width: float, col: Color) =
  ## `frac` is 0..1 around the dial (0 = 12 o'clock, clockwise).
  let a = -PI / 2 + frac * TAU
  nim2d.setColor(col.r, col.g, col.b)
  nim2d.line(@[(cx, cy), (cx + cos(a) * len, cy + sin(a) * len)], width)

n2d.draw = proc(nim2d: Nim2d) =
  # face
  nim2d.setColor(40, 44, 56)
  nim2d.circle(cx, cy, R, true)
  nim2d.setColor(120, 130, 150)
  nim2d.circle(cx, cy, R, false)

  # ticks
  for i in 0 ..< 60:
    let a = i.float / 60.0 * TAU
    let inner = (if i mod 5 == 0: R - 24 else: R - 12)
    if i mod 5 == 0: nim2d.setColor(220, 225, 235)
    else: nim2d.setColor(90, 96, 110)
    nim2d.line(@[(cx + cos(a) * inner, cy + sin(a) * inner),
                 (cx + cos(a) * (R - 4), cy + sin(a) * (R - 4))],
               (if i mod 5 == 0: 3.0 else: 1.5))

  let t = now()
  let sec = t.second.float + t.nanosecond.float / 1_000_000_000.0
  let mins = t.minute.float + sec / 60.0
  let hrs = (t.hour mod 12).float + mins / 60.0

  nim2d.hand(hrs / 12.0, R * 0.5, 8, (230'u8, 235'u8, 245'u8, 255'u8))
  nim2d.hand(mins / 60.0, R * 0.72, 5, (190'u8, 210'u8, 240'u8, 255'u8))
  nim2d.hand(sec / 60.0, R * 0.86, 2, (240'u8, 120'u8, 110'u8, 255'u8))

  nim2d.setColor(240, 130, 120)
  nim2d.circle(cx, cy, 7, true)

  # digital
  nim2d.setColor(200, 210, 230)
  let digital = &"{t.hour:02}:{t.minute:02}:{t.second:02}"
  nim2d.print(digital, cx - 60, H.float - 56)

n2d.play()
