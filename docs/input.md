# Input and timing

Input arrives through callbacks you assign on the engine, the same way as `draw` and `update`.

## Keyboard

`keydown` and `keyup` fire once when a key goes down or comes back up. They hand you an `SDL_Scancode`, which names the physical key. The scancode names are re-exported by nim2d, so you can use them directly.

```nim
n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  if scancode == SDL_SCANCODE_ESCAPE:
    nim2d.running = false
```

There is no held-key polling yet, so for movement that should continue while a key is held, track the state yourself by flipping a bool in `keydown` and `keyup`.

```nim
var goLeft = false

n2d.keydown = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  if scancode == SDL_SCANCODE_LEFT: goLeft = true

n2d.keyup = proc(nim2d: Nim2d, scancode: SDL_Scancode) =
  if scancode == SDL_SCANCODE_LEFT: goLeft = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  if goLeft: x -= 200 * dt
```

## Mouse

`mousemove` gives the cursor position and how far it moved since the last event. `mousepressed` and `mousereleased` give the position, the button number, and how many clicks in quick succession. Button 1 is left, 2 is middle, 3 is right. All the coordinates are floats.

```nim
n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  cursorX = x
  cursorY = y

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button, clicks: uint8) =
  if button == 1:
    spawnAt(x, y)
```

## Window events

There are callbacks for window changes too, like `window_resized`, `window_focus_gained`, `window_focus_lost`, `window_minimized` and so on, plus `window_close` when someone closes the window. Each one is a `proc(nim2d: Nim2d)`. The quit callback runs when the program is shutting down.

```nim
n2d.window_focus_lost = proc(nim2d: Nim2d) =
  paused = true
```

## Timing

`update` already receives `dt`, the seconds since the last frame, which is what you multiply speeds by so motion stays the same regardless of frame rate. If you need timing elsewhere, `getTime` returns seconds as a high-resolution number, `getDelta` returns the same `dt` as the last frame, and `getFPS` returns the current frames per second. `sleep` pauses for a number of seconds.

```nim
nim2d.print("fps: " & $int(nim2d.getFPS), 16, 16)
```

## Quitting

Set `nim2d.running` to false to end the loop, or just close the window.
