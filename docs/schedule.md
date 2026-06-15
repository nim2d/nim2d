# Schedule

A lot of game logic is about time. Something should happen in two seconds, or on every beat, or run for half a second and then stop. You can track each of those with a counter you tick down by hand, but that is a lot of bookkeeping once there are a few of them. The schedule module keeps those counters for you. It is a small opt-in module, imported on its own with `import nim2d/schedule`, and the core engine does not pull it in.

You make a [`Scheduler`](api/schedule.md#Scheduler), add timers to it, and advance it once per frame from your own update with the frame's `dt`. When a timer comes due it calls the callback you gave it.

```nim { .annotate }
import nim2d
import nim2d/schedule

let sched = newScheduler()    # (1)!

n2d.update = proc(nim2d: Nim2d, dt: float) =
  sched.update(dt)            # (2)!
```

1.  Make a scheduler to hold your timers.
2.  Advance it once per frame with the frame's dt; timers that come due fire here.

## Once, on a repeat, or for a while

[`after`](api/schedule.md#after) runs a callback once, a set number of seconds from now.

```nim
sched.after(2.0, proc() = showMessage("go!"))
```

[`every`](api/schedule.md#every) runs one on a repeat. Left alone it repeats forever, or you give it a count to stop after that many fires.

```nim
sched.every(1.5, proc() = spawnEnemy())          # forever
sched.every(0.2, proc() = blink(), count = 6)    # six blinks, then done
```

[`during`](api/schedule.md#during) calls a callback every frame for a stretch of time and hands it the frame's `dt`, which is what you want for something that has to keep running for a moment rather than fire at one instant, like a screen shake or a fade. Pass a second callback to run once when it finishes.

```nim
sched.during(0.4, proc(dt: float) = shake(40.0 * dt))
```

## Cancelling

Each of after, every and during hands back a [`TimerId`](api/schedule.md#TimerId). Keep it if you might want to stop the timer early, and pass it to [`cancel`](api/schedule.md#cancel).

```nim
let id = sched.every(1.0, proc() = tick())
# ...
sched.cancel(id)        # stop ticking
sched.clear()           # or drop every timer at once
```

Cancelling a timer that has already fired or is not there does nothing, so you never have to guard the call.

## Scheduling from a callback

The callbacks are plain closures, so they read whatever they need from around them, and they can schedule or cancel more timers, even themselves. A callback that re-arms itself with a fresh delay each time gives you a repeat whose gap can change from one round to the next.

```nim
proc blinkOnce() =
  toggleCursor()
  sched.after(random(0.4, 0.9), proc() = blinkOnce())

blinkOnce()
```

A timer added from inside a callback waits until the next update to start counting, so a callback that schedules another never runs the new one in the same frame.

The schedule example wires several of these together. A metronome on [`every`](api/schedule.md#every) pulses a ring on each beat, each beat queues an offbeat with [`after`](api/schedule.md#after), every fourth beat runs a [`during`](api/schedule.md#during) sweep that fills a bar, and a feed lists the callbacks as they fire so you can watch the timing line up.

!!! info "See also"
    The runnable [`schedule` example](https://github.com/nim2d/nim2d/blob/master/examples/schedule.nim), and the [`schedule` API reference](api/schedule.md).
