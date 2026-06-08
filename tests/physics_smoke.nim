## Headless physics check. It needs Box2D, so it is kept out of the auto-run test
## suite (the name does not start with "t") and is run on its own by CI on the
## platforms where Box2D is installed:
##
##   nim c -r tests/physics_smoke.nim

import std/math
import nim2d/physics

let w = newWorld(0.0, 10.0)
let ball = w.newBody(0.0, 0.0, btDynamic)
ball.addCircle(0.5)

let y0 = ball.position.y
for i in 0 ..< 60:                 # about one second of simulation
  w.update(1.0 / 60.0)
let p = ball.position
let v = ball.velocity

# Under gravity 10 for one second the body should fall about 5 units and reach a
# downward speed near 10.
doAssert p.y > y0 + 4.0, "body did not fall as expected: y = " & $p.y
doAssert v.y > 9.0, "downward speed too low: vy = " & $v.y

# A box dropped onto a static floor should come to rest on top of it.
let floor = w.newBody(0.0, 10.0, btStatic)
floor.addBox(10.0, 0.5)
let box = w.newBody(0.0, 6.0, btDynamic)
box.addBox(0.5, 0.5)
for i in 0 ..< 300:
  w.update(1.0 / 60.0)
doAssert abs(box.position.y - 9.0) < 0.1, "box did not rest on the floor: y = " & $box.position.y
doAssert abs(box.velocity.y) < 0.5, "box did not settle: vy = " & $box.velocity.y

w.destroy()

# A distance joint should hold a bob a fixed length from a static anchor, so
# under gravity it hangs straight down at that length rather than falling away.
block:
  let jw = newWorld(0.0, 10.0)
  let anchor = jw.newBody(0.0, 0.0, btStatic)
  let bob = jw.newBody(0.0, 3.0, btDynamic)
  bob.addCircle(0.2)
  discard jw.distanceJoint(anchor, bob, 0.0, 0.0, 0.0, 3.0)
  for i in 0 ..< 240:
    jw.update(1.0 / 60.0)
  let bp = bob.position
  doAssert abs(hypot(bp.x, bp.y) - 3.0) < 0.3, "distance joint did not hold: " & $hypot(bp.x, bp.y)
  jw.destroy()

# A ray fired through a static box should hit it, report the body by its user
# data, and strike the near face. The same box should turn up in an AABB query.
block:
  let qw = newWorld(0.0, 0.0)
  let target = qw.newBody(5.0, 0.0, btStatic)
  target.addBox(0.5, 0.5)
  target.userData = 42
  qw.update(1.0 / 60.0)
  let hit = qw.raycast(0.0, 0.0, 10.0, 0.0)
  doAssert hit.hit, "ray missed the box"
  doAssert hit.body.userData == 42, "ray hit the wrong body: " & $hit.body.userData
  doAssert abs(hit.x - 4.5) < 0.1, "ray hit the wrong face: x = " & $hit.x
  var found = false
  for b in qw.queryBox(4.0, -1.0, 2.0, 2.0):
    if b.userData == 42: found = true
  doAssert found, "AABB query did not find the box"
  qw.destroy()

# A body dropped onto a floor should report a begin-touch contact event.
block:
  let cw = newWorld(0.0, 10.0)
  let ground = cw.newBody(0.0, 5.0, btStatic)
  ground.addBox(5.0, 0.5)
  let faller = cw.newBody(0.0, 2.0, btDynamic)
  faller.addBox(0.3, 0.3)
  var sawContact = false
  for i in 0 ..< 240:
    cw.update(1.0 / 60.0)
    if cw.beginContacts().len > 0: sawContact = true
  doAssert sawContact, "no contact event was reported on landing"
  cw.destroy()

echo "physics smoke ok"
