# love2d parity

nim2d aims for capability parity with love2d, not a name-for-name clone. The API is idiomatic Nim (object-method style, `uint8` colors, radians, float coordinates), so the question this page answers is whether each thing you can do in love2d has a nim2d equivalent, and where the gaps still are. It is the running scorecard for the project.

Status words: **done** means the capability is there and used in examples or tests; **basic** means a usable subset with known room to grow; **partial** means some of it landed and some is listed as missing; **not yet** means it is planned but absent.

## Graphics

**done**, with a small tail. The renderer is an SDL_GPU batch renderer that breaks shapes into triangles.

- Shapes: circle, ellipse, arc, pie, rectangle (with rounded corners), triangle, polygon (convex and concave fill), line, points. Done.
- Thick lines get round joins; points take a size. Done.
- Images and canvases (render targets), drawn with rotation, scale and origin, plus quads for sprite-sheet frames. Done.
- Per-texture filter (nearest, linear), wrap (clamp, repeat, mirror) and opt-in mipmaps. Done.
- Transforms: push, pop, translate, rotate, scale, shear, origin. Done.
- Sprite batches, meshes (triangle list, fan, strip), particle systems. Done.
- Blend modes, scissor, and a stencil buffer for arbitrary-shape masking (opt-in with `stencil = true`). Done.
- Anti-aliasing through supersampling (`aa = 2`), not hardware MSAA. Done, by a different route than love.
- Text: TrueType via SDL3_ttf as UTF-8, and bitmap/image fonts via `newImageFont`. **mostly done**: each TTF string still rasterizes to a texture per frame, so a glyph-atlas engine is the remaining optimization.
- Shaders: built-in shaders run cross-platform (Metal and Vulkan); a user `newShader` takes MSL source for Metal, or precompiled SPIR-V plus MSL blobs to run everywhere. **partial**: there is no runtime GLSL compile (that would need the SDL_shadercross runtime library), so cross-platform user shaders must be precompiled offline.
- Meshes with custom vertex formats and instancing: **not yet**. The batch renderer is built around one vertex format, so this is an architectural addition; the sprite batch already covers the common "many of the same" case.

## Window, event, timer

**done**. Window mode, fullscreen with a query, resize and resizable, minimize, maximize and restore, desktop size, an icon from an ImageData, a message box, vsync, and an opt-in high-DPI window. Events arrive through callbacks; there is frame timing, `getTime`, `getFPS` and `getDelta`.

## Input

**done**. Keyboard (held-key polling and key callbacks), mouse (position, buttons, wheel, cursor visibility, relative mode, grab, warping), gamepads (auto-opened, press/release/axis callbacks and polling), and touch (finger callbacks and polling).

## Audio and sound

**done** (SDL3_mixer). Load and play static or streaming sources, pause, resume, stop, seek, volume, pitch, looping, and positional stereo with a movable listener.

## Image, font, filesystem, data, math

- love.image: **done**. CPU `ImageData` buffers, per-pixel read and write, `mapPixel`, upload to a texture, save to PNG.
- love.font: **mostly done**. TrueType fonts and bitmap/image fonts; the glyph-atlas optimization is the gap (see Graphics, text).
- love.filesystem: **done**. A sandboxed save directory and read-only source directory, read, write, append, a lines iterator, directory listing, info, mount points.
- love.data: **done**. base64 and hex, md5/sha1/sha256/sha512 digests, zlib/gzip/deflate compression, and a small endian-aware integer packer.
- love.math: **done**. A seeded PCG random with the `random` family, value/Perlin/simplex noise, Bezier curves, ear-clipping triangulation, a standalone transform, and helpers.

## Physics

**done** (Box2D 3.x, imported on its own with `import nim2d/physics`). Worlds, static/dynamic/kinematic bodies, box and circle shapes, the common joints (revolute, distance, prismatic, weld, wheel, motor), raycasts, AABB region queries, and begin/end contact events, with a per-body user-data integer.

## System and thread

- love.system: **done**. OS name, processor count, clipboard, open URL, and battery and power info.
- love.thread: **done**. Background threads and typed channels, with rendering kept on the main thread.

## Video

**not yet**. love builds video on Ogg Theora, and SDL3 ships no codec, so this needs a decoder dependency (libtheora or ffmpeg) and a frame-to-texture path with audio sync. It is the least-used part of love and is the last thing planned.

## Remaining gaps, in one place

- A glyph-atlas text engine, so TrueType text does not re-rasterize each frame (bitmap fonts already exist).
- Cross-platform user shaders authored as live GLSL (currently precompiled offline or MSL-on-Metal); this needs the SDL_shadercross runtime library as an optional desktop layer.
- DXIL for Direct3D 12 on Windows machines without a Vulkan driver; this needs a shadercross build with the DirectX compiler.
- Mesh custom vertex formats and instancing.
- love.video.
