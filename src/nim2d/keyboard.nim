## Keyboard polling and text input.
##
## `keydown` and `keyup` callbacks (see events) tell you about edges. For things
## that should keep happening while a key is held, ask `isKeyDown` each frame.

import backend/sdl
import types

proc toKey*(sc: SDL_Scancode): Key =
  ## The nim2d Key for an SDL scancode, or Key.unknown if it has no name here.
  let o = ord(sc)
  if o >= ord(SDL_SCANCODE_A) and o <= ord(SDL_SCANCODE_Z):
    return Key(ord(Key.a) + (o - ord(SDL_SCANCODE_A)))
  if o >= ord(SDL_SCANCODE_1) and o <= ord(SDL_SCANCODE_9):
    return Key(ord(Key.one) + (o - ord(SDL_SCANCODE_1)))
  if o >= ord(SDL_SCANCODE_F1) and o <= ord(SDL_SCANCODE_F12):
    return Key(ord(Key.f1) + (o - ord(SDL_SCANCODE_F1)))
  case sc
  of SDL_SCANCODE_0: Key.zero
  of SDL_SCANCODE_SPACE: Key.space
  of SDL_SCANCODE_RETURN: Key.enter
  of SDL_SCANCODE_ESCAPE: Key.escape
  of SDL_SCANCODE_TAB: Key.tab
  of SDL_SCANCODE_BACKSPACE: Key.backspace
  of SDL_SCANCODE_DELETE: Key.delete
  of SDL_SCANCODE_LEFT: Key.left
  of SDL_SCANCODE_RIGHT: Key.right
  of SDL_SCANCODE_UP: Key.up
  of SDL_SCANCODE_DOWN: Key.down
  of SDL_SCANCODE_LSHIFT: Key.lshift
  of SDL_SCANCODE_RSHIFT: Key.rshift
  of SDL_SCANCODE_LCTRL: Key.lctrl
  of SDL_SCANCODE_RCTRL: Key.rctrl
  of SDL_SCANCODE_LALT: Key.lalt
  of SDL_SCANCODE_RALT: Key.ralt
  of SDL_SCANCODE_HOME: Key.home
  of SDL_SCANCODE_END: Key.End
  of SDL_SCANCODE_PAGEUP: Key.pageUp
  of SDL_SCANCODE_PAGEDOWN: Key.pageDown
  of SDL_SCANCODE_MINUS: Key.minus
  of SDL_SCANCODE_EQUALS: Key.equals
  of SDL_SCANCODE_COMMA: Key.comma
  of SDL_SCANCODE_PERIOD: Key.period
  of SDL_SCANCODE_SLASH: Key.slash
  of SDL_SCANCODE_BACKSLASH: Key.backslash
  of SDL_SCANCODE_GRAVE: Key.grave
  of SDL_SCANCODE_SEMICOLON: Key.semicolon
  of SDL_SCANCODE_APOSTROPHE: Key.apostrophe
  of SDL_SCANCODE_LEFTBRACKET: Key.leftBracket
  of SDL_SCANCODE_RIGHTBRACKET: Key.rightBracket
  else: Key.unknown

proc keyScancode*(key: Key): SDL_Scancode =
  ## The SDL scancode for a Key, the inverse of `toKey`.
  if key >= Key.a and key <= Key.z:
    return SDL_Scancode(ord(SDL_SCANCODE_A) + (ord(key) - ord(Key.a)))
  if key >= Key.one and key <= Key.nine:
    return SDL_Scancode(ord(SDL_SCANCODE_1) + (ord(key) - ord(Key.one)))
  if key >= Key.f1 and key <= Key.f12:
    return SDL_Scancode(ord(SDL_SCANCODE_F1) + (ord(key) - ord(Key.f1)))
  case key
  of Key.zero: SDL_SCANCODE_0
  of Key.space: SDL_SCANCODE_SPACE
  of Key.enter: SDL_SCANCODE_RETURN
  of Key.escape: SDL_SCANCODE_ESCAPE
  of Key.tab: SDL_SCANCODE_TAB
  of Key.backspace: SDL_SCANCODE_BACKSPACE
  of Key.delete: SDL_SCANCODE_DELETE
  of Key.left: SDL_SCANCODE_LEFT
  of Key.right: SDL_SCANCODE_RIGHT
  of Key.up: SDL_SCANCODE_UP
  of Key.down: SDL_SCANCODE_DOWN
  of Key.lshift: SDL_SCANCODE_LSHIFT
  of Key.rshift: SDL_SCANCODE_RSHIFT
  of Key.lctrl: SDL_SCANCODE_LCTRL
  of Key.rctrl: SDL_SCANCODE_RCTRL
  of Key.lalt: SDL_SCANCODE_LALT
  of Key.ralt: SDL_SCANCODE_RALT
  of Key.home: SDL_SCANCODE_HOME
  of Key.End: SDL_SCANCODE_END
  of Key.pageUp: SDL_SCANCODE_PAGEUP
  of Key.pageDown: SDL_SCANCODE_PAGEDOWN
  of Key.minus: SDL_SCANCODE_MINUS
  of Key.equals: SDL_SCANCODE_EQUALS
  of Key.comma: SDL_SCANCODE_COMMA
  of Key.period: SDL_SCANCODE_PERIOD
  of Key.slash: SDL_SCANCODE_SLASH
  of Key.backslash: SDL_SCANCODE_BACKSLASH
  of Key.grave: SDL_SCANCODE_GRAVE
  of Key.semicolon: SDL_SCANCODE_SEMICOLON
  of Key.apostrophe: SDL_SCANCODE_APOSTROPHE
  of Key.leftBracket: SDL_SCANCODE_LEFTBRACKET
  of Key.rightBracket: SDL_SCANCODE_RIGHTBRACKET
  else: SDL_SCANCODE_UNKNOWN

proc isKeyDown*(scancode: SDL_Scancode): bool =
  ## Whether a physical key is currently held down, by SDL scancode.
  let state = cast[ptr UncheckedArray[bool]](SDL_GetKeyboardState(nil))
  if state == nil: return false
  state[ord(scancode)]

proc isDown*(key: Key): bool =
  ## Whether `key` is currently held down. The friendly form of `isKeyDown`.
  isKeyDown(keyScancode(key))

proc startTextInput*(nim2d: Nim2d) =
  ## Begin receiving `textinput` events for typed characters.
  discard SDL_StartTextInput(nim2d.gpu.window)

proc stopTextInput*(nim2d: Nim2d) =
  discard SDL_StopTextInput(nim2d.gpu.window)
