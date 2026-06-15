# Examples

The `examples` folder has runnable demos, each a single file. Run any of them with `nim c -r examples/<name>.nim`, or run the showcase with `nimble examples`.

Three of them are complete little games. `snake.nim` has a grid, steering by arrows or WASD, a score, and a restart after you lose, and `pong.nim` plays against a simple AI, moving the left paddle with W and S or the arrow keys.

![the snake example](assets/snake.png){ width="400" }

![the pong example](assets/pong.png){ width="400" }

`starfield.nim` is a fake-3D shmup. Enemies dive at you over a perspective ground grid, growing as they close in; steer with the arrow keys or the mouse, hold space or the left button to fire, and survive waves that keep getting faster and meaner. Between waves the stars stretch into a warp jump, the screen shakes when you take a hit, and the run keeps score across three lives, restarting on R. The whole 3D effect is one divide: a point at depth z lands at `center + position * focal / z`, the same projection the background stars use.

![the starfield shmup, with enemies diving over a perspective grid](assets/starfield.png){ width="480" }

The rest, in the order you might explore them:

- `all.nim` is a showcase that touches most of what nim2d does: shapes, an image, a canvas, text and input.
- `bounce.nim` drops balls under gravity that bounce off the walls. Click to spawn one, space for a burst, c to clear.
- `particles.nim` is a particle fountain that follows the mouse and uses additive blending for the glow. Click for a firework.
- `clock.nim` draws an analog clock from the system time, with ticks, hands and a digital readout.
- `transforms.nim` shows the transform stack with orbiting, self-spinning satellites and a pulsing row of squares.
- `camera.nim` flies a glowing orb across a world wider than the window and flips between two cameras, a close follow view and a pulled-back tilted overview, blending smoothly between them on each switch. It pins gate labels with [`toScreen`](api/camera.md#toScreen), drops a ping at the world point under the cursor with [`toWorld`](api/camera.md#toWorld), and uses `import nim2d/camera`.
- `collide.nim` is a live reference for the collide module, a panel for each test that reacts to the mouse, so you can watch every overlap, point, segment and resolution check light up as a probe shape moves against a fixed one. It uses `import nim2d/collide`.
- `tween.nim` is a chart of every easing curve in the tween module, a cell per curve with a dot tracing along it on a shared clock, rows for the families and columns for the in, out and in-out variants, with a ball up top riding one curve at a time through a [`VecTween`](api/tween.md#VecTween). It uses `import nim2d/tween`.
- `schedule.nim` drives a small clockwork from a scheduler: a metronome on [`every`](api/schedule.md#every) pulses a ring, each beat queues an offbeat with [`after`](api/schedule.md#after), every fourth beat runs a [`during`](api/schedule.md#during) sweep, and a feed lists the callbacks as they fire. Click to queue a burst, space cancels the metronome, C clears every timer. It uses `import nim2d/schedule`.
- `scene.nim` moves between a title, a play field and a pause overlay with a scene manager, showing [`switch`](api/scene.md#switch) between screens and [`push`](api/scene.md#push)/[`pop`](api/scene.md#pop) for the pause, which draws over the still-visible game because the stack draws from the bottom up. It uses `import nim2d/scene`.
- `animation.nim` walks a warrior around a field of grass with WASD or the arrow keys, playing a sprite-sheet walk cycle for whichever way he faces and resting on the standing frame when he stops, over a ground of randomly scattered grass tiles. It uses `import nim2d/animation`.
- `tilemap.nim` loads a cave level made in LDtk, draws its tiles scaled up, and walks a square around it that jumps and bumps into the walls marked on the level's IntGrid. It uses `import nim2d/tilemap` and lives in its own folder with the `.ldtk` file and tileset. Move with A/D or the arrows, jump with Space.
- `platformer.nim`, in the same folder, loads the LDtk "typical 2D platformer" sample. Its four levels sit next to each other in world space, joined at the ladders, so the example draws them all at their world positions and a camera from the camera module follows the player while staying inside the part it is in, bringing the next part into view as you cross into it. The player starts at the `Player` entity, the mobs patrol between the waypoints on their `patrol` field, and touching a mob or falling out of a level sends you back to the start. Chests and doors are drawn as markers, and the collision grid has dirt and stone as solid with a ladder value you climb with W or S. It uses `import nim2d/tilemap`, `import nim2d/collide` and `import nim2d/camera`.
- `input.nim` shows held-key polling, mouse position and buttons, the wheel, and text input.
- `sprites.nim` shows a sprite batch, a colored mesh and a quad crop.
- `shader.nim` runs a fragment shader over a fullscreen rectangle for an animated plasma. The shader is authored in GLSL (`plasma.frag`) and compiled offline to SPIR-V and MSL blobs, so it runs on both Metal and Vulkan.
- `noise.nim` scrolls Perlin noise across the window and shows a concave star filled by ear clipping and a Bezier curve.
- `data.nim` has no window and prints base64, hex, hashes, compression sizes and a packed value, so it doubles as a quick check.
- `imagedata.nim` builds a small texture on the CPU pixel by pixel, draws it scaled up, and saves it to a PNG when you press S.
- `filesystem.nim` keeps a high-score table in the save directory, appending a new score on each press and reading it back.
- `audio.nim` plays a looping music track and a sound effect, with keys for volume, stereo panning and pitch.
- `system.nim` shows the platform and power info and drives the window and cursor from the keyboard: fullscreen, resize, minimize, relative mouse mode, grab, clipboard and a message box.
- `physics.nim` drops boxes and balls that fall, collide and stack on Box2D, click or space to add more. It needs Box2D installed and is built with `nim c -r examples/physics.nim`.
- `threads.nim` runs a prime count on a background thread and reports its progress over a channel, while a spinner keeps turning at full frame rate to show the main loop never blocks.
- `touch.nim` draws a dot under each finger and ripples out where you press, using the touch callbacks and polling. On a desktop the trackpad usually acts as a touch device.
- `polish.nim` tours the graphics extras: nearest and linear filtering, texture wrap, mipmaps, point size, round joins on thick lines, supersampled anti-aliasing (`aa = 2`) and stencil masking (`stencil = true`).
- `bitmapfont.nim` builds a small pixel font in memory and draws scaled, tinted text with it, showing [`newImageFont`](api/font.md#newImageFont).

These are a good place to see the API used in context. snake and pong show input and game state, starfield shows held-key polling and faking depth with a projection, particles shows blend modes, clock shows building shapes from lines and trigonometry, and all shows images, canvases and text together.

There is one more program of this kind in the repository: `tools/docshots.nim` renders every screenshot in these docs by drawing scenes into a canvas, reading the pixels back with [`newImageData`](api/imagedata.md#newImageData), and saving PNGs. If you want to capture images of your own game, that is the file to crib from.
