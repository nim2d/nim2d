## A bitmap (image) font. Normally you load a glyph sheet from a PNG with
## `newImageFont(filename, glyphs)`; here the sheet is built in memory from a
## hand-drawn 3x5 pixel font, then used like any font, scaled up and tinted.
## ESC quits.

import std/[os, math, strutils]
import nim2d

const
  W = 620
  H = 280

let n2d = newNim2d("nim2d - bitmap font", 120, 90, W.cint, H.cint, (16'u8, 18'u8, 28'u8, 255'u8))
let ttf = newFont(getAppDir() / "font.ttf", 18)

# A 3x5 pixel font for the digits and a blank space, '#' for a lit pixel.
const glyphChars = "0123456789 "
let pats = @[
  @["###", "#.#", "#.#", "#.#", "###"],  # 0
  @[".#.", "##.", ".#.", ".#.", "###"],  # 1
  @["###", "..#", "###", "#..", "###"],  # 2
  @["###", "..#", "###", "..#", "###"],  # 3
  @["#.#", "#.#", "###", "..#", "..#"],  # 4
  @["###", "#..", "###", "..#", "###"],  # 5
  @["###", "#..", "###", "#.#", "###"],  # 6
  @["###", "..#", "..#", "..#", "..#"],  # 7
  @["###", "#.#", "###", "#.#", "###"],  # 8
  @["###", "#.#", "###", "..#", "###"],  # 9
  @["...", "...", "...", "...", "..."],  # space
]

const gw = 3
const gh = 5
let total = int32(1 + glyphChars.len * (gw + 1))
# Start as all separator color (the top-left pixel tells newImageFont what the
# separator is), then draw the glyphs into their cells.
var sheet = newImageData(total, gh.int32, (255'u8, 0'u8, 255'u8, 255'u8))
var px = 1
for pat in pats:
  for ry in 0 ..< gh:
    for cx in 0 ..< gw:
      if pat[ry][cx] == '#':
        sheet.setPixel(int32(px + cx), int32(ry), (240'u8, 240'u8, 245'u8, 255'u8))
      else:
        sheet.setPixel(int32(px + cx), int32(ry), (0'u8, 0'u8, 0'u8, 0'u8))
  px += gw + 1
let pixFont = n2d.newImageFont(sheet, glyphChars, 1)

var t = 0.0

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setFont(ttf)
  nim2d.setColor(150, 160, 185)
  nim2d.print("a bitmap font, drawn crisp and tinted, scaled to any size:", 24, 22)

  nim2d.setFont(pixFont)
  nim2d.setColor(120, 220, 255)
  nim2d.print(intToStr(int(t * 137) mod 1000000, 6), 30, 70, 0, 12, 12)
  nim2d.setColor(255, 170, 90)
  nim2d.print("0123456789", 30, 200, 0, 6, 6)

n2d.play()
