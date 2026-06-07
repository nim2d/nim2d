## Images and the shared textured-quad draw used by images and canvases.

import types
import transform
import backend/sdl
import backend/sdlimage
import backend/renderer

# --- shared drawable quad --------------------------------------------------

proc draw*(t: Texture, nim2d: Nim2d, x, y: float, angle: float = 0,
           sx: float = 1, sy: float = 1, ox: float = 0, oy: float = 0,
           flipH = false, flipV = false) =
  ## Draw a texture (image or canvas) with rotation/scale about origin (ox,oy).
  let tr = identity().translate(x, y).rotate(angle).scale(sx, sy)
  let w = t.width.float
  let h = t.height.float
  let (x0, y0) = tr.apply(0 - ox, 0 - oy)
  let (x1, y1) = tr.apply(w - ox, 0 - oy)
  let (x2, y2) = tr.apply(w - ox, h - oy)
  let (x3, y3) = tr.apply(0 - ox, h - oy)
  let c = (t.tint.r.float32 / 255, t.tint.g.float32 / 255,
           t.tint.b.float32 / 255, t.tint.a.float32 / 255)
  var u0 = 0'f32; var u1 = 1'f32
  var v0 = 0'f32; var v1 = 1'f32
  if flipH: swap(u0, u1)
  if flipV: swap(v0, v1)
  template vtx(px, py, tu, tv: untyped): Vertex =
    Vertex(x: px.float32, y: py.float32, u: tu, v: tv, r: c[0], g: c[1], b: c[2], a: c[3])
  let verts = [vtx(x0, y0, u0, v0), vtx(x1, y1, u1, v0),
               vtx(x2, y2, u1, v1), vtx(x3, y3, u0, v1)]
  nim2d.gpu.addGeometry(pkTextured, nim2d.blend, t.tex, verts, [0'u32, 1, 2, 0, 2, 3])

# --- images ----------------------------------------------------------------

proc newImage*(nim2d: Nim2d, filename: string): Image =
  var surf = IMG_Load(filename.cstring)
  if surf == nil:
    raise newException(IOError, "could not load image '" & filename & "': " & $SDL_GetError())
  if surf.format != SDL_PIXELFORMAT_RGBA32:
    let conv = SDL_ConvertSurface(surf, SDL_PIXELFORMAT_RGBA32)
    SDL_DestroySurface(surf)
    if conv == nil:
      raise newException(IOError, "could not convert image '" & filename & "'")
    surf = conv
  let tex = nim2d.gpu.createTextureFromPixels(surf.pixels, surf.w, surf.h, surf.pitch)
  result = Image(tex: tex, width: surf.w, height: surf.h,
                 tint: (255'u8, 255'u8, 255'u8, 255'u8))
  SDL_DestroySurface(surf)

proc setColorMod*(t: Texture, r, g, b: uint8) =
  t.tint = (r, g, b, t.tint.a)

proc setAlphaMod*(t: Texture, a: uint8) =
  t.tint = (t.tint.r, t.tint.g, t.tint.b, a)

proc getWidth*(t: Texture): int32 = t.width
proc getHeight*(t: Texture): int32 = t.height
proc getDimensions*(t: Texture): tuple[w, h: int32] = (t.width, t.height)

proc destroy*(nim2d: Nim2d, t: Texture) =
  if t.tex != nil:
    SDL_ReleaseGPUTexture(nim2d.gpu.device, t.tex)
    t.tex = nil
