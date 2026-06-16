## Branching dialogue with a typewriter reveal, choices and rich text.
##
## This is an opt-in module, imported on its own with `import nim2d/dialogue`.
## The core engine does not pull it in.
##
## A conversation is a `Script`: nodes keyed by id, each with a speaker, an
## optional portrait, one or more pages of text, and choices that branch to
## other nodes. You build a script as plain Nim data (a parser for a file format
## could target the same shape later), hand it to `newDialogue`, and `start` it.
## Each frame the game calls `update` and `draw`, and routes keys through
## `handleKey`.
##
## Text is rich. A page is a string with a small markup the renderer understands:
## `*italic*` and `**bold**` as in markdown, plus bracket tags closed with `[/]`
## and nestable: `[b]` bold, `[i]` italic, `[o]` a per-character outline (a border
## on the glyphs, not the box), `[#ffcc00]` a hex color and `[gold]` a palette
## name. So `"The [#ff5555]dragon[/] **roars**. *You* feel [o]afraid[/]."` works.
##
## Two ways to render. The simple path is a `Style` record (a font set, a box,
## colors, padding) feeding the built-in renderer. The advanced path sets `Hooks`
## to take over the box, the text or the choices, any left nil falling back to the
## default, so a game can lay the message out however it likes while keeping the
## markup.

import std/[unicode, tables, strutils]
import types
import font
import graphics
import image
import color
import scene

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

type
  Choice* = object ## A branch the player can pick.
    text*: string ## the label shown
    goto*: string ## the node it leads to ("" ends the dialogue)
    cond*: proc(): bool ## when set, the choice is hidden while it returns false
    action*: proc() ## when set, runs as the choice is picked

  Node* = object ## One step of a conversation.
    id*: string
    speaker*: string ## optional name label
    portrait*: Image ## optional image drawn beside the text
    pages*: seq[string] ## one or more screens of text, shown before the choices
    choices*: seq[Choice] ## empty means a plain line
    next*: string ## where a choiceless node goes on advance ("" ends)
    onEnter*: proc() ## optional side effect when the node becomes current

  Script* = ref object ## A whole conversation, nodes keyed by id.
    nodes*: Table[string, Node]

  RevealKind* = enum
    rvTypewriter ## one character at a time
    rvWord ## one word at a time
    rvFade ## all at once, fading in
    rvInstant ## shown immediately

  Reveal* = object ## How the current page's text appears.
    kind*: RevealKind
    cps*: float ## characters (or words for rvWord) per second
    punctuationPause*: float ## extra seconds after . ! ? , ; :
    fadeTime*: float ## seconds for rvFade
    onGlyph*: proc(r: Rune) ## called for each character as it appears
    custom*: proc(d: Dialogue, dt: float): bool
      ## a fully custom reveal: advance it by `dt`, set `d.shown` (out of
      ## `d.totalRunes`), and return true when complete. Used when set, whatever
      ## `kind` is.

  Align* = enum
    alLeft
    alCenter
    alRight

  Style* = object ## The simple styling: a handful of attributes.
    fonts*: tuple[regular, bold, italic, boldItalic: Font]
      ## the regular font is required; the others are used for bold/italic when
      ## set, and faked otherwise (bold by a double draw, italic by a shear)
    box*: tuple[x, y, w, h: float]
      ## where the box sits; leave w at 0 for an automatic strip across the
      ## bottom of the window
    padding*, roundness*, lineSpacing*: float
    align*: Align
    boxColor*, textColor*, speakerColor*, choiceColor*, choiceHighlight*: Color
    outlineColor*: Color
    outlineWidth*: float ## border thickness for outlined text (0 uses 1.5)
    outlineText*: bool ## outline every character, not only `[o]` spans

  Hooks* = object ## The advanced styling: any nil falls back to the default.
    drawBox*: proc(nim2d: Nim2d, d: Dialogue)
    drawText*: proc(nim2d: Nim2d, d: Dialogue)
    drawChoices*: proc(nim2d: Nim2d, d: Dialogue)

  DialogueState* = enum
    dsRevealing ## text is still appearing
    dsWaiting ## a page is fully shown, waiting to advance
    dsChoosing ## the last page is shown and choices are up
    dsDone ## the conversation has ended

  SpanStyle = object ## internal: the style of a run of characters
    bold, italic, outline: bool
    color: Color
    hasColor: bool

  Run = object ## internal: a positioned run of same-style text on a line
    text: string
    style: SpanStyle
    x, y: float
    startRune, runeCount: int

  Layout = object ## internal: a laid-out page
    runs: seq[Run]
    flat: seq[Rune] ## the visible runes in order, for the reveal
    wordEnds: seq[int] ## rune index after each word, for rvWord
    total: int
    height: float

  Dialogue* = ref object ## A running conversation over a `Script`.
    script*: Script
    style*: Style
    reveal*: Reveal
    hooks*: Hooks
    current*: string ## current node id
    page*: int ## current page within the node
    state*: DialogueState
    cursor*: int ## highlighted choice (index into the visible choices)
    shown*: int ## revealed rune count
    totalRunes*: int
    onFinish*: proc() ## called once when the conversation ends
    revealBudget: float
    revealAlpha: float
    layout: Layout
    laidOut: bool

# ---------------------------------------------------------------------------
# Building a script
# ---------------------------------------------------------------------------

proc newScript*(): Script =
  ## An empty script.
  Script(nodes: initTable[string, Node]())

proc add*(s: Script, node: Node) =
  ## Add a node, or replace one with the same id.
  s.nodes[node.id] = node

proc has*(s: Script, id: string): bool =
  ## Whether the script has a node with this id.
  s.nodes.hasKey(id)

proc choice*(
    text, goto: string, cond: proc(): bool = nil, action: proc() = nil
): Choice =
  ## A choice leading to `goto`, optionally gated by `cond` and with the side
  ## effect `action` that runs when it is picked.
  Choice(text: text, goto: goto, cond: cond, action: action)

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

proc defaultReveal*(): Reveal =
  ## A typewriter reveal at a readable speed with a small pause on punctuation.
  Reveal(kind: rvTypewriter, cps: 42, punctuationPause: 0.16, fadeTime: 0.25)

proc defaultStyle*(font: Font): Style =
  ## A dark rounded box with light text, ready to use. Set `box` for a custom
  ## position, or leave it for an automatic strip across the bottom of the window.
  Style(
    fonts: (font, nil, nil, nil),
    box: (0.0, 0.0, 0.0, 0.0),
    padding: 16,
    roundness: 10,
    lineSpacing: 1.3,
    align: alLeft,
    boxColor: rgba(18, 22, 30, 235),
    textColor: rgb(236, 239, 245),
    speakerColor: gold,
    choiceColor: lightgray,
    choiceHighlight: gold,
    outlineColor: black,
    outlineWidth: 0,
    outlineText: false,
  )

# ---------------------------------------------------------------------------
# Markup parsing
# ---------------------------------------------------------------------------

type
  TagKind = enum
    tkBold
    tkItalic
    tkOutline
    tkColor

  Segment = object
    text: string
    style: SpanStyle
    newline: bool

proc `==`(a, b: SpanStyle): bool =
  a.bold == b.bold and a.italic == b.italic and a.outline == b.outline and
    a.hasColor == b.hasColor and (not a.hasColor or a.color == b.color)

proc paletteColor(name: string): tuple[c: Color, found: bool] =
  case name
  of "white": (white, true)
  of "black": (black, true)
  of "red": (red, true)
  of "green": (green, true)
  of "blue": (blue, true)
  of "yellow": (yellow, true)
  of "orange": (orange, true)
  of "cyan": (cyan, true)
  of "magenta": (magenta, true)
  of "purple": (purple, true)
  of "pink": (pink, true)
  of "brown": (brown, true)
  of "lightgray", "lightgrey": (lightgray, true)
  of "darkgray", "darkgrey": (darkgray, true)
  of "sky": (sky, true)
  of "navy": (navy, true)
  of "lime": (lime, true)
  of "teal": (teal, true)
  of "gold": (gold, true)
  else: (white, false)

proc parseMarkup(page: string): seq[Segment] =
  ## Split a page into contiguous styled segments, with markup removed and
  ## newlines kept as break markers. Unknown bracket tags are left as literal
  ## text, and a backslash escapes the next character.
  var segs: seq[Segment]
  var boldTog, italTog = false
  var boldN, italN, outN = 0
  var colorStack: seq[Color]
  var openStack: seq[TagKind]
  var buf = ""

  proc cur(): SpanStyle =
    result.bold = boldTog or boldN > 0
    result.italic = italTog or italN > 0
    result.outline = outN > 0
    if colorStack.len > 0:
      result.color = colorStack[^1]
      result.hasColor = true

  var curStyle = cur()
  proc flush() =
    if buf.len > 0:
      segs.add Segment(text: buf, style: curStyle)
      buf = ""

  proc sync() =
    let s = cur()
    if s != curStyle:
      flush()
      curStyle = s

  var i = 0
  while i < page.len:
    let ch = page[i]
    if ch == '\\' and i + 1 < page.len:
      buf.add page[i + 1]
      i += 2
      continue
    if ch == '\n':
      flush()
      segs.add Segment(newline: true)
      inc i
      continue
    if ch == '*':
      if i + 1 < page.len and page[i + 1] == '*':
        boldTog = not boldTog
        sync()
        i += 2
      else:
        italTog = not italTog
        sync()
        inc i
      continue
    if ch == '[':
      let close = page.find(']', i + 1)
      if close > i:
        let tag = page[i + 1 ..< close]
        var handled = true
        if tag == "/":
          if openStack.len > 0:
            let closing = openStack[^1]
            openStack.setLen(openStack.len - 1)
            case closing
            of tkBold: dec boldN
            of tkItalic: dec italN
            of tkOutline: dec outN
            of tkColor:
              if colorStack.len > 0:
                colorStack.setLen(colorStack.len - 1)
        elif tag == "b":
          inc boldN
          openStack.add tkBold
        elif tag == "i":
          inc italN
          openStack.add tkItalic
        elif tag == "o":
          inc outN
          openStack.add tkOutline
        elif tag.len > 0 and tag[0] == '#':
          try:
            colorStack.add color(tag)
            openStack.add tkColor
          except ValueError:
            handled = false
        else:
          let p = paletteColor(tag)
          if p.found:
            colorStack.add p.c
            openStack.add tkColor
          else:
            handled = false
        if handled:
          sync()
          i = close + 1
          continue
      # not a recognized tag: keep the bracket as literal text
      buf.add ch
      inc i
      continue
    buf.add ch
    inc i
  flush()
  result = segs

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

proc fontFor(style: Style, s: SpanStyle): Font =
  if s.bold and s.italic and style.fonts.boldItalic != nil:
    style.fonts.boldItalic
  elif s.bold and style.fonts.bold != nil:
    style.fonts.bold
  elif s.italic and style.fonts.italic != nil:
    style.fonts.italic
  else:
    style.fonts.regular

proc runeWidth(style: Style, runes: seq[Rune], style0: SpanStyle): float =
  if runes.len == 0:
    return 0
  var s = ""
  for r in runes:
    s.add $r
  fontFor(style, style0).getSize(s).w.float

proc layoutPage(style: Style, page: string, maxWidth: float): Layout =
  ## Parse markup and wrap the page into positioned runs.
  let segs = parseMarkup(page)
  let baseFont = style.fonts.regular
  let lineH = baseFont.getHeight.float * style.lineSpacing
  let spaceW = baseFont.getSize(" ").w.float

  # Flatten to a styled rune stream with space and newline markers.
  type SR = object
    r: Rune
    st: SpanStyle
    space, br: bool

  var stream: seq[SR]
  for seg in segs:
    if seg.newline:
      stream.add SR(br: true)
      continue
    for r in seg.text.toRunes:
      stream.add SR(r: r, st: seg.style, space: r == Rune(' '))

  type LineRun = object
    runs: seq[Run]
    width: float

  var lines: seq[LineRun]
  var curRuns: seq[Run]
  var curX = 0.0
  var startRune = 0
  var flat: seq[Rune]
  var wordEnds: seq[int]

  proc finishLine() =
    lines.add LineRun(runs: curRuns, width: curX)
    curRuns = @[]
    curX = 0

  var i = 0
  while i < stream.len:
    if stream[i].br:
      finishLine()
      inc i
      continue
    if stream[i].space:
      if curRuns.len > 0:
        curX += spaceW
      inc i
      continue
    # gather a word (runs of the same style become chunks)
    var j = i
    var chunks: seq[tuple[runes: seq[Rune], st: SpanStyle, w: float]]
    while j < stream.len and not stream[j].space and not stream[j].br:
      let st = stream[j].st
      var runes: seq[Rune]
      while j < stream.len and not stream[j].space and not stream[j].br and
          stream[j].st == st:
        runes.add stream[j].r
        inc j
      chunks.add (runes, st, runeWidth(style, runes, st))
    var wordW = 0.0
    for c in chunks:
      wordW += c.w
    if curRuns.len > 0 and curX + wordW > maxWidth:
      finishLine()
    var cx = curX
    for c in chunks:
      var s = ""
      for r in c.runes:
        s.add $r
      curRuns.add Run(
        text: s,
        style: c.st,
        x: cx,
        y: 0,
        startRune: startRune,
        runeCount: c.runes.len,
      )
      for r in c.runes:
        flat.add r
      startRune += c.runes.len
      cx += c.w
    curX = cx
    wordEnds.add startRune
    i = j
  finishLine()

  # Assign y per line and apply alignment, flattening to absolute runs.
  var outRuns: seq[Run]
  for li, ln in lines:
    let xoff =
      case style.align
      of alLeft: 0.0
      of alCenter: max(0.0, (maxWidth - ln.width) / 2)
      of alRight: max(0.0, maxWidth - ln.width)
    for r in ln.runs:
      var rr = r
      rr.x = r.x + xoff
      rr.y = li.float * lineH
      outRuns.add rr

  Layout(
    runs: outRuns,
    flat: flat,
    wordEnds: wordEnds,
    total: startRune,
    height: lines.len.float * lineH,
  )

# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

proc boxRect(d: Dialogue, nim2d: Nim2d): tuple[x, y, w, h: float] =
  if d.style.box.w > 0:
    d.style.box
  else:
    let w = nim2d.width.float - 48.0
    let h = 150.0
    (24.0, nim2d.height.float - h - 24.0, w, h)

proc currentNode*(d: Dialogue): Node =
  ## The node being shown, or an empty node if the current id is unknown.
  if d.script != nil and d.script.has(d.current):
    d.script.nodes[d.current]
  else:
    Node()

proc textOrigin(
    d: Dialogue, box: tuple[x, y, w, h: float]
): tuple[x, y, maxW: float] =
  let node = currentNode(d)
  var tx = box.x + d.style.padding
  var ty = box.y + d.style.padding
  if node.portrait != nil:
    let scale = (box.h - 2 * d.style.padding) / node.portrait.getHeight.float
    tx += node.portrait.getWidth.float * scale + d.style.padding
  if node.speaker.len > 0:
    ty += d.style.fonts.regular.getHeight.float + 4
  result = (tx, ty, box.x + box.w - d.style.padding - tx)

proc visibleChoices*(d: Dialogue): seq[Choice] =
  ## The choices on the current node whose `cond` allows them.
  for c in currentNode(d).choices:
    if c.cond == nil or c.cond():
      result.add c

# ---------------------------------------------------------------------------
# State and reveal
# ---------------------------------------------------------------------------

proc lastPage(d: Dialogue): bool =
  d.page >= currentNode(d).pages.len - 1

proc ensureLayout(d: Dialogue, nim2d: Nim2d) =
  if d.laidOut:
    return
  let box = boxRect(d, nim2d)
  let org = textOrigin(d, box)
  let node = currentNode(d)
  let pageText =
    if d.page >= 0 and d.page < node.pages.len: node.pages[d.page] else: ""
  d.layout = layoutPage(d.style, pageText, max(16.0, org.maxW))
  d.totalRunes = d.layout.total
  d.laidOut = true
  if d.reveal.kind == rvInstant and d.reveal.custom == nil:
    d.shown = d.totalRunes

proc settle(d: Dialogue) =
  ## Move out of revealing once the text is fully shown.
  if d.state != dsRevealing:
    return
  let done =
    if d.reveal.kind == rvFade and d.reveal.custom == nil:
      d.revealAlpha >= 1.0
    else:
      d.shown >= d.totalRunes
  if done:
    if lastPage(d) and visibleChoices(d).len > 0:
      d.state = dsChoosing
      d.cursor = 0
    else:
      d.state = dsWaiting

proc startPage(d: Dialogue) =
  d.shown = 0
  d.revealBudget = 0
  d.revealAlpha = if d.reveal.kind == rvFade and d.reveal.custom == nil: 0.0 else: 1.0
  d.state = dsRevealing
  d.laidOut = false

proc start*(d: Dialogue, nodeId: string) =
  ## Begin (or jump to) a node, from its first page. Runs the node's `onEnter`.
  d.current = nodeId
  d.page = 0
  d.cursor = 0
  let node = currentNode(d)
  if node.onEnter != nil:
    node.onEnter()
  startPage(d)

proc isPause(r: Rune): bool =
  case r.int32
  of ord('.'), ord('!'), ord('?'), ord(','), ord(';'), ord(':'): true
  else: false

proc advanceReveal(d: Dialogue, dt: float) =
  if d.state != dsRevealing:
    return
  if d.reveal.custom != nil:
    if d.reveal.custom(d, dt):
      d.shown = d.totalRunes
    return
  case d.reveal.kind
  of rvInstant:
    d.shown = d.totalRunes
  of rvFade:
    let t = if d.reveal.fadeTime > 0: dt / d.reveal.fadeTime else: 1.0
    d.revealAlpha = min(1.0, d.revealAlpha + t)
    d.shown = d.totalRunes
  of rvTypewriter:
    d.revealBudget += dt * d.reveal.cps
    while d.revealBudget >= 1.0 and d.shown < d.totalRunes:
      let r = d.layout.flat[d.shown]
      inc d.shown
      d.revealBudget -= 1.0
      if d.reveal.onGlyph != nil:
        d.reveal.onGlyph(r)
      if isPause(r):
        d.revealBudget -= d.reveal.punctuationPause * d.reveal.cps
  of rvWord:
    d.revealBudget += dt * d.reveal.cps
    while d.revealBudget >= 1.0 and d.shown < d.totalRunes:
      var nextEnd = d.totalRunes
      for e in d.layout.wordEnds:
        if e > d.shown:
          nextEnd = e
          break
      d.shown = nextEnd
      d.revealBudget -= 1.0

proc update*(d: Dialogue, nim2d: Nim2d, dt: float) =
  ## Advance the reveal. Call once a frame while the dialogue is active. Takes
  ## `nim2d` because the text is laid out against the window and the box.
  if d.state == dsDone:
    return
  ensureLayout(d, nim2d)
  advanceReveal(d, dt)
  settle(d)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

proc active*(d: Dialogue): bool =
  ## Whether a conversation is currently up.
  d.state != dsDone

proc isRevealing*(d: Dialogue): bool =
  ## Whether the current page is still appearing.
  d.state == dsRevealing

proc finish(d: Dialogue) =
  d.state = dsDone
  if d.onFinish != nil:
    d.onFinish()

proc gotoNext(d: Dialogue) =
  let node = currentNode(d)
  if node.next.len > 0 and d.script.has(node.next):
    d.start(node.next)
  else:
    finish(d)

proc select*(d: Dialogue) =
  ## Confirm the highlighted choice.
  if d.state != dsChoosing:
    return
  let vis = visibleChoices(d)
  if d.cursor < 0 or d.cursor >= vis.len:
    return
  let ch = vis[d.cursor]
  if ch.action != nil:
    ch.action()
  if ch.goto.len > 0 and d.script.has(ch.goto):
    d.start(ch.goto)
  else:
    finish(d)

proc choose*(d: Dialogue, index: int) =
  ## Pick a visible choice directly by index (for mouse selection).
  if d.state != dsChoosing:
    return
  let vis = visibleChoices(d)
  if index >= 0 and index < vis.len:
    d.cursor = index
    d.select()

proc advance*(d: Dialogue) =
  ## The single "continue" action. While revealing it skips to the full text;
  ## while waiting it moves to the next page or ends the line; while choosing it
  ## confirms the highlighted choice.
  case d.state
  of dsRevealing:
    d.shown = d.totalRunes
    d.revealAlpha = 1.0
    settle(d)
  of dsWaiting:
    if not lastPage(d):
      inc d.page
      startPage(d)
    else:
      gotoNext(d)
  of dsChoosing:
    d.select()
  of dsDone:
    discard

proc moveCursor*(d: Dialogue, delta: int) =
  ## Move the choice highlight, wrapping around.
  if d.state != dsChoosing:
    return
  let n = visibleChoices(d).len
  if n > 0:
    d.cursor = (d.cursor + delta + n) mod n

proc handleKey*(d: Dialogue, key: Key) =
  ## Route a key: space or enter advances and confirms, the arrows move the
  ## choice highlight. Call from the engine's `keydown`.
  case key
  of Key.space, Key.enter:
    d.advance()
  of Key.up, Key.left:
    d.moveCursor(-1)
  of Key.down, Key.right:
    d.moveCursor(1)
  else:
    discard

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

proc choiceLineHeight(d: Dialogue): float =
  d.style.fonts.regular.getHeight.float * d.style.lineSpacing

proc choicesTop(d: Dialogue, nim2d: Nim2d): float =
  ## Where the choice list starts: below the text, but pushed up so the whole
  ## list stays inside the box and never spills past its bottom (or the window).
  let box = boxRect(d, nim2d)
  let org = textOrigin(d, box)
  let lh = choiceLineHeight(d)
  let n = visibleChoices(d).len
  let flow = org.y + d.layout.height + d.style.fonts.regular.getHeight.float * 0.4
  let bottomFit = box.y + box.h - d.style.padding - n.float * lh
  result = max(box.y + d.style.padding, min(flow, bottomFit))

proc drawRun(
    nim2d: Nim2d, style: Style, run: Run, ox, oy: float, count: int, alpha: float
) =
  if count <= 0:
    return
  let chosen = fontFor(style, run.style)
  if chosen == nil:
    return
  let rs = run.text.toRunes
  let n = min(count, rs.len)
  if n <= 0:
    return
  var text = ""
  for k in 0 ..< n:
    text.add $rs[k]
  if text.len == 0:
    return

  let usingBold = chosen == style.fonts.bold or chosen == style.fonts.boldItalic
  let usingItalic = chosen == style.fonts.italic or chosen == style.fonts.boldItalic
  let fauxBold = run.style.bold and not usingBold
  let fauxItalic = run.style.italic and not usingItalic
  let baseCol = if run.style.hasColor: run.style.color else: style.textColor
  proc fade(c: Color): Color =
    if alpha < 1.0: c.withAlpha(int(c.a.float * alpha)) else: c

  nim2d.font = chosen
  proc stroke(dx, dy: float, c: Color) =
    nim2d.setColor(c)
    if fauxItalic:
      let h = chosen.getHeight.float
      nim2d.push()
      nim2d.translate(run.x + ox + dx + 0.2 * h, run.y + oy + dy)
      nim2d.shear(-0.2, 0.0)
      nim2d.print(text, 0, 0)
      nim2d.pop()
    else:
      nim2d.print(text, run.x + ox + dx, run.y + oy + dy)

  if run.style.outline or style.outlineText:
    let ow = if style.outlineWidth > 0: style.outlineWidth else: 1.5
    let oc = fade(style.outlineColor)
    for dx in [-ow, 0.0, ow]:
      for dy in [-ow, 0.0, ow]:
        if dx != 0 or dy != 0:
          stroke(dx, dy, oc)
  let col = fade(baseCol)
  stroke(0, 0, col)
  if fauxBold:
    stroke(1, 0, col)

proc defaultDrawBox(nim2d: Nim2d, d: Dialogue) =
  let box = boxRect(d, nim2d)
  nim2d.setColor(d.style.boxColor)
  nim2d.rectangle(box.x, box.y, box.w, box.h, filled = true, roundness = d.style.roundness)
  let node = currentNode(d)
  if node.portrait != nil:
    let scale = (box.h - 2 * d.style.padding) / node.portrait.getHeight.float
    node.portrait.draw(
      nim2d, box.x + d.style.padding, box.y + d.style.padding, 0, scale, scale
    )
  if node.speaker.len > 0:
    let org = textOrigin(d, box)
    nim2d.font = d.style.fonts.regular
    nim2d.setColor(d.style.speakerColor)
    nim2d.print(node.speaker, org.x, box.y + d.style.padding)

proc defaultDrawText(nim2d: Nim2d, d: Dialogue) =
  let box = boxRect(d, nim2d)
  let org = textOrigin(d, box)
  for run in d.layout.runs:
    let count = max(0, min(run.runeCount, d.shown - run.startRune))
    if count > 0:
      drawRun(nim2d, d.style, run, org.x, org.y, count, d.revealAlpha)
  # a small "press to continue" triangle when a page is fully shown with more to come
  if d.state == dsWaiting:
    let s = 7.0
    let cx = box.x + box.w - d.style.padding - s
    let cy = box.y + box.h - d.style.padding - s
    nim2d.setColor(d.style.choiceHighlight)
    nim2d.triangle(cx, cy, cx + s, cy, cx + s / 2, cy + s, filled = true)

proc defaultDrawChoices(nim2d: Nim2d, d: Dialogue) =
  let box = boxRect(d, nim2d)
  let lh = choiceLineHeight(d)
  var y = choicesTop(d, nim2d)
  let x = textOrigin(d, box).x # align with the text column, past any portrait
  nim2d.font = d.style.fonts.regular
  for i, ch in visibleChoices(d):
    let selected = i == d.cursor
    nim2d.setColor(if selected: d.style.choiceHighlight else: d.style.choiceColor)
    nim2d.print((if selected: "> " else: "  ") & ch.text, x, y)
    y += lh

proc draw*(d: Dialogue, nim2d: Nim2d) =
  ## Draw the box, the revealed text and any choices. A no-op when the dialogue
  ## is done. Call inside the engine's `draw`, after the world.
  if d.state == dsDone:
    return
  ensureLayout(d, nim2d)
  let savedFont = nim2d.font
  let savedColor = nim2d.color

  if d.hooks.drawBox != nil:
    d.hooks.drawBox(nim2d, d)
  else:
    defaultDrawBox(nim2d, d)

  if d.hooks.drawText != nil:
    d.hooks.drawText(nim2d, d)
  else:
    defaultDrawText(nim2d, d)

  if d.state == dsChoosing:
    if d.hooks.drawChoices != nil:
      d.hooks.drawChoices(nim2d, d)
    else:
      defaultDrawChoices(nim2d, d)

  nim2d.font = savedFont
  nim2d.setColor(savedColor)

proc choiceAt*(d: Dialogue, nim2d: Nim2d, mx, my: float): int =
  ## The index of the visible choice under (mx, my) with the default choice
  ## layout, or -1. Useful for mouse selection.
  if d.state != dsChoosing:
    return -1
  ensureLayout(d, nim2d)
  let box = boxRect(d, nim2d)
  let lh = choiceLineHeight(d)
  let top = choicesTop(d, nim2d)
  let x = textOrigin(d, box).x
  let n = visibleChoices(d).len
  for i in 0 ..< n:
    let y = top + i.float * lh
    if mx >= x and mx <= box.x + box.w - d.style.padding and my >= y and my < y + lh:
      return i
  -1

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc newDialogue*(
    script: Script, style: Style, reveal: Reveal = defaultReveal()
): Dialogue =
  ## A dialogue player over `script`, drawn with `style`. Call `start` to begin.
  Dialogue(
    script: script,
    style: style,
    reveal: reveal,
    state: dsDone,
    revealAlpha: 1.0,
  )

# ---------------------------------------------------------------------------
# Scene integration
# ---------------------------------------------------------------------------

type DialogueScene* = ref object of Scene
  ## A `Scene` wrapping a `Dialogue`, forwarding update, draw and input. Push it
  ## on a `SceneManager` and set `dlg.onFinish` to pop it when the talk ends.
  dlg*: Dialogue

proc newDialogueScene*(dlg: Dialogue): DialogueScene =
  ## Wrap a dialogue as a scene.
  DialogueScene(dlg: dlg)

method update*(s: DialogueScene, nim2d: Nim2d, dt: float) =
  s.dlg.update(nim2d, dt)

method draw*(s: DialogueScene, nim2d: Nim2d) =
  s.dlg.draw(nim2d)

method keydown*(s: DialogueScene, nim2d: Nim2d, key: Key) =
  s.dlg.handleKey(key)

method mousepressed*(
    s: DialogueScene, nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8
) =
  let i = s.dlg.choiceAt(nim2d, x, y)
  if i >= 0:
    s.dlg.choose(i)
  else:
    s.dlg.advance()
