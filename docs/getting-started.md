# Getting started

This page takes you from a blank machine to a window with something moving in it. Three things need to be in place: Nim itself, the SDL3 libraries that nim2d draws and plays sound through, and nim2d. None of it takes long.

## Installing Nim

You need Nim 2.0 or newer. If you don't have it, choosenim installs and manages Nim versions and is the easiest route on macOS and Linux:

```console
$ curl https://nim-lang.org/choosenim/init.sh -sSf | sh
```

Package managers work too, like `brew install nim` on macOS or `sudo pacman -S nim` on Arch Linux. On Windows, the [Nim website](https://nim-lang.org/install_windows.html) has an installer and a zip. Whichever way you go, check the result with `nim -v` and make sure it says 2.x.

## Installing SDL3

nim2d draws, reads input and plays sound through SDL3 and its three satellite libraries: SDL3_image for loading images, SDL3_ttf for fonts, and SDL3_mixer for audio. They are linked into your game when it compiles, so they have to be installed before you build anything.

On macOS, Homebrew has all four:

```console
$ brew install sdl3 sdl3_image sdl3_ttf sdl3_mixer
```

On Arch Linux, all four are in the official repositories:

```console
$ sudo pacman -S sdl3 sdl3_image sdl3_ttf sdl3_mixer
```

On Ubuntu, SDL3 arrived in the official packages with 25.04, along with image and ttf:

```console
$ sudo apt install libsdl3-dev libsdl3-image-dev libsdl3-ttf-dev
```

SDL3_mixer is not packaged on Ubuntu at the time of writing, so build that one from source. It lands in `/usr/local`, which is where nim2d looks on Linux by default:

```console
$ sudo apt install build-essential git cmake ninja-build pkg-config libogg-dev libvorbis-dev
$ git clone --depth 1 --branch release-3.2.4 https://github.com/libsdl-org/SDL_mixer
$ cmake -S SDL_mixer -B SDL_mixer/build -G Ninja -DCMAKE_BUILD_TYPE=Release
$ cmake --build SDL_mixer/build
$ sudo cmake --install SDL_mixer/build
$ sudo ldconfig
```

On an older Ubuntu, or any distribution without SDL3 packages, the same recipe builds the rest of the family. Build SDL itself first, then SDL_image, SDL_ttf and SDL_mixer, cloning `https://github.com/libsdl-org/SDL` and so on at their latest release tags. Before building SDL, install your desktop's development headers (`libx11-dev`, `libxext-dev`, `libwayland-dev`, `libxkbcommon-dev`, `libegl-dev` on Ubuntu) so it builds with video support, and give SDL_image and SDL_ttf `libpng-dev`, `libjpeg-dev`, `libfreetype-dev` and `libharfbuzz-dev` so they can do their jobs.

On Windows, every library ships prebuilt. Download the `-devel-...-mingw.zip` file from the releases page of each of [SDL](https://github.com/libsdl-org/SDL/releases), [SDL_image](https://github.com/libsdl-org/SDL_image/releases), [SDL_ttf](https://github.com/libsdl-org/SDL_ttf/releases) and [SDL_mixer](https://github.com/libsdl-org/SDL_mixer/releases), and merge the `x86_64-w64-mingw32` folder from each zip into one place, say `C:\sdl3`, so it has `bin`, `include` and `lib` folders. Then set the environment variable `NIM2D_SDL_PREFIX` to `C:/sdl3` and add `C:\sdl3\bin` to your `PATH` so the DLLs are found when your game runs.

On Windows the GPU backend is either Direct3D 12 or Vulkan, and SDL picks one at startup; both ship inside `SDL3.dll`, and Direct3D 12 itself is part of Windows 10 and 11, so there is nothing extra to install. The [graphics backends](#graphics-backends) section below covers choosing between them.

The same environment variable works everywhere. If your libraries live somewhere unusual, point `NIM2D_SDL_PREFIX` at the prefix that holds their `include` and `lib` directories.

There is one optional extra. The physics module builds on Box2D and is imported separately with `import nim2d/physics`, so you only need Box2D if you use it: `brew install box2d` on macOS, `sudo pacman -S box2d` on Arch, built from source elsewhere. The [physics page](physics.md) has the details.

## Installing nim2d

The quickest way to see something running is to clone the repository and start an example. Inside the clone everything is already wired up, so this is also the easiest way to check your SDL3 install:

```console
$ git clone https://github.com/nim2d/nim2d
$ cd nim2d
$ nim c -r examples/snake.nim
```

If a window opens and you are playing snake, everything is in place.

For your own project, install nim2d through nimble:

```console
$ nimble install nim2d
```

In a nimble project the same thing is a `requires "nim2d"` line in your .nimble file. To run the development version instead, install straight from the repository with `nimble install https://github.com/nim2d/nim2d@#head`.

One small file is still needed. nim2d links the SDL3 libraries into your game at build time, and your project has to tell the compiler where they are, so put this `config.nims` next to your program. The default prefixes match the install steps above, and `NIM2D_SDL_PREFIX` overrides them, the same as everywhere else:

```nim
# config.nims
proc linkSdl(prefix: string) =
  switch("dynlibOverride", "SDL3")
  switch("dynlibOverride", "SDL3_image")
  switch("dynlibOverride", "SDL3_ttf")
  switch("dynlibOverride", "SDL3_mixer")
  switch("passC", "-I" & prefix & "/include")
  switch("passL", "-L" & prefix & "/lib")
  switch("passL", "-lSDL3")
  switch("passL", "-lSDL3_image")
  switch("passL", "-lSDL3_ttf")
  switch("passL", "-lSDL3_mixer")

when defined(macosx):
  linkSdl(getEnv("NIM2D_SDL_PREFIX", "/opt/homebrew"))
elif defined(windows):
  linkSdl(getEnv("NIM2D_SDL_PREFIX", "C:/sdl3"))
else:
  linkSdl(getEnv("NIM2D_SDL_PREFIX", "/usr/local"))
```

With that in place, `import nim2d` works in any program in that directory. The repository's own `config.nims` is the same thing with a few repo-specific extras, if you want to compare.

## Graphics backends

nim2d draws through SDL's GPU API, which talks to a native backend underneath: Metal on macOS, Vulkan on Linux, and either Direct3D 12 or Vulkan on Windows. You do not choose this in code. SDL picks a backend when the window is created, and nim2d hands it the matching precompiled shaders: the built-in renderer ships SPIR-V for Vulkan, MSL for Metal and DXIL for Direct3D 12, all committed in the repository, so an ordinary build needs no shader toolchain and no extra runtime libraries. Direct3D 12 is part of Windows 10 and 11, so a Windows game needs only the SDL3 DLLs it already ships with.

On Windows you can steer the choice with SDL's `SDL_GPU_DRIVER` hint, set as an environment variable before the game starts:

```console
> set SDL_GPU_DRIVER=direct3d12
> set SDL_GPU_DRIVER=vulkan
```

Leaving it unset lets SDL decide. This is worth knowing because the two backends are not always equivalent on a given machine: a driver bug on one can show up as a hang, a crash or wrong colors that the other does not have, and switching the hint is the quickest way to tell a backend problem from a game problem. Direct3D 12 is generally the steadier choice on Windows.

Custom shaders are cross-platform too. A shader made with [`newShader`](api/shader.md#newShader) from SPIR-V, MSL and DXIL blobs runs on all three backends, the same as the built-in drawing. The only thing to know is that the DXIL blob needs a DXC-enabled shadercross to produce (the SPIR-V and MSL blobs do not): the prebuilt `SDL3_shadercross-*-VC-x64` release bundles DXC and works as-is, and the [drawing guide](drawing.md#shaders) shows the three compile commands. If you give `newShader` only the SPIR-V and MSL blobs, it still runs on Vulkan and Metal and falls back to the built-in shader on Direct3D 12; set `SDL_GPU_DRIVER=vulkan` to run such a shader on Windows.

## The first program

Here is the smallest program that draws something. Put it in `hello.nim`:

!!! example
    ```nim
    import nim2d

    let n2d = newNim2d("hello", 100, 100, 640, 480)

    n2d.draw = proc(nim2d: Nim2d) =
      nim2d.setColor(255, 120, 60)
      nim2d.circle(320, 240, 80, true)

    n2d.play()
    ```

The arguments to [`newNim2d`](api/nim2d.md#newNim2d) are the title, the window position on the desktop, and the window size. Run it with `nim c -r hello.nim`. A window opens and stays up until you close it.

![the window the program above opens](assets/hello.png){ width="480" }

Every nim2d program has this shape. You make a window with `newNim2d`, you assign callbacks for the parts you care about, and [`play`](api/nim2d.md#play) runs the loop until the window closes or you set `nim2d.running` to false. The callbacks you will use most are [`load`](api/nim2d.md#load), which runs once at the start, [`update`](api/nim2d.md#update), which runs every frame with the time since the last frame, and [`draw`](api/nim2d.md#draw), which runs every frame and is where all your drawing goes.

## Making it move

A still circle is a start, but games move. [`update`](api/nim2d.md#update) hands you `dt`, the seconds since the last frame, and whatever you accumulate from it can drive the drawing:

```nim { .annotate }
import std/math
import nim2d

let n2d = newNim2d("loop", 100, 100, 640, 480, (20'u8, 22'u8, 30'u8, 255'u8)) # (1)!
var t = 0.0

n2d.load = proc(nim2d: Nim2d) = # (2)!
  echo "starting"

n2d.update = proc(nim2d: Nim2d, dt: float) =
  t += dt # (3)!

n2d.draw = proc(nim2d: Nim2d) =
  nim2d.setColor(120, 200, 255)
  nim2d.circle(320, 240, 80 + 24 * sin(t * 3), true) # (4)!

n2d.play() # (5)!
```

1.  The sixth argument is the background color, four bytes for red, green, blue and alpha.
2.  Runs once before the first frame, a place for setup.
3.  Adds the seconds since the last frame to t, so t tracks the time elapsed.
4.  The radius rises and falls as sin moves, so the circle breathes.
5.  Starts the loop and runs it until the window closes.

Run it and the circle breathes. The sixth argument to [`newNim2d`](api/nim2d.md#newNim2d) is the background color as four bytes for red, green, blue and alpha; the window clears to it at the start of every frame, so [`draw`](api/nim2d.md#draw) always starts from a clean slate.

## How coordinates work

Coordinates are in pixels with the origin at the top left and y pointing down. Positions and sizes are plain `float`, so you can pass numbers and the results of math without sprinkling type conversions everywhere. Colors are bytes from 0 to 255. Angles, where they show up, are in radians.

From here, the [drawing page](drawing.md) walks through everything you can put on the screen, and the [input page](input.md) covers reading the keyboard, mouse and gamepads. Or just open the [examples](examples.md) and start changing numbers. When the game is ready to share with others, the [shipping page](shipping.md) covers the release build and getting the libraries onto a player's machine.

!!! info "See also"
    The runnable [`all` example](https://github.com/nim2d/nim2d/blob/master/examples/all.nim), and the [`nim2d` API reference](api/nim2d.md).
