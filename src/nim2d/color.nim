## Colors: named constants, constructors and small helpers.
##
## A Color is the (r, g, b, a) byte tuple used everywhere in nim2d, so these are
## conveniences over that tuple, not a separate type. You can write a color by
## name (`red`), from bytes (`rgb(255, 120, 60)`), from a hex string
## (`color("#ff7a3c")`), or as a level of gray (`gray(128)`), and pass any of
## them anywhere a Color is wanted, including `setColor` and the window
## background. Channels are 0 to 255.

import std/strutils
import types

func rgb*(r, g, b: int): Color =
  ## A solid color from three 0-to-255 bytes.
  (uint8(r), uint8(g), uint8(b), 255'u8)

func rgba*(r, g, b, a: int): Color =
  ## A color from four 0-to-255 bytes.
  (uint8(r), uint8(g), uint8(b), uint8(a))

func gray*(v: int, a = 255): Color =
  ## A shade of gray, 0 black to 255 white.
  (uint8(v), uint8(v), uint8(v), uint8(a))

func withAlpha*(c: Color, a: int): Color =
  ## The same color with a different alpha, 0 to 255.
  (c.r, c.g, c.b, uint8(a))

func lerp*(a, b: Color, t: float): Color =
  ## Blend from a to b by t (0 to 1), channel by channel.
  func mix(x, y: uint8): uint8 =
    uint8(clamp(x.float + (y.float - x.float) * t, 0.0, 255.0))
  (mix(a.r, b.r), mix(a.g, b.g), mix(a.b, b.b), mix(a.a, b.a))

proc color*(hex: string): Color =
  ## Parse a hex color: "#rgb", "#rrggbb" or "#rrggbbaa", with the # optional.
  var s = hex
  if s.len > 0 and s[0] == '#': s = s[1 .. ^1]
  proc hx(sub: string): uint8 = uint8(parseHexInt(sub))
  case s.len
  of 3: (uint8(parseHexInt($s[0]) * 17), uint8(parseHexInt($s[1]) * 17),
         uint8(parseHexInt($s[2]) * 17), 255'u8)
  of 6: (hx(s[0..1]), hx(s[2..3]), hx(s[4..5]), 255'u8)
  of 8: (hx(s[0..1]), hx(s[2..3]), hx(s[4..5]), hx(s[6..7]))
  else: raise newException(ValueError,
    "color: expected #rgb, #rrggbb or #rrggbbaa, got '" & hex & "'")

# A small named palette, enough for quick sketches and HUDs. Built through `rgb`
# so each is a proper Color (a bare tuple literal would lose the r/g/b/a names).
const
  white* = rgb(255, 255, 255)
  black* = rgb(0, 0, 0)
  transparent* = rgba(0, 0, 0, 0)
  red* = rgb(230, 60, 60)
  green* = rgb(70, 200, 95)
  blue* = rgb(60, 120, 230)
  yellow* = rgb(245, 215, 65)
  orange* = rgb(245, 150, 50)
  cyan* = rgb(65, 210, 220)
  magenta* = rgb(220, 70, 200)
  purple* = rgb(150, 80, 210)
  pink* = rgb(245, 130, 180)
  brown* = rgb(150, 95, 55)
  lightgray* = rgb(200, 205, 215)
  darkgray* = rgb(60, 64, 72)
  sky* = rgb(120, 200, 255)
  navy* = rgb(30, 45, 90)
  lime* = rgb(170, 230, 70)
  teal* = rgb(50, 170, 165)
  gold* = rgb(235, 195, 80)
