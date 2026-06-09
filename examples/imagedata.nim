## Build a texture on the CPU pixel by pixel, upload it, and draw it scaled up.
## Press S to save it to out.png next to the example. ESC quits.

import std/[os, math]
import nim2d

const
  W = 640
  H = 480
  texSize = 64

let n2d = newNim2d("nim2d - imagedata", 140, 90, W.cint, H.cint, (18'u8, 18'u8, 24'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 20)
n2d.setFont(font)

# Fill a small buffer with a plasma-like pattern, then upload it once.
let data = newImageData(texSize, texSize)
data.mapPixel(proc(x, y: int32, c: Color): Color =
  let fx = x.float / texSize.float
  let fy = y.float / texSize.float
  let v = 0.5 + 0.5 * sin(fx * 12.0) * cos(fy * 12.0)
  let n = noise(fx * 4.0, fy * 4.0)
  (uint8(v * 255.0), uint8(n * 255.0), uint8((1.0 - v) * 255.0), 255'u8))

let tex = n2d.newImage(data)
var saved = false

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false
  elif sc == Key.s:
    data.encode(getAppDir() / "out.png")
    saved = true

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setColor(255, 255, 255)
  tex.draw(nim2d, 100, 80, 0, 6, 6)   # 64x64 scaled up 6x
  nim2d.print("an ImageData built with mapPixel, uploaded and drawn 6x", 16, 16)
  nim2d.print(if saved: "saved out.png" else: "press S to save out.png", 16, 44)

n2d.play()
