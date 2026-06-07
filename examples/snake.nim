## Snake, the classic. Arrow keys or WASD to steer, R to restart, ESC to quit.

import std/[random, os]
import nim2d

const
  Cell = 26
  Cols = 28
  Rows = 22
  TopBar = 44
  W = Cols * Cell
  H = Rows * Cell + TopBar

type Cellxy = tuple[x, y: int]

var
  snake: seq[Cellxy]
  dir: Cellxy
  nextDir: Cellxy
  food: Cellxy
  acc: float
  step: float
  score: int
  dead: bool

randomize()
let n2d = newNim2d("nim2d - snake", 140, 80, W.cint, H.cint, (16'u8, 20'u8, 24'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 24)
let bigFont = newFont(getAppDir() / "font.ttf", 56)
n2d.setFont(font)

proc placeFood() =
  while true:
    let f = (rand(0 ..< Cols), rand(0 ..< Rows))
    if f notin snake:
      food = f
      break

proc reset() =
  snake = @[(Cols div 2, Rows div 2), (Cols div 2 - 1, Rows div 2),
            (Cols div 2 - 2, Rows div 2)]
  dir = (1, 0)
  nextDir = (1, 0)
  acc = 0
  step = 0.12
  score = 0
  dead = false
  placeFood()

reset()

n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  case scancode
  of SDL_SCANCODE_UP, SDL_SCANCODE_W:
    if dir.y == 0: nextDir = (0, -1)
  of SDL_SCANCODE_DOWN, SDL_SCANCODE_S:
    if dir.y == 0: nextDir = (0, 1)
  of SDL_SCANCODE_LEFT, SDL_SCANCODE_A:
    if dir.x == 0: nextDir = (-1, 0)
  of SDL_SCANCODE_RIGHT, SDL_SCANCODE_D:
    if dir.x == 0: nextDir = (1, 0)
  of SDL_SCANCODE_R:
    if dead: reset()
  of SDL_SCANCODE_ESCAPE:
    nim2d.running = false
  else: discard

n2d.update = proc(nim2d: Nim2d, dt: float) =
  if dead: return
  acc += dt
  if acc < step: return
  acc = 0
  dir = nextDir
  let head: Cellxy = (snake[0].x + dir.x, snake[0].y + dir.y)
  if head.x < 0 or head.x >= Cols or head.y < 0 or head.y >= Rows or head in snake:
    dead = true
    return
  snake.insert(head, 0)
  if head == food:
    inc score
    step = max(0.05, step * 0.97)
    placeFood()
  else:
    snake.setLen(snake.len - 1)

proc cellRect(nim2d: Nim2d, c: Cellxy, pad: float) =
  nim2d.rectangle(c.x.float * Cell.float + pad, c.y.float * Cell.float + TopBar.float + pad,
                  Cell.float - pad * 2, Cell.float - pad * 2, true, 5)

n2d.draw = proc(nim2d: Nim2d) =
  # board
  nim2d.setColor(22, 28, 34)
  nim2d.rectangle(0, TopBar.float, W.float, (H - TopBar).float, true)
  # food
  nim2d.setColor(235, 90, 90)
  nim2d.cellRect(food, 3)
  # snake
  for i, c in snake:
    if i == 0: nim2d.setColor(150, 240, 130)
    else: nim2d.setColor(90, 200, 110)
    nim2d.cellRect(c, 2)
  # hud
  nim2d.setColor(235, 240, 255)
  nim2d.print("score: " & $score, 14, 10)
  if dead:
    nim2d.setColor(0, 0, 0, 150)
    nim2d.rectangle(0, 0, W.float, H.float, true)
    nim2d.setFont(bigFont)
    nim2d.setColor(255, 120, 120)
    nim2d.print("Game Over", W / 2 - 150, H / 2 - 60)
    nim2d.setFont(font)
    nim2d.setColor(235, 240, 255)
    nim2d.print("press R to restart", W / 2 - 100, H / 2 + 10)

n2d.play()
