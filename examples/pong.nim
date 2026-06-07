## Pong against a simple AI. Move the left paddle with W/S or the arrow keys.
## R resets, ESC quits.

import std/[random, os]
import nim2d

const
  W = 900
  H = 600
  PadW = 16.0
  PadH = 110.0
  PadSpeed = 460.0
  AiSpeed = 360.0
  Ball = 14.0

var
  ly, ry: float          # paddle y (top)
  bx, by, bvx, bvy: float
  lScore, rScore: int
  upHeld, downHeld: bool

randomize()
let n2d = newNim2d("nim2d - pong", 140, 90, W.cint, H.cint, (12'u8, 14'u8, 20'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 28)
let bigFont = newFont(getAppDir() / "font.ttf", 64)

proc serve(toLeft: bool) =
  bx = W / 2
  by = H / 2
  bvx = (if toLeft: -340.0 else: 340.0)
  bvy = rand(-200.0..200.0)

proc reset() =
  ly = H / 2 - PadH / 2
  ry = ly
  lScore = 0
  rScore = 0
  serve(rand(0..1) == 0)

reset()

n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  case scancode
  of SDL_SCANCODE_W, SDL_SCANCODE_UP: upHeld = true
  of SDL_SCANCODE_S, SDL_SCANCODE_DOWN: downHeld = true
  of SDL_SCANCODE_R: reset()
  of SDL_SCANCODE_ESCAPE: nim2d.running = false
  else: discard

n2d.keyup = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  case scancode
  of SDL_SCANCODE_W, SDL_SCANCODE_UP: upHeld = false
  of SDL_SCANCODE_S, SDL_SCANCODE_DOWN: downHeld = false
  else: discard

proc clampPad(y: float): float =
  max(0.0, min(H.float - PadH, y))

n2d.update = proc(nim2d: Nim2d, dt: float) =
  # player
  if upHeld: ly = clampPad(ly - PadSpeed * dt)
  if downHeld: ly = clampPad(ly + PadSpeed * dt)
  # ai tracks the ball
  let target = by - PadH / 2
  if ry + 4 < target: ry = clampPad(ry + AiSpeed * dt)
  elif ry - 4 > target: ry = clampPad(ry - AiSpeed * dt)

  # ball
  bx += bvx * dt
  by += bvy * dt
  if by - Ball < 0: by = Ball; bvy = -bvy
  if by + Ball > H.float: by = H.float - Ball; bvy = -bvy

  # paddle collisions
  if bvx < 0 and bx - Ball < PadW + 24 and bx > 24 and by > ly and by < ly + PadH:
    bvx = -bvx * 1.05
    bvy += (by - (ly + PadH / 2)) * 4
  if bvx > 0 and bx + Ball > W.float - PadW - 24 and bx < W.float - 24 and
     by > ry and by < ry + PadH:
    bvx = -bvx * 1.05
    bvy += (by - (ry + PadH / 2)) * 4

  # scoring
  if bx < -Ball: inc rScore; serve(false)
  if bx > W.float + Ball: inc lScore; serve(true)

n2d.draw = proc(nim2d: Nim2d) =
  # center dashed line
  nim2d.setColor(60, 70, 90)
  var y = 0.0
  while y < H.float:
    nim2d.rectangle(W / 2 - 2, y, 4, 16, true)
    y += 28
  # paddles + ball
  nim2d.setColor(120, 200, 255)
  nim2d.rectangle(24, ly, PadW, PadH, true, 4)
  nim2d.setColor(255, 150, 120)
  nim2d.rectangle(W.float - 24 - PadW, ry, PadW, PadH, true, 4)
  nim2d.setColor(245, 245, 255)
  nim2d.circle(bx, by, Ball, true)
  # score
  nim2d.setFont(bigFont)
  nim2d.print($lScore, W / 2 - 120, 24)
  nim2d.print($rScore, W / 2 + 80, 24)
  nim2d.setFont(font)
  nim2d.setColor(150, 160, 180)
  nim2d.print("W/S or Up/Down", 24, H.float - 44)

n2d.play()
