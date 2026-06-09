## A high-score table saved to disk. Press SPACE to add a random score, which is
## appended to scores.txt in the save directory and read back. ESC quits.

import std/[os, strutils, algorithm]
import nim2d

const
  W = 640
  H = 480

let n2d = newNim2d("nim2d - filesystem", 140, 90, W.cint, H.cint, (20'u8, 22'u8, 30'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 20)
n2d.setFont(font)

n2d.fs.setIdentity("nim2d", "filesystem-example")

proc loadScores(): seq[int] =
  result = @[]
  if n2d.fs.exists("scores.txt"):
    for line in n2d.fs.lines("scores.txt"):
      let s = line.strip
      if s.len > 0:
        try: result.add parseInt(s)
        except ValueError: discard
  result.sort(SortOrder.Descending)

var scores = loadScores()

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape:
    nim2d.running = false
  elif sc == Key.space:
    nim2d.fs.append("scores.txt", $randomInt(100, 9999) & "\n")
    scores = loadScores()

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setColor(240, 240, 250)
  nim2d.print("high scores, press SPACE to add a random one", 16, 16)
  nim2d.setColor(150, 160, 180)
  nim2d.print("save dir: " & nim2d.fs.getSaveDirectory(), 16, 44)
  nim2d.setColor(255, 220, 120)
  var y = 90.0
  for i, s in scores:
    if i >= 10: break
    nim2d.print($(i + 1) & ".   " & $s, 40, y)
    y += 28

n2d.play()
