# nim2d

nim2d is a small 2D game engine for Nim, loosely modeled on love2d. You open a window, set a few callbacks for loading, updating and drawing, and call `play`. This is the documentation for what it can do right now.

These docs come in two parts. The guides are hand-written and walk through how things work, and the API reference is generated from the source so it always matches the code.

- [Getting started](getting-started.html)
- [Drawing](drawing.html)
- [Input and timing](input.html)
- [Math](math.html)
- [Data](data.html)
- [Files](filesystem.html)
- [Audio](audio.html)
- [System](system.html)
- [Physics](physics.html)
- [Parity](parity.html), how close nim2d is to love2d, module by module
- [Examples](examples.html)
- [API reference](api/nim2d.html), the main module, with links to every other module under it
- [Symbol index](api/theindex.html), every type and proc in one list

nim2d is pre-alpha. It runs on macOS, Linux and Windows through SDL3 and its GPU API, drawing on Metal or Vulkan depending on the platform. Shapes, images, text, canvases, a transform stack, shaders and input all work, and so do sound, physics, threads and the non-graphics pieces like a seeded random generator, noise, file saving and data encoding. See the parity page for how close it is to love2d and what is still missing.
