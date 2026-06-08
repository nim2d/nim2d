## Window queries and control (love.window).

import backend/sdl
import types
import imagedata

proc setTitle*(nim2d: Nim2d, title: string) =
  discard SDL_SetWindowTitle(nim2d.gpu.window, title.cstring)

proc getWidth*(nim2d: Nim2d): int32 = nim2d.width
proc getHeight*(nim2d: Nim2d): int32 = nim2d.height
proc getSize*(nim2d: Nim2d): tuple[w, h: int32] = (nim2d.width, nim2d.height)

proc setSize*(nim2d: Nim2d, width, height: int32) =
  ## Resize the window, and the size the engine draws with.
  discard SDL_SetWindowSize(nim2d.gpu.window, width.cint, height.cint)
  nim2d.width = width
  nim2d.height = height

proc setResizable*(nim2d: Nim2d, resizable: bool) =
  ## Allow or stop the user resizing the window.
  discard SDL_SetWindowResizable(nim2d.gpu.window, resizable)

proc setFullscreen*(nim2d: Nim2d, fullscreen: bool) =
  ## Switch between fullscreen and windowed.
  discard SDL_SetWindowFullscreen(nim2d.gpu.window, fullscreen)

proc isFullscreen*(nim2d: Nim2d): bool =
  ## Whether the window is fullscreen.
  (uint64(SDL_GetWindowFlags(nim2d.gpu.window)) and SDL_WINDOW_FULLSCREEN) != 0

proc minimize*(nim2d: Nim2d) =
  ## Minimize the window to the taskbar or dock.
  discard SDL_MinimizeWindow(nim2d.gpu.window)

proc maximize*(nim2d: Nim2d) =
  ## Maximize the window.
  discard SDL_MaximizeWindow(nim2d.gpu.window)

proc restore*(nim2d: Nim2d) =
  ## Restore a minimized or maximized window to its previous size.
  discard SDL_RestoreWindow(nim2d.gpu.window)

proc getDesktopDimensions*(): tuple[w, h: int32] =
  ## The desktop resolution of the primary display.
  let mode = SDL_GetDesktopDisplayMode(SDL_GetPrimaryDisplay())
  if mode == nil: return (0'i32, 0'i32)
  (mode.w.int32, mode.h.int32)

proc setIcon*(nim2d: Nim2d, data: ImageData) =
  ## Set the window icon from an ImageData.
  if data.width <= 0 or data.height <= 0: return
  let surf = SDL_CreateSurfaceFrom(data.width.cint, data.height.cint,
    SDL_PIXELFORMAT_RGBA32, addr data.pixels[0], (data.width.int * 4).cint)
  if surf == nil: return
  discard SDL_SetWindowIcon(nim2d.gpu.window, surf)
  SDL_DestroySurface(surf)

proc showMessageBox*(nim2d: Nim2d, title, message: string) =
  ## Show a simple information message box, blocking until it is dismissed.
  discard SDL_ShowSimpleMessageBox(
    SDL_MessageBoxFlags(SDL_MESSAGEBOX_INFORMATION),
    title.cstring, message.cstring, nim2d.gpu.window)

proc setVSync*(nim2d: Nim2d, on: bool) =
  ## Turn vertical sync on or off. With it off the frame rate is uncapped, which
  ## is handy for benchmarking. Vsync is always available; if the immediate mode
  ## the off state wants is not supported, vsync stays on.
  let dev = nim2d.gpu.device
  let win = nim2d.gpu.window
  var mode = (if on: SDL_GPU_PRESENTMODE_VSYNC else: SDL_GPU_PRESENTMODE_IMMEDIATE)
  if not on and not SDL_WindowSupportsGPUPresentMode(dev, win, mode):
    mode = SDL_GPU_PRESENTMODE_VSYNC
  discard SDL_SetGPUSwapchainParameters(dev, win, SDL_GPU_SWAPCHAINCOMPOSITION_SDR, mode)

proc getDPIScale*(nim2d: Nim2d): float =
  ## The ratio of backing pixels to window points. It is 1.0 on a normal display
  ## or when high-DPI is off, and 2.0 on a 2x display with high-DPI enabled.
  SDL_GetWindowPixelDensity(nim2d.gpu.window).float
