## Built-in shaders for the 2D batch renderer.
##
## Each shader is authored once in GLSL in the repo's `shaders/` directory and
## compiled offline by `make shaders` into two blobs next to this module: SPIR-V
## for the Vulkan backend (Linux, and Windows without a Metal driver) and MSL for
## the Metal backend (macOS, iOS). The renderer picks the matching blob at runtime
## from `SDL_GetGPUShaderFormats`. Both blobs are committed, so an ordinary build
## needs no shader toolchain.
##
## The SPIR-V entry point is `main`; the MSL entry point is `main0`, since
## SPIRV-Cross renames `main` when it transpiles (`main` is reserved in MSL).

const
  VertexSPIRV* = staticRead("shaders/vertex.spv")
  VertexMSL* = staticRead("shaders/vertex.metal")
  FragmentColorSPIRV* = staticRead("shaders/color.spv")
  FragmentColorMSL* = staticRead("shaders/color.metal")
  FragmentTextureSPIRV* = staticRead("shaders/texture.spv")
  FragmentTextureMSL* = staticRead("shaders/texture.metal")
