# Animation

A sprite sheet is one image holding all the frames of an animation, laid out in a grid. Drawing a character that walks means picking the right cell of that grid each frame and stepping through the cells over time. The animation module does both halves. A [`SpriteSheet`](api/animation.md#SpriteSheet) cuts the image into cells, and an [`Animation`](api/animation.md#Animation) plays a run of those cells, each held for a while. It is opt-in, imported on its own with `import nim2d/animation`, and the core engine does not pull it in.

## Cutting a sheet into frames

[`newSpriteSheet`](api/animation.md#newSpriteSheet) takes a loaded image and the size of one cell, and works out the columns and rows from there. A 96 by 144 image cut into 32 by 36 cells is three columns and four rows.

```nim { .annotate }
import nim2d
import nim2d/animation

let img = newImage(n2d, "warrior.png")  # (1)!
img.setFilter(filNearest)               # (2)!
let sheet = newSpriteSheet(img, 32, 36) # (3)!
```

1.  Load the sheet image.
2.  Keep pixel art crisp when scaled up.
3.  Cut the image into 32 by 36 cells.

[`sheet.quad(col, row)`](api/animation.md#quad) hands you any cell as a [`Quad`](api/types.md#Quad), counting from zero, left to right and top to bottom, and [`sheet.frameCount`](api/animation.md#frameCount) is the number of cells, the columns times the rows. That is enough on its own to draw a single fixed frame, which is what a resting pose is.

```nim
img.draw(n2d, sheet.quad(1, 2), x, y, 0, 3, 3)   # column 1, row 2, scaled 3x
```

## Playing an animation

An [`Animation`](api/animation.md#Animation) is a list of cells played in order. [`newAnimation`](api/animation.md#newAnimation) takes the frames as (column, row) pairs and a time to hold each one, and [`rowAnimation`](api/animation.md#rowAnimation) is the shortcut for a whole row, left to right, which suits a sheet that puts one cycle per row. You advance it from your update with the frame time, and draw it where you want it.

```nim { .annotate }
var walk = rowAnimation(sheet, 2, 0.12)  # (1)!

n2d.update = proc(nim2d: Nim2d, dt: float) =
  walk.update(dt)  # (2)!

n2d.draw = proc(nim2d: Nim2d) =
  walk.draw(nim2d, x, y, scale = 3)  # (3)!
```

1.  Row 2, each frame held 0.12s.
2.  Advance the animation by the frame time.
3.  Draw the current frame at a position and scale.

Frame times must be positive. By default an animation loops. Pass `loop = false` to play it once and hold on the last frame, where [`done`](api/animation.md#done) then reads true, which is what you want for a one-shot like an explosion. [`reset`](api/animation.md#reset) sends it back to the start, [`pause`](api/animation.md#pause) and [`resume`](api/animation.md#resume) stop and restart it, and [`setFrame`](api/animation.md#setFrame) parks it on a chosen frame. [`currentFrame`](api/animation.md#currentFrame) and [`frameCount`](api/animation.md#frameCount) read which frame is showing and how many there are, and [`quad`](api/animation.md#quad) hands you the current cell so you can draw it yourself.

## Per-frame durations

When one pose should linger while others flick past, give each frame its own time instead of a single number. The list of durations has to be the same length as the frames.

```nim
let blink = newAnimation(sheet, @[(0, 0), (1, 0)], @[1.4, 0.1])   # eyes open long, shut briefly
```

## One sheet, several animations

A sheet can feed any number of animations, which is how a character holds a separate walk cycle for each way it faces. The warrior in the example keeps four, one per row, and advances whichever matches the direction it is moving.

```nim
let walk = [
  rowAnimation(sheet, 0, 0.12), # up
  rowAnimation(sheet, 1, 0.12), # right
  rowAnimation(sheet, 2, 0.12), # down
  rowAnimation(sheet, 3, 0.12), # left
]
```

The animation example walks that warrior around a field of grass with WASD or the arrow keys, playing the matching cycle while it moves and resting on the standing frame when it stops.

!!! info "See also"
    The runnable [`animation` example](https://github.com/nim2d/nim2d/blob/master/examples/animation.nim), and the [`animation` API reference](api/animation.md).
