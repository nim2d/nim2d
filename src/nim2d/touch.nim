## Touch polling.
##
## The `touchpressed`, `touchmoved` and `touchreleased` callbacks (see events)
## cover most needs and report positions in pixels. This reads the live set of
## touches the same way, for when polling fits better.

import backend/sdl
import types

proc getTouches*(nim2d: Nim2d): seq[tuple[id: int64, x, y, pressure: float]] =
  ## The active touch points across all touch devices, with x and y in pixels.
  result = @[]
  var ndev: cint
  let devs = SDL_GetTouchDevices(addr ndev)
  if devs == nil: return
  let darr = cast[ptr UncheckedArray[SDL_TouchID]](devs)
  for di in 0 ..< ndev.int:
    var nf: cint
    let fingers = SDL_GetTouchFingers(darr[di], addr nf)
    if fingers != nil:
      let farr = cast[ptr UncheckedArray[ptr SDL_Finger]](fingers)
      for fi in 0 ..< nf.int:
        let f = farr[fi]
        result.add (cast[int64](f.id),
                    f.x.float * nim2d.width.float, f.y.float * nim2d.height.float,
                    f.pressure.float)
      SDL_free(fingers)
  SDL_free(devs)
