# nim2d

nim2d is a small 2D game engine for Nim, in the spirit of love2d. You open a window, set a few callbacks for loading, updating and drawing, and call `play`. The rest is a box of parts: shapes, images, text, canvases, shaders, input, sound, physics, and the plain-Nim modules for random numbers, noise, files and data.

![shapes, a bezier curve and text rendered by nim2d](assets/hero.png){ width="740" }

It runs on macOS, Linux and Windows through SDL3 and its GPU API, drawing on Metal or Vulkan depending on the platform. Every screenshot in these docs was rendered by nim2d itself, by a small tool that draws each scene into a canvas, reads the pixels back and saves a PNG.

nim2d is batteries-included. Beyond the core there is a set of opt-in modules for the things almost every game ends up rebuilding, a camera, collision, tweening, tilemaps and more, each carried only when you import it. The code lives on GitHub at [github.com/nim2d/nim2d](https://github.com/nim2d/nim2d).

The guides are hand-written and walk through how things work, and the API reference is generated from the source so it always matches the code.

## Guides

- [Getting started](getting-started.md), from setup to a window with a circle in it
- [Drawing](drawing.md), shapes, images, text, particles, canvases and shaders
- [Input and timing](input.md), keyboard, mouse, gamepads and the clock
- [Math](math.md), seeded random, noise, Bezier curves and vectors
- [Data](data.md), encoding, hashing, compression and packing
- [Files](filesystem.md), the save directory and reading what you ship
- [Audio](audio.md), loading and playing sounds
- [System](system.md), clipboard, battery, background threads and other platform bits
- [Physics](physics.md), rigid bodies on Box2D
- [Examples](examples.md), the runnable demos in the repository

## Included batteries

These are the opt-in modules. The core never pulls them in, so you reach for one with its own import, like `import nim2d/camera`, and each ships with an example and the guide page below.

- [Camera](camera.md), a movable, zoomable view with smooth following and switching
- [Collide](collide.md), lightweight overlap and point tests for games that do not want full physics
- [Tween](tween.md), easing curves and value tweens for smooth motion over time
- [Schedule](schedule.md), timers that fire callbacks after a delay, on a repeat, or for a while
- [Scene](scene.md), a scene stack for menus, levels and pause screens
- [Animation](animation.md), sprite-sheet frames played over time
- [Tilemap](tilemap.md), loading and drawing levels made in the LDtk editor

## Reference

The [API reference](api/nim2d.md) is generated from the source comments. The core sits under `nim2d`, and the opt-in modules, physics along with [camera](api/camera.md), [collide](api/collide.md), [tween](api/tween.md), [schedule](api/schedule.md), [scene](api/scene.md), [animation](api/animation.md) and [tilemap](api/tilemap.md), each have their own page since they are imported separately. The search box at the top finds any type or proc by name.
