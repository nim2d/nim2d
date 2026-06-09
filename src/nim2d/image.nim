## Images and the shared textured-quad draw used by images and canvases.

import types
import transform
import backend/sdl
import backend/sdlimage
import backend/renderer

# --- shared drawable quad --------------------------------------------------

proc emitQuad(nim2d: Nim2d, tex: ptr SDL_GPUTexture, sampler: ptr SDL_GPUSampler,
              tint: Color, w, h, x, y, angle, sx, sy, ox, oy: float,
              u0, v0, u1, v1: float32) =
  ## Place one textured quad of size w by h, with rotation and scale about the
  ## origin (ox, oy), and the given texcoords.
  let tr = identity().translate(x, y).rotate(angle).scale(sx, sy)
  let (x0, y0) = tr.apply(0 - ox, 0 - oy)
  let (x1, y1) = tr.apply(w - ox, 0 - oy)
  let (x2, y2) = tr.apply(w - ox, h - oy)
  let (x3, y3) = tr.apply(0 - ox, h - oy)
  let c = (tint.r.float32 / 255, tint.g.float32 / 255,
           tint.b.float32 / 255, tint.a.float32 / 255)
  template vtx(px, py, tu, tv: untyped): Vertex =
    Vertex(x: px.float32, y: py.float32, u: tu, v: tv, r: c[0], g: c[1], b: c[2], a: c[3])
  let verts = [vtx(x0, y0, u0, v0), vtx(x1, y1, u1, v0),
               vtx(x2, y2, u1, v1), vtx(x3, y3, u0, v1)]
  nim2d.gpu.addGeometry(pkTextured, nim2d.blend, tex, verts, [0'u32, 1, 2, 0, 2, 3], sampler)

proc draw*(t: Texture, nim2d: Nim2d, x, y: float, angle: float = 0,
           sx: float = 1, sy: float = 1, ox: float = 0, oy: float = 0,
           flipH = false, flipV = false) =
  ## Draw a texture (image or canvas) with rotation/scale about origin (ox,oy).
  var u0 = 0'f32; var u1 = 1'f32
  var v0 = 0'f32; var v1 = 1'f32
  if flipH: swap(u0, u1)
  if flipV: swap(v0, v1)
  emitQuad(nim2d, t.tex, nim2d.gpu.samplerFor(t.filter, t.wrap), t.tint,
           t.width.float, t.height.float,
           x, y, angle, sx, sy, ox, oy, u0, v0, u1, v1)

proc newQuad*(x, y, w, h, sw, sh: float): Quad =
  ## A sub-region (x, y, w, h) of a texture that is sw by sh pixels.
  Quad(u0: (x / sw).float32, v0: (y / sh).float32,
       u1: ((x + w) / sw).float32, v1: ((y + h) / sh).float32,
       w: w.float32, h: h.float32)

proc draw*(t: Texture, nim2d: Nim2d, quad: Quad, x, y: float, angle: float = 0,
           sx: float = 1, sy: float = 1, ox: float = 0, oy: float = 0) =
  ## Draw just the `quad` region of a texture.
  emitQuad(nim2d, t.tex, nim2d.gpu.samplerFor(t.filter, t.wrap), t.tint,
           quad.w.float, quad.h.float,
           x, y, angle, sx, sy, ox, oy, quad.u0, quad.v0, quad.u1, quad.v1)

proc setFilter*(t: Texture, filter: Filter) =
  ## Choose smooth sampling (`filLinear`, the default) or sharp, blocky sampling
  ## (`filNearest`), which keeps pixel art crisp when scaled up.
  t.filter = filter

proc setWrap*(t: Texture, wrap: Wrap) =
  ## Choose how texcoords outside 0..1 behave: clamp to the edge (the default),
  ## repeat, or mirror. Repeat is what you want for a tiling texture.
  t.wrap = wrap

# --- images ----------------------------------------------------------------

proc newImage*(nim2d: Nim2d, filename: string, mipmaps = false): Image =
  var surf = IMG_Load(filename.cstring)
  if surf == nil:
    raise newException(IOError, "could not load image '" & filename & "': " & $SDL_GetError())
  if surf.format != SDL_PIXELFORMAT_RGBA32:
    let conv = SDL_ConvertSurface(surf, SDL_PIXELFORMAT_RGBA32)
    SDL_DestroySurface(surf)
    if conv == nil:
      raise newException(IOError, "could not convert image '" & filename & "'")
    surf = conv
  let tex = nim2d.gpu.createTextureFromPixels(surf.pixels, surf.w, surf.h, surf.pitch, mipmaps)
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
