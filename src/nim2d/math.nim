## Random numbers, noise, curves, triangulation and small geometry helpers.
##
## This is pure Nim with no SDL or renderer dependency. It carries a seeded
## generator you can keep alongside the global one, normally distributed random,
## value/Perlin/simplex noise in the 0-to-1 range love uses, Bezier curves,
## ear-clipping polygon triangulation, and helpers like distance, angle, lerp
## and gamma to linear color conversion. The triangulation is what lets the
## shape drawing fill concave polygons.
##
## The standalone transform here is the same `Transform` the renderer uses for
## the transform stack, so `newTransform` and `transformPoint` build on it
## rather than introducing a second matrix type.

import std/math
import std/monotimes
import types
import transform

export transform

# --- vectors ---------------------------------------------------------------

# Vec2 is the (x, y) float tuple used for positions all over nim2d, so these
# operators work on any of them, including plain literals like (10.0, 20.0).

func vec2*(x, y: float): Vec2 =
  ## A 2D vector.
  (x, y)

func `+`*(a, b: Vec2): Vec2 = (a.x + b.x, a.y + b.y)
func `-`*(a, b: Vec2): Vec2 = (a.x - b.x, a.y - b.y)
func `-`*(a: Vec2): Vec2 = (-a.x, -a.y)
func `*`*(a: Vec2, s: float): Vec2 = (a.x * s, a.y * s)
func `*`*(s: float, a: Vec2): Vec2 = (a.x * s, a.y * s)
func `/`*(a: Vec2, s: float): Vec2 = (a.x / s, a.y / s)
proc `+=`*(a: var Vec2, b: Vec2) = a = (a.x + b.x, a.y + b.y)
proc `-=`*(a: var Vec2, b: Vec2) = a = (a.x - b.x, a.y - b.y)
proc `*=`*(a: var Vec2, s: float) = a = (a.x * s, a.y * s)

func dot*(a, b: Vec2): float = a.x * b.x + a.y * b.y
func lengthSq*(a: Vec2): float = a.x * a.x + a.y * a.y
func length*(a: Vec2): float = sqrt(a.x * a.x + a.y * a.y)

func normalized*(a: Vec2): Vec2 =
  ## The unit vector pointing the same way as a, or (0, 0) if a has no length.
  let l = a.length
  if l == 0: (0.0, 0.0) else: (a.x / l, a.y / l)

func lerp*(a, b: Vec2, t: float): Vec2 =
  ## Linear interpolation from a to b by t.
  (a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)

func rotated*(a: Vec2, angle: float): Vec2 =
  ## a turned counter-clockwise by angle radians.
  let c = cos(angle)
  let s = sin(angle)
  (a.x * c - a.y * s, a.x * s + a.y * c)

func fromAngle*(angle: float, magnitude = 1.0): Vec2 =
  ## A vector of the given length pointing at angle radians.
  (cos(angle) * magnitude, sin(angle) * magnitude)

# --- seeded generator (PCG32) ----------------------------------------------

type
  Rng* = object
    ## A seeded pseudo-random generator. It is a PCG32: a 64-bit linear
    ## congruential state with a permuted 32-bit output, small and fast, and it
    ## gives the same sequence from the same seed on every platform.
    state, inc: uint64
    spare: float        ## cached second sample from the gaussian pair
    hasSpare: bool

const
  pcgMul = 6364136223846793005'u64
  defaultSeed = 0x853c49e6748fea9b'u64
  defaultSeq = 0xda3e39cb94b95bdb'u64

proc nextUint*(rng: var Rng): uint32 =
  ## The next raw 32-bit value from the generator.
  let old = rng.state
  rng.state = old * pcgMul + (rng.inc or 1'u64)
  let xorshifted = uint32(((old shr 18'u64) xor old) shr 27'u64)
  let rot = uint32(old shr 59'u64)
  result = (xorshifted shr rot) or (xorshifted shl ((32'u32 - rot) and 31'u32))

proc setSeed*(rng: var Rng, seed: uint64, seq: uint64 = defaultSeq) =
  ## Reseed an existing generator in place.
  rng.state = 0
  rng.inc = (seq shl 1'u64) or 1'u64
  rng.hasSpare = false
  discard rng.nextUint()
  rng.state = rng.state + seed
  discard rng.nextUint()

proc newRng*(seed: uint64 = defaultSeed, seq: uint64 = defaultSeq): Rng =
  ## Make a seeded generator. The same seed and stream give the same sequence.
  result.setSeed(seed, seq)

proc nextBounded(rng: var Rng, bound: uint32): uint32 =
  # A uniform value in [0, bound) with no modulo bias, by rejection.
  if bound == 0: return rng.nextUint()
  let threshold = (0'u32 - bound) mod bound   # 2^32 mod bound
  while true:
    let r = rng.nextUint()
    if r >= threshold: return r mod bound

proc random*(rng: var Rng): float =
  ## A uniform float from 0 up to 1.
  rng.nextUint().float / 4294967296.0

proc random*(rng: var Rng, max: float): float =
  ## A uniform float from 0 up to max.
  rng.random() * max

proc random*(rng: var Rng, min, max: float): float =
  ## A uniform float from min up to max.
  min + rng.random() * (max - min)

proc randomInt*(rng: var Rng, min, max: int): int =
  ## A uniform integer from min to max, both ends included. The span from min to
  ## max has to fit in 32 bits.
  if max <= min: return min
  let span = uint64(max - min) + 1
  if span > uint64(high(uint32)):
    raise newException(ValueError, "randomInt: range wider than 2^32")
  min + int(rng.nextBounded(uint32(span)))

proc randomNormal*(rng: var Rng, mean = 0.0, stddev = 1.0): float =
  ## A normally distributed (gaussian) sample with the given mean and standard
  ## deviation, by the polar Box-Muller method.
  if rng.hasSpare:
    rng.hasSpare = false
    return mean + stddev * rng.spare
  var u, v, s: float
  while true:
    u = rng.random() * 2.0 - 1.0
    v = rng.random() * 2.0 - 1.0
    s = u * u + v * v
    if s > 0.0 and s < 1.0: break
  let mul = sqrt(-2.0 * ln(s) / s)
  rng.spare = v * mul
  rng.hasSpare = true
  mean + stddev * (u * mul)

# --- global generator ------------------------------------------------------

var gRng = newRng(cast[uint64](getMonoTime().ticks) xor 0x9e3779b97f4a7c15'u64)

proc setRandomSeed*(seed: uint64, seq: uint64 = defaultSeq) =
  ## Reseed the shared global generator.
  gRng.setSeed(seed, seq)

proc random*(): float =
  ## A uniform float from 0 up to 1 from the shared global generator.
  gRng.random()

proc random*(max: float): float =
  ## A uniform float from 0 up to max from the global generator.
  gRng.random(max)

proc random*(min, max: float): float =
  ## A uniform float from min up to max from the global generator.
  gRng.random(min, max)

proc randomInt*(min, max: int): int =
  ## A uniform integer from min to max inclusive, from the global generator. The
  ## span from min to max has to fit in 32 bits.
  gRng.randomInt(min, max)

proc randomNormal*(mean = 0.0, stddev = 1.0): float =
  ## A normally distributed sample from the global generator.
  gRng.randomNormal(mean, stddev)

# --- noise -----------------------------------------------------------------

const basePerm = [
  151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140,
  36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234,
  75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237,
  149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48,
  27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105,
  92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73,
  209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86,
  164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38,
  147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189,
  28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101,
  155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232,
  178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12,
  191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31,
  181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254,
  138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215,
  61, 156, 180]

const perm = block:
  var p: array[512, int]
  for i in 0 ..< 256:
    p[i] = basePerm[i]
    p[i + 256] = basePerm[i]
  p

const grad3 = [
  [1, 1, 0], [-1, 1, 0], [1, -1, 0], [-1, -1, 0],
  [1, 0, 1], [-1, 0, 1], [1, 0, -1], [-1, 0, -1],
  [0, 1, 1], [0, -1, 1], [0, 1, -1], [0, -1, -1]]

func fade(t: float): float = t * t * t * (t * (t * 6 - 15) + 10)

func mix(a, b, t: float): float = a + (b - a) * t

func to01(n: float): float = clamp((n + 1.0) * 0.5, 0.0, 0.999999)

func pgrad(hash: int, x, y, z: float): float =
  ## Improved-noise gradient: dot of (x,y,z) with one of twelve directions.
  let h = hash and 15
  let u = if h < 8: x else: y
  let v = if h < 4: y elif h == 12 or h == 14: x else: z
  result = (if (h and 1) == 0: u else: -u) + (if (h and 2) == 0: v else: -v)

func valueHash(i: int): float =
  ## A scrambled value from 0 up to 1 for one integer lattice point.
  var h = uint32(i) * 2654435761'u32
  h = (h xor (h shr 13'u32)) * 1274126177'u32
  h = h xor (h shr 16'u32)
  float(h) / 4294967296.0

proc noise*(x: float): float =
  ## 1D value noise from 0 up to 1, smooth within each integer cell.
  let i0 = floor(x).int
  let t = x - floor(x)
  mix(valueHash(i0), valueHash(i0 + 1), fade(t))

proc noise*(x, y, z: float): float =
  ## 3D Perlin noise mapped to the 0-to-1 range.
  let xi = floor(x).int and 255
  let yi = floor(y).int and 255
  let zi = floor(z).int and 255
  let xf = x - floor(x)
  let yf = y - floor(y)
  let zf = z - floor(z)
  let u = fade(xf)
  let v = fade(yf)
  let w = fade(zf)
  let a = perm[xi] + yi
  let aa = perm[a] + zi
  let ab = perm[a + 1] + zi
  let b = perm[xi + 1] + yi
  let ba = perm[b] + zi
  let bb = perm[b + 1] + zi
  let n = mix(
    mix(
      mix(pgrad(perm[aa], xf, yf, zf), pgrad(perm[ba], xf - 1, yf, zf), u),
      mix(pgrad(perm[ab], xf, yf - 1, zf), pgrad(perm[bb], xf - 1, yf - 1, zf), u),
      v),
    mix(
      mix(pgrad(perm[aa + 1], xf, yf, zf - 1), pgrad(perm[ba + 1], xf - 1, yf, zf - 1), u),
      mix(pgrad(perm[ab + 1], xf, yf - 1, zf - 1), pgrad(perm[bb + 1], xf - 1, yf - 1, zf - 1), u),
      v),
    w)
  to01(n)

proc noise*(x, y: float): float =
  ## 2D Perlin noise mapped to the 0-to-1 range.
  noise(x, y, 0.0)

func dot2(g: array[3, int], x, y: float): float = g[0].float * x + g[1].float * y
func dot3(g: array[3, int], x, y, z: float): float =
  g[0].float * x + g[1].float * y + g[2].float * z

proc simplexNoise*(x, y: float): float =
  ## 2D simplex noise mapped to the 0-to-1 range. Fewer directional artifacts than Perlin.
  const f2 = 0.3660254037844386      # 0.5 * (sqrt(3) - 1)
  const g2 = 0.21132486540518708     # (3 - sqrt(3)) / 6
  let s = (x + y) * f2
  let i = floor(x + s).int
  let j = floor(y + s).int
  let t = float(i + j) * g2
  let x0 = x - (float(i) - t)
  let y0 = y - (float(j) - t)
  var i1, j1: int
  if x0 > y0: (i1, j1) = (1, 0)
  else: (i1, j1) = (0, 1)
  let x1 = x0 - float(i1) + g2
  let y1 = y0 - float(j1) + g2
  let x2 = x0 - 1.0 + 2.0 * g2
  let y2 = y0 - 1.0 + 2.0 * g2
  let ii = i and 255
  let jj = j and 255
  let gi0 = perm[ii + perm[jj]] mod 12
  let gi1 = perm[ii + i1 + perm[jj + j1]] mod 12
  let gi2 = perm[ii + 1 + perm[jj + 1]] mod 12
  var n0, n1, n2 = 0.0
  var t0 = 0.5 - x0 * x0 - y0 * y0
  if t0 > 0:
    t0 *= t0
    n0 = t0 * t0 * dot2(grad3[gi0], x0, y0)
  var t1 = 0.5 - x1 * x1 - y1 * y1
  if t1 > 0:
    t1 *= t1
    n1 = t1 * t1 * dot2(grad3[gi1], x1, y1)
  var t2 = 0.5 - x2 * x2 - y2 * y2
  if t2 > 0:
    t2 *= t2
    n2 = t2 * t2 * dot2(grad3[gi2], x2, y2)
  to01(70.0 * (n0 + n1 + n2))

proc simplexNoise*(x, y, z: float): float =
  ## 3D simplex noise mapped to the 0-to-1 range.
  const f3 = 1.0 / 3.0
  const g3 = 1.0 / 6.0
  let s = (x + y + z) * f3
  let i = floor(x + s).int
  let j = floor(y + s).int
  let k = floor(z + s).int
  let t = float(i + j + k) * g3
  let x0 = x - (float(i) - t)
  let y0 = y - (float(j) - t)
  let z0 = z - (float(k) - t)
  var i1, j1, k1: int
  var i2, j2, k2: int
  if x0 >= y0:
    if y0 >= z0: (i1, j1, k1, i2, j2, k2) = (1, 0, 0, 1, 1, 0)
    elif x0 >= z0: (i1, j1, k1, i2, j2, k2) = (1, 0, 0, 1, 0, 1)
    else: (i1, j1, k1, i2, j2, k2) = (0, 0, 1, 1, 0, 1)
  else:
    if y0 < z0: (i1, j1, k1, i2, j2, k2) = (0, 0, 1, 0, 1, 1)
    elif x0 < z0: (i1, j1, k1, i2, j2, k2) = (0, 1, 0, 0, 1, 1)
    else: (i1, j1, k1, i2, j2, k2) = (0, 1, 0, 1, 1, 0)
  let x1 = x0 - float(i1) + g3
  let y1 = y0 - float(j1) + g3
  let z1 = z0 - float(k1) + g3
  let x2 = x0 - float(i2) + 2.0 * g3
  let y2 = y0 - float(j2) + 2.0 * g3
  let z2 = z0 - float(k2) + 2.0 * g3
  let x3 = x0 - 1.0 + 3.0 * g3
  let y3 = y0 - 1.0 + 3.0 * g3
  let z3 = z0 - 1.0 + 3.0 * g3
  let ii = i and 255
  let jj = j and 255
  let kk = k and 255
  let gi0 = perm[ii + perm[jj + perm[kk]]] mod 12
  let gi1 = perm[ii + i1 + perm[jj + j1 + perm[kk + k1]]] mod 12
  let gi2 = perm[ii + i2 + perm[jj + j2 + perm[kk + k2]]] mod 12
  let gi3 = perm[ii + 1 + perm[jj + 1 + perm[kk + 1]]] mod 12
  var n0, n1, n2, n3 = 0.0
  var t0 = 0.6 - x0 * x0 - y0 * y0 - z0 * z0
  if t0 > 0:
    t0 *= t0
    n0 = t0 * t0 * dot3(grad3[gi0], x0, y0, z0)
  var t1 = 0.6 - x1 * x1 - y1 * y1 - z1 * z1
  if t1 > 0:
    t1 *= t1
    n1 = t1 * t1 * dot3(grad3[gi1], x1, y1, z1)
  var t2 = 0.6 - x2 * x2 - y2 * y2 - z2 * z2
  if t2 > 0:
    t2 *= t2
    n2 = t2 * t2 * dot3(grad3[gi2], x2, y2, z2)
  var t3 = 0.6 - x3 * x3 - y3 * y3 - z3 * z3
  if t3 > 0:
    t3 *= t3
    n3 = t3 * t3 * dot3(grad3[gi3], x3, y3, z3)
  to01(32.0 * (n0 + n1 + n2 + n3))

# --- bezier curves ---------------------------------------------------------

type
  BezierCurve* = object
    ## A Bezier curve of any degree, holding its control points.
    points*: seq[Vec2]

proc newBezierCurve*(points: openArray[Vec2]): BezierCurve =
  ## A Bezier curve through the given control points (degree = points.len - 1).
  if points.len < 2:
    raise newException(ValueError, "bezier curve needs at least 2 control points")
  BezierCurve(points: @points)

proc evaluate*(curve: BezierCurve, t: float): Vec2 =
  ## The point on the curve at parameter t from 0 to 1, by de Casteljau.
  var pts = curve.points
  var n = pts.len
  while n > 1:
    for i in 0 ..< n - 1:
      pts[i] = ((1.0 - t) * pts[i].x + t * pts[i + 1].x,
                (1.0 - t) * pts[i].y + t * pts[i + 1].y)
    dec n
  pts[0]

proc derivative*(curve: BezierCurve): BezierCurve =
  ## The curve whose evaluation gives this curve's tangent vector.
  if curve.points.len < 2:
    raise newException(ValueError, "a single-point curve has no derivative")
  let n = (curve.points.len - 1).float
  var d = newSeq[Vec2](curve.points.len - 1)
  for i in 0 ..< curve.points.len - 1:
    d[i] = (n * (curve.points[i + 1].x - curve.points[i].x),
            n * (curve.points[i + 1].y - curve.points[i].y))
  BezierCurve(points: d)

proc render*(curve: BezierCurve, segments = 30): seq[Vec2] =
  ## Sample the curve into a polyline of segments+1 points, ready for `line`.
  let steps = max(segments, 1)
  result = newSeq[Vec2](steps + 1)
  for i in 0 .. steps:
    result[i] = curve.evaluate(i.float / steps.float)

# --- polygons --------------------------------------------------------------

func cross(o, a, b: Vec2): float =
  (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)

proc isConvex*(points: openArray[Vec2]): bool =
  ## True when the polygon outline is convex (a triangle or fewer points counts
  ## as convex).
  let n = points.len
  if n <= 3: return true
  var sign = 0
  for i in 0 ..< n:
    let c = cross(points[i], points[(i + 1) mod n], points[(i + 2) mod n])
    if c != 0:
      let s = if c > 0: 1 else: -1
      if sign == 0: sign = s
      elif s != sign: return false
  true

func pointInTriangle(p, a, b, c: Vec2): bool =
  ## Strictly inside the (counter-clockwise) triangle a, b, c.
  cross(a, b, p) > 0 and cross(b, c, p) > 0 and cross(c, a, p) > 0

proc triangulate*(points: openArray[Vec2]): seq[uint32] =
  ## Ear-clip a simple polygon into triangles, returning indices into `points`,
  ## three per triangle. Works for convex and concave outlines without holes;
  ## raises ValueError on fewer than 3 points or input it cannot triangulate.
  let n = points.len
  if n < 3:
    raise newException(ValueError, "triangulate: need at least 3 points")

  # Work counter-clockwise so a convex corner is a left turn (cross > 0).
  var signedArea = 0.0
  for i in 0 ..< n:
    let j = (i + 1) mod n
    signedArea += points[i].x * points[j].y - points[j].x * points[i].y
  var v = newSeq[int](n)
  if signedArea >= 0:
    for i in 0 ..< n: v[i] = i
  else:
    for i in 0 ..< n: v[i] = n - 1 - i

  result = newSeqOfCap[uint32]((n - 2) * 3)
  while v.len > 3:
    var clipped = false
    for i in 0 ..< v.len:
      let ip = (i + v.len - 1) mod v.len
      let inx = (i + 1) mod v.len
      let a = points[v[ip]]
      let b = points[v[i]]
      let c = points[v[inx]]
      if cross(a, b, c) <= 0: continue   # reflex or collinear, not an ear
      var ear = true
      for k in 0 ..< v.len:
        if k == ip or k == i or k == inx: continue
        if pointInTriangle(points[v[k]], a, b, c):
          ear = false
          break
      if ear:
        result.add uint32(v[ip])
        result.add uint32(v[i])
        result.add uint32(v[inx])
        v.delete(i)
        clipped = true
        break
    if not clipped:
      raise newException(ValueError,
        "triangulate: no ear found (degenerate or self-intersecting polygon)")
  result.add uint32(v[0])
  result.add uint32(v[1])
  result.add uint32(v[2])

# --- standalone transform --------------------------------------------------

proc newTransform*(): Transform =
  ## An identity standalone transform you can translate, rotate and scale.
  identity()

proc transformPoint*(t: Transform, x, y: float): Vec2 =
  ## Map a point through a standalone transform.
  let (px, py) = t.apply(x, y)
  (px, py)

# --- small helpers ---------------------------------------------------------

proc distance*(x1, y1, x2, y2: float): float =
  ## Euclidean distance between two points.
  let dx = x2 - x1
  let dy = y2 - y1
  sqrt(dx * dx + dy * dy)

proc distance*(a, b: Vec2): float =
  ## Euclidean distance between two points.
  distance(a.x, a.y, b.x, b.y)

proc angle*(x1, y1, x2, y2: float): float =
  ## Angle in radians from the first point to the second.
  arctan2(y2 - y1, x2 - x1)

proc angle*(a, b: Vec2): float =
  ## Angle in radians from a to b.
  angle(a.x, a.y, b.x, b.y)

proc lerp*(a, b, t: float): float =
  ## Linear interpolation from a to b by t.
  a + (b - a) * t

proc gammaToLinear*(c: float): float =
  ## Convert one sRGB gamma-space channel, 0 to 1, into linear space.
  if c <= 0.04045: c / 12.92
  else: pow((c + 0.055) / 1.055, 2.4)

proc linearToGamma*(c: float): float =
  ## Convert one linear channel, 0 to 1, into sRGB gamma space.
  if c <= 0.0031308: c * 12.92
  else: 1.055 * pow(c, 1.0 / 2.4) - 0.055

func toByte(c: float): uint8 = uint8(clamp(c, 0.0, 1.0) * 255.0 + 0.5)

proc gammaToLinear*(c: Color): Color =
  ## Convert an sRGB color to linear space, leaving alpha unchanged.
  (toByte(gammaToLinear(c.r.float / 255)),
   toByte(gammaToLinear(c.g.float / 255)),
   toByte(gammaToLinear(c.b.float / 255)), c.a)

proc linearToGamma*(c: Color): Color =
  ## Convert a linear color to sRGB gamma space, leaving alpha unchanged.
  (toByte(linearToGamma(c.r.float / 255)),
   toByte(linearToGamma(c.g.float / 255)),
   toByte(linearToGamma(c.b.float / 255)), c.a)
