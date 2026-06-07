## A showcase that touches most of what nim2d exposes right now. It draws shapes,
## images, fonts and a canvas, and handles input, running on SDL3 and the GPU.

import std/[math, os]
import nim2d

let assets = getAppDir()

let n2d = newNim2d("nim2d - all", 80, 80, 1024, 768, (40'u8, 44'u8, 60'u8, 255'u8))

let font = newFont(assets / "font.ttf", 36)
let bigFont = newFont(assets / "font.ttf", 72)
let logo = newImage(n2d, assets / "Nim-logo.png")
let canvas = newCanvas(n2d, 260, 200)

var angle = 0.0
var mx = 512.0
var my = 384.0

n2d.load = proc(nim2d: Nim2d) =
  nim2d.setFont(font)
  echo "font height: ", font.getHeight, "  ascent: ", font.getAscent

n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  mx = x
  my = y

n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  if scancode == SDL_SCANCODE_ESCAPE:
    nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  angle += dt

n2d.draw = proc(nim2d: Nim2d) =
  # --- render into the canvas first ---
  nim2d.setCanvas(canvas)
  nim2d.clear(70, 80, 110)
  nim2d.setColor(255, 220, 90)
  nim2d.circle(130, 110, 60, true)
  nim2d.setColor(20, 20, 30)
  nim2d.setFont(font)
  nim2d.print("canvas", 80, 80)
  nim2d.setCanvas()  # back to the screen

  # --- shapes ---
  nim2d.setColor(255, 90, 90)
  nim2d.circle(120, 150, 70, true)
  nim2d.setColor(255, 255, 255)
  nim2d.circle(120, 150, 70, false)

  nim2d.setColor(90, 255, 140)
  nim2d.rectangle(240, 90, 160, 110, true, 18)

  nim2d.setColor(120, 170, 255)
  nim2d.triangle(470, 90, 560, 210, 400, 210, true)

  nim2d.setColor(255, 255, 255)
  nim2d.arc(700, 160, 80, 0, angle)

  nim2d.setColor(255, 210, 80)
  nim2d.pie(880, 160, 70, 0, PI * 1.3, true)

  nim2d.setColor(200, 120, 255)
  nim2d.polygon([100.0, 160, 200, 150, 90], [320.0, 280, 320, 380, 380], true)

  nim2d.setColor(255, 255, 255)
  nim2d.line(@[(260.0, 320.0), (360.0, 380.0), (460.0, 320.0), (560.0, 380.0)], 2)

  # --- image: spinning logo about its own center ---
  let (lw, lh) = logo.getDimensions
  logo.draw(nim2d, 760, 460, angle, 0.35, 0.35, lw.float / 2, lh.float / 2)

  # --- the canvas, drawn as a texture ---
  canvas.draw(nim2d, 620, 30)

  # --- text (UTF-8, no rune juggling) ---
  nim2d.setFont(bigFont)
  nim2d.setColor(230, 240, 255)
  nim2d.print("Hallå, Världen!", 60, 600)
  nim2d.setFont(font)
  nim2d.setColor(180, 200, 230)
  nim2d.print("fps: " & $int(nim2d.getFPS), 60, 690)

  # --- cursor marker ---
  nim2d.setColor(255, 80, 80)
  nim2d.circle(mx, my, 6, true)

n2d.play()
