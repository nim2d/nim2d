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

Step the world with a steady `update(dt)` for the most stable result; the sub-step count is tunable but the default is fine. The module covers worlds, bodies, and box and circle shapes. Joints, raycasts and contact callbacks are not wrapped yet.
