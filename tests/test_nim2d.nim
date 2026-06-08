import std/unittest
import std/math
import std/os
import nim2d
import nim2d/transform

# Module-scope channel and worker for the thread test. A thread proc cannot be a
# closure, so the worker reaches this global rather than capturing anything.
var threadChan = newChannel[int]()
proc threadWorker() {.thread.} =
  for i in 1 .. 5: threadChan.send(i)

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

suite "math (rng / noise / geometry)":
  test "rng is deterministic for a given seed":
    var a = newRng(42'u64)
    var b = newRng(42'u64)
    for _ in 0 ..< 16:
      check a.nextUint() == b.nextUint()
    var c = newRng(1'u64)
    c.setSeed(42'u64)
    var d = newRng(42'u64)
    check c.nextUint() == d.nextUint()

  test "random stays in range":
    var r = newRng(123'u64)
    for _ in 0 ..< 1000:
      let f = r.random()
      check f >= 0.0 and f < 1.0
      let g = r.random(5.0, 9.0)
      check g >= 5.0 and g < 9.0
      let i = r.randomInt(3, 7)
      check i >= 3 and i <= 7

  test "gaussian mean is near the requested mean":
    var r = newRng(7'u64)
    var sum = 0.0
    let n = 20000
    for _ in 0 ..< n: sum += r.randomNormal(10.0, 2.0)
    check abs(sum / n.float - 10.0) < 0.1

  test "noise is in [0,1), reproducible and continuous":
    for i in 0 ..< 200:
      let x = i.float * 0.13
      let v = noise(x, x * 0.7)
      check v >= 0.0 and v < 1.0
    check noise(1.0, 2.0) == noise(1.0, 2.0)
    check abs(noise(1.0, 2.0) - noise(1.001, 2.0)) < 0.05
    check noise(0.3) >= 0.0 and noise(0.3) < 1.0
    let s = simplexNoise(0.5, 0.5)
    check s >= 0.0 and s < 1.0
    let s3 = simplexNoise(0.1, 0.2, 0.3)
    check s3 >= 0.0 and s3 < 1.0

  test "bezier hits its endpoints":
    let curve = newBezierCurve(@[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)])
    let p0 = curve.evaluate(0.0)
    let p1 = curve.evaluate(1.0)
    check abs(p0.x) < 1e-9 and abs(p0.y) < 1e-9
    check abs(p1.x - 10.0) < 1e-9 and abs(p1.y - 10.0) < 1e-9
    check curve.render(8).len == 9

  test "triangulate handles concave polygons":
    let dart = @[(0.0, 0.0), (4.0, 2.0), (0.0, 4.0), (2.0, 2.0)]
    check not isConvex(dart)
    let idx = triangulate(dart)
    check idx.len == (dart.len - 2) * 3
    for k in idx: check k < uint32(dart.len)
    let square = @[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    check isConvex(square)
    check triangulate(square).len == 6
    expect ValueError:
      discard triangulate(@[(0.0, 0.0), (1.0, 1.0)])

  test "geometry helpers":
    check abs(distance(0, 0, 3, 4) - 5.0) < 1e-9
    check abs(lerp(0.0, 10.0, 0.25) - 2.5) < 1e-9
    check abs(angle(0, 0, 0, 1) - (PI / 2)) < 1e-9
    let lin = gammaToLinear(0.5)
    check abs(linearToGamma(lin) - 0.5) < 1e-6

  test "standalone transform maps points":
    let t = newTransform().translate(10.0, 5.0).scale(2.0, 2.0)
    let p = t.transformPoint(3.0, 4.0)
    check abs(p.x - 16.0) < 1e-9   # 3*2 + 10
    check abs(p.y - 13.0) < 1e-9   # 4*2 + 5

suite "imagedata (cpu pixel buffer)":
  test "blank image is zeroed":
    let d = newImageData(4, 4)
    check d.getWidth == 4 and d.getHeight == 4
    check d.pixels.len == 4 * 4 * 4
    for b in d.pixels: check b == 0'u8

  test "filled image and pixel round-trip keep RGBA byte order":
    let d = newImageData(2, 2, (10'u8, 20'u8, 30'u8, 40'u8))
    check d.getPixel(0, 0) == (10'u8, 20'u8, 30'u8, 40'u8)
    d.setPixel(1, 1, (255'u8, 0'u8, 0'u8, 255'u8))
    check d.getPixel(1, 1) == (255'u8, 0'u8, 0'u8, 255'u8)
    let i = (1 * 2 + 1) * 4
    check d.pixels[i] == 255'u8      # red byte first
    check d.pixels[i + 1] == 0'u8

  test "out-of-range access raises":
    let d = newImageData(2, 2)
    expect IndexDefect: discard d.getPixel(2, 0)
    expect IndexDefect: d.setPixel(-1, 0, (0'u8, 0'u8, 0'u8, 0'u8))

  test "mapPixel visits every pixel":
    let d = newImageData(3, 3)
    var count = 0
    d.mapPixel(proc(x, y: int32, c: Color): Color =
      inc count
      (uint8(x), uint8(y), 0'u8, 255'u8))
    check count == 9
    check d.getPixel(2, 1) == (2'u8, 1'u8, 0'u8, 255'u8)

  test "encode then reload round-trips through PNG":
    let d = newImageData(3, 2, (12'u8, 34'u8, 56'u8, 255'u8))
    d.setPixel(2, 1, (200'u8, 100'u8, 50'u8, 255'u8))
    let path = getTempDir() / "nim2d_imagedata_test.png"
    try:
      d.encode(path)
      let r = newImageData(path)
      check r.getWidth == 3 and r.getHeight == 2
      check r.getPixel(0, 0) == (12'u8, 34'u8, 56'u8, 255'u8)
      check r.getPixel(2, 1) == (200'u8, 100'u8, 50'u8, 255'u8)
    finally:
      removeFile(path)

suite "audio (headless helpers)":
  test "listenerRelative offsets a source and flips screen y":
    let r = listenerRelative(10.0, 8.0, 0.0, 4.0, 3.0, 0.0)
    check abs(r.x - 6.0) < 1e-9
    check abs(r.y - (-5.0)) < 1e-9   # screen y is down, the mixer's y is up
    check abs(r.z - 0.0) < 1e-9

suite "audio (runtime, only when a device is available)":
  test "a source loads, plays, and teardown is safe":
    var n = Nim2d()
    n.initAudio()
    if not n.audioAvailable():
      skip()      # no audio device, as on a CI machine
    else:
      let s = n.newSource("examples/assets/blip.wav", stStatic)
      check s.duration > 0
      s.setLooping(true)
      check s.isLooping
      s.play()
      check s.isPlaying
      n.shutdownAudio()
      s.play()        # after shutdown these are safe no-ops, not a crash
      s.destroy()
      check not s.isPlaying

suite "system (platform queries)":
  test "os, cpu and power return sane values":
    check getOS().len > 0
    check getProcessorCount() >= 1
    let p = getPowerInfo()
    check p.state.len > 0

suite "thread (background work)":
  test "a worker thread sends values over a channel":
    let t = newThread(threadWorker)
    t.join()                       # worker has finished; the five values are queued
    var total = 0
    for _ in 0 ..< 5: total += threadChan.receive()
    check total == 15

# Compile-only: exercises the full public surface without running the GPU.
when false:
  proc demo() =
    let n2d = newNim2d("t", 0, 0, 320, 240)
    let img = n2d.newImage("x.png")
    let made = n2d.newImage(newImageData(2, 2, (1'u8, 2'u8, 3'u8, 4'u8)))
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
      made.draw(nim2d, 0, 0)
      cv.draw(nim2d, 0, 0)
      nim2d.print("hi", 0, 0)
    let snd = n2d.newSource("x.ogg", stStream)
    snd.setVolume(0.5)
    snd.setPitch(1.2)
    snd.setLooping(true)
    snd.setPosition(10, 20)
    snd.play()
    snd.pause()
    snd.resume()
    snd.seek(1.0)
    discard snd.tell()
    discard snd.isPlaying()
    discard snd.duration()
    snd.clearPosition()
    snd.stop()
    snd.destroy()
    n2d.setVolume(0.8)
    discard n2d.getVolume()
    n2d.setListenerPosition(0, 0)
    discard n2d.getListenerPosition()
    n2d.stopAll()
    # window and mouse niceties
    n2d.setRelativeMode(true)
    discard n2d.isRelativeMode()
    n2d.setMouseGrabbed(true)
    discard n2d.isMouseGrabbed()
    setMouseVisible(false)
    discard isMouseVisible()
    n2d.setMousePosition(10, 10)
    n2d.setFullscreen(true)
    discard n2d.isFullscreen()
    n2d.setResizable(true)
    n2d.setSize(640, 480)
    n2d.minimize(); n2d.maximize(); n2d.restore()
    discard getDesktopDimensions()
    n2d.setIcon(newImageData(16, 16))
    n2d.showMessageBox("hi", "there")
    # system
    discard getOS(); discard getProcessorCount(); discard getPowerInfo()
    n2d.play()
  demo()
