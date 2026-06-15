# Physics

Rigid-body physics runs on Box2D 3. It is a separate dependency, so you install Box2D and import the module on its own, since not every program wants it. Homebrew and the Arch repositories carry it:

```console
$ brew install box2d        # macOS
$ sudo pacman -S box2d      # Arch Linux
```

Elsewhere, build it from source; it is a small cmake project (`git clone https://github.com/erincatto/box2d`, configure with `-DBOX2D_SAMPLES=OFF -DBOX2D_UNIT_TESTS=OFF`, build and install). The distribution packages named libbox2d are usually the 2.4 series, which is a different API and will not work.

```nim
import nim2d
import nim2d/physics
```

You make a world with some gravity, add bodies, give them shapes, and step the world each frame. Box2D is happiest in small units like meters, so the usual approach is to simulate in meters and multiply by a scale when you draw, rather than feeding pixel-sized numbers to the solver.

![boxes and balls dropped onto a floor, settled into a pile](assets/physics.png){ width="560" }

```nim { .annotate }
let world = newWorld(0.0, 10.0)        # (1)!
let ground = world.newBody(8.0, 11.0, btStatic) # (2)!
ground.addBox(8.0, 0.5)                # (3)!
let box = world.newBody(8.0, 2.0, btDynamic) # (4)!
box.addBox(0.5, 0.5, restitution = 0.3) # (5)!

n2d.update = proc(nim2d: Nim2d, dt: float) =
  world.update(dt)                     # (6)!

n2d.draw = proc(nim2d: Nim2d) =
  let (x, y) = box.position            # (7)!
  nim2d.push()
  nim2d.translate(x * 50, y * 50)      # (8)!
  nim2d.rotate(box.angle)              # (9)!
  nim2d.rectangle(-25, -25, 50, 50, filled = true)
  nim2d.pop()
```

1.  Gravity pulls down, since positive y is down.
2.  A static body for the floor, it never moves.
3.  A wide, thin floor shape, sized as half extents.
4.  A dynamic body that moves and collides.
5.  Its box shape, with a little bounce from restitution.
6.  Step the simulation forward by the frame time.
7.  Read the body's position back, in meters.
8.  Scale meters to pixels when drawing, 50 pixels per meter.
9.  Turn the drawing to match the body's angle.

Bodies come in three kinds. Dynamic bodies move and collide, static ones never move and make floors and walls, and kinematic ones move only by the velocity you set. [`addBox`](api/physics.md#addBox) and [`addCircle`](api/physics.md#addCircle) give a body a shape with a density, friction and restitution, where restitution is bounciness. `addBox` takes half extents, so `addBox(0.5, 0.5)` is a box one unit on a side. You read a body back with [`position`](api/physics.md#position), [`angle`](api/physics.md#angle) and [`velocity`](api/physics.md#velocity), push it around with [`setVelocity`](api/physics.md#setVelocity), [`applyForce`](api/physics.md#applyForce) and [`applyImpulse`](api/physics.md#applyImpulse), or place it with [`setPosition`](api/physics.md#setPosition). [`destroy`](api/physics.md#destroy) removes a body, and destroying the world frees everything in it.

Step the world with a steady [`update(dt)`](api/physics.md#update) for the most stable result; the sub-step count is tunable but the default is fine.

Bodies can be tied together with joints. [`revoluteJoint`](api/physics.md#revoluteJoint) is a hinge, [`distanceJoint`](api/physics.md#distanceJoint) is a rod or a spring between two points, [`prismaticJoint`](api/physics.md#prismaticJoint) is a slider along an axis, [`weldJoint`](api/physics.md#weldJoint) fuses two bodies rigidly, [`wheelJoint`](api/physics.md#wheelJoint) is a suspension-plus-motor for cars, and [`motorJoint`](api/physics.md#motorJoint) drives one body toward an offset from another. They take world anchor points and convert them to each body's local frame for you, and the revolute and prismatic joints take an optional motor and limits. Read a revolute joint's `angle` or a prismatic joint's [`translation`](api/physics.md#translation), change a motor at runtime with [`setMotorSpeed`](api/physics.md#setMotorSpeed), and `destroy` a joint to remove it.

```nim
let hinge = world.revoluteJoint(wall, arm, 4.0, 2.0, enableMotor = true,
                                motorSpeed = 2.0, maxMotorTorque = 50.0)
```

To find things in the world, [`raycast(x1, y1, x2, y2)`](api/physics.md#raycast) returns the closest body a ray hits along with the impact point, the surface normal and how far along it struck, and [`queryBox(x, y, w, h)`](api/physics.md#queryBox) returns every body overlapping a rectangle. After a step, [`beginContacts`](api/physics.md#beginContacts) and [`endContacts`](api/physics.md#endContacts) return the pairs of bodies that just started or stopped touching. To tell bodies apart in any of these, tag each one with `body.userData = someInt` and read it back; the ray hit, the query results and the contact pairs all carry it.

```nim
let hit = world.raycast(player.x, player.y, player.x + 200, player.y)
if hit.hit and hit.body.userData == enemyTag:
  echo "line of sight to an enemy at ", hit.x, ", ", hit.y
```

!!! info "See also"
    The runnable [`physics` example](https://github.com/nim2d/nim2d/blob/master/examples/physics.nim), and the [`physics` API reference](api/physics.md).
