## love.timer-style timing.

import backend/sdl
import types

proc getTime*(): float =
  ## Seconds since SDL init, as a high-resolution value.
  float(SDL_GetPerformanceCounter()) / float(SDL_GetPerformanceFrequency())

proc getDelta*(nim2d: Nim2d): float =
  ## Seconds elapsed between the previous two frames.
  nim2d.dt

proc getFPS*(nim2d: Nim2d): float =
  nim2d.fps

proc sleep*(seconds: float) =
  SDL_Delay(Uint32(seconds * 1000))
