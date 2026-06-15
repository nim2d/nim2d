# System

A handful of platform bits, thin wrappers over SDL3. [`getOS`](api/system.md#getOS) returns the operating system name, like "macOS", "Linux" or "Windows", and [`getProcessorCount`](api/system.md#getProcessorCount) returns the number of logical CPU cores. Controls for the window itself, like fullscreen, resizing and message boxes, live on the [input page](input.md).

The clipboard is [`getClipboardText`](api/system.md#getClipboardText), [`setClipboardText`](api/system.md#setClipboardText) and [`hasClipboardText`](api/system.md#hasClipboardText), and [`openURL`](api/system.md#openURL) opens a link in the default browser.

[`getPowerInfo`](api/system.md#getPowerInfo) reports the battery as a tuple: the state, which is one of "battery", "charging", "charged", "nobattery" or "unknown", the charge percent, and the seconds of charge left, with -1 for the last two when they cannot be told.

```nim { .annotate }
echo "running on ", getOS(), " with ", getProcessorCount(), " cores"  # (1)!
setClipboardText("copied from the game")  # (2)!
let power = getPowerInfo()  # (3)!
if power.state == "battery" and power.percent < 20:  # (4)!
  warnLowBattery()
```

1.  The OS name and the logical core count.
2.  Put text on the system clipboard.
3.  Read the battery state, percent and seconds left.
4.  Act when running low on battery.

## Threads

For work that should not stall a frame, like loading, decoding or generation, the thread module runs it off to the side. A [`Thread2d`](api/thread.md#Thread2d) runs a top-level proc marked `{.thread.}`, and a typed [`Channel2d`](api/thread.md#Channel2d) passes messages between threads, with each message copied as it crosses so nothing is shared by accident. SDL, the GPU and all drawing belong to the main thread, so a worker computes and sends, and the main loop receives and draws.

```nim { .annotate }
var progress = newChannel[int]()  # (1)!

proc worker() {.thread.} =
  for step in 1 .. 100:
    crunch(step)
    progress.send(step)           # (2)!

n2d.load = proc(nim2d: Nim2d) =
  discard newThread(worker)       # (3)!

n2d.update = proc(nim2d: Nim2d, dt: float) =
  let (got, step) = progress.tryReceive()  # (4)!
  if got: percent = step
```

1.  A typed channel both threads can name.
2.  Send a message from the worker to the main thread.
3.  Start the worker running off to the side.
4.  Take a waiting message without blocking the frame.

The channel is a module-level global because a thread proc carries no captured state, so both sides have to be able to name it. [`receive`](api/thread.md#receive) blocks until a message arrives, [`tryReceive`](api/thread.md#tryReceive) returns immediately with a flag, [`peek`](api/thread.md#peek) counts what is waiting, and [`join`](api/thread.md#join) waits for a thread to finish. [`close`](api/thread.md#close) frees a channel once the threads using it are done. The threads example runs a prime count this way while a spinner proves the main loop never blocks.

!!! info "See also"
    The runnable [`system` example](https://github.com/nim2d/nim2d/blob/master/examples/system.nim) and [`threads` example](https://github.com/nim2d/nim2d/blob/master/examples/threads.nim), and the [`system`](api/system.md) and [`thread`](api/thread.md) API references.
