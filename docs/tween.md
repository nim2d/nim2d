# Tween

Movement at a constant speed looks mechanical. A menu that slides in, a coin that pops up, a camera that settles into place all feel better when they start or stop gently, or overshoot a touch and come back. That shaping of motion over time is easing, and the tween module gives you the standard set of easing curves along with a small value tween that walks a number or a point from one value to another over a set time. It is opt-in, imported on its own with `import nim2d/tween`, and the core engine does not pull it in.

## Easing curves

An easing curve takes a time from 0 at the start to 1 at the end and returns an eased position, also from 0 to 1. [`ease`](api/tween.md#ease) is the one function you call, picking a curve from the `Easing` enum.

```nim
let y = ease(Easing.quadOut, t)   # t from 0 to 1, y eased from 0 to 1
```

The names follow the usual convention. An `In` curve starts slow and speeds up, an `Out` curve starts fast and eases into the end, and an `InOut` curve does both, slow at each end and quick through the middle. So `quadIn` accelerates away from the start, `quadOut` decelerates into the finish, and `quadInOut` does both. The families run from gentle to sharp, with `sine` and `quad` soft and `quint` and `expo` steep, and the three at the end have a character of their own. `back` pulls back a little before it sets off and overshoots before it lands, `elastic` springs past the target and wobbles in, and `bounce` lands and bounces like a dropped ball. `back` and `elastic` cross past 0 and 1 on purpose, which is where their snap comes from, so leave room for that if you are easing something that should not visibly go past its bounds.

Times outside 0 to 1 are clamped, so you do not have to guard the input.

## Tweening a value

Most of the time you are not easing a bare fraction, you are moving some value from where it is to where it should be over a second or two. A [`Tween`](api/tween.md#Tween) holds that for you. You make one with [`newTween`](api/tween.md#newTween), advance it each frame from [`update`](api/tween.md#update), and read where it is with [`value`](api/tween.md#value).

```nim { .annotate }
import nim2d
import nim2d/tween

var fade = newTween(0.0, 1.0, 0.4, Easing.quadOut)  # (1)!

n2d.update = proc(nim2d: Nim2d, dt: float) =
  fade.update(dt)  # (2)!

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setColor(gray(255).withAlpha(int(fade.value * 255)))  # (3)!
  # draw the thing that is fading in
```

1.  Tween a number from 0 to 1 over 0.4 seconds with an ease-out curve.
2.  Advance the tween by the frame time each update.
3.  Read the eased value and use it as the alpha.

`value` blends the start and target by the eased progress, so it gives you the actual number you are after rather than a 0-to-1 fraction. [`done`](api/tween.md#done) tells you when it has arrived, [`progress`](api/tween.md#progress) is the raw time fraction before easing if you ever want it, and [`reset`](api/tween.md#reset) sends the tween back to the start to run again.

`newTween` also takes a [`Vec2`](api/types.md#Vec2), which tweens a point. Both coordinates run on the one curve, so sliding something from one place to another is the same three calls.

```nim
var slide = newTween((startX, startY), (endX, endY), 0.6, Easing.backOut)

n2d.update = proc(nim2d: Nim2d, dt: float) =
  slide.update(dt)
  box.pos = slide.value          # a Vec2
```

A duration of zero or less finishes the tween at once, and stepping it past the end holds it at the target, so an `update` that runs every frame never overshoots and never needs a guard.

## Easing anything with lerp

The value tween covers numbers and points, which is most of what a game animates. For anything else you can interpolate, hand the eased fraction straight to [`lerp`](api/color.md#lerp). [`ease`](api/tween.md#ease) gives you the fraction, and `lerp` is overloaded for floats, vectors and colors, so a color fade is one line.

```nim { .annotate }
let k = ease(Easing.sineInOut, t)  # (1)!
let tint = lerp(rgb(40, 40, 60), rgb(240, 200, 120), k)  # (2)!
```

1.  Ease the raw fraction with a sine in-out curve.
2.  Blend two colors by the eased fraction.

The tween example is a chart of every curve in the module. Each cell plots one curve with a dot tracing along it on a shared clock, where the rows are the families and the columns are the in, out and in-out variants, so you can see at a glance how each one moves. The ball along the top rides one curve at a time with a [`VecTween`](api/tween.md#VecTween), which is the value tween in action.

!!! info "See also"
    The runnable [`tween` example](https://github.com/nim2d/nim2d/blob/master/examples/tween.nim), and the [`tween` API reference](api/tween.md).
