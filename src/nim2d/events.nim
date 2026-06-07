## SDL3 event pump that dispatches to the nim2d callbacks.
##
## A few things changed from SDL2. Mouse coordinates are floats now, key events
## carry the scancode directly, and the window sub-events became top-level event
## types.

import backend/sdl
import types

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
    nim2d.mousemove(nim2d, evt.motion.x.float, evt.motion.y.float,
                    evt.motion.xrel.float, evt.motion.yrel.float)
  elif t == uint32(SDL_EVENT_MOUSE_BUTTON_DOWN):
    nim2d.mousepressed(nim2d, evt.button.x.float, evt.button.y.float,
                       evt.button.button, evt.button.clicks)
  elif t == uint32(SDL_EVENT_MOUSE_BUTTON_UP):
    nim2d.mousereleased(nim2d, evt.button.x.float, evt.button.y.float,
                        evt.button.button, evt.button.clicks)
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
