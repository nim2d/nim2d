## CPU pixel buffers you can read, write and build by hand, then upload.
##
## An `ImageData` holds tightly packed RGBA8 pixels (four bytes per pixel, row
## by row). You can make one blank, filled with a color, or loaded from a file,
## read and write single pixels as a `Color`, run a proc over every pixel, save
## it to PNG, and upload it to a drawable image. The byte order lines up with
## `SDL_PIXELFORMAT_RGBA32` and the GPU's RGBA8 textures, so the common path
## needs no conversion. This assumes a little-endian host, which covers the
## platforms nim2d targets.

import types
import backend/sdl
import backend/sdlimage
import backend/renderer

type
  ImageData* = ref object
    ## A CPU pixel buffer in RGBA8 you can read and write one pixel at a time,
    ## then upload to a drawable image.
    pixels*: seq[uint8]
    width*: int32
    height*: int32

proc newImageData*(width, height: int32): ImageData =
  ## Create a blank (fully transparent) ImageData of the given size.
  ImageData(width: width, height: height,
            pixels: newSeq[uint8](width.int * height.int * 4))

proc newImageData*(width, height: int32, fill: Color): ImageData =
  ## Create an ImageData filled with a single color.
  result = newImageData(width, height)
  var i = 0
  while i < result.pixels.len:
    result.pixels[i] = fill.r
    result.pixels[i + 1] = fill.g
    result.pixels[i + 2] = fill.b
    result.pixels[i + 3] = fill.a
    i += 4

proc newImageData*(filename: string): ImageData =
  ## Load an image file into a CPU pixel buffer, converting to RGBA8 if needed.
  var surf = IMG_Load(filename.cstring)
  if surf == nil:
    raise newException(IOError, "could not load image '" & filename & "': " & $SDL_GetError())
  if surf.format != SDL_PIXELFORMAT_RGBA32:
    let conv = SDL_ConvertSurface(surf, SDL_PIXELFORMAT_RGBA32)
    SDL_DestroySurface(surf)
    if conv == nil:
      raise newException(IOError, "could not convert image '" & filename & "'")
    surf = conv
  result = newImageData(surf.w.int32, surf.h.int32)
  let src = cast[ptr UncheckedArray[byte]](surf.pixels)
  let w = surf.w.int
  let pitch = surf.pitch.int
  for row in 0 ..< surf.h.int:
    copyMem(addr result.pixels[row * w * 4], addr src[row * pitch], w * 4)
  SDL_DestroySurface(surf)

proc getWidth*(d: ImageData): int32 =
  ## The width of the pixel buffer.
  d.width

proc getHeight*(d: ImageData): int32 =
  ## The height of the pixel buffer.
  d.height

proc getDimensions*(d: ImageData): tuple[w, h: int32] =
  ## The width and height of the pixel buffer.
  (d.width, d.height)

template offset(d: ImageData, x, y: int32): int =
  (y.int * d.width.int + x.int) * 4

proc getPixel*(d: ImageData, x, y: int32): Color =
  ## The color at (x, y). Raises IndexDefect when out of range.
  if x < 0 or y < 0 or x >= d.width or y >= d.height:
    raise newException(IndexDefect, "getPixel: (" & $x & ", " & $y & ") out of range")
  let i = d.offset(x, y)
  (d.pixels[i], d.pixels[i + 1], d.pixels[i + 2], d.pixels[i + 3])

proc setPixel*(d: ImageData, x, y: int32, color: Color) =
  ## Set the color at (x, y). Raises IndexDefect when out of range.
  if x < 0 or y < 0 or x >= d.width or y >= d.height:
    raise newException(IndexDefect, "setPixel: (" & $x & ", " & $y & ") out of range")
  let i = d.offset(x, y)
  d.pixels[i] = color.r
  d.pixels[i + 1] = color.g
  d.pixels[i + 2] = color.b
  d.pixels[i + 3] = color.a

proc mapPixel*(d: ImageData, fn: proc(x, y: int32, c: Color): Color) =
  ## Apply `fn` to every pixel, replacing each with the color it returns.
  for y in 0'i32 ..< d.height:
    for x in 0'i32 ..< d.width:
      let i = d.offset(x, y)
      let c = (d.pixels[i], d.pixels[i + 1], d.pixels[i + 2], d.pixels[i + 3])
      let nc = fn(x, y, c)
      d.pixels[i] = nc.r
      d.pixels[i + 1] = nc.g
      d.pixels[i + 2] = nc.b
      d.pixels[i + 3] = nc.a

proc encode*(d: ImageData, filename: string) =
  ## Save the pixel buffer to a PNG file. Raises IOError on failure.
  if d.width <= 0 or d.height <= 0:
    raise newException(IOError, "encode: cannot save an empty image")
  let surf = SDL_CreateSurfaceFrom(d.width.cint, d.height.cint,
    SDL_PIXELFORMAT_RGBA32, addr d.pixels[0], (d.width.int * 4).cint)
  if surf == nil:
    raise newException(IOError, "encode: SDL_CreateSurfaceFrom failed: " & $SDL_GetError())
  let ok = IMG_SavePNG(surf, filename.cstring)
  SDL_DestroySurface(surf)
  if not ok:
    raise newException(IOError, "could not save '" & filename & "': " & $SDL_GetError())

proc save*(d: ImageData, filename: string) =
  ## Alias for `encode`: save the pixel buffer to a PNG file.
  d.encode(filename)

proc newImage*(nim2d: Nim2d, data: ImageData, mipmaps = false): Image =
  ## Upload a CPU pixel buffer to a drawable GPU image.
  if data.width <= 0 or data.height <= 0:
    raise newException(ValueError, "newImage: image data is empty")
  let tex = nim2d.gpu.createTextureFromPixels(
    addr data.pixels[0], data.width.int, data.height.int, data.width.int * 4, mipmaps)
  Image(tex: tex, width: data.width, height: data.height,
        tint: (255'u8, 255'u8, 255'u8, 255'u8))
