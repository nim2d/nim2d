# Nim2D

![](https://github.com/beshrkayali/nim2d/workflows/Tests/badge.svg)

Nim2D is a small 2D game engine for Nim, loosely modeled on love2d. It started as a way for me to get my hands dirty with Nim and SDL, and it has since moved over to Nim 2.x and SDL3, drawing through SDL's GPU API. It's pre-alpha, so expect rough edges.

The plan is to slowly grow toward love2d feature parity, so anything you can do there you can eventually do here, written in plain Nim. Right now there's enough to draw shapes, images and text, render to a canvas, run fragment shaders, move things with a transform stack, batch sprites, and build meshes and particle systems, with keyboard, mouse and gamepad input. Beyond graphics it also has sound, a seeded random generator with noise and Bezier curves, CPU pixel buffers, file saving, data encoding and compression, platform and window controls, background threads, and rigid-body physics through Box2D. `examples/all.nim` touches most of the drawing, and there are small demos next to it for snake, pong, a particle fountain, a starfield, an analog clock, bouncing balls, shaders, sprites, transforms, noise, audio, the system and window controls, a physics sandbox, background threads, and touch.

Shapes get broken into triangles and drawn through a GPU batch renderer, so there's no dependency on SDL2_gfx anymore. Images load through SDL3_image, text goes through SDL3_ttf as UTF-8, and canvases are real render targets. Keyboard, mouse, gamepad and window events come in through callbacks, and there's basic timing. Sound runs on SDL3_mixer. The one big gap is that shaders are Metal only for now, so the engine runs on macOS today and other platforms still need cross-platform shader support.

## Building

You need Nim 2.0 or newer and the SDL3 libraries (SDL3, SDL3_image, SDL3_ttf, and later SDL3_mixer for audio).

On macOS:

```sh
brew install sdl3 sdl3_image sdl3_ttf sdl3_mixer
```

The physics module also needs Box2D (`brew install box2d`), but only if you use it, since it is imported on its own with `import nim2d/physics`.

nim2d uses the [sdl3_nim](https://github.com/dinau/sdl3_nim) binding for the core SDL3 and GPU API, with small local bindings for SDL3_image and SDL3_ttf. nimble pulls it in for you. One detail worth knowing about the build is that nim2d links SDL3 directly at compile time with `--dynlibOverride` (set up in `config.nims`) instead of loading it at runtime, because the binding looks for `libSDL3.so`, which doesn't exist on macOS. So the libraries need to be installed when you build.

## Running

```sh
nimble examples              # build and run examples/all.nim
nim c -r examples/snake.nim  # or any other example
nimble test                  # headless unit tests
```
