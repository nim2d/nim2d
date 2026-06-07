## Minimal SDL3_ttf binding (the core sdl3_nim binding doesn't cover it).
## Linked directly via -lSDL3_ttf (see config.nims). SDL_ttf 3.x takes UTF-8
## text directly (length 0 == NUL-terminated), so no rune-pointer juggling.

import sdl

type TTF_Font* = object

proc TTF_Init*(): bool {.cdecl, importc: "TTF_Init".}
proc TTF_Quit*() {.cdecl, importc: "TTF_Quit".}
proc TTF_OpenFont*(file: cstring, ptsize: cfloat): ptr TTF_Font {.cdecl, importc: "TTF_OpenFont".}
proc TTF_CloseFont*(font: ptr TTF_Font) {.cdecl, importc: "TTF_CloseFont".}
proc TTF_RenderText_Blended*(font: ptr TTF_Font, text: cstring, length: csize_t,
  fg: SDL_Color): ptr SDL_Surface {.cdecl, importc: "TTF_RenderText_Blended".}
proc TTF_GetStringSize*(font: ptr TTF_Font, text: cstring, length: csize_t,
  w, h: ptr cint): bool {.cdecl, importc: "TTF_GetStringSize".}
proc TTF_GetFontAscent*(font: ptr TTF_Font): cint {.cdecl, importc: "TTF_GetFontAscent".}
proc TTF_GetFontDescent*(font: ptr TTF_Font): cint {.cdecl, importc: "TTF_GetFontDescent".}
proc TTF_GetFontHeight*(font: ptr TTF_Font): cint {.cdecl, importc: "TTF_GetFontHeight".}
