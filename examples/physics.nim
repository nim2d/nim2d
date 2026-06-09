## Rigid bodies falling and stacking, on the physics module. Click or hold space
## to drop boxes and balls, R clears them, ESC quits.
##
## Needs Box2D (brew install box2d). The simulation runs in meters and is scaled
## to pixels for drawing.

import std/[os, math]
import nim2d
import nim2d/physics

const
  W = 800
  H = 600
  scale = 50.0          # pixels per simulation meter

let n2d = newNim2d("nim2d - physics", 120, 80, W.cint, H.cint, (18'u8, 20'u8, 30'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 18)
let world = newWorld(0.0, 10.0)

type
  ShapeKind = enum skBox, skCircle
  Obj = object
    body: Body
    kind: ShapeKind
    size: float         # box half-extent or circle radius, in meters
    color: Color

var objs: seq[Obj]

# Static frame: a floor and two side walls, in meters.
proc wall(cx, cy, hw, hh: float) =
  let b = world.newBody(cx, cy, btStatic)
  b.addBox(hw, hh, friction = 0.7)
wall(W / 2 / scale, (H - 16).float / scale, W / 2 / scale, 16 / scale)   # floor
wall(8 / scale, H / 2 / scale, 8 / scale, H / scale)                     # left wall
wall((W - 8).float / scale, H / 2 / scale, 8 / scale, H / scale)         # right wall

proc spawn(px, py: float) =
  if objs.len > 200: return
  let size = random(0.16, 0.42)
  let col = (uint8(randomInt(120, 255)), uint8(randomInt(120, 255)),
             uint8(randomInt(120, 255)), 255'u8)
  let body = world.newBody(px / scale, py / scale, btDynamic)
  var o = Obj(body: body, size: size, color: col)
  if random(0.0, 1.0) < 0.5:
    o.kind = skBox
    body.addBox(size, size, density = 1.0, friction = 0.5, restitution = 0.2)
  else:
    o.kind = skCircle
    body.addCircle(size, density = 1.0, friction = 0.3, restitution = 0.4)
  objs.add o

proc reset() =
  for o in objs: o.body.destroy()
  objs.setLen(0)

n2d.load = proc(nim2d: Nim2d) =
  for i in 0 ..< 12: spawn(random(120.0, W - 120.0), random(40.0, 220.0))

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  spawn(x, y)

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false
  elif sc == Key.r: reset()
  elif sc == Key.space:
    for i in 0 ..< 6: spawn(random(120.0, W - 120.0), random(40.0, 120.0))

n2d.update = proc(nim2d: Nim2d, dt: float) =
  world.update(min(dt, 1.0 / 30.0))

n2d.draw = proc(nim2d: Nim2d) =
  # the static frame
  nim2d.setColor(60, 66, 86)
  nim2d.rectangle(0, H - 32, W, 32, filled = true)
  nim2d.rectangle(0, 0, 16, H, filled = true)
  nim2d.rectangle(W - 16, 0, 16, H, filled = true)

  for o in objs:
    let (mx, my) = o.body.position
    let cx = mx * scale
    let cy = my * scale
    let a = o.body.angle
    nim2d.setColor(o.color.r, o.color.g, o.color.b)
    case o.kind
    of skBox:
      let s = o.size * scale
      nim2d.push()
      nim2d.translate(cx, cy)
      nim2d.rotate(a)
      nim2d.rectangle(-s, -s, s * 2, s * 2, filled = true)
      nim2d.pop()
    of skCircle:
      let r = o.size * scale
      nim2d.circle(cx, cy, r, filled = true, segments = 20)
      nim2d.setColor(255, 255, 255)
      nim2d.line(@[(cx, cy), (cx + cos(a) * r, cy + sin(a) * r)], 2)

  nim2d.setFont(font)
  nim2d.setColor(225, 230, 245)
  nim2d.print("physics: " & $objs.len & " bodies   click/space to drop   R clears", 20, 16)

n2d.play()
