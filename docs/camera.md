# Camera

A game world is usually bigger than the window. You keep your objects at their world positions and let a camera decide which part of that world the window shows, so you never recompute coordinates by hand when the player walks somewhere or you zoom in. The camera is a small opt-in module, imported on its own with `import nim2d/camera`. The core engine does not pull it in, so you only carry it when you want it.

A camera looks at a world point, with a zoom and a rotation. You make one with [`newCamera`](api/camera.md#newCamera), then point it somewhere with [`lookAt`](api/camera.md#lookAt), nudge it by an offset with [`move`](api/camera.md#move), or let it trail a target with [`follow`](api/camera.md#follow). The fields `x`, `y`, `scale` and `rotation` are public, so reading or setting them directly is fine next to the helpers.

```nim { .annotate }
import nim2d
import nim2d/camera

let cam = newCamera()
cam.lookAt(player.x, player.y)   # (1)!
cam.move(40, 0)                  # (2)!
cam.zoom(1.5)                    # (3)!
cam.rotate(0.1)                  # (4)!
```

1.  Center the view on a world point.
2.  Or shift it by an offset in world units.
3.  Multiply the zoom; `cam.scale = 1.5` sets it directly.
4.  Add to the rotation, in radians.

## Attaching

To draw through a camera you wrap your world drawing in [`attach`](api/camera.md#attach) and [`detach`](api/camera.md#detach). `attach` pushes a transform so the point the camera looks at lands in the middle of the window, scaled by the zoom and turned by the rotation. Everything you draw after it is in world coordinates. `detach` puts the transform back so you can draw a HUD on top in plain screen coordinates.

```nim
n2d.draw = proc(nim2d: Nim2d) =
  nim2d.attach(cam)
  drawWorld(nim2d)        # all in world coordinates
  nim2d.detach()
  drawHud(nim2d)          # back in screen coordinates
```

attach and detach pair up the same way `push` and `pop` do, and forgetting the detach leaves the transform pushed. The scoped form [`withCamera`](api/camera.md#withCamera) runs a block through the camera and detaches for you afterwards, so it cannot be left open.

```nim
nim2d.withCamera(cam):
  drawWorld(nim2d)
drawHud(nim2d)
```

## Following

A camera that snaps straight to the player jitters and feels stiff. [`follow`](api/camera.md#follow) eases toward a target a little each frame instead, which gives a soft trailing motion. The step is scaled by `dt`, so it looks the same whatever the frame rate, and `speed` sets how quickly it catches up.

```nim
n2d.update = proc(nim2d: Nim2d, dt: float) =
  cam.follow((player.x, player.y), dt, speed = 6.0)
```

## Switching between cameras

[`lerp`](api/camera.md#lerp) blends two cameras into a third, interpolating the position, zoom and rotation together. If you keep one value running from 0 to 1 and blend the two cameras by it, the whole view glides from one to the other rather than cutting, which is how you switch views smoothly.

```nim
var blend = 0.0           # eased toward 0 or 1 when the view switches

n2d.update = proc(nim2d: Nim2d, dt: float) =
  blend += (target - blend) * (1.0 - exp(-9.0 * dt))

n2d.draw = proc(nim2d: Nim2d) =
  let view = lerp(camA, camB, blend)
  nim2d.withCamera(view):
    drawWorld(nim2d)
```

The camera example does exactly this. It pilots an orb across a world wider than the window and flips between a close follow camera and a pulled-back, tilted overview, blending between the two on each switch.

## Screen and world coordinates

Two functions cross between the two coordinate spaces. [`toScreen`](api/camera.md#toScreen) gives the pixel where a world point lands under the camera, which is what you use to pin a label or a health bar above something in the world so it tracks as the camera moves. [`toWorld`](api/camera.md#toWorld) is the inverse, turning a screen pixel into a world point, so a mouse click lands on the right spot whatever the camera is doing.

```nim
let labelAt = nim2d.toScreen(cam, (enemy.x, enemy.y))
nim2d.print("boss", labelAt.x, labelAt.y)

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  let world = nim2d.toWorld(cam, (x, y))
  spawnAt(world.x, world.y)
```

Round-tripping a point through `toScreen` and then `toWorld` gives the point back, so the two stay consistent under any zoom and rotation. Both read the window size from the engine, so pass the same camera you drew with to get matching results.

!!! info "See also"
    The runnable [`camera` example](https://github.com/nim2d/nim2d/blob/master/examples/camera.nim), and the [`camera` API reference](api/camera.md).
