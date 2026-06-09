## Warp-speed starfield. Up/Down change speed, ESC quits.

import std/[random, os]
import nim2d

const
  W = 900
  H = 640
  Count = 600

type Star = object
  x, y, z, pz: float

var
  stars: seq[Star]
  speed = 40.0

randomize()
let n2d = newNim2d("nim2d - starfield", 130, 80, W.cint, H.cint, (4'u8, 4'u8, 10'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
n2d.setFont(font)

proc resetStar(s: var Star, fresh: bool) =
  s.x = rand(-W.float .. W.float)
  s.y = rand(-H.float .. H.float)
  s.z = (if fresh: rand(1.0 .. W.float) else: W.float)
  s.pz = s.z

for _ in 0 ..< Count:
  var s: Star
  resetStar(s, true)
  stars.add s

n2d.keydown = proc(nim2d: Nim2d, scancode: Key) =
  case scancode
  of Key.up: speed = min(400.0, speed + 30)
  of Key.down: speed = max(10.0, speed - 30)
  of Key.escape: nim2d.running = false
  else: discard

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let d = dt * 60.0   # tuned for a ~60fps feel
  for s in stars.mitems:
    s.pz = s.z
    s.z -= speed * d
    if s.z < 1:
      resetStar(s, false)

n2d.draw = proc(nim2d: Nim2d) =
  let cx = W / 2
  let cy = H / 2
  for s in stars:
    let sx = cx + (s.x / s.z) * cx
    let sy = cy + (s.y / s.z) * cy
    let px = cx + (s.x / s.pz) * cx
    let py = cy + (s.y / s.pz) * cy
    let b = uint8(max(0.0, min(1.0, 1.0 - s.z / W.float)) * 255)
    let w = (1.0 - s.z / W.float) * 3.0 + 0.5
    nim2d.setColor(b, b, 255'u8)
    nim2d.line(@[(px, py), (sx, sy)], w)
  nim2d.setColor(235, 240, 255)
  nim2d.print("warp: " & $int(speed) & "   up/down to change", 16, 14)

n2d.play()
