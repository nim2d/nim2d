## User fragment shaders.
##
## `newShader` takes Metal Shading Language source for a fragment function named
## "frag", which replaces the built-in fragment stage while the shader is set.
## A standard preamble (the metal header and the VSOutput struct the built-in
## vertex shader produces) is prepended for you, so the source you pass is just
## the fragment function. It takes the vertex output through stage_in, a texture
## and sampler at slot 0, and, when you ask for a uniform, a fragment uniform
## buffer at slot 0. The exact signature is in the Shaders section of the docs
## and in the shader example.
##
## Inside the function, in.uv and in.color come from the vertex, in.position.xy
## is the pixel position, tex is the current texture (a white pixel when drawing
## shapes), and the uniform is filled by `send`.
##
## MSL source runs on the Metal backend only. To write a shader that runs
## everywhere, author it in GLSL, compile it offline to SPIR-V, MSL and DXIL the
## same way the built-in shaders are (see the shaders Makefile), and pass the
## three blobs to the `newShader` overload below, which picks the one the live
## backend wants. A two-blob (SPIR-V + MSL) overload covers Vulkan and Metal only.

import types
import backend/sdl
import backend/renderer

const Preamble =
  """
#include <metal_stdlib>
using namespace metal;
struct VSOutput { float4 position [[position]]; float2 uv [[user(locn0)]]; float4 color [[user(locn1)]]; };
"""

proc newShader*(nim2d: Nim2d, fragmentSrc: string, uniformFloats = 0): Shader =
  ## Compile a fragment shader from MSL source (entry "frag"); runs on Metal.
  ## `uniformFloats` is how many float32 the fragment uniform holds (0 for none);
  ## fill it later with `send`.
  result = Shader(hasUniform: uniformFloats > 0)
  if uniformFloats > 0:
    result.uniform = newSeq[byte](uniformFloats * sizeof(float32))
  result.pipelines = nim2d.gpu.createShaderPipelines(
    Preamble & fragmentSrc,
    "frag",
    SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_MSL),
    result.hasUniform,
  )

proc newShader*(
    nim2d: Nim2d, spirv, msl, dxil: string, uniformFloats = 0
): Shader =
  ## Compile a fragment shader from precompiled cross-platform blobs: SPIR-V for
  ## Vulkan, MSL for Metal and DXIL for Direct3D 12, all produced offline from one
  ## GLSL source. The blob matching the live backend is chosen, so a single call
  ## runs everywhere nim2d does — macOS and iOS (Metal), Linux (Vulkan) and Windows
  ## (Direct3D 12 or Vulkan). `uniformFloats` is how many float32 the fragment
  ## uniform holds (0 for none); fill it later with `send`.
  ##
  ## Author the GLSL the way the built-in textured shader is: `vUV` at location 0
  ## and `vColor` at location 1 from the vertex, a sampler in set 2, and (when
  ## used) a uniform buffer in set 3. Compile the three blobs with the same tools
  ## as the built-in shaders — glslc, then a DXC-enabled shadercross (the prebuilt
  ## `SDL3_shadercross-*-VC-x64` works on Windows):
  ##
  ## .. code-block:: sh
  ##   glslc       -fshader-stage=fragment my.frag -o my.spv
  ##   shadercross my.spv -s SPIRV -d MSL  -t fragment -e main -o my.metal
  ##   shadercross my.spv -s SPIRV -d DXIL -t fragment -e main -o my.dxil
  ##
  ## If no blob is supplied for the live backend (e.g. an empty `dxil` while
  ## Direct3D 12 is active), or the pipeline fails to build, this returns nil and
  ## the draw falls back to the built-in shader rather than risk a broken pipeline.
  ## Always give a backend its own format: a mismatched blob can hang the GPU, so
  ## the selection always goes through the format-matching `blobFor`.
  result = Shader(hasUniform: uniformFloats > 0)
  if uniformFloats > 0:
    result.uniform = newSeq[byte](uniformFloats * sizeof(float32))
  let (blob, entry) = blobFor(nim2d.gpu.shaderFormat, spirv, msl, dxil)
  if blob.len == 0:
    return nil
  try:
    result.pipelines =
      nim2d.gpu.createShaderPipelines(blob, entry, nim2d.gpu.shaderFormat, result.hasUniform)
  except CatchableError:
    return nil

proc newShader*(nim2d: Nim2d, spirv, msl: string, uniformFloats = 0): Shader =
  ## Two-blob form covering Vulkan (SPIR-V) and Metal (MSL); a convenience wrapper
  ## over the three-blob overload above with no DXIL blob. With no DXIL it returns
  ## nil on the Direct3D 12 backend SDL may pick on Windows, and the draw falls
  ## back to the built-in shader. Pass a DXIL blob as well (the three-blob form),
  ## or force Vulkan with `SDL_GPU_DRIVER=vulkan`, to run a custom shader on
  ## Windows.
  newShader(nim2d, spirv, msl, "", uniformFloats)

proc send*(shader: Shader, values: openArray[float32]) =
  ## Fill the fragment uniform buffer with float32 values.
  if not shader.hasUniform or values.len == 0:
    return
  let n = min(values.len * sizeof(float32), shader.uniform.len)
  copyMem(addr shader.uniform[0], unsafeAddr values[0], n)

proc destroy*(nim2d: Nim2d, shader: Shader) =
  ## Release a shader's pipelines right away rather than waiting for it to be
  ## collected. The shader is unusable afterwards. Use it when you build and drop
  ## many shaders; otherwise a shader frees itself when it goes out of use.
  if shader == nil:
    return
  for blend in BlendMode:
    if shader.pipelines[blend] != nil:
      SDL_ReleaseGPUGraphicsPipeline(nim2d.gpu.device, shader.pipelines[blend])
      shader.pipelines[blend] = nil

proc setShader*(nim2d: Nim2d, shader: Shader) =
  ## Draw with this shader until it is unset.
  nim2d.gpu.curShader = shader

proc setShader*(nim2d: Nim2d) =
  ## Go back to the built-in shaders.
  nim2d.gpu.curShader = nil
