## 2D affine transform.
##
## It's stored as the six significant components of a 3x3 affine matrix. The
## mapping works out to
##   x' = a*x + c*y + e
##   y' = b*x + d*y + f
##
## nim2d bakes transforms into vertices on the CPU, since the renderer's only GPU
## uniform is the orthographic projection, so this is what shape and image
## drawing use to place geometry. The push/pop transform stack from love2d
## (graphics.push, translate, rotate, scale) builds on these same operations.

import std/math

type
  Transform* = object
    a*, b*, c*, d*, e*, f*: float

func identity*(): Transform =
  Transform(a: 1, b: 0, c: 0, d: 1, e: 0, f: 0)

func `*`*(p, q: Transform): Transform =
  ## Compose two transforms (apply `q` first, then `p`): result = p * q.
  Transform(
    a: p.a * q.a + p.c * q.b,
    b: p.b * q.a + p.d * q.b,
    c: p.a * q.c + p.c * q.d,
    d: p.b * q.c + p.d * q.d,
    e: p.a * q.e + p.c * q.f + p.e,
    f: p.b * q.e + p.d * q.f + p.f,
  )

func translate*(t: Transform, tx, ty: float): Transform =
  t * Transform(a: 1, b: 0, c: 0, d: 1, e: tx, f: ty)

func rotate*(t: Transform, radians: float): Transform =
  let cs = cos(radians)
  let sn = sin(radians)
  t * Transform(a: cs, b: sn, c: -sn, d: cs, e: 0, f: 0)

func scale*(t: Transform, sx, sy: float): Transform =
  t * Transform(a: sx, b: 0, c: 0, d: sy, e: 0, f: 0)

func apply*(t: Transform, x, y: float): (float, float) =
  ## Map a local point through the transform.
  (t.a * x + t.c * y + t.e, t.b * x + t.d * y + t.f)
