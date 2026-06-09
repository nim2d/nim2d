# Input and timing

Input arrives through callbacks you assign on the engine, the same way as `draw` and `update`.

## Keyboard

`keydown` and `keyup` fire once when a key goes down or comes back up. They hand you a `Key`, a nim2d enum that names the key, used qualified like `Key.escape`, `Key.space` or `Key.a`. A key with no name in the enum arrives as `Key.unknown`.

```nim
n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  if key == Key.escape:
    nim2d.running = false
```

For movement that should continue while a key is held, the callbacks aren't what you want, since they only fire on the edges. Ask `isDown` each frame instead.

```nim
n2d.update = proc(nim2d: Nim2d, dt: float) =
  if isDown(Key.left): x -= 200 * dt
  if isDown(Key.right): x += 200 * dt
```

To receive typed characters, turn on text input with `startTextInput` and set a `textinput` callback. The text arrives already decoded as a UTF-8 string, so a key and its shifted or accented form come through correctly. `stopTextInput` turns it back off.

```nim
n2d.load = proc(nim2d: Nim2d) =
  nim2d.startTextInput()

n2d.textinput = proc(nim2d: Nim2d, text: string) =
  buffer.add text
```

## Mouse

`mousemove` gives the cursor position and how far it moved since the last event. `mousepressed` and `mousereleased` give the position, the button, and how many clicks in quick succession. The button is a `MouseButton`, one of `MouseButton.left`, `.middle`, `.right`, `.x1` or `.x2`. All the coordinates are floats.

```nim
n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  cursorX = x
  cursorY = y

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  if button == MouseButton.left:
    spawnAt(x, y)
```

Like the keyboard, the mouse can be polled instead of waited on. `mousePosition` returns where the cursor is, with `mouseX` and `mouseY` if you only want one, and `isMouseDown` tells you whether a button is held. The scroll wheel comes through a `mousewheel` callback, where y is the usual vertical scroll.

```nim
n2d.mousewheel = proc(nim2d: Nim2d, x, y: float) =
  zoom += y * 0.1

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let m = mousePosition()
  if isMouseDown(MouseButton.left):
    paint(m.x, m.y)
```

The cursor and capture have their own controls. `setMouseVisible` shows or hides the pointer and `isMouseVisible` reports it. `setRelativeMode` captures the mouse and hides the cursor so `mousemove` reports movement deltas without the pointer getting stuck at a screen edge, which is what you want for steering by mouse motion or for mouse-look, and `isRelativeMode` reads it back. `setMouseGrabbed` confines the cursor to the window, and `setMousePosition` warps it to a spot.

## Gamepads

Controllers are opened for you when they connect. The `gamepadpressed` and `gamepadreleased` callbacks give you the controller id and which button, and `gamepadaxis` gives the id, the axis, and a value from -1 to 1 (triggers go 0 to 1). The buttons and axes use the SDL3 names, like `SDL_GAMEPAD_BUTTON_SOUTH` and `SDL_GAMEPAD_AXIS_LEFTX`. You can also poll with `isGamepadDown` and `gamepadAxis`, and `connectedGamepads` lists what's plugged in.

```nim
n2d.gamepadpressed = proc(nim2d: Nim2d, id: SDL_JoystickID, button: SDL_GamepadButton) =
  if button == SDL_GAMEPAD_BUTTON_SOUTH:
    jump()
```

## Window events

There are callbacks for window changes too, like `window_resized`, `window_focus_gained`, `window_focus_lost`, `window_minimized` and so on, plus `window_close` when someone closes the window. Each one is a `proc(nim2d: Nim2d)`. The quit callback runs when the program is shutting down.

```nim
n2d.window_focus_lost = proc(nim2d: Nim2d) =
  paused = true
```

## Window control

Beyond `getWidth`, `getHeight` and `getSize`, there are controls for the window itself. `setTitle` sets the title, `setSize` resizes it and `setResizable` decides whether the user can. `setFullscreen` switches to fullscreen and back, and `isFullscreen` reads the state. `minimize`, `maximize` and `restore` do what they say. `getDesktopDimensions` gives the primary display's resolution, `setIcon` takes an ImageData for the window icon, and `showMessageBox` pops up a simple message and waits for it to be dismissed.

```nim
n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  if key == Key.f:
    nim2d.setFullscreen(not nim2d.isFullscreen)
```

## Timing

`update` already receives `dt`, the seconds since the last frame, which is what you multiply speeds by so motion stays the same regardless of frame rate. If you need timing elsewhere, `getTime` returns seconds as a high-resolution number, `getDelta` returns the same `dt` as the last frame, and `getFPS` returns the current frames per second. `sleep` pauses for a number of seconds.

```nim
nim2d.print("fps: " & $int(nim2d.getFPS), 16, 16)
```

## Quitting

Set `nim2d.running` to false to end the loop, or just close the window.
