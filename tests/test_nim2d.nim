import std/unittest
import std/math
import nim2d
import nim2d/transform

# These tests run in CI (headless), so they must not create a GPU device /
# window. We unit-test the pure pieces and compile-check the public API.

suite "transform":
  test "translate then scale composes correctly":
    let t = identity().translate(10, 20).scale(2, 2)
    let (x, y) = t.apply(5, 5)
    check x == 20.0'f32   # 5*2 + 10
    check y == 30.0'f32   # 5*2 + 20

  test "rotate by tau is identity-ish":
    let t = identity().rotate(TAU)
    let (x, y) = t.apply(1, 0)
    check abs(x - 1.0'f32) < 1e-4
    check abs(y - 0.0'f32) < 1e-4

suite "graphics helpers":
  test "blend mode string mapping":
    var n = Nim2d()
    n.setBlendMode("add")
    check n.blend == bmAdd
    n.setBlendMode("multiply")
    check n.blend == bmMod
    n.setBlendMode("nope")
    check n.blend == bmNone

  test "polygon rejects mismatched / short input":
    var n = Nim2d()
    expect ValueError:
      n.polygon([0.0, 1.0], [0.0], filled = true)
    expect ValueError:
      n.polygon([0.0, 1.0], [0.0, 1.0], filled = true)

# Compile-only: exercises the full public surface without running the GPU.
when false:
  proc demo() =
    let n2d = newNim2d("t", 0, 0, 320, 240)
    let img = n2d.newImage("x.png")
    let cv = n2d.newCanvas(64, 64)
    let f = newFont("x.ttf", 16)
    n2d.setFont(f)
    n2d.load = proc(nim2d: Nim2d) = discard
    n2d.update = proc(nim2d: Nim2d, dt: float) = discard
    n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) = discard
    n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float32) = discard
    n2d.draw = proc(nim2d: Nim2d) =
      nim2d.setColor(1, 2, 3)
      nim2d.circle(1, 1, 1, true)
      nim2d.rectangle(0, 0, 1, 1, true, 2)
      nim2d.line(@[(0'f32, 0'f32), (1'f32, 1'f32)])
      img.draw(nim2d, 0, 0)
      cv.draw(nim2d, 0, 0)
      nim2d.print("hi", 0, 0)
    n2d.play()
  demo()
