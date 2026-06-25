# Package

version       = "0.5.1"
author        = "Beshr Kayali Reinholdsson"
description   = "2d game engine for Nim, inspired by Love2d (SDL3 / SDL_GPU)"
license       = "zlib"
srcDir        = "src"


# Dependencies
requires "nim >= 2.0.0"
requires "sdl3_nim == 3.4.2.0"
requires "zippy == 0.10.19"      # compression for the data module
requires "nimcrypto == 0.6.2"    # sha1/sha256/sha512 for the data module


# Tasks
task examples, "Build the bundled examples":
  exec "nim c -r examples/all.nim"
