## Minimal SDL3_image binding (the core sdl3_nim binding doesn't cover it).
## Linked directly via -lSDL3_image (see config.nims).

import sdl

proc IMG_Load*(file: cstring): ptr SDL_Surface {.cdecl, importc: "IMG_Load".}
proc IMG_SavePNG*(surface: ptr SDL_Surface, file: cstring): bool {.cdecl, importc: "IMG_SavePNG".}
