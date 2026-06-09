## A background worker thread doing heavy work while the main loop stays smooth.
## The worker counts primes and sends its progress over a channel; the spinner
## keeps turning at full frame rate the whole time, which is the point. ESC quits.

import std/[os, math]
import nim2d

const target = 1_500_000

# The channel and the worker proc are module-level globals, because a thread proc
# carries no captured state and reaches what it needs as a global.
var progress = newChannel[tuple[pct, primes: int]]()

proc isPrime(n: int): bool =
  if n < 2: return false
  if n < 4: return true
  if (n and 1) == 0: return false
  var i = 3
  while i * i <= n:
    if n mod i == 0: return false
    i += 2
  true

proc countPrimes() {.thread.} =
  var found = 0
  var lastPct = -1
  for n in 2 .. target:
    if isPrime(n): inc found
    let pct = n * 100 div target
    if pct != lastPct:
      lastPct = pct
      progress.send((pct, found))

let n2d = newNim2d("nim2d - threads", 140, 100, 720, 460, (16'u8, 18'u8, 28'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 20)
let fontSmall = newFont(getAppDir() / "font.ttf", 15)
var worker: Thread2d

var
  pct = 0
  primes = 0
  spin = 0.0

n2d.load = proc(nim2d: Nim2d) =
  worker = newThread(countPrimes)

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  if sc == Key.escape: nim2d.running = false

n2d.update = proc(nim2d: Nim2d, dt: float) =
  spin += dt * 2.6
  while progress.peek() > 0:           # drain whatever the worker has sent
    let (p, f) = progress.receive()
    pct = p
    primes = f

n2d.draw = proc(nim2d: Nim2d) =
  # The spinner runs off the main loop, so it stays smooth while the worker
  # hammers the CPU on another thread.
  let cx = 360.0
  let cy = 150.0
  nim2d.setBlendMode("add")
  for i in 0 ..< 12:
    let a = spin + i.float * (TAU / 12)
    let f = 0.25 + 0.75 * (0.5 + 0.5 * sin(spin * 2 - i.float * 0.5))
    nim2d.setColor(uint8(90 * f), uint8(170 * f), uint8(255 * f))
    nim2d.circle(cx + cos(a) * 46, cy + sin(a) * 46, 6, filled = true, segments = 12)
  nim2d.setBlendMode("blend")

  # progress bar
  let bx = 120.0
  let bw = 480.0
  nim2d.setColor(40, 46, 64)
  nim2d.rectangle(bx, 250, bw, 22, filled = true, roundness = 5)
  nim2d.setColor(90, 200, 130)
  nim2d.rectangle(bx, 250, bw * pct.float / 100.0, 22, filled = true, roundness = 5)

  nim2d.setFont(font)
  nim2d.setColor(230, 235, 250)
  nim2d.print("counting primes up to " & $target & " on a background thread", 120, 300)
  nim2d.print("progress: " & $pct & "%      primes found: " & $primes, 120, 330)
  nim2d.setColor(150, 200, 255)
  nim2d.print(if pct >= 100: "done, and the spinner never stuttered" else:
              "the spinner keeps turning while the work runs off the main loop", 120, 366)

n2d.play()
