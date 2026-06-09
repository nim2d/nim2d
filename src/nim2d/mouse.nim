## Mouse polling. The `mousemove`, `mousepressed`, `mousereleased` and
## `mousewheel` callbacks (see events) cover edges; these read the live state.

import backend/sdl
import types

proc toMouseButton*(b: uint8): MouseButton =
  ## The nim2d MouseButton for an SDL button number.
  case b
  of 1: MouseButton.left
  of 2: MouseButton.middle
  of 3: MouseButton.right
  of 4: MouseButton.x1
  of 5: MouseButton.x2
  else: MouseButton.left

proc mousePosition*(): Vec2 =
  ## Cursor position relative to the window.
  var x, y: cfloat
  discard SDL_GetMouseState(addr x, addr y)
  (x.float, y.float)

proc mouseX*(): float = mousePosition().x
proc mouseY*(): float = mousePosition().y

proc isMouseDown*(button: int = 1): bool =
  ## Whether a mouse button is held. 1 is left, 2 is middle, 3 is right.
  var x, y: cfloat
  let state = SDL_GetMouseState(addr x, addr y)
  let mask = SDL_MouseButtonFlags(1'u32 shl (button - 1))
  (state and mask) != 0

proc isMouseDown*(button: MouseButton): bool =
  ## Whether a mouse button is held, as a MouseButton (the friendly form).
  let n = case button
    of MouseButton.left: 1
    of MouseButton.middle: 2
    of MouseButton.right: 3
    of MouseButton.x1: 4
    of MouseButton.x2: 5
  isMouseDown(n)

# --- cursor, capture and warping -------------------------------------------

proc setMouseVisible*(visible: bool) =
  ## Show or hide the mouse cursor.
  if visible: discard SDL_ShowCursor()
  else: discard SDL_HideCursor()

proc isMouseVisible*(): bool =
  ## Whether the cursor is shown.
  SDL_CursorVisible()

proc setRelativeMode*(nim2d: Nim2d, enabled: bool) =
  ## Capture the mouse and report relative motion, with the cursor hidden. The
  ## `mousemove` callback then reports movement deltas (dx, dy) without the
  ## pointer being pinned at a screen edge, which suits mouse-look and games
  ## that steer by mouse movement.
  discard SDL_SetWindowRelativeMouseMode(nim2d.gpu.window, enabled)

proc isRelativeMode*(nim2d: Nim2d): bool =
  ## Whether relative mouse mode is on.
  SDL_GetWindowRelativeMouseMode(nim2d.gpu.window)

proc setMouseGrabbed*(nim2d: Nim2d, grabbed: bool) =
  ## Confine the cursor to the window.
  discard SDL_SetWindowMouseGrab(nim2d.gpu.window, grabbed)

proc isMouseGrabbed*(nim2d: Nim2d): bool =
  ## Whether the cursor is confined to the window.
  SDL_GetWindowMouseGrab(nim2d.gpu.window)

proc setMousePosition*(nim2d: Nim2d, x, y: float) =
  ## Warp the cursor to a position inside the window.
  SDL_WarpMouseInWindow(nim2d.gpu.window, x.cfloat, y.cfloat)
