# Shipping your game

Everywhere else in these guides the build command is `nim c -r mygame.nim`. That is the debug build, and it is the right thing while you are working: the compiler leaves the runtime checks in, skips most optimization, and keeps the debug symbols so a crash points at a line. None of that is what you want in the copy you hand to a player. A debug build runs the game slower than it needs to, and it is larger than it needs to be. When you are ready to give the game to other people, you build it in release mode, and you make sure the libraries it draws and plays sound through reach the player's machine.

## The release build

This is the build to ship:

```console
$ nim c -d:release --panics:on -d:strip mygame.nim
```

`-d:release` is the one that matters most. It turns on the optimizer and drops the debug-only checks, which is the difference between a steady frame rate and a stuttery one. `--panics:on` changes what happens when something does go wrong, like a bounds error or an integer overflow. Instead of raising an exception that nothing is waiting to catch, the program stops there with a message. In a finished game that is the honest behavior, since there is no recovery path for a bug you did not anticipate. `-d:strip` removes the debug symbols from the binary so it is smaller. On macOS the linker prints `ld: warning: -s is obsolete` while doing it, which is safe to ignore; the binary still comes out stripped.

There is one more flag worth adding, link-time optimization:

```console
$ nim c -d:release --panics:on -d:strip -d:lto mygame.nim
```

`-d:lto` lets the optimizer work across module boundaries and into the statically linked SDL and Box2D, so calls that the per-module build leaves alone can be inlined. It makes the compile slower, and it works fine alongside the direct SDL linking nim2d uses, so it is a safe addition once you are building for release anyway.

If you want to go further, `-d:danger` builds on top of release by removing the remaining runtime checks entirely, trading the last bit of safety for a little more speed. It is worth reaching for only once the game is well tested, because a bug that release would have caught becomes undefined behavior instead.

One flag belongs in the other direction. When you are chasing a memory problem with a sanitizer or Valgrind, add `-d:useMalloc` so allocations go through the system allocator those tools understand. It has no place in a shipping build, but it is the thing to add for that kind of debugging, given the manual teardown order nim2d uses for its native resources.

## Windows: hide the console

On Windows a normal build opens a console window behind the game. Add `--app:gui` so it runs as a windowed application with no console:

```console
$ nim c -d:release --panics:on -d:strip --app:gui mygame.nim
```

This flag does nothing useful on macOS or Linux, so leave it out there.

## Shipping the libraries

Your game links against SDL3 and the three satellite libraries (SDL3_image, SDL3_ttf, SDL3_mixer), and SDL_GPU loads its backend driver at runtime, so those libraries have to be present wherever the game runs. During development they come from the install you set up in [getting started](getting-started.md). For a build you give to someone else, they have to travel with it or already be on the target machine.

On Windows the libraries are DLLs. Copy `SDL3.dll`, `SDL3_image.dll`, `SDL3_ttf.dll` and `SDL3_mixer.dll` from your `C:\sdl3\bin` into the same folder as the `.exe`. A shipped Windows game is the executable, those DLLs, and the assets, all in one folder.

On macOS the binary records the path it was linked against. For a Homebrew install that path lives under `/opt/homebrew`, and `otool -L mygame` lists exactly what it expects:

```console
$ otool -L mygame
	/opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib ...
	/opt/homebrew/opt/sdl3_image/lib/libSDL3_image.0.dylib ...
	...
```

A binary like that runs on a Mac with the same Homebrew setup and nowhere else. To hand it to anyone, either tell them to `brew install sdl3 sdl3_image sdl3_ttf sdl3_mixer` first, or copy the dylibs into an app bundle and rewrite the recorded paths with `install_name_tool` so they point inside the bundle instead of at `/opt/homebrew`.

On Linux, ship the `.so` files next to the binary and set an rpath so it finds them there, or list the SDL3 packages as a dependency and let the player's package manager provide them, which is the simpler path on distributions that package SDL3.

## Assets travel too

nim2d loads an image, font or sound from the path you give it, and that path is resolved from where the game is started. The simplest layout is the binary and its `assets` folder in one place, started from that place, so a `newImage("assets/player.png")` finds the file. If you want paths that resolve relative to the executable no matter where it is launched from, the [files guide](filesystem.md) covers the source directory the filesystem module exposes for exactly that.

!!! info "See also"
    [Getting started](getting-started.md) for the development setup these builds extend, and the [files guide](filesystem.md) for resolving asset paths relative to the program.
