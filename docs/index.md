# nim2d

nim2d is a small 2D game engine for Nim, loosely modeled on love2d. You open a window, set a few callbacks for loading, updating and drawing, and call `play`. This is the documentation for what it can do right now.

These docs come in two parts. The guides are hand-written and walk through how things work, and the API reference is generated from the source so it always matches the code.

- [Getting started](getting-started.html)
- [Drawing](drawing.html)
- [Input and timing](input.html)
- [Examples](examples.html)
- [API reference](api/nim2d.html), the main module, with links to every other module under it
- [Symbol index](api/theindex.html), every type and proc in one list

nim2d is pre-alpha. It runs on macOS today through SDL3 and its GPU API. Shapes, images, text, canvases and input all work. Shaders, a transform stack, audio and the rest are not here yet.
