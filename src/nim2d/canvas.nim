## Canvases are off-screen render targets you can draw into and then draw from.
##
## You render to a canvas by calling `nim2d.setCanvas(canvas)` (see nim2d.nim),
## and you draw a canvas like an image with `canvas.draw(...)`, which is shared
## with image.nim.

import types
import backend/renderer

proc newCanvas*(nim2d: Nim2d, width, height: int32): Canvas =
  result = Canvas(
    tex: nim2d.gpu.createRenderTarget(width, height),
    width: width, height: height,
    tint: (255'u8, 255'u8, 255'u8, 255'u8))
  # When stencil masking is on, every render target needs a paired depth-stencil
  # target, since the pipelines are built to expect one.
  if nim2d.gpu.stencilEnabled:
    result.depth = nim2d.gpu.createDepthTarget(width, height)

proc newCanvas*(nim2d: Nim2d): Canvas =
  newCanvas(nim2d, nim2d.width, nim2d.height)
