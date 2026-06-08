## Headless physics check. It needs Box2D, so it is kept out of the auto-run test
## suite (the name does not start with "t") and is run on its own by CI on the
## platforms where Box2D is installed:
##
##   nim c -r tests/physics_smoke.nim

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
echo "physics smoke ok"
