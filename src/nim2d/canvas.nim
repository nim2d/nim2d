## Canvases are off-screen render targets you can draw into and then draw from.
##
## You render to a canvas by calling `nim2d.setCanvas(canvas)` (see nim2d.nim),
## and you draw a canvas like an image with `canvas.draw(...)`, which is shared
## with image.nim.

import types
import backend/sdl
import backend/renderer
import imagedata

proc newCanvas*(nim2d: Nim2d, width, height: int32): Canvas =
  ## An off-screen render target. Point drawing at it with `setCanvas`, then
  ## draw it like any image.
  result = Canvas(
    tex: nim2d.gpu.createRenderTarget(width, height),
    width: width,
    height: height,
    tint: (255'u8, 255'u8, 255'u8, 255'u8),
  )
  # When stencil masking is on, every render target needs a paired depth-stencil
  # target, since the pipelines are built to expect one.
  if nim2d.gpu.stencilEnabled:
    result.depth = nim2d.gpu.createDepthTarget(width, height)

proc newCanvas*(nim2d: Nim2d): Canvas =
  ## A canvas the size of the window.
  newCanvas(nim2d, nim2d.width, nim2d.height)

proc destroy*(nim2d: Nim2d, c: Canvas) =
  ## Free a canvas's GPU textures: its color target and, when stencil is
  ## enabled, the paired depth target. Like the texture `destroy`, this releases
  ## memory early; a canvas otherwise frees both when it is collected.
  if c.depth != nil:
    SDL_ReleaseGPUTexture(nim2d.gpu.device, c.depth)
    c.depth = nil
  if c.tex != nil:
    SDL_ReleaseGPUTexture(nim2d.gpu.device, c.tex)
    c.tex = nil

proc newImageData*(nim2d: Nim2d, canvas: Canvas): ImageData =
  ## Read a canvas's pixels back from the GPU into a new ImageData, which you
  ## can inspect with `getPixel` or save to a PNG with `encode`. The renderer
  ## defers drawing until the end of the frame, so the pixels are what the
  ## canvas held after the last completed frame. Draw to the canvas in one
  ## frame and read it back in the next, in `update`, not in the middle of
  ## the `draw` that fills it.
  result = newImageData(canvas.width, canvas.height)
  result.pixels = nim2d.gpu.downloadTexture(canvas.tex, canvas.width, canvas.height)
