## SDL_GPU 2D batch renderer.
##
## Drawing is deferred. During a frame the geometry accumulates into one CPU
## vertex and index buffer, grouped into draw commands that batch by pipeline,
## blend mode and texture. At the end of the frame everything is uploaded in a
## single copy pass and then replayed across one render pass per target. Doing it
## this way works around the SDL_GPU rule that copy passes cannot be nested
## inside render passes.

import std/math
import sdl, shaders
import ../types
import ../transform

# --- math ------------------------------------------------------------------

proc ortho(w, h: int32): array[16, float32] =
  ## Column-major projection from pixel space (top-left origin, y-down) to NDC.
  let fw = float32(max(w, 1))
  let fh = float32(max(h, 1))
  result = [2'f32 / fw, 0, 0, 0, 0, -2'f32 / fh, 0, 0, 0, 0, 1, 0, -1, 1, 0, 1]

# --- device / pipeline setup ----------------------------------------------

proc makeShader(
    device: ptr SDL_GPUDevice,
    src: string,
    entry: cstring,
    stage: SDL_GPUShaderStage,
    numSamplers, numUniforms: uint32,
    format: SDL_GPUShaderFormat,
): ptr SDL_GPUShader =
  var ci = SDL_GPUShaderCreateInfo(
    code_size: csize_t(src.len),
    code: cast[ptr Uint8](src.cstring),
    entrypoint: entry,
    format: format,
    stage: stage,
    num_samplers: numSamplers,
    num_uniform_buffers: numUniforms,
  )
  result = SDL_CreateGPUShader(device, addr ci)
  if result == nil:
    raise newException(CatchableError, "SDL_CreateGPUShader failed: " & $SDL_GetError())

proc blendState(mode: BlendMode): SDL_GPUColorTargetBlendState =
  case mode
  of bmNone:
    SDL_GPUColorTargetBlendState(enable_blend: false)
  of bmAlpha:
    SDL_GPUColorTargetBlendState(
      enable_blend: true,
      src_color_blendfactor: SDL_GPU_BLENDFACTOR_SRC_ALPHA,
      dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
      color_blend_op: SDL_GPU_BLENDOP_ADD,
      src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
      dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
      alpha_blend_op: SDL_GPU_BLENDOP_ADD,
    )
  of bmAdd:
    SDL_GPUColorTargetBlendState(
      enable_blend: true,
      src_color_blendfactor: SDL_GPU_BLENDFACTOR_SRC_ALPHA,
      dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
      color_blend_op: SDL_GPU_BLENDOP_ADD,
      src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
      dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
      alpha_blend_op: SDL_GPU_BLENDOP_ADD,
    )
  of bmMod:
    SDL_GPUColorTargetBlendState(
      enable_blend: true,
      src_color_blendfactor: SDL_GPU_BLENDFACTOR_DST_COLOR,
      dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ZERO,
      color_blend_op: SDL_GPU_BLENDOP_ADD,
      src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_DST_COLOR,
      dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ZERO,
      alpha_blend_op: SDL_GPU_BLENDOP_ADD,
    )

proc makePipeline(
    gpu: GpuContext,
    vs, fs: ptr SDL_GPUShader,
    blend: BlendMode,
    dsState = SDL_GPUDepthStencilState(),
    writeColor = true,
): ptr SDL_GPUGraphicsPipeline =
  var vbDesc = SDL_GPUVertexBufferDescription(
    slot: 0, pitch: Uint32(sizeof(Vertex)), input_rate: SDL_GPU_VERTEXINPUTRATE_VERTEX
  )
  var attrs = [
    SDL_GPUVertexAttribute(
      location: 0, buffer_slot: 0, format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, offset: 0
    ),
    SDL_GPUVertexAttribute(
      location: 1,
      buffer_slot: 0,
      format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
      offset: Uint32(2 * sizeof(float32)),
    ),
    SDL_GPUVertexAttribute(
      location: 2,
      buffer_slot: 0,
      format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
      offset: Uint32(4 * sizeof(float32)),
    ),
  ]
  var bs = blendState(blend)
  if not writeColor: # mask draws write stencil, not color
    bs.enable_color_write_mask = true
    bs.color_write_mask = SDL_GPUColorComponentFlags(0)
  var colorTarget = SDL_GPUColorTargetDescription(format: gpu.swFormat, blend_state: bs)
  var ti = SDL_GPUGraphicsPipelineTargetInfo(
    color_target_descriptions: addr colorTarget, num_color_targets: 1
  )
  if gpu.stencilEnabled: # passes carry a depth-stencil target
    ti.depth_stencil_format = gpu.depthFormat
    ti.has_depth_stencil_target = true
  var ci = SDL_GPUGraphicsPipelineCreateInfo(
    vertex_shader: vs,
    fragment_shader: fs,
    vertex_input_state: SDL_GPUVertexInputState(
      vertex_buffer_descriptions: addr vbDesc,
      num_vertex_buffers: 1,
      vertex_attributes: addr attrs[0],
      num_vertex_attributes: 3,
    ),
    primitive_type: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
    rasterizer_state: SDL_GPURasterizerState(
      fill_mode: SDL_GPU_FILLMODE_FILL,
      cull_mode: SDL_GPU_CULLMODE_NONE,
      front_face: SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
    ),
    multisample_state: SDL_GPUMultisampleState(sample_count: SDL_GPU_SAMPLECOUNT_1),
    depth_stencil_state: dsState,
    target_info: ti,
  )
  result = SDL_CreateGPUGraphicsPipeline(gpu.device, addr ci)
  if result == nil:
    raise newException(
      CatchableError, "SDL_CreateGPUGraphicsPipeline failed: " & $SDL_GetError()
    )

proc blobFor*(
    fmt: SDL_GPUShaderFormat, spv, msl, dxil: string
): (string, cstring) =
  ## (blob, entry point) for the active shader format, shared by the built-in and
  ## the user-shader pipelines. SPIR-V (Vulkan) and DXIL (Direct3D 12) keep the
  ## authored `main`; MSL (Metal) uses `main0`, since SPIRV-Cross renames `main`
  ## when it transpiles. The returned blob is empty when the caller passed no blob
  ## for this format, which the user-shader path treats as "skip the effect".
  if fmt == SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_SPIRV):
    (spv, "main".cstring)
  elif fmt == SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_DXIL):
    (dxil, "main".cstring)
  else:
    (msl, "main0".cstring)

proc buildPipelines(gpu: GpuContext) =
  let dev = gpu.device
  let (vsBlob, vsEntry) =
    blobFor(gpu.shaderFormat, VertexSPIRV, VertexMSL, VertexDXIL)
  let vs = makeShader(
    dev,
    vsBlob,
    vsEntry,
    SDL_GPU_SHADERSTAGE_VERTEX,
    0,
    1,
    gpu.shaderFormat,
  )
  let (fcBlob, fcEntry) =
    blobFor(gpu.shaderFormat, FragmentColorSPIRV, FragmentColorMSL, FragmentColorDXIL)
  let fsColor = makeShader(
    dev,
    fcBlob,
    fcEntry,
    SDL_GPU_SHADERSTAGE_FRAGMENT,
    0,
    0,
    gpu.shaderFormat,
  )
  let (ftBlob, ftEntry) = blobFor(
    gpu.shaderFormat, FragmentTextureSPIRV, FragmentTextureMSL, FragmentTextureDXIL
  )
  let fsTex = makeShader(
    dev,
    ftBlob,
    ftEntry,
    SDL_GPU_SHADERSTAGE_FRAGMENT,
    1,
    0,
    gpu.shaderFormat,
  )
  for blend in BlendMode:
    gpu.pipelines[pkColored][blend] = makePipeline(gpu, vs, fsColor, blend)
    gpu.pipelines[pkTextured][blend] = makePipeline(gpu, vs, fsTex, blend)
  if gpu.stencilEnabled:
    # A test pipeline draws only where the stencil already holds the mask value;
    # a write pipeline stamps that value, drawing into the stencil but not color.
    let testOp = SDL_GPUStencilOpState(
      compare_op: SDL_GPU_COMPAREOP_EQUAL,
      fail_op: SDL_GPU_STENCILOP_KEEP,
      pass_op: SDL_GPU_STENCILOP_KEEP,
      depth_fail_op: SDL_GPU_STENCILOP_KEEP,
    )
    let testState = SDL_GPUDepthStencilState(
      enable_stencil_test: true,
      compare_mask: 255'u8,
      write_mask: 0'u8,
      front_stencil_state: testOp,
      back_stencil_state: testOp,
    )
    let writeOp = SDL_GPUStencilOpState(
      compare_op: SDL_GPU_COMPAREOP_ALWAYS,
      fail_op: SDL_GPU_STENCILOP_KEEP,
      pass_op: SDL_GPU_STENCILOP_REPLACE,
      depth_fail_op: SDL_GPU_STENCILOP_KEEP,
    )
    let writeState = SDL_GPUDepthStencilState(
      enable_stencil_test: true,
      compare_mask: 255'u8,
      write_mask: 255'u8,
      front_stencil_state: writeOp,
      back_stencil_state: writeOp,
    )
    for blend in BlendMode:
      gpu.stencilTestPipes[pkColored][blend] =
        makePipeline(gpu, vs, fsColor, blend, testState)
      gpu.stencilTestPipes[pkTextured][blend] =
        makePipeline(gpu, vs, fsTex, blend, testState)
    gpu.stencilWritePipe =
      makePipeline(gpu, vs, fsColor, bmNone, writeState, writeColor = false)
  SDL_ReleaseGPUShader(dev, vs)
  SDL_ReleaseGPUShader(dev, fsColor)
  SDL_ReleaseGPUShader(dev, fsTex)

proc createShaderPipelines*(
    gpu: GpuContext,
    fragBlob: string,
    fragEntry: cstring,
    fragFormat: SDL_GPUShaderFormat,
    hasUniform: bool,
): array[BlendMode, ptr SDL_GPUGraphicsPipeline] =
  ## Build one pipeline per blend mode from a user fragment shader, reusing the
  ## built-in vertex shader. The fragment gets a sampler at slot 0 and, when
  ## hasUniform is set, a fragment uniform buffer at slot 0. The fragment's blob,
  ## entry point and format are passed in: MSL source uses entry "frag" (Metal
  ## only), while precompiled SPIR-V/MSL uses "main"/"main0" and runs everywhere.
  let dev = gpu.device
  let (vsBlob, vsEntry) =
    blobFor(gpu.shaderFormat, VertexSPIRV, VertexMSL, VertexDXIL)
  let vs = makeShader(
    dev,
    vsBlob,
    vsEntry,
    SDL_GPU_SHADERSTAGE_VERTEX,
    0,
    1,
    gpu.shaderFormat,
  )
  let fs = makeShader(
    dev,
    fragBlob,
    fragEntry,
    SDL_GPU_SHADERSTAGE_FRAGMENT,
    1,
    (if hasUniform: 1'u32 else: 0'u32),
    fragFormat,
  )
  for blend in BlendMode:
    result[blend] = makePipeline(gpu, vs, fs, blend)
  SDL_ReleaseGPUShader(dev, vs)
  SDL_ReleaseGPUShader(dev, fs)

proc createSampler(gpu: GpuContext) =
  var ci = SDL_GPUSamplerCreateInfo(
    min_filter: SDL_GPU_FILTER_LINEAR,
    mag_filter: SDL_GPU_FILTER_LINEAR,
    mipmap_mode: SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
    address_mode_u: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    address_mode_v: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    address_mode_w: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    max_lod: 1000.0,
  )
  gpu.sampler = SDL_CreateGPUSampler(gpu.device, addr ci)
  if gpu.sampler == nil:
    raise
      newException(CatchableError, "SDL_CreateGPUSampler failed: " & $SDL_GetError())

proc samplerFor*(gpu: GpuContext, filter: Filter, wrap: Wrap): ptr SDL_GPUSampler =
  ## The cached sampler for a filter/wrap combination, created on first use. The
  ## default (linear, clamp) reuses the context's default sampler.
  if filter == filLinear and wrap == wrapClamp:
    return gpu.sampler
  if gpu.samplers[filter][wrap] != nil:
    return gpu.samplers[filter][wrap]
  let f = (if filter == filNearest: SDL_GPU_FILTER_NEAREST else: SDL_GPU_FILTER_LINEAR)
  let mm = (
    if filter == filNearest: SDL_GPU_SAMPLERMIPMAPMODE_NEAREST
    else: SDL_GPU_SAMPLERMIPMAPMODE_LINEAR
  )
  let a =
    case wrap
    of wrapClamp: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE
    of wrapRepeat: SDL_GPU_SAMPLERADDRESSMODE_REPEAT
    of wrapMirror: SDL_GPU_SAMPLERADDRESSMODE_MIRRORED_REPEAT
  var ci = SDL_GPUSamplerCreateInfo(
    min_filter: f,
    mag_filter: f,
    mipmap_mode: mm,
    address_mode_u: a,
    address_mode_v: a,
    address_mode_w: a,
    max_lod: 1000.0,
  )
  result = SDL_CreateGPUSampler(gpu.device, addr ci)
  if result == nil:
    raise
      newException(CatchableError, "SDL_CreateGPUSampler failed: " & $SDL_GetError())
  gpu.samplers[filter][wrap] = result

proc createTextureFromPixels*(
  gpu: GpuContext, pixels: pointer, w, h, pitch: int, mipmaps = false
): ptr SDL_GPUTexture

proc createRenderTarget*(gpu: GpuContext, w, h: int32): ptr SDL_GPUTexture
proc createDepthTarget*(gpu: GpuContext, w, h: int32): ptr SDL_GPUTexture

proc newGpuContext*(
    window: ptr SDL_Window, aa: int32 = 1, stencil = false
): GpuContext =
  result = GpuContext(window: window, ssFactor: max(1'i32, aa), stencilEnabled: stencil)
  # Accept any of the three shader formats and let SDL choose a backend: Metal
  # with MSL on Apple platforms, Vulkan with SPIR-V on Linux, and Direct3D 12 with
  # DXIL or Vulkan with SPIR-V on Windows.
  let want = SDL_GPUShaderFormat(
    uint32(SDL_GPU_SHADERFORMAT_MSL) or uint32(SDL_GPU_SHADERFORMAT_SPIRV) or
    uint32(SDL_GPU_SHADERFORMAT_DXIL)
  )
  result.device = SDL_CreateGPUDevice(want, false, nil)
  if result.device == nil:
    raise newException(CatchableError, "SDL_CreateGPUDevice failed: " & $SDL_GetError())
  # Publish the live device so device-bound destructors know it is safe to
  # release GPU handles. Cleared in destroy().
  gpuLiveDevice = result.device
  # Record which format the chosen backend actually takes, to pick the shader
  # blob. A Vulkan device reports SPIR-V, a D3D12 device reports DXIL, and a Metal
  # device reports MSL, so this matches the backend SDL selected.
  let got = uint32(SDL_GetGPUShaderFormats(result.device))
  if (got and uint32(SDL_GPU_SHADERFORMAT_SPIRV)) != 0:
    result.shaderFormat = SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_SPIRV)
  elif (got and uint32(SDL_GPU_SHADERFORMAT_DXIL)) != 0:
    result.shaderFormat = SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_DXIL)
  else:
    result.shaderFormat = SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_MSL)
  if not SDL_ClaimWindowForGPUDevice(result.device, window):
    raise
      newException(CatchableError, "ClaimWindowForGPUDevice failed: " & $SDL_GetError())
  result.swFormat = SDL_GetGPUSwapchainTextureFormat(result.device, window)
  if stencil:
    let d24 = SDL_GPU_TEXTUREFORMAT_D24_UNORM_S8_UINT
    let dsUsage = SDL_GPUTextureUsageFlags(SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET)
    if SDL_GPUTextureSupportsFormat(result.device, d24, SDL_GPU_TEXTURETYPE_2D, dsUsage):
      result.depthFormat = d24
    else:
      result.depthFormat = SDL_GPU_TEXTUREFORMAT_D32_FLOAT_S8_UINT
  result.createSampler()
  result.buildPipelines()
  var white = [255'u8, 255'u8, 255'u8, 255'u8]
  result.whiteTex = result.createTextureFromPixels(addr white[0], 1, 1, 4)

# --- GPU buffer management -------------------------------------------------

proc ensureVbuf(gpu: GpuContext, n: int) =
  if n <= gpu.vbufCap:
    return
  if gpu.vbuf != nil:
    SDL_ReleaseGPUBuffer(gpu.device, gpu.vbuf)
  var cap = max(n, 4096)
  var ci = SDL_GPUBufferCreateInfo(
    usage: SDL_GPUBufferUsageFlags(SDL_GPU_BUFFERUSAGE_VERTEX),
    size: Uint32(cap * sizeof(Vertex)),
  )
  gpu.vbuf = SDL_CreateGPUBuffer(gpu.device, addr ci)
  gpu.vbufCap = cap

proc ensureIbuf(gpu: GpuContext, n: int) =
  if n <= gpu.ibufCap:
    return
  if gpu.ibuf != nil:
    SDL_ReleaseGPUBuffer(gpu.device, gpu.ibuf)
  var cap = max(n, 8192)
  var ci = SDL_GPUBufferCreateInfo(
    usage: SDL_GPUBufferUsageFlags(SDL_GPU_BUFFERUSAGE_INDEX),
    size: Uint32(cap * sizeof(uint32)),
  )
  gpu.ibuf = SDL_CreateGPUBuffer(gpu.device, addr ci)
  gpu.ibufCap = cap

proc ensureTransfer(gpu: GpuContext, bytes: int) =
  if bytes <= gpu.transferCap:
    return
  if gpu.transferBuf != nil:
    SDL_ReleaseGPUTransferBuffer(gpu.device, gpu.transferBuf)
  var cap = max(bytes, 65536)
  var ci = SDL_GPUTransferBufferCreateInfo(
    usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, size: Uint32(cap)
  )
  gpu.transferBuf = SDL_CreateGPUTransferBuffer(gpu.device, addr ci)
  gpu.transferCap = cap

# --- frame / pass recording ------------------------------------------------

proc startPass(
    gpu: GpuContext,
    target: ptr SDL_GPUTexture,
    w, h: int32,
    doClear: bool,
    clearColor: Color,
    depth: ptr SDL_GPUTexture = nil,
) =
  gpu.passes.add RenderPassRec(
    target: target,
    depth: depth,
    w: w,
    h: h,
    doClear: doClear,
    clearColor: clearColor,
    projection: ortho(w, h),
    cmds: @[],
  )

proc beginFrame*(gpu: GpuContext, background: Color, width, height: var int32): bool =
  ## Acquire the command buffer and swapchain texture and start the screen pass.
  ## The swapchain's real size is reported back through `width` and `height`, so
  ## the projection and scissor follow the actual framebuffer. A resized or
  ## fullscreen window then draws at its true pixel size instead of being
  ## stretched into the corner.
  gpu.vertices.setLen(0)
  gpu.indices.setLen(0)
  gpu.passes.setLen(0)
  gpu.transform = identity()
  gpu.transformStack.setLen(0)
  gpu.curScissor = Scissor(on: false)
  gpu.curShader = nil
  gpu.stencilMode = 0
  gpu.cmd = SDL_AcquireGPUCommandBuffer(gpu.device)
  if gpu.cmd == nil:
    return false
  var w, h: Uint32
  if not SDL_WaitAndAcquireGPUSwapchainTexture(
    gpu.cmd, gpu.window, addr gpu.swTex, addr w, addr h
  ):
    return false
  if gpu.swTex == nil:
    # Window minimized / no swapchain image this frame.
    discard SDL_SubmitGPUCommandBuffer(gpu.cmd)
    gpu.cmd = nil
    return false
  width = int32(w)
  height = int32(h)
  gpu.frameW = width
  gpu.frameH = height
  # The swapchain depth target is needed for the screen pass and the downscale
  # blit, so ensure it whenever stencil is on, before splitting on supersampling.
  if gpu.stencilEnabled and
      (
        gpu.screenDepth == nil or gpu.screenDepthW != width or gpu.screenDepthH != height
      ):
    if gpu.screenDepth != nil:
      SDL_ReleaseGPUTexture(gpu.device, gpu.screenDepth)
    gpu.screenDepth = gpu.createDepthTarget(width, height)
    gpu.screenDepthW = width
    gpu.screenDepthH = height
  if gpu.ssFactor > 1:
    # Render the frame into a higher-resolution target, then downscale it to the
    # swapchain in endFrame. The projection stays at the logical size, so drawing
    # is unchanged; only the target is bigger. This anti-aliases everything.
    let sw = width * gpu.ssFactor
    let sh = height * gpu.ssFactor
    if gpu.ssTex == nil or gpu.ssW != sw or gpu.ssH != sh:
      if gpu.ssTex != nil:
        SDL_ReleaseGPUTexture(gpu.device, gpu.ssTex)
      gpu.ssTex = gpu.createRenderTarget(sw, sh)
      if gpu.stencilEnabled:
        if gpu.ssDepth != nil:
          SDL_ReleaseGPUTexture(gpu.device, gpu.ssDepth)
        gpu.ssDepth = gpu.createDepthTarget(sw, sh)
      gpu.ssW = sw
      gpu.ssH = sh
    startPass(gpu, gpu.ssTex, width, height, true, background, gpu.ssDepth)
  else:
    startPass(gpu, gpu.swTex, width, height, true, background, gpu.screenDepth)
  return true

proc addGeometry*(
    gpu: GpuContext,
    kind: PipelineKind,
    blend: BlendMode,
    texture: ptr SDL_GPUTexture,
    verts: openArray[Vertex],
    idx: openArray[uint32],
    sampler: ptr SDL_GPUSampler = nil,
) =
  ## Append geometry to the current pass, extending the last draw command when
  ## pipeline/blend/texture match (so consecutive same-state draws batch).
  if verts.len == 0 or idx.len == 0:
    return
  let base = uint32(gpu.vertices.len)
  for v in verts:
    var vv = v
    let (nx, ny) = gpu.transform.apply(v.x.float, v.y.float)
    vv.x = nx.float32
    vv.y = ny.float32
    gpu.vertices.add vv
  let first = uint32(gpu.indices.len)
  for i in idx:
    gpu.indices.add base + i

  template pass(): untyped =
    gpu.passes[^1]

  let n = pass.cmds.len
  if n > 0 and pass.cmds[n - 1].kind == kind and pass.cmds[n - 1].blend == blend and
      pass.cmds[n - 1].texture == texture and pass.cmds[n - 1].sampler == sampler and
      pass.cmds[n - 1].shader == gpu.curShader and
      pass.cmds[n - 1].scissor == gpu.curScissor and
      pass.cmds[n - 1].stencil == gpu.stencilMode:
    pass.cmds[n - 1].indexCount += uint32(idx.len)
  else:
    pass.cmds.add DrawCmd(
      kind: kind,
      blend: blend,
      texture: texture,
      sampler: sampler,
      shader: gpu.curShader,
      scissor: gpu.curScissor,
      stencil: gpu.stencilMode,
      firstIndex: first,
      indexCount: uint32(idx.len),
    )

proc setTarget*(
    gpu: GpuContext,
    target: ptr SDL_GPUTexture,
    w, h: int32,
    depth: ptr SDL_GPUTexture = nil,
) =
  ## Switch the render target (canvas vs screen); preserves existing contents.
  startPass(gpu, target, w, h, false, (0'u8, 0'u8, 0'u8, 255'u8), depth)

proc clearTarget*(
    gpu: GpuContext,
    target: ptr SDL_GPUTexture,
    w, h: int32,
    color: Color,
    depth: ptr SDL_GPUTexture = nil,
) =
  ## Clear the current target by beginning a fresh clearing pass on it.
  startPass(gpu, target, w, h, true, color, depth)

proc endFrame*(gpu: GpuContext) =
  ## Upload all geometry, then replay every recorded pass, then submit.
  if gpu.cmd == nil:
    return

  if gpu.ssFactor > 1 and gpu.ssTex != nil:
    # Downscale the high-res target onto the swapchain with linear filtering.
    gpu.transform = identity()
    gpu.curShader = nil
    gpu.curScissor = Scissor(on: false)
    startPass(
      gpu,
      gpu.swTex,
      gpu.frameW,
      gpu.frameH,
      true,
      (0'u8, 0'u8, 0'u8, 255'u8),
      gpu.screenDepth,
    )
    let w = gpu.frameW.float32
    let h = gpu.frameH.float32
    let verts = [
      Vertex(x: 0'f32, y: 0'f32, u: 0'f32, v: 0'f32, r: 1, g: 1, b: 1, a: 1),
      Vertex(x: w, y: 0'f32, u: 1'f32, v: 0'f32, r: 1, g: 1, b: 1, a: 1),
      Vertex(x: w, y: h, u: 1'f32, v: 1'f32, r: 1, g: 1, b: 1, a: 1),
      Vertex(x: 0'f32, y: h, u: 0'f32, v: 1'f32, r: 1, g: 1, b: 1, a: 1),
    ]
    gpu.addGeometry(
      pkTextured, bmNone, gpu.ssTex, verts, [0'u32, 1, 2, 0, 2, 3], gpu.sampler
    )

  if gpu.vertices.len > 0:
    ensureVbuf(gpu, gpu.vertices.len)
    ensureIbuf(gpu, gpu.indices.len)
    let vBytes = gpu.vertices.len * sizeof(Vertex)
    let iBytes = gpu.indices.len * sizeof(uint32)
    ensureTransfer(gpu, vBytes + iBytes)
    let mapped = cast[ptr UncheckedArray[byte]](SDL_MapGPUTransferBuffer(
      gpu.device, gpu.transferBuf, true
    ))
    copyMem(addr mapped[0], addr gpu.vertices[0], vBytes)
    copyMem(addr mapped[vBytes], addr gpu.indices[0], iBytes)
    SDL_UnmapGPUTransferBuffer(gpu.device, gpu.transferBuf)

    let cp = SDL_BeginGPUCopyPass(gpu.cmd)
    var vsrc =
      SDL_GPUTransferBufferLocation(transfer_buffer: gpu.transferBuf, offset: 0)
    var vdst = SDL_GPUBufferRegion(buffer: gpu.vbuf, offset: 0, size: Uint32(vBytes))
    SDL_UploadToGPUBuffer(cp, addr vsrc, addr vdst, true)
    var isrc = SDL_GPUTransferBufferLocation(
      transfer_buffer: gpu.transferBuf, offset: Uint32(vBytes)
    )
    var idst = SDL_GPUBufferRegion(buffer: gpu.ibuf, offset: 0, size: Uint32(iBytes))
    SDL_UploadToGPUBuffer(cp, addr isrc, addr idst, true)
    SDL_EndGPUCopyPass(cp)

  for p in gpu.passes.mitems:
    var cti = SDL_GPUColorTargetInfo(
      texture: p.target,
      clear_color: (
        if p.doClear:
          SDL_FColor(
            r: p.clearColor.r.float32 / 255,
            g: p.clearColor.g.float32 / 255,
            b: p.clearColor.b.float32 / 255,
            a: p.clearColor.a.float32 / 255,
          )
        else: SDL_FColor()
      ),
      load_op: (if p.doClear: SDL_GPU_LOADOP_CLEAR else: SDL_GPU_LOADOP_LOAD),
      store_op: SDL_GPU_STOREOP_STORE,
    )
    var dsti = SDL_GPUDepthStencilTargetInfo(
      texture: p.depth,
      clear_stencil: 0,
      load_op: SDL_GPU_LOADOP_DONT_CARE,
      store_op: SDL_GPU_STOREOP_DONT_CARE,
      stencil_load_op: SDL_GPU_LOADOP_CLEAR,
      stencil_store_op: SDL_GPU_STOREOP_DONT_CARE,
    )
    let rp = SDL_BeginGPURenderPass(
      gpu.cmd, addr cti, 1, (if p.depth != nil: addr dsti else: nil)
    )
    SDL_PushGPUVertexUniformData(
      gpu.cmd, 0, addr p.projection[0], Uint32(sizeof(p.projection))
    )
    var vbind = SDL_GPUBufferBinding(buffer: gpu.vbuf, offset: 0)
    var ibind = SDL_GPUBufferBinding(buffer: gpu.ibuf, offset: 0)
    if gpu.vbuf != nil:
      SDL_BindGPUVertexBuffers(rp, 0, addr vbind, 1)
      SDL_BindGPUIndexBuffer(rp, addr ibind, SDL_GPU_INDEXELEMENTSIZE_32BIT)
    for c in p.cmds:
      if c.shader != nil:
        SDL_BindGPUGraphicsPipeline(rp, c.shader.pipelines[c.blend])
        if c.shader.hasUniform and c.shader.uniform.len > 0:
          SDL_PushGPUFragmentUniformData(
            gpu.cmd, 0, addr c.shader.uniform[0], Uint32(c.shader.uniform.len)
          )
        # Shader pipelines always take a sampler; use a white texture if none.
        let tex = if c.texture != nil: c.texture else: gpu.whiteTex
        let smp = if c.sampler != nil: c.sampler else: gpu.sampler
        var tsb = SDL_GPUTextureSamplerBinding(texture: tex, sampler: smp)
        SDL_BindGPUFragmentSamplers(rp, 0, addr tsb, 1)
      else:
        let pipe =
          if c.stencil == 1:
            gpu.stencilWritePipe
          elif c.stencil == 2:
            gpu.stencilTestPipes[c.kind][c.blend]
          else:
            gpu.pipelines[c.kind][c.blend]
        SDL_BindGPUGraphicsPipeline(rp, pipe)
        if c.stencil != 0:
          SDL_SetGPUStencilReference(rp, 1)
        if c.kind == pkTextured and c.texture != nil and c.stencil != 1:
          let smp = if c.sampler != nil: c.sampler else: gpu.sampler
          var tsb = SDL_GPUTextureSamplerBinding(texture: c.texture, sampler: smp)
          SDL_BindGPUFragmentSamplers(rp, 0, addr tsb, 1)
      if c.scissor.on:
        var sr = SDL_Rect(
          x: c.scissor.x.cint,
          y: c.scissor.y.cint,
          w: c.scissor.w.cint,
          h: c.scissor.h.cint,
        )
        SDL_SetGPUScissor(rp, addr sr)
      else:
        var sr = SDL_Rect(x: 0, y: 0, w: p.w.cint, h: p.h.cint)
        SDL_SetGPUScissor(rp, addr sr)
      SDL_DrawGPUIndexedPrimitives(rp, c.indexCount, 1, c.firstIndex, 0, 0)
    SDL_EndGPURenderPass(rp)

  discard SDL_SubmitGPUCommandBuffer(gpu.cmd)
  gpu.cmd = nil

  # Release transient textures such as rasterized text. SDL_GPU defers the actual
  # free until the GPU is done with them, so this is safe right after submit.
  for t in gpu.tempTextures:
    SDL_ReleaseGPUTexture(gpu.device, t)
  gpu.tempTextures.setLen(0)

proc addTempTexture*(gpu: GpuContext, tex: ptr SDL_GPUTexture) =
  gpu.tempTextures.add tex

proc createTextureFromPixels*(
    gpu: GpuContext, pixels: pointer, w, h, pitch: int, mipmaps = false
): ptr SDL_GPUTexture =
  ## Upload tightly-packed RGBA8 pixel data (handling source row pitch) into a
  ## new sampled GPU texture, via a one-off command buffer + copy pass. With
  ## mipmaps it allocates the full mip chain and generates it after the upload.
  var levels = 1'u32
  var usage = uint32(SDL_GPU_TEXTUREUSAGE_SAMPLER)
  if mipmaps:
    var d = max(w, h)
    while d > 1:
      d = d div 2
      inc levels
    usage = usage or uint32(SDL_GPU_TEXTUREUSAGE_COLOR_TARGET) # required to generate
  var tci = SDL_GPUTextureCreateInfo(
    type_field: SDL_GPU_TEXTURETYPE_2D,
    format: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
    usage: SDL_GPUTextureUsageFlags(usage),
    width: Uint32(w),
    height: Uint32(h),
    layer_count_or_depth: 1,
    num_levels: levels,
    sample_count: SDL_GPU_SAMPLECOUNT_1,
  )
  result = SDL_CreateGPUTexture(gpu.device, addr tci)
  if result == nil:
    raise
      newException(CatchableError, "SDL_CreateGPUTexture failed: " & $SDL_GetError())

  let bytes = w * h * 4
  var tbci = SDL_GPUTransferBufferCreateInfo(
    usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, size: Uint32(bytes)
  )
  let tb = SDL_CreateGPUTransferBuffer(gpu.device, addr tbci)
  let dst =
    cast[ptr UncheckedArray[byte]](SDL_MapGPUTransferBuffer(gpu.device, tb, false))
  let src = cast[ptr UncheckedArray[byte]](pixels)
  for row in 0 ..< h:
    copyMem(addr dst[row * w * 4], addr src[row * pitch], w * 4)
  SDL_UnmapGPUTransferBuffer(gpu.device, tb)

  let cmd = SDL_AcquireGPUCommandBuffer(gpu.device)
  let cp = SDL_BeginGPUCopyPass(cmd)
  var srcInfo = SDL_GPUTextureTransferInfo(
    transfer_buffer: tb, offset: 0, pixels_per_row: Uint32(w), rows_per_layer: Uint32(h)
  )
  var region = SDL_GPUTextureRegion(
    texture: result,
    mip_level: 0,
    layer: 0,
    x: 0,
    y: 0,
    z: 0,
    w: Uint32(w),
    h: Uint32(h),
    d: 1,
  )
  SDL_UploadToGPUTexture(cp, addr srcInfo, addr region, false)
  SDL_EndGPUCopyPass(cp)
  if mipmaps:
    SDL_GenerateMipmapsForGPUTexture(cmd, result)
  discard SDL_SubmitGPUCommandBuffer(cmd)
  SDL_ReleaseGPUTransferBuffer(gpu.device, tb)

proc downloadTexture*(
    gpu: GpuContext, tex: ptr SDL_GPUTexture, w, h: int32
): seq[uint8] =
  ## Read a texture's pixels back from the GPU as tightly packed RGBA8 bytes.
  ## Waits for all submitted GPU work first, so the bytes reflect the last
  ## completed frame. Render targets use the swapchain format, which can be
  ## BGRA, so the channels are reordered to RGBA when needed.
  let bytes = w.int * h.int * 4
  result = newSeq[uint8](bytes)
  if bytes == 0:
    return
  discard SDL_WaitForGPUIdle(gpu.device)
  var tbci = SDL_GPUTransferBufferCreateInfo(
    usage: SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD, size: Uint32(bytes)
  )
  let tb = SDL_CreateGPUTransferBuffer(gpu.device, addr tbci)
  if tb == nil:
    raise newException(
      CatchableError, "SDL_CreateGPUTransferBuffer failed: " & $SDL_GetError()
    )
  let cmd = SDL_AcquireGPUCommandBuffer(gpu.device)
  let cp = SDL_BeginGPUCopyPass(cmd)
  var region = SDL_GPUTextureRegion(
    texture: tex,
    mip_level: 0,
    layer: 0,
    x: 0,
    y: 0,
    z: 0,
    w: Uint32(w),
    h: Uint32(h),
    d: 1,
  )
  var dst = SDL_GPUTextureTransferInfo(
    transfer_buffer: tb, offset: 0, pixels_per_row: Uint32(w), rows_per_layer: Uint32(h)
  )
  SDL_DownloadFromGPUTexture(cp, addr region, addr dst)
  SDL_EndGPUCopyPass(cp)
  var fence = SDL_SubmitGPUCommandBufferAndAcquireFence(cmd)
  if fence != nil:
    discard SDL_WaitForGPUFences(gpu.device, true, addr fence, 1)
    SDL_ReleaseGPUFence(gpu.device, fence)
  let src =
    cast[ptr UncheckedArray[byte]](SDL_MapGPUTransferBuffer(gpu.device, tb, false))
  copyMem(addr result[0], addr src[0], bytes)
  SDL_UnmapGPUTransferBuffer(gpu.device, tb)
  SDL_ReleaseGPUTransferBuffer(gpu.device, tb)
  if gpu.swFormat == SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM or
      gpu.swFormat == SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM_SRGB:
    var i = 0
    while i < bytes:
      swap(result[i], result[i + 2])
      i += 4

proc createRenderTarget*(gpu: GpuContext, w, h: int32): ptr SDL_GPUTexture =
  ## A texture usable both as a color target (canvas) and as a sampled texture.
  ## Must use the swapchain format so the built-in pipelines can target it.
  var tci = SDL_GPUTextureCreateInfo(
    type_field: SDL_GPU_TEXTURETYPE_2D,
    format: gpu.swFormat,
    usage: SDL_GPUTextureUsageFlags(
      SDL_GPU_TEXTUREUSAGE_SAMPLER or SDL_GPU_TEXTUREUSAGE_COLOR_TARGET
    ),
    width: Uint32(w),
    height: Uint32(h),
    layer_count_or_depth: 1,
    num_levels: 1,
    sample_count: SDL_GPU_SAMPLECOUNT_1,
  )
  result = SDL_CreateGPUTexture(gpu.device, addr tci)
  if result == nil:
    raise newException(
      CatchableError, "SDL_CreateGPUTexture (target) failed: " & $SDL_GetError()
    )

proc createDepthTarget*(gpu: GpuContext, w, h: int32): ptr SDL_GPUTexture =
  ## A depth-stencil target matching a color target's size, for stencil masking.
  var tci = SDL_GPUTextureCreateInfo(
    type_field: SDL_GPU_TEXTURETYPE_2D,
    format: gpu.depthFormat,
    usage: SDL_GPUTextureUsageFlags(SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET),
    width: Uint32(w),
    height: Uint32(h),
    layer_count_or_depth: 1,
    num_levels: 1,
    sample_count: SDL_GPU_SAMPLECOUNT_1,
  )
  result = SDL_CreateGPUTexture(gpu.device, addr tci)
  if result == nil:
    raise newException(
      CatchableError, "SDL_CreateGPUTexture (depth) failed: " & $SDL_GetError()
    )

proc destroy*(gpu: GpuContext) =
  let dev = gpu.device
  # Mark the device gone before tearing it down, so any resource destructor that
  # runs afterward (during ORC's exit teardown, in unspecified order) is a no-op
  # rather than releasing handles against a freed device.
  gpuLiveDevice = nil
  for kind in PipelineKind:
    for blend in BlendMode:
      if gpu.pipelines[kind][blend] != nil:
        SDL_ReleaseGPUGraphicsPipeline(dev, gpu.pipelines[kind][blend])
  if gpu.sampler != nil:
    SDL_ReleaseGPUSampler(dev, gpu.sampler)
  for fr in gpu.samplers:
    for s in fr:
      if s != nil:
        SDL_ReleaseGPUSampler(dev, s)
  if gpu.ssTex != nil:
    SDL_ReleaseGPUTexture(dev, gpu.ssTex)
  if gpu.screenDepth != nil:
    SDL_ReleaseGPUTexture(dev, gpu.screenDepth)
  if gpu.ssDepth != nil:
    SDL_ReleaseGPUTexture(dev, gpu.ssDepth)
  if gpu.stencilWritePipe != nil:
    SDL_ReleaseGPUGraphicsPipeline(dev, gpu.stencilWritePipe)
  for kind in PipelineKind:
    for blend in BlendMode:
      if gpu.stencilTestPipes[kind][blend] != nil:
        SDL_ReleaseGPUGraphicsPipeline(dev, gpu.stencilTestPipes[kind][blend])
  if gpu.vbuf != nil:
    SDL_ReleaseGPUBuffer(dev, gpu.vbuf)
  if gpu.ibuf != nil:
    SDL_ReleaseGPUBuffer(dev, gpu.ibuf)
  if gpu.transferBuf != nil:
    SDL_ReleaseGPUTransferBuffer(dev, gpu.transferBuf)
  SDL_ReleaseWindowFromGPUDevice(dev, gpu.window)
  SDL_DestroyGPUDevice(dev)
