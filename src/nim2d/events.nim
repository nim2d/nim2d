## SDL3 event pump that dispatches to the nim2d callbacks.
##
## A few things changed from SDL2. Mouse coordinates are floats now, key events
## carry the scancode directly, and the window sub-events became top-level event
## types.

import backend/sdl
import types
import gamepad

proc dispatch*(nim2d: Nim2d, evt: SDL_Event) =
  let t = evt.type_field
  if t == uint32(SDL_EVENT_QUIT):
    nim2d.quit(nim2d)
    nim2d.running = false
  elif t == uint32(SDL_EVENT_KEY_DOWN):
    nim2d.keydown(nim2d, evt.key.scancode)
  elif t == uint32(SDL_EVENT_KEY_UP):
    nim2d.keyup(nim2d, evt.key.scancode)
  elif t == uint32(SDL_EVENT_MOUSE_MOTION):
    let d = SDL_GetWindowPixelDensity(nim2d.gpu.window).float
    nim2d.mousemove(nim2d, evt.motion.x.float * d, evt.motion.y.float * d,
                    evt.motion.xrel.float * d, evt.motion.yrel.float * d)
  elif t == uint32(SDL_EVENT_MOUSE_BUTTON_DOWN):
    let d = SDL_GetWindowPixelDensity(nim2d.gpu.window).float
    nim2d.mousepressed(nim2d, evt.button.x.float * d, evt.button.y.float * d,
                       evt.button.button, evt.button.clicks)
  elif t == uint32(SDL_EVENT_MOUSE_BUTTON_UP):
    let d = SDL_GetWindowPixelDensity(nim2d.gpu.window).float
    nim2d.mousereleased(nim2d, evt.button.x.float * d, evt.button.y.float * d,
                        evt.button.button, evt.button.clicks)
  elif t == uint32(SDL_EVENT_MOUSE_WHEEL):
    nim2d.mousewheel(nim2d, evt.wheel.x.float, evt.wheel.y.float)
  elif t == uint32(SDL_EVENT_TEXT_INPUT):
    nim2d.textinput(nim2d, $evt.text.text)
  elif t == uint32(SDL_EVENT_GAMEPAD_ADDED):
    openGamepad(evt.gdevice.which)
  elif t == uint32(SDL_EVENT_GAMEPAD_REMOVED):
    closeGamepad(evt.gdevice.which)
  elif t == uint32(SDL_EVENT_GAMEPAD_BUTTON_DOWN):
    nim2d.gamepadpressed(nim2d, evt.gbutton.which, SDL_GamepadButton(evt.gbutton.button))
  elif t == uint32(SDL_EVENT_GAMEPAD_BUTTON_UP):
    nim2d.gamepadreleased(nim2d, evt.gbutton.which, SDL_GamepadButton(evt.gbutton.button))
  elif t == uint32(SDL_EVENT_GAMEPAD_AXIS_MOTION):
    nim2d.gamepadaxis(nim2d, evt.gaxis.which, SDL_GamepadAxis(evt.gaxis.axis),
                      evt.gaxis.value.float / 32767.0)
  elif t == uint32(SDL_EVENT_FINGER_DOWN):
    nim2d.touchpressed(nim2d, cast[int64](evt.tfinger.fingerID),
      evt.tfinger.x.float * nim2d.width.float, evt.tfinger.y.float * nim2d.height.float,
      evt.tfinger.pressure.float)
  elif t == uint32(SDL_EVENT_FINGER_MOTION):
    nim2d.touchmoved(nim2d, cast[int64](evt.tfinger.fingerID),
      evt.tfinger.x.float * nim2d.width.float, evt.tfinger.y.float * nim2d.height.float,
      evt.tfinger.pressure.float)
  elif t == uint32(SDL_EVENT_FINGER_UP):
    nim2d.touchreleased(nim2d, cast[int64](evt.tfinger.fingerID),
      evt.tfinger.x.float * nim2d.width.float, evt.tfinger.y.float * nim2d.height.float,
      evt.tfinger.pressure.float)
  elif t == uint32(SDL_EVENT_WINDOW_SHOWN): nim2d.window_shown(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_HIDDEN): nim2d.window_hidden(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_MOVED): nim2d.window_moved(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_RESIZED): nim2d.window_resized(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_MINIMIZED): nim2d.window_minimized(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_MAXIMIZED): nim2d.window_maximized(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_RESTORED): nim2d.window_restored(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_MOUSE_ENTER): nim2d.window_enter(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_MOUSE_LEAVE): nim2d.window_leave(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_FOCUS_GAINED): nim2d.window_focus_gained(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_FOCUS_LOST): nim2d.window_focus_lost(nim2d)
  elif t == uint32(SDL_EVENT_WINDOW_CLOSE_REQUESTED):
    nim2d.window_close(nim2d)
    nim2d.quit(nim2d)
    nim2d.running = false
