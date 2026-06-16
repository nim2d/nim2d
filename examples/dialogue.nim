## A branching conversation with a portrait, a typewriter reveal, rich text and
## choices, on the dialogue battery. Run it with `nim c -r examples/dialogue.nim`.
##
## Space or enter advances the line and confirms a choice, the arrow keys move
## the choice highlight, a click picks a choice or advances, and escape quits.
## The conversation loops back to the start when it ends.

import nim2d
import nim2d/dialogue
import std/os

let n2d = newNim2d("dialogue", 120, 120, 880, 520, rgb(22, 25, 35))
let font = newFont(getAppDir() / "font.ttf", 22)
let portrait = newImage(n2d, getAppDir() / "Nim-logo.png")

# State the dialogue reads and writes through plain closures. The royal pass is
# what gates the third choice, and picking it bumps a reputation counter.
var hasPass = true
var reputation = 0

# Nim does not parse a multi-line closure as a call argument, so bind the gate
# and the side effect to names and pass those.
let hasPassCond = proc(): bool =
  hasPass
let bumpReputation = proc() =
  inc reputation

var script = newScript()

script.add Node(
  id: "start",
  speaker: "Captain Vire",
  # portrait: portrait,
  pages:
    @[
      # "Halt! [#ffd24d]Who goes there[/] at this hour, [o]traveler[/]? The roads past the gate are not safe after dark.",
      # "**Choose your words.**",
      "Last week, I got a LinkedIn message from a recruiter at a small crypto startup.",
      "We exchanged a few messages over a couple of days, she described a broken proof-of-concept they needed a lead engineer for, and then sent me a public GitHub repo to review.",
      "Specifically, she asked me to /“check out the deprecated Node modules issue./”",
      "It’s not uncommon to ask for a review of an existing codebase,",
      "but something felt off and raised an alarm in my head, so I decided to get a bit extra paranoid."
    ],
  choices:
    @[
      choice("A weary friend.", "friend"),
      choice("None of your concern.", "rude"),
      choice("Show the royal pass.", "vip", cond = hasPassCond, action = bumpReputation),
    ],
)

script.add Node(
  id: "friend",
  speaker: "Captain Vire",
  # portrait: portrait,
  pages: @["Then pass, friend. [green]Stay on the lit path.[/]"],
)

script.add Node(
  id: "rude",
  speaker: "Captain Vire",
  # portrait: portrait,
  pages: @["**Hmph.** Mind your [#ff6666]tongue[/], or mind the cells."],
)

script.add Node(
  id: "vip",
  speaker: "Captain Vire",
  # portrait: portrait,
  pages: @["A royal seal... *forgive me, my lord.* The gate is [gold]yours[/]."],
)

# The simple styling path: take the defaults and set the box and a couple of
# colors. The single font means bold and italic are faked, and [o] outlines text.
var style = defaultStyle(font)
style.box = (40.0, 250.0, 800.0, 230.0)
style.speakerColor = gold
style.outlineColor = black

let dlg = newDialogue(script, style)
dlg.onFinish = proc() =
  dlg.start("start") # loop the demo
dlg.start("start")

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  if key == Key.escape:
    nim2d.running = false
  else:
    dlg.handleKey(key)

n2d.mousepressed = proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8) =
  let i = dlg.choiceAt(nim2d, x, y)
  if i >= 0:
    dlg.choose(i)
  else:
    dlg.advance()

n2d.update = proc(nim2d: Nim2d, dt: float) =
  dlg.update(nim2d, dt)

n2d.draw = proc(nim2d: Nim2d) =
  # a plain scene behind the dialogue box
  nim2d.setColor(48, 58, 84)
  nim2d.rectangle(0, 0, nim2d.width.float, 300, filled = true)
  nim2d.setColor(86, 102, 140)
  nim2d.circle(720, 90, 46, filled = true)
  nim2d.setFont(font)
  nim2d.setColor(210, 216, 228)
  nim2d.print("space / enter advance, arrows pick, esc quit", 40, 36)
  dlg.draw(nim2d)

n2d.play()
