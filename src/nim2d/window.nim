## Window queries / mutation (love.window subset; grows over time).

import backend/sdl
import types

proc setTitle*(nim2d: Nim2d, title: string) =
  discard SDL_SetWindowTitle(nim2d.gpu.window, title.cstring)

proc getWidth*(nim2d: Nim2d): int32 = nim2d.width
proc getHeight*(nim2d: Nim2d): int32 = nim2d.height
proc getSize*(nim2d: Nim2d): tuple[w, h: int32] = (nim2d.width, nim2d.height)
