## Gamepads.
##
## Controllers are opened automatically when they connect (the event loop calls
## openGamepad), and any already connected when the game starts are opened up
## front, so they are reported from the first frame. The `gamepadpressed`,
## `gamepadreleased` and `gamepadaxis` callbacks report input. You can also poll
## with `isGamepadDown` and `gamepadAxis`. Built on the SDL3 gamepad API, so
## anything SDL recognizes as a gamepad works.

import std/tables
import backend/sdl
import types

proc toGamepadButton*(b: SDL_GamepadButton): GamepadButton =
  ## The nim2d GamepadButton for an SDL gamepad button.
  case b
  of SDL_GAMEPAD_BUTTON_SOUTH: GamepadButton.south
  of SDL_GAMEPAD_BUTTON_EAST: GamepadButton.east
  of SDL_GAMEPAD_BUTTON_WEST: GamepadButton.west
  of SDL_GAMEPAD_BUTTON_NORTH: GamepadButton.north
  of SDL_GAMEPAD_BUTTON_BACK: GamepadButton.back
  of SDL_GAMEPAD_BUTTON_GUIDE: GamepadButton.guide
  of SDL_GAMEPAD_BUTTON_START: GamepadButton.start
  of SDL_GAMEPAD_BUTTON_LEFT_STICK: GamepadButton.leftStick
  of SDL_GAMEPAD_BUTTON_RIGHT_STICK: GamepadButton.rightStick
  of SDL_GAMEPAD_BUTTON_LEFT_SHOULDER: GamepadButton.leftShoulder
  of SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: GamepadButton.rightShoulder
  of SDL_GAMEPAD_BUTTON_DPAD_UP: GamepadButton.dpadUp
  of SDL_GAMEPAD_BUTTON_DPAD_DOWN: GamepadButton.dpadDown
  of SDL_GAMEPAD_BUTTON_DPAD_LEFT: GamepadButton.dpadLeft
  of SDL_GAMEPAD_BUTTON_DPAD_RIGHT: GamepadButton.dpadRight
  else: GamepadButton.unknown

proc toSdlButton(b: GamepadButton): SDL_GamepadButton =
  case b
  of GamepadButton.south: SDL_GAMEPAD_BUTTON_SOUTH
  of GamepadButton.east: SDL_GAMEPAD_BUTTON_EAST
  of GamepadButton.west: SDL_GAMEPAD_BUTTON_WEST
  of GamepadButton.north: SDL_GAMEPAD_BUTTON_NORTH
  of GamepadButton.back: SDL_GAMEPAD_BUTTON_BACK
  of GamepadButton.guide: SDL_GAMEPAD_BUTTON_GUIDE
  of GamepadButton.start: SDL_GAMEPAD_BUTTON_START
  of GamepadButton.leftStick: SDL_GAMEPAD_BUTTON_LEFT_STICK
  of GamepadButton.rightStick: SDL_GAMEPAD_BUTTON_RIGHT_STICK
  of GamepadButton.leftShoulder: SDL_GAMEPAD_BUTTON_LEFT_SHOULDER
  of GamepadButton.rightShoulder: SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER
  of GamepadButton.dpadUp: SDL_GAMEPAD_BUTTON_DPAD_UP
  of GamepadButton.dpadDown: SDL_GAMEPAD_BUTTON_DPAD_DOWN
  of GamepadButton.dpadLeft: SDL_GAMEPAD_BUTTON_DPAD_LEFT
  of GamepadButton.dpadRight: SDL_GAMEPAD_BUTTON_DPAD_RIGHT
  else: SDL_GAMEPAD_BUTTON_INVALID

proc toGamepadAxis*(a: SDL_GamepadAxis): GamepadAxis =
  ## The nim2d GamepadAxis for an SDL gamepad axis.
  case a
  of SDL_GAMEPAD_AXIS_LEFTX: GamepadAxis.leftX
  of SDL_GAMEPAD_AXIS_LEFTY: GamepadAxis.leftY
  of SDL_GAMEPAD_AXIS_RIGHTX: GamepadAxis.rightX
  of SDL_GAMEPAD_AXIS_RIGHTY: GamepadAxis.rightY
  of SDL_GAMEPAD_AXIS_LEFT_TRIGGER: GamepadAxis.leftTrigger
  of SDL_GAMEPAD_AXIS_RIGHT_TRIGGER: GamepadAxis.rightTrigger
  else: GamepadAxis.unknown

proc toSdlAxis(a: GamepadAxis): SDL_GamepadAxis =
  case a
  of GamepadAxis.leftX: SDL_GAMEPAD_AXIS_LEFTX
  of GamepadAxis.leftY: SDL_GAMEPAD_AXIS_LEFTY
  of GamepadAxis.rightX: SDL_GAMEPAD_AXIS_RIGHTX
  of GamepadAxis.rightY: SDL_GAMEPAD_AXIS_RIGHTY
  of GamepadAxis.leftTrigger: SDL_GAMEPAD_AXIS_LEFT_TRIGGER
  of GamepadAxis.rightTrigger: SDL_GAMEPAD_AXIS_RIGHT_TRIGGER
  else: SDL_GAMEPAD_AXIS_INVALID

var pads: Table[GamepadId, ptr SDL_Gamepad]

proc openGamepad*(id: GamepadId) =
  ## Open a controller. The event loop calls this when one connects, so games
  ## normally never do.
  if id notin pads:
    let g = SDL_OpenGamepad(id)
    if g != nil:
      pads[id] = g

proc closeGamepad*(id: GamepadId) =
  ## Close a controller. The event loop calls this when one disconnects.
  if id in pads:
    SDL_CloseGamepad(pads[id])
    pads.del(id)

proc openConnectedGamepads*() =
  ## Open every controller the system currently reports. `newNim2d` calls this at
  ## startup and `connectedGamepads` calls it before reading the list, so a
  ## controller plugged in before the game launched is opened and reported from
  ## the first frame rather than waiting for SDL's connect event, which can lag
  ## past the opening frames. Opening is idempotent, so repeated calls are cheap.
  var count: cint = 0
  let ids = SDL_GetGamepads(addr count)
  if ids == nil:
    return
  let arr = cast[ptr UncheckedArray[GamepadId]](ids)
  for i in 0 ..< count.int:
    openGamepad(arr[i])
  SDL_free(ids)

proc connectedGamepads*(): seq[GamepadId] =
  ## The ids of every connected controller. Controllers connected before the game
  ## launched are included from the first frame, not only once SDL reports them.
  openConnectedGamepads()
  for id in pads.keys:
    result.add id

proc isGamepadDown*(id: GamepadId, button: GamepadButton): bool =
  ## Whether a controller button is currently held.
  if id in pads:
    SDL_GetGamepadButton(pads[id], toSdlButton(button))
  else:
    false

proc gamepadAxis*(id: GamepadId, axis: GamepadAxis): float =
  ## Axis value from -1 to 1 (triggers run 0 to 1).
  if id in pads:
    SDL_GetGamepadAxis(pads[id], toSdlAxis(axis)).float / 32767.0
  else:
    0.0
