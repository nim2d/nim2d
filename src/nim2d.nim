## nim2d is a small 2D game engine for Nim, in the spirit of love2d, running on
## SDL3 and its GPU API. This module re-exports everything except physics,
## which sits on an optional Box2D dependency and is imported separately with
## `import nim2d/physics`.

import std/exitprocs
import nim2d/backend/sdl
import nim2d/types
import nim2d/backend/renderer
import nim2d/graphics
import nim2d/color
import nim2d/image
import nim2d/canvas
import nim2d/font
import nim2d/timer
import nim2d/events
import nim2d/window
import nim2d/keyboard
import nim2d/mouse
import nim2d/gamepad
import nim2d/spritebatch
import nim2d/mesh
import nim2d/particlesystem
import nim2d/shader
import nim2d/math
import nim2d/data
import nim2d/imagedata
import nim2d/filesystem
import nim2d/audio
import nim2d/system
import nim2d/touch
import nim2d/thread

export types, graphics, color, image, canvas, font, timer, window
export keyboard, mouse, gamepad, spritebatch, mesh, particlesystem, shader
export math, data, imagedata, filesystem, audio, system, touch, thread
export sdl # the raw SDL bindings, as an escape hatch for advanced use

# --- callback setters ------------------------------------------------------

proc `load=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback that runs once when `play` starts, before the first frame.
  n2d.load = p

proc `update=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, dt: float)) =
  ## Set the callback that runs every frame with the seconds since the last one.
  n2d.update = p

proc `draw=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback that draws each frame. All drawing goes here.
  n2d.draw = p

proc `quit=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback that runs once when the program ends, whether the main loop
  ## finished normally (the window closed or `running` was set to false) or it
  ## was cut short by a `system.quit` call or an escaping exception. It runs
  ## before teardown and fires exactly once, so it is the place to save state.
  n2d.quit = p

proc `keydown=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, key: Key)) =
  ## Set the callback for a key going down.
  n2d.keydown = p

proc `keyup=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, key: Key)) =
  ## Set the callback for a key coming back up.
  n2d.keyup = p

proc `mousemove=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, x, y, dx, dy: float)) =
  ## Set the callback for mouse motion: the position and the distance moved.
  n2d.mousemove = p

proc `mousepressed=`*(
    n2d: Nim2d, p: proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8)
) =
  ## Set the callback for a mouse button press: position, button, click count.
  n2d.mousepressed = p

proc `mousereleased=`*(
    n2d: Nim2d, p: proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8)
) =
  ## Set the callback for a mouse button release.
  n2d.mousereleased = p

proc `mousewheel=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, x, y: float)) =
  ## Set the callback for the scroll wheel; y is the usual vertical scroll.
  n2d.mousewheel = p

proc `textinput=`*(n2d: Nim2d, p: proc(nim2d: Nim2d, text: string)) =
  ## Set the callback for typed text, delivered as UTF-8 once `startTextInput`
  ## has turned text input on.
  n2d.textinput = p

proc `gamepadpressed=`*(
    n2d: Nim2d, p: proc(nim2d: Nim2d, id: GamepadId, button: GamepadButton)
) =
  ## Set the callback for a controller button press.
  n2d.gamepadpressed = p

proc `gamepadreleased=`*(
    n2d: Nim2d, p: proc(nim2d: Nim2d, id: GamepadId, button: GamepadButton)
) =
  ## Set the callback for a controller button release.
  n2d.gamepadreleased = p

proc `gamepadaxis=`*(
    n2d: Nim2d, p: proc(nim2d: Nim2d, id: GamepadId, axis: GamepadAxis, value: float)
) =
  ## Set the callback for stick and trigger motion. Sticks run -1 to 1,
  ## triggers 0 to 1.
  n2d.gamepadaxis = p

proc `touchpressed=`*(
    n2d: Nim2d, p: proc(nim2d: Nim2d, id: int64, x, y, pressure: float)
) =
  ## Set the callback for a finger touching the screen, with x and y in pixels.
  n2d.touchpressed = p

proc `touchmoved=`*(
    n2d: Nim2d, p: proc(nim2d: Nim2d, id: int64, x, y, pressure: float)
) =
  ## Set the callback for a finger moving while touching.
  n2d.touchmoved = p

proc `touchreleased=`*(
    n2d: Nim2d, p: proc(nim2d: Nim2d, id: int64, x, y, pressure: float)
) =
  ## Set the callback for a finger lifting off.
  n2d.touchreleased = p

proc `window_shown=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window becoming visible.
  n2d.window_shown = p

proc `window_hidden=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window being hidden.
  n2d.window_hidden = p

proc `window_moved=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window being moved.
  n2d.window_moved = p

proc `window_resized=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window being resized.
  n2d.window_resized = p

proc `window_minimized=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window being minimized.
  n2d.window_minimized = p

proc `window_maximized=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window being maximized.
  n2d.window_maximized = p

proc `window_restored=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window being restored from minimized or maximized.
  n2d.window_restored = p

proc `window_enter=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the mouse entering the window.
  n2d.window_enter = p

proc `window_leave=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the mouse leaving the window.
  n2d.window_leave = p

proc `window_focus_gained=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window gaining keyboard focus.
  n2d.window_focus_gained = p

proc `window_focus_lost=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window losing keyboard focus.
  n2d.window_focus_lost = p

proc `window_close=`*(n2d: Nim2d, p: proc(nim2d: Nim2d)) =
  ## Set the callback for the window being asked to close.
  n2d.window_close = p

# --- render-target / state -------------------------------------------------

proc setFont*(nim2d: Nim2d, font: Font) =
  ## Set the font `print` draws with.
  nim2d.font = font

proc setCanvas*(nim2d: Nim2d) =
  ## Render to the screen (default target).
  nim2d.gpu.setTarget(nim2d.gpu.swTex, nim2d.width, nim2d.height, nim2d.gpu.screenDepth)

proc setCanvas*(nim2d: Nim2d, canvas: Canvas) =
  ## Render to a canvas (off-screen target). Call inside `draw`.
  nim2d.gpu.setTarget(canvas.tex, canvas.width, canvas.height, canvas.depth)

proc clear*(nim2d: Nim2d, r, g, b: uint8, a: uint8 = 255) =
  ## Clear the current render target. Call inside `draw`.
  let p = nim2d.gpu.passes[^1]
  nim2d.gpu.clearTarget(p.target, p.w, p.h, (r, g, b, a), p.depth)

proc clear*(nim2d: Nim2d) =
  ## Clear the current render target to the background color.
  nim2d.clear(nim2d.background.r, nim2d.background.g, nim2d.background.b)

# --- scoped state ----------------------------------------------------------

template withColor*(nim2d: Nim2d, c: Color, body: untyped) =
  ## Run `body` with the draw color set to `c`, then restore the previous color.
  let savedColor = nim2d.color
  nim2d.setColor(c)
  body
  nim2d.setColor(savedColor)

template withFont*(nim2d: Nim2d, f: Font, body: untyped) =
  ## Run `body` with `f` as the font, then restore the previous font.
  let savedFont = nim2d.font
  nim2d.setFont(f)
  body
  nim2d.setFont(savedFont)

template withBlend*(nim2d: Nim2d, mode: BlendMode, body: untyped) =
  ## Run `body` with the given blend mode, then restore the previous one.
  let savedBlend = nim2d.blend
  nim2d.setBlendMode(mode)
  body
  nim2d.setBlendMode(savedBlend)

template withCanvas*(nim2d: Nim2d, canvas: Canvas, body: untyped) =
  ## Run `body` drawing into `canvas`, then switch back to the screen.
  nim2d.setCanvas(canvas)
  body
  nim2d.setCanvas()

template transformed*(
    nim2d: Nim2d, move: Vec2, angle: float, zoom: float, body: untyped
) =
  ## Run `body` inside a pushed transform, translated by `move`, turned by
  ## `angle` radians and scaled uniformly by `zoom`, then pop back. The later
  ## arguments can be left off, so `transformed(move = vec2(x, y)): ...` is
  ## enough when there is no rotation or scaling.
  nim2d.push()
  nim2d.translate(move.x, move.y)
  nim2d.rotate(angle)
  nim2d.scale(zoom, zoom)
  body
  nim2d.pop()

template transformed*(nim2d: Nim2d, move: Vec2, angle: float, body: untyped) =
  ## `transformed` without scaling.
  transformed(nim2d, move, angle, 1.0, body)

template transformed*(nim2d: Nim2d, move: Vec2, body: untyped) =
  ## `transformed` with a translation only.
  transformed(nim2d, move, 0.0, 1.0, body)

# --- lifecycle -------------------------------------------------------------

proc newNim2d*(
    title: string,
    x, y, width, height: cint,
    background: Color,
    highDpi = false,
    aa: int32 = 1,
    stencil = false,
): Nim2d =
  ## Open a window and set up the engine. (x, y) is the window position and
  ## `background` the color it clears to each frame. `highDpi` asks for a
  ## backing buffer at the display's real pixel resolution, `aa = 2` renders
  ## each frame at twice the size and scales it down for anti-aliasing, and
  ## `stencil` builds the stencil machinery that `stencil` masking needs.
  when defined(macosx):
    # By default macOS fullscreen enters a native "Spaces" fullscreen that sits
    # inside the display's usable area, so on a Mac with a menu bar or a notch it
    # leaves a black strip across the top. Turning Spaces off makes fullscreen a
    # borderless window over the whole display, which fills the screen edge to
    # edge and switches instantly with no transition animation, the behaviour a
    # game wants. The Cocoa video backend reads this when it initializes, so it
    # has to be set before SDL_Init.
    discard SDL_SetHint(SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES, "0")

  if not SDL_Init(SDL_InitFlags(SDL_INIT_VIDEO or SDL_INIT_GAMEPAD)):
    raise newException(CatchableError, "SDL_Init failed: " & $SDL_GetError())

  # Open any controller already connected at launch, so it is reported and polled
  # from the first frame instead of waiting for SDL's connect event, which lags.
  openConnectedGamepads()

  # High-DPI gives a backing buffer at the display's real pixel resolution, so on
  # a 2x screen the drawable, and getWidth/getHeight, are twice the point size.
  let flags = (if highDpi: SDL_WINDOW_HIGH_PIXEL_DENSITY else: 0'u64)
  let win = SDL_CreateWindow(title.cstring, width, height, SDL_WindowFlags(flags))
  if win == nil:
    raise newException(CatchableError, "SDL_CreateWindow failed: " & $SDL_GetError())
  discard SDL_SetWindowPosition(win, x, y)
  discard SDL_RaiseWindow(win)

  let noop = proc(nim2d: Nim2d) =
    discard

  result = Nim2d(
    width: width,
    height: height,
    gpu: newGpuContext(win, aa, stencil),
    background: background,
    fs: newFilesystem(),
    color: (255'u8, 255'u8, 255'u8, 255'u8),
    blend: bmAlpha,
    running: true,
    perfFreq: SDL_GetPerformanceFrequency(),
    load: noop,
    draw: noop,
    quit: noop,
    update: proc(nim2d: Nim2d, dt: float) =
      discard,
    keydown: proc(nim2d: Nim2d, key: Key) =
      discard,
    keyup: proc(nim2d: Nim2d, key: Key) =
      discard,
    mousemove: proc(nim2d: Nim2d, x, y, dx, dy: float) =
      discard,
    mousepressed: proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
      discard,
    mousereleased: proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
      discard,
    mousewheel: proc(nim2d: Nim2d, x, y: float) =
      discard,
    textinput: proc(nim2d: Nim2d, text: string) =
      discard,
    gamepadpressed: proc(nim2d: Nim2d, id: GamepadId, button: GamepadButton) =
      discard,
    gamepadreleased: proc(nim2d: Nim2d, id: GamepadId, button: GamepadButton) =
      discard,
    gamepadaxis: proc(nim2d: Nim2d, id: GamepadId, axis: GamepadAxis, value: float) =
      discard,
    touchpressed: proc(nim2d: Nim2d, id: int64, x, y, pressure: float) =
      discard,
    touchmoved: proc(nim2d: Nim2d, id: int64, x, y, pressure: float) =
      discard,
    touchreleased: proc(nim2d: Nim2d, id: int64, x, y, pressure: float) =
      discard,
    window_shown: noop,
    window_hidden: noop,
    window_moved: noop,
    window_resized: noop,
    window_minimized: noop,
    window_maximized: noop,
    window_restored: noop,
    window_enter: noop,
    window_leave: noop,
    window_focus_gained: noop,
    window_focus_lost: noop,
    window_close: noop,
  )
  result.initAudio()

proc newNim2d*(title: string, x, y, width, height: cint): Nim2d =
  ## Open a window with the default sky-blue background.
  newNim2d(title, x, y, width, height, (89'u8, 157'u8, 220'u8, 255'u8))

proc teardown(nim2d: Nim2d) =
  ## Run the `quit` callback, then tear down audio, the GPU and the window. This
  ## is reached from the tail of `play` on a normal exit and from an exit hook
  ## when `quit` or an exception cuts the loop short, so it guards against running
  ## twice. The GPU and window come down even if the `quit` callback raises.
  if nim2d.teardownRan:
    return
  nim2d.teardownRan = true
  try:
    nim2d.quit(nim2d)
  finally:
    nim2d.shutdownAudio()
    nim2d.gpu.destroy()
    SDL_DestroyWindow(nim2d.gpu.window)
    sdlQuit()

proc play*(nim2d: Nim2d) =
  ## Run the main loop: dispatch events, call `update` and `draw` every frame,
  ## and keep going until the window closes or `running` is set to false. The
  ## `quit` callback runs once after the loop, then audio, the GPU and the
  ## window are torn down. An exit hook runs the same teardown if the program
  ## ends some other way, so a `system.quit` or an escaping exception still
  ## releases the device and window instead of leaking them.
  addExitProc(
    proc() =
      try:
        nim2d.teardown()
      except CatchableError:
        discard
  )
  nim2d.load(nim2d)
  nim2d.lastCounter = SDL_GetPerformanceCounter()
  var evt: SDL_Event

  while nim2d.running:
    while SDL_PollEvent(addr evt):
      nim2d.dispatch(evt)

    let now = SDL_GetPerformanceCounter()
    nim2d.dt = float(now - nim2d.lastCounter) / float(nim2d.perfFreq)
    nim2d.lastCounter = now
    if nim2d.dt > 0:
      nim2d.fps = 1.0 / nim2d.dt

    nim2d.update(nim2d, nim2d.dt)

    # beginFrame writes the live swapchain size back into width/height, so the
    # projection and getWidth/getHeight track window resizes and fullscreen.
    if nim2d.gpu.beginFrame(nim2d.background, nim2d.width, nim2d.height):
      nim2d.draw(nim2d)
      nim2d.gpu.endFrame()

  nim2d.teardown()
