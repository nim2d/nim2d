# Examples

The `examples` folder has runnable demos, each a single file. Run any of them with `nim c -r examples/<name>.nim`, or run the showcase with `nimble examples`.

- `all.nim` is a showcase that touches most of what nim2d does: shapes, an image, a canvas, text and input.
- `bounce.nim` drops balls under gravity that bounce off the walls. Click to spawn one, space for a burst, c to clear.
- `snake.nim` is the whole game, with a grid, steering by arrows or WASD, a score, and a restart after you lose.
- `pong.nim` is Pong against a simple AI. Move the left paddle with W and S or the arrow keys.
- `particles.nim` is a particle fountain that follows the mouse and uses additive blending for the glow. Click for a firework.
- `starfield.nim` flies through a field of stars. Up and down change the speed.
- `clock.nim` draws an analog clock from the system time, with ticks, hands and a digital readout.

These are a good place to see the API used in context. snake and pong show input and game state, particles shows blend modes, clock shows building shapes from lines and trigonometry, and all shows images, canvases and text together.
