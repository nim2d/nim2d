## A fragment shader running over a fullscreen rectangle: an animated plasma.
## The shader is authored in GLSL (plasma.frag) and compiled offline to SPIR-V
## and MSL blobs, so it runs on Metal and Vulkan alike. ESC quits.

import std/os
import nim2d

const
  W = 800
  H = 600

# The blobs are built from plasma.frag (see its header). The renderer picks the
# one the backend wants, so this is a cross-platform user shader.
const plasmaSpv = staticRead("plasma.spv")
const plasmaMsl = staticRead("plasma.metal")

let n2d = newNim2d("nim2d - shader", 140, 90, W.cint, H.cint, (0'u8, 0'u8, 0'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
n2d.setFont(font)

# The uniform holds time in x and the resolution in y, z.
let plasma = n2d.newShader(plasmaSpv, plasmaMsl, uniformFloats = 4)
var t = 0.0

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt

n2d.draw = proc(nim2d: Nim2d) =
  plasma.send([t.float32, W.float32, H.float32, 0'f32])
  nim2d.setShader(plasma)
  nim2d.setColor(255, 255, 255)
  nim2d.rectangle(0, 0, W.float, H.float, true)
  nim2d.setShader()

  nim2d.setColor(240, 240, 250)
  nim2d.print("a fragment shader over a fullscreen rectangle", 16, 14)

n2d.play()
