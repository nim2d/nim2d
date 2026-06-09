# Examples

The `examples` folder has runnable demos, each a single file. Run any of them with `nim c -r examples/<name>.nim`, or run the showcase with `nimble examples`.

- `all.nim` is a showcase that touches most of what nim2d does: shapes, an image, a canvas, text and input.
- `bounce.nim` drops balls under gravity that bounce off the walls. Click to spawn one, space for a burst, c to clear.
- `snake.nim` is the whole game, with a grid, steering by arrows or WASD, a score, and a restart after you lose.
- `pong.nim` is Pong against a simple AI. Move the left paddle with W and S or the arrow keys.
- `particles.nim` is a particle fountain that follows the mouse and uses additive blending for the glow. Click for a firework.
- `starfield.nim` flies through a field of stars. Up and down change the speed.
- `clock.nim` draws an analog clock from the system time, with ticks, hands and a digital readout.
- `transforms.nim` shows the transform stack with orbiting, self-spinning satellites and a pulsing row of squares.
- `input.nim` shows held-key polling, mouse position and buttons, the wheel, and text input.
- `sprites.nim` shows a sprite batch, a colored mesh and a quad crop.
- `shader.nim` runs a fragment shader over a fullscreen rectangle for an animated plasma. The shader is authored in GLSL (`plasma.frag`) and compiled offline to SPIR-V and MSL blobs, so it shows a cross-platform user shader running on both Metal and Vulkan.
- `noise.nim` scrolls Perlin noise across the window and shows a concave star filled by ear clipping and a Bezier curve.
- `data.nim` has no window and prints base64, hex, hashes, compression sizes and a packed value, so it doubles as a quick check.
- `imagedata.nim` builds a small texture on the CPU pixel by pixel, draws it scaled up, and saves it to a PNG when you press S.
- `filesystem.nim` keeps a high-score table in the save directory, appending a new score on each press and reading it back.
- `audio.nim` plays a looping music track and a sound effect, with keys for volume, stereo panning and pitch.
- `system.nim` shows the platform and power info and drives the window and cursor from the keyboard: fullscreen, resize, minimize, relative mouse mode, grab, clipboard and a message box.
- `physics.nim` drops boxes and balls that fall, collide and stack on Box2D, click or space to add more. It needs Box2D installed and is built with `nim c -r examples/physics.nim`.
- `threads.nim` runs a prime count on a background thread and reports its progress over a channel, while a spinner keeps turning at full frame rate to show the main loop never blocks.
- `touch.nim` draws a dot under each finger and ripples out where you press, using the touch callbacks and polling. On a desktop the trackpad usually acts as a touch device.
- `polish.nim` tours the graphics-polish features: nearest and linear filtering, texture wrap, mipmaps, point size, round joins on thick lines, supersampled anti-aliasing (`aa = 2`) and stencil masking (`stencil = true`).
- `bitmapfont.nim` builds a small pixel font in memory and draws scaled, tinted text with it, showing `newImageFont`.

These are a good place to see the API used in context. snake and pong show input and game state, particles shows blend modes, clock shows building shapes from lines and trigonometry, and all shows images, canvases and text together.
