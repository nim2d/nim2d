## Immediate-mode 2D shapes, broken into triangles for the batch renderer.
##
## SDL2_gfx, the old primitive backend, has no SDL3 successor, so every shape is
## turned into triangles or edges here and fed to the GPU batcher. Angles are in
## radians, the same as love2d. Outlines are drawn as quad strips.
##
## Coordinates use Nim's default `float` for ergonomics and get converted to
## float32 only when building GPU vertices.

import std/math
import types
import backend/renderer

# --- helpers ---------------------------------------------------------------

func norm(c: Color): tuple[r, g, b, a: float32] =
  (c.r.float32 / 255, c.g.float32 / 255, c.b.float32 / 255, c.a.float32 / 255)

proc emitColored(nim2d: Nim2d, verts: openArray[Vertex], idx: openArray[uint32]) =
  nim2d.gpu.addGeometry(pkColored, nim2d.blend, nil, verts, idx)

proc mkVert(x, y: float, c: tuple[r, g, b, a: float32]): Vertex =
  Vertex(x: x.float32, y: y.float32, u: 0, v: 0, r: c.r, g: c.g, b: c.b, a: c.a)

proc fillFan(nim2d: Nim2d, center: Vec2, rim: openArray[Vec2]) =
  ## Triangle fan from `center` around `rim` (convex shapes / sectors).
  if rim.len < 2: return
  let c = norm(nim2d.color)
  var verts = newSeq[Vertex](rim.len + 1)
  verts[0] = mkVert(center.x, center.y, c)
  for i, p in rim: verts[i + 1] = mkVert(p.x, p.y, c)
  var idx = newSeq[uint32]()
  for i in 0 ..< rim.len - 1:
    idx.add 0'u32
    idx.add uint32(i + 1)
    idx.add uint32(i + 2)
  nim2d.emitColored(verts, idx)

proc segQuad(nim2d: Nim2d, p0, p1: Vec2, width: float) =
  ## A line segment as a quad of the given width.
  let dx = p1.x - p0.x
  let dy = p1.y - p0.y
  let len = sqrt(dx * dx + dy * dy)
  if len <= 0: return
  let nx = -dy / len * (width / 2)
  let ny = dx / len * (width / 2)
  let c = norm(nim2d.color)
  let verts = [
    mkVert(p0.x + nx, p0.y + ny, c), mkVert(p1.x + nx, p1.y + ny, c),
    mkVert(p1.x - nx, p1.y - ny, c), mkVert(p0.x - nx, p0.y - ny, c)]
  nim2d.emitColored(verts, [0'u32, 1, 2, 0, 2, 3])

proc polyline(nim2d: Nim2d, pts: openArray[Vec2], closed: bool, width = 1.0) =
  if pts.len < 2: return
  for i in 0 ..< pts.len - 1:
    nim2d.segQuad(pts[i], pts[i + 1], width)
  if closed and pts.len > 2:
    nim2d.segQuad(pts[^1], pts[0], width)

proc fillConvex(nim2d: Nim2d, pts: openArray[Vec2]) =
  ## Fan fill from the polygon centroid (correct for convex polygons).
  if pts.len < 3: return
  var cx, cy: float
  for p in pts:
    cx += p.x
    cy += p.y
  cx /= pts.len.float
  cy /= pts.len.float
  var rim = newSeq[Vec2](pts.len + 1)
  for i, p in pts: rim[i] = p
  rim[^1] = pts[0]
  nim2d.fillFan((cx, cy), rim)

iterator arcPoints(cx, cy, rx, ry, a1, a2: float, segments: int): Vec2 =
  let steps = max(segments, 1)
  for i in 0 .. steps:
    let t = a1 + (a2 - a1) * (i.float / steps.float)
    yield (cx + cos(t) * rx, cy + sin(t) * ry)

# --- state -----------------------------------------------------------------

proc setColor*(nim2d: Nim2d, r, g, b: uint8, a: uint8 = 255) =
  nim2d.color = (r, g, b, a)

proc setBackgroundColor*(nim2d: Nim2d, r, g, b: uint8, a: uint8 = 255) =
  nim2d.background = (r, g, b, a)

proc setBlendMode*(nim2d: Nim2d, mode: BlendMode) =
  nim2d.blend = mode

proc setBlendMode*(nim2d: Nim2d, mode: string) =
  nim2d.blend = case mode
    of "blend", "alpha": bmAlpha
    of "add": bmAdd
    of "mod", "multiply": bmMod
    else: bmNone

# --- shapes ----------------------------------------------------------------

proc circle*(nim2d: Nim2d, x, y, radius: float, filled = false, segments = 48) =
  var rim = newSeq[Vec2]()
  for p in arcPoints(x, y, radius, radius, 0, TAU, segments): rim.add p
  if filled: nim2d.fillFan((x, y), rim)
  else: nim2d.polyline(rim, closed = false)

proc ellipse*(nim2d: Nim2d, x, y, rx, ry: float, filled = false, segments = 48) =
  var rim = newSeq[Vec2]()
  for p in arcPoints(x, y, rx, ry, 0, TAU, segments): rim.add p
  if filled: nim2d.fillFan((x, y), rim)
  else: nim2d.polyline(rim, closed = false)

proc arc*(nim2d: Nim2d, x, y, radius, a1, a2: float, segments = 48) =
  var pts = newSeq[Vec2]()
  for p in arcPoints(x, y, radius, radius, a1, a2, segments): pts.add p
  nim2d.polyline(pts, closed = false)

proc pie*(nim2d: Nim2d, x, y, radius, a1, a2: float, filled = false, segments = 48) =
  var rim = newSeq[Vec2]()
  for p in arcPoints(x, y, radius, radius, a1, a2, segments): rim.add p
  if filled:
    nim2d.fillFan((x, y), rim)
  else:
    nim2d.polyline(rim, closed = false)
    nim2d.segQuad((x, y), rim[0], 1)
    nim2d.segQuad((x, y), rim[^1], 1)

proc roundedRectPoints(x, y, w, h, r: float, seg = 8): seq[Vec2] =
  let rr = min(r, min(w, h) / 2)
  result = @[]
  for p in arcPoints(x + w - rr, y + rr, rr, rr, -PI / 2, 0, seg): result.add p
  for p in arcPoints(x + w - rr, y + h - rr, rr, rr, 0, PI / 2, seg): result.add p
  for p in arcPoints(x + rr, y + h - rr, rr, rr, PI / 2, PI, seg): result.add p
  for p in arcPoints(x + rr, y + rr, rr, rr, PI, 3 * PI / 2, seg): result.add p

proc rectangle*(nim2d: Nim2d, x, y, w, h: float, filled = false, roundness = 0.0) =
  if roundness > 0:
    let pts = roundedRectPoints(x, y, w, h, roundness)
    if filled: nim2d.fillConvex(pts)
    else: nim2d.polyline(pts, closed = true)
  else:
    let pts = @[(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    if filled: nim2d.fillConvex(pts)
    else: nim2d.polyline(pts, closed = true)

proc triangle*(nim2d: Nim2d, x1, y1, x2, y2, x3, y3: float, filled = false) =
  let pts = @[(x1, y1), (x2, y2), (x3, y3)]
  if filled: nim2d.fillConvex(pts)
  else: nim2d.polyline(pts, closed = true)

proc polygon*(nim2d: Nim2d, xs, ys: openArray[float], filled = false) =
  if xs.len != ys.len:
    raise newException(ValueError, "polygon: x and y must have equal length")
  if xs.len < 3:
    raise newException(ValueError, "polygon: need at least 3 points")
  var pts = newSeq[Vec2](xs.len)
  for i in 0 ..< xs.len: pts[i] = (xs[i], ys[i])
  if filled: nim2d.fillConvex(pts)
  else: nim2d.polyline(pts, closed = true)

proc line*(nim2d: Nim2d, points: openArray[Vec2], width = 1.0) =
  nim2d.polyline(points, closed = false, width)

proc points*(nim2d: Nim2d, pts: openArray[Vec2], size = 1.0) =
  let c = norm(nim2d.color)
  let h = size / 2
  for p in pts:
    let verts = [
      mkVert(p.x - h, p.y - h, c), mkVert(p.x + h, p.y - h, c),
      mkVert(p.x + h, p.y + h, c), mkVert(p.x - h, p.y + h, c)]
    nim2d.emitColored(verts, [0'u32, 1, 2, 0, 2, 3])
