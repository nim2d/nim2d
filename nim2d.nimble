# Package

version       = "0.1.0"
author        = "Beshr Kayali"
description   = "2d game engine for Nim, inspired by Love2d (SDL3 / SDL_GPU)"
license       = "zlib"
srcDir        = "src"


# Dependencies
requires "nim >= 2.0.0"
requires "sdl3_nim"


# Tasks
task examples, "Build the bundled examples":
  exec "nim c -r examples/all.nim"
