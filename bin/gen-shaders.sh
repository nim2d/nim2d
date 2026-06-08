#!/usr/bin/env bash
# Compile the built-in shaders from GLSL (shaders/) to SPIR-V and MSL blobs in
# the library source tree (src/nim2d/backend/shaders/). Driven by `make shaders`;
# see shaders.mk for how to get glslc and the shadercross CLI.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/shaders"
OUT="$ROOT/src/nim2d/backend/shaders"
GLSLC="${GLSLC:-glslc}"
SHADERCROSS="${SHADERCROSS:-shadercross}"

gen() {
  local src="$1" stage="$2" name="$3"
  "$GLSLC" -fshader-stage="$stage" "$SRC/$src" -o "$OUT/$name.spv"
  "$SHADERCROSS" "$OUT/$name.spv" -s SPIRV -d MSL -t "$stage" -e main -o "$OUT/$name.metal"
}

gen vertex.vert  vertex   vertex
gen color.frag   fragment color
gen texture.frag fragment texture
echo "shaders compiled to $OUT"
