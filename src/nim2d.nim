## nim2d is a small 2D game engine for Nim, loosely modeled on love2d, running on
## SDL3 and its GPU API.

import nim2d/backend/sdl
import nim2d/types
import nim2d/backend/renderer
import nim2d/graphics
import nim2d/image
import nim2d/canvas
import nim2d/font
import nim2d/timer
import nim2d/events
import nim2d/window

export types, graphics, image, canvas, font, timer, window
export sdl  # SDL_Scancode, SDL_SCANCODE_*, etc. for callback handlers

# --- callback setters ------------------------------------------------------

proc `load=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.load = p
proc `update=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, dt: float)) = n2d.update = p
proc `draw=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.draw = p
proc `quit=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.quit = p
proc `keydown=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, scancode: SDL_Scancode)) = n2d.keydown = p
proc `keyup=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, scancode: SDL_Scancode)) = n2d.keyup = p
proc `mousemove=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, x, y, dx, dy: float)) = n2d.mousemove = p
proc `mousepressed=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, x, y: float, button, clicks: uint8)) = n2d.mousepressed = p
proc `mousereleased=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, x, y: float, button, clicks: uint8)) = n2d.mousereleased = p

proc `window_shown=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_shown = p
proc `window_hidden=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_hidden = p
proc `window_moved=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_moved = p
proc `window_resized=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_resized = p
proc `window_minimized=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_minimized = p
proc `window_maximized=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_maximized = p
proc `window_restored=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_restored = p
proc `window_enter=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_enter = p
proc `window_leave=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_leave = p
proc `window_focus_gained=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_focus_gained = p
proc `window_focus_lost=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_focus_lost = p
proc `window_close=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) = n2d.window_close = p

# --- render-target / state -------------------------------------------------

proc setFont*(nim2d: Nim2d, font: Font) =
  nim2d.font = font

proc setCanvas*(nim2d: Nim2d) =
  ## Render to the screen (default target).
  nim2d.gpu.setTarget(nim2d.gpu.swTex, nim2d.width, nim2d.height)

proc setCanvas*(nim2d: Nim2d, canvas: Canvas) =
  ## Render to a canvas (off-screen target). Call inside `draw`.
  nim2d.gpu.setTarget(canvas.tex, canvas.width, canvas.height)

proc clear*(nim2d: Nim2d, r, g, b: uint8, a: uint8 = 255) =
  ## Clear the current render target. Call inside `draw`.
  let p = nim2d.gpu.passes[^1]
  nim2d.gpu.clearTarget(p.target, p.w, p.h, (r, g, b, a))

proc clear*(nim2d: Nim2d) =
  nim2d.clear(nim2d.background.r, nim2d.background.g, nim2d.background.b)

# --- lifecycle -------------------------------------------------------------

proc newNim2d*(title: string, x, y, width, height: cint,
               background: Color): Nim2d =
  if not SDL_Init(SDL_InitFlags(SDL_INIT_VIDEO)):
    raise newException(CatchableError, "SDL_Init failed: " & $SDL_GetError())

  let win = SDL_CreateWindow(title.cstring, width, height, SDL_WindowFlags(0))
  if win == nil:
    raise newException(CatchableError, "SDL_CreateWindow failed: " & $SDL_GetError())
  discard SDL_SetWindowPosition(win, x, y)
  discard SDL_RaiseWindow(win)

  let noop = proc(nim2d: Nim2d) = discard

  result = Nim2d(
    width: width, height: height,
    gpu: newGpuContext(win),
    background: background,
    color: (255'u8, 255'u8, 255'u8, 255'u8),
    blend: bmAlpha,
    running: true,
    perfFreq: SDL_GetPerformanceFrequency(),
    load: noop, draw: noop, quit: noop,
    update: proc(nim2d: Nim2d, dt: float) = discard,
    keydown: proc(nim2d: Nim2d, scancode: SDL_Scancode) = discard,
    keyup: proc(nim2d: Nim2d, scancode: SDL_Scancode) = discard,
    mousemove: proc(nim2d: Nim2d, x, y, dx, dy: float) = discard,
    mousepressed: proc(nim2d: Nim2d, x, y: float, button, clicks: uint8) = discard,
    mousereleased: proc(nim2d: Nim2d, x, y: float, button, clicks: uint8) = discard,
    window_shown: noop, window_hidden: noop, window_moved: noop,
    window_resized: noop, window_minimized: noop, window_maximized: noop,
    window_restored: noop, window_enter: noop, window_leave: noop,
    window_focus_gained: noop, window_focus_lost: noop, window_close: noop,
  )

proc newNim2d*(title: string, x, y, width, height: cint): Nim2d =
  newNim2d(title, x, y, width, height, (89'u8, 157'u8, 220'u8, 255'u8))

proc play*(nim2d: Nim2d) =
  nim2d.load(nim2d)
  nim2d.lastCounter = SDL_GetPerformanceCounter()
  var evt: SDL_Event

  while nim2d.running:
    while SDL_PollEvent(addr evt):
      nim2d.dispatch(evt)

    let now = SDL_GetPerformanceCounter()
    nim2d.dt = float(now - nim2d.lastCounter) / float(nim2d.perfFreq)
    nim2d.lastCounter = now
    if nim2d.dt > 0: nim2d.fps = 1.0 / nim2d.dt

    nim2d.update(nim2d, nim2d.dt)

    if nim2d.gpu.beginFrame(nim2d.width, nim2d.height, nim2d.background):
      nim2d.draw(nim2d)
      nim2d.gpu.endFrame()

  nim2d.gpu.destroy()
  SDL_DestroyWindow(nim2d.gpu.window)
  sdlQuit()
