# Getting started

You need Nim 2.0 or newer and the SDL3 libraries. On macOS that is one brew command.

```
brew install sdl3 sdl3_image sdl3_ttf sdl3_mixer
```

nim2d pulls in the `sdl3_nim` binding through nimble, and it links SDL3 at build time using settings in `config.nims`, so as long as the libraries are installed you don't have to pass anything extra to the compiler.

The physics module is the one extra. It builds on Box2D (`brew install box2d`) and you import it on its own with `import nim2d/physics`, so you only need Box2D installed if you actually use it.

Here is the smallest program that draws something.

```nim
import nim2d

let n2d = newNim2d("hello", 100, 100, 640, 480)

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setColor(255, 120, 60)
  nim2d.circle(320, 240, 80, true)

n2d.play()
```

Run it with `nim c -r hello.nim`. A window opens and stays up until you close it.

The shape of a nim2d program is the same as love2d. You make a window with `newNim2d`, you assign callbacks for the parts you care about, and `play` runs the loop until the window closes or you set `nim2d.running` to false. The callbacks you will use most are `load`, which runs once at the start, `update`, which runs every frame with the time since the last frame, and `draw`, which runs every frame and is where all your drawing goes.

```nim
import nim2d

let n2d = newNim2d("loop", 100, 100, 640, 480, (20'u8, 22'u8, 30'u8, 255'u8))
var t = 0.0

n2d.load = proc(nim2d: Nim2d) =
  echo "starting"

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setColor(120, 200, 255)
  nim2d.circle(320, 240, 60 + 20 * t, true)

n2d.play()
```

The fourth and fifth arguments to `newNim2d` are the window width and height. The sixth, when you pass it, is the background color as four bytes for red, green, blue and alpha. The window clears to that color at the start of every frame, so `draw` always starts from a clean background.

Coordinates are in pixels with the origin at the top left and y pointing down. Positions and sizes are plain `float`, so you can pass numbers and the results of math without sprinkling type conversions everywhere. Colors are bytes from 0 to 255. Angles, where they show up, are in radians.
