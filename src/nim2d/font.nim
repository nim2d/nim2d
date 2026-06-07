## Text rendering via SDL_ttf 3.x.
##
## Rasterizes each string to a surface with TTF_RenderText_Blended, uploads it
## as a transient texture, and draws it as a quad. UTF-8 in, no rune-pointer
## juggling.

import types
import backend/sdl
import backend/sdlttf
import backend/renderer
import image

var ttfReady = false

proc ensureTtf() =
  if not ttfReady:
    if not TTF_Init():
      raise newException(CatchableError, "TTF_Init failed: " & $SDL_GetError())
    ttfReady = true

proc newFont*(filename: string, size: cint): Font =
  ensureTtf()
  let f = TTF_OpenFont(filename.cstring, size.cfloat)
  if f == nil:
    raise newException(IOError, "could not open font '" & filename & "': " & $SDL_GetError())
  Font(font: cast[pointer](f), size: size)

proc getAscent*(font: Font): int = TTF_GetFontAscent(cast[ptr TTF_Font](font.font)).int
proc getDescent*(font: Font): int = TTF_GetFontDescent(cast[ptr TTF_Font](font.font)).int
proc getHeight*(font: Font): int = TTF_GetFontHeight(cast[ptr TTF_Font](font.font)).int

proc getSize*(font: Font, text: string): tuple[w, h: int32] =
  var w, h: cint
  discard TTF_GetStringSize(cast[ptr TTF_Font](font.font), text.cstring,
                            csize_t(text.len), addr w, addr h)
  (w.int32, h.int32)

proc print*(nim2d: Nim2d, text: string, x, y: float, angle: float = 0,
            sx: float = 1, sy: float = 1) =
  ## Draw `text` in the current color using the current font. Call inside `draw`.
  if nim2d.font == nil or nim2d.font.font == nil:
    return
  if text.len == 0:
    return
  let f = cast[ptr TTF_Font](nim2d.font.font)
  let col = SDL_Color(r: nim2d.color.r, g: nim2d.color.g, b: nim2d.color.b, a: nim2d.color.a)
  var surf = TTF_RenderText_Blended(f, text.cstring, csize_t(text.len), col)
  if surf == nil: return
  if surf.format != SDL_PIXELFORMAT_RGBA32:
    let conv = SDL_ConvertSurface(surf, SDL_PIXELFORMAT_RGBA32)
    SDL_DestroySurface(surf)
    if conv == nil: return
    surf = conv

  let tex = nim2d.gpu.createTextureFromPixels(surf.pixels, surf.w, surf.h, surf.pitch)
  let glyphs = Texture(tex: tex, width: surf.w, height: surf.h,
                       tint: (255'u8, 255'u8, 255'u8, 255'u8))
  SDL_DestroySurface(surf)
  glyphs.draw(nim2d, x, y, angle, sx, sy)
  nim2d.gpu.addTempTexture(tex)
