# Dialogue

Conversations are something most games end up rebuilding: a text box that types itself out, a portrait and a name, and a branch when the player picks an answer. The dialogue battery handles that. It is a small opt-in module, imported on its own with `import nim2d/dialogue`, and the core engine does not pull it in.

You write a conversation as a [`Script`](api/dialogue.md#Script): [`Node`](api/dialogue.md#Node)s keyed by id, each with a speaker, an optional portrait, one or more pages of text, and the [`Choice`](api/dialogue.md#Choice)s that branch to other nodes. Build one with [`newScript`](api/dialogue.md#newScript) and [`add`](api/dialogue.md#add), then hand it to [`newDialogue`](api/dialogue.md#newDialogue) with a style and call [`start`](api/dialogue.md#start).

```nim { .annotate }
import nim2d
import nim2d/dialogue

var script = newScript()
script.add Node(id: "start", speaker: "Guard",       # (1)!
  pages: @["Halt! Who goes there?"],
  choices: @[
    choice("A friend.", "friend"),                   # (2)!
    choice("None of your business.", "rude"),
  ])
script.add Node(id: "friend", speaker: "Guard", pages: @["Then pass."])
script.add Node(id: "rude",   speaker: "Guard", pages: @["Watch your tongue."])

let dlg = newDialogue(script, defaultStyle(font))    # (3)!
dlg.start("start")
```

1.  A node with a speaker and a page of text. With choices the player picks one; without, it advances to `next` or ends.
2.  A choice leads to another node by id.
3.  `defaultStyle(font)` is a ready dark box, so you only need a font.

Each frame the game drives it like the other drawable batteries, with [`update`](api/dialogue.md#update) and [`draw`](api/dialogue.md#draw), and routes keys through [`handleKey`](api/dialogue.md#handleKey):

```nim
n2d.update = proc(nim2d: Nim2d, dt: float) =
  dlg.update(nim2d, dt)

n2d.draw = proc(nim2d: Nim2d) =
  drawWorld(nim2d)
  dlg.draw(nim2d)            # draws nothing once the dialogue is done

n2d.keydown = proc(nim2d: Nim2d, key: Key) =
  dlg.handleKey(key)
```

`update` takes `nim2d` because the text is laid out against the window and the box. `handleKey` maps space and enter to [`advance`](api/dialogue.md#advance), which skips the reveal, then moves to the next page, then confirms a choice, and the arrow keys to [`moveCursor`](api/dialogue.md#moveCursor). For the mouse, [`choiceAt`](api/dialogue.md#choiceAt) hit-tests a click and [`choose`](api/dialogue.md#choose) picks a choice by index.

## Branching, conditions and side effects

A node with no choices advances to its `next` node, and an empty `next` ends the conversation, firing the dialogue's `onFinish` callback. A node with choices waits on its last page for the player to pick one, and the chosen choice's `goto` is the node it leads to.

A [`choice`](api/dialogue.md#choice) carries two optional closures. `cond` hides it while it returns false, so a line only shows when the player has the key, the gold or the reputation for it. `action` runs as the choice is picked, which is where you set a flag, give an item or open a door. Both read and write your own game state directly, so there is no separate variables store to keep in sync.

```nim
choice("Show the royal pass.", "vip",
  cond = proc(): bool = player.hasPass,
  action = proc() = inc player.reputation)
```

Nim does not parse a multi-line closure as a call argument, so bind a longer `cond` or `action` to a `let` and pass the name.

## Rich text

A page is not a plain string. The renderer reads a small markup and styles the text character by character:

- `*italic*` and `**bold**`, the same as markdown.
- `[b]` bold, `[i]` italic and `[o]` an outline, a border on the glyphs rather than the box, each closed with `[/]` and nestable.
- `[#ffcc00]` a hex color and `[gold]` a palette name, also closed with `[/]`.

So `"The [#ff5555]dragon[/] **roars**. *You* feel [o]afraid[/]."` draws "dragon" in red, "roars" in bold, "You" in italic and "afraid" with an outline. A backslash escapes a marker, and a real newline in the string breaks the line. Bold and italic use the matching font from the [`Style`](api/dialogue.md#Style) when you supply one and are faked otherwise (bold by a double draw, italic by a shear), so a single font still gets you all four styles.

## The reveal

By default the text types itself out one character at a time. The [`Reveal`](api/dialogue.md#Reveal) from [`defaultReveal`](api/dialogue.md#defaultReveal) controls it: `cps` is the speed in characters per second, `punctuationPause` holds a little longer on a comma or a full stop, and `onGlyph` is called for each character as it appears, which is where a typing blip goes. The [`RevealKind`](api/dialogue.md#RevealKind) switches the whole style between a typewriter, a word at a time, a fade and an instant show, and `custom` hands the progression to a proc of yours.

```nim
var reveal = defaultReveal()
reveal.cps = 50
reveal.onGlyph = proc(r: Rune) =
  if not r.isWhiteSpace: blip.play()

let dlg = newDialogue(script, style, reveal)
```

## Styling, simple and custom

The simple path is the [`Style`](api/dialogue.md#Style) record from [`defaultStyle`](api/dialogue.md#defaultStyle): a font set, the `box` rectangle (leave its width at 0 for an automatic strip across the bottom of the window), the colors for the box, text, speaker and choices, the padding, the corner roundness and the alignment. Set what you want and leave the rest.

```nim
var style = defaultStyle(font)
style.box = (40.0, 320.0, 800.0, 160.0)
style.boxColor = rgba(18, 22, 30, 235)
style.choiceHighlight = gold
```

For full control, set the [`Hooks`](api/dialogue.md#Hooks): `drawBox`, `drawText` and `drawChoices` each take over that part of the rendering, and any left nil falls back to the default. So you can keep the default box and text but draw the choices your own way, reading the dialogue's public state.

The default box draws the node's portrait on the left scaled to its height, the speaker name above the text, the revealed text wrapped to the box, and the choices below it in the same column as the text. The choices always stay inside the box, so they never spill past the window even when the box is small, which means you size the box for the longest page plus its choices.

## Pages

A node's `pages` is a sequence, so a node can hold several screens of text shown one after another before any choices, and `advance` steps through them. This is the usual shape in an RPG, a few lines of patter and then the question.

## With the scene battery

[`DialogueScene`](api/dialogue.md#DialogueScene) wraps a dialogue as a [`Scene`](api/scene.md#Scene) that forwards update, draw and input. Push it on a [`SceneManager`](api/scene.md#SceneManager) and set `dlg.onFinish` to pop it, so a game can start a conversation and get control back when it ends.

!!! info "See also"
    The runnable [`dialogue` example](https://github.com/nim2d/nim2d/blob/master/examples/dialogue.nim), and the [`dialogue` API reference](api/dialogue.md).
