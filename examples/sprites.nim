## Sprite batch, mesh and quad demo. A grid of spinning logos drawn in one
## batch, a gradient mesh built from colored vertices, and a quad that crops the
## middle of the logo. ESC quits.

import std/[math, os]
import nim2d

const
  W = 900
  H = 680

let n2d = newNim2d("nim2d - sprites", 120, 70, W.cint, H.cint, (16'u8, 18'u8, 24'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 22)
let logo = newImage(n2d, getAppDir() / "Nim-logo.png")
n2d.setFont(font)

let batch = newSpriteBatch(logo)
let (lw, lh) = logo.getDimensions

# A gradient disc: a white center vertex surrounded by colored rim vertices.
let cols = [(255'u8, 80'u8, 80'u8, 255'u8), (255'u8, 200'u8, 80'u8, 255'u8),
            (80'u8, 255'u8, 120'u8, 255'u8), (80'u8, 200'u8, 255'u8, 255'u8),
            (180'u8, 120'u8, 255'u8, 255'u8), (255'u8, 80'u8, 80'u8, 255'u8)]
var mverts = @[meshVertex(0, 0)]
for i in 0 .. 5:
  let a = i.float / 5 * TAU
  mverts.add meshVertex(cos(a) * 90, sin(a) * 90, color = cols[i])
let fan = newMesh(mverts, mdFan)

# A quad that crops the middle half of the logo.
let crop = newQuad(lw.float * 0.25, lh.float * 0.25, lw.float * 0.5, lh.float * 0.5,
                   lw.float, lh.float)

var t = 0.0

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt

n2d.draw = proc(nim2d: Nim2d) =
  # Rebuild the batch each frame: a grid of logos, each spinning about itself.
  batch.clear()
  for gy in 0 .. 4:
    for gx in 0 .. 7:
      let x = 80.0 + gx.float * 95
      let y = 80.0 + gy.float * 70
      batch.add(x, y, t + (gx + gy).float * 0.3, 0.1, 0.1, lw.float / 2, lh.float / 2)
  batch.draw(nim2d)

  # Gradient mesh, slowly turning.
  nim2d.push()
  nim2d.translate(150, H - 140)
  nim2d.rotate(t * 0.5)
  fan.draw(nim2d)
  nim2d.pop()

  # The cropped quad, scaled up.
  logo.draw(nim2d, crop, W - 280, H - 250, 0, 0.7, 0.7)

  nim2d.setColor(230, 235, 245)
  nim2d.print("SpriteBatch grid, a gradient Mesh, and a Quad crop", 16, 14)

n2d.play()
