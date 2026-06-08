# Physics

Rigid-body physics runs on Box2D. It is a separate dependency, so you install Box2D and import the module on its own, since not every program wants it.

```sh
brew install box2d
```

```nim
import nim2d
import nim2d/physics
```

You make a world with some gravity, add bodies, give them shapes, and step the world each frame. Box2D is happiest in small units like meters, so the usual approach is to simulate in meters and multiply by a scale when you draw, rather than feeding pixel-sized numbers to the solver.

```nim
let world = newWorld(0.0, 10.0)        # gravity pulls down, since positive y is down
let ground = world.newBody(8.0, 11.0, btStatic)
ground.addBox(8.0, 0.5)                # a wide, thin floor
let box = world.newBody(8.0, 2.0, btDynamic)
box.addBox(0.5, 0.5, restitution = 0.3)

n2d.update = proc(nim2d: Nim2d, dt: float) =
  world.update(dt)

n2d.draw = proc(nim2d: Nim2d) =
  let (x, y) = box.position
  nim2d.push()
  nim2d.translate(x * 50, y * 50)      # 50 pixels per meter
  nim2d.rotate(box.angle)
  nim2d.rectangle(-25, -25, 50, 50, filled = true)
  nim2d.pop()
```

Bodies come in three kinds. Dynamic bodies move and collide, static ones never move and make floors and walls, and kinematic ones move only by the velocity you set. `addBox` and `addCircle` give a body a shape with a density, friction and restitution, where restitution is bounciness. You read a body back with `position`, `angle` and `velocity`, push it around with `setVelocity`, `applyForce` and `applyImpulse`, or place it with `setPosition`. `destroy` removes a body, and destroying the world frees everything in it.

Step the world with a steady `update(dt)` for the most stable result; the sub-step count is tunable but the default is fine.

Bodies can be tied together with joints. `revoluteJoint` is a hinge, `distanceJoint` is a rod or a spring between two points, `prismaticJoint` is a slider along an axis, `weldJoint` fuses two bodies rigidly, `wheelJoint` is a suspension-plus-motor for cars, and `motorJoint` drives one body toward an offset from another. They take world anchor points and convert them to each body's local frame for you, and the revolute and prismatic joints take an optional motor and limits. Read a revolute joint's `angle` or a prismatic joint's `translation`, change a motor at runtime with `setMotorSpeed`, and `destroy` a joint to remove it.

```nim
let hinge = world.revoluteJoint(wall, arm, 4.0, 2.0, enableMotor = true,
                                motorSpeed = 2.0, maxMotorTorque = 50.0)
```

To find things in the world, `raycast(x1, y1, x2, y2)` returns the closest body a ray hits along with the impact point, the surface normal and how far along it struck, and `queryBox(x, y, w, h)` returns every body overlapping a rectangle. After a step, `beginContacts` and `endContacts` return the pairs of bodies that just started or stopped touching. To tell bodies apart in any of these, tag each one with `body.userData = someInt` and read it back; the ray hit, the query results and the contact pairs all carry it.

```nim
let hit = world.raycast(player.x, player.y, player.x + 200, player.y)
if hit.hit and hit.body.userData == enemyTag:
  echo "line of sight to an enemy at ", hit.x, ", ", hit.y
```
