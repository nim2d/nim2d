## Curated access to the SDL3 binding.
##
## This re-exports dinau/sdl3_nim and adds small shims for the handful of C
## symbols that collide under Nim's case and underscore insensitive identifier
## rules. One example is the `SDL_QUIT` type alias, which shadows the `SDL_Quit`
## proc. Internal nim2d modules import this module rather than `sdl3_nim`
## directly, and always use the canonical SDL3 names like `SDL_EVENT_QUIT`
## instead of the legacy `SDL_QUIT`.

import sdl3_nim
export sdl3_nim

proc sdlQuit*() {.cdecl, importc: "SDL_Quit".}
