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

# --- math ------------------------------------------------------------------

proc ortho(w, h: int32): array[16, float32] =
  ## Column-major projection from pixel space (top-left origin, y-down) to NDC.
  let fw = float32(max(w, 1))
  let fh = float32(max(h, 1))
  result = [
    2'f32 / fw, 0, 0, 0,
    0, -2'f32 / fh, 0, 0,
    0, 0, 1, 0,
    -1, 1, 0, 1,
  ]

# --- device / pipeline setup ----------------------------------------------

proc makeShader(device: ptr SDL_GPUDevice, src: string, entry: cstring,
                stage: SDL_GPUShaderStage, numSamplers, numUniforms: uint32):
                ptr SDL_GPUShader =
  var ci = SDL_GPUShaderCreateInfo(
    code_size: csize_t(src.len),
    code: cast[ptr Uint8](src.cstring),
    entrypoint: entry,
    format: SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_MSL),
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
      alpha_blend_op: SDL_GPU_BLENDOP_ADD)
  of bmAdd:
    SDL_GPUColorTargetBlendState(
      enable_blend: true,
      src_color_blendfactor: SDL_GPU_BLENDFACTOR_SRC_ALPHA,
      dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
      color_blend_op: SDL_GPU_BLENDOP_ADD,
      src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
      dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
      alpha_blend_op: SDL_GPU_BLENDOP_ADD)
  of bmMod:
    SDL_GPUColorTargetBlendState(
      enable_blend: true,
      src_color_blendfactor: SDL_GPU_BLENDFACTOR_DST_COLOR,
      dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ZERO,
      color_blend_op: SDL_GPU_BLENDOP_ADD,
      src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_DST_COLOR,
      dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ZERO,
      alpha_blend_op: SDL_GPU_BLENDOP_ADD)

proc buildPipelines(gpu: GpuContext) =
  let dev = gpu.device
  let vs = makeShader(dev, VertexShaderMSL, "vertexMain",
                      SDL_GPU_SHADERSTAGE_VERTEX, 0, 1)
  let fsColor = makeShader(dev, FragmentColorMSL, "fragmentColor",
                           SDL_GPU_SHADERSTAGE_FRAGMENT, 0, 0)
  let fsTex = makeShader(dev, FragmentTextureMSL, "fragmentTexture",
                         SDL_GPU_SHADERSTAGE_FRAGMENT, 1, 0)

  var vbDesc = SDL_GPUVertexBufferDescription(
    slot: 0, pitch: Uint32(sizeof(Vertex)),
    input_rate: SDL_GPU_VERTEXINPUTRATE_VERTEX)
  var attrs = [
    SDL_GPUVertexAttribute(location: 0, buffer_slot: 0,
      format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, offset: 0),
    SDL_GPUVertexAttribute(location: 1, buffer_slot: 0,
      format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, offset: Uint32(2 * sizeof(float32))),
    SDL_GPUVertexAttribute(location: 2, buffer_slot: 0,
      format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, offset: Uint32(4 * sizeof(float32))),
  ]
  let swFormat = SDL_GetGPUSwapchainTextureFormat(dev, gpu.window)

  for kind in PipelineKind:
    for blend in BlendMode:
      var colorTarget = SDL_GPUColorTargetDescription(
        format: swFormat, blend_state: blendState(blend))
      var ci = SDL_GPUGraphicsPipelineCreateInfo(
        vertex_shader: vs,
        fragment_shader: (if kind == pkColored: fsColor else: fsTex),
        vertex_input_state: SDL_GPUVertexInputState(
          vertex_buffer_descriptions: addr vbDesc, num_vertex_buffers: 1,
          vertex_attributes: addr attrs[0], num_vertex_attributes: 3),
        primitive_type: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        rasterizer_state: SDL_GPURasterizerState(
          fill_mode: SDL_GPU_FILLMODE_FILL, cull_mode: SDL_GPU_CULLMODE_NONE,
          front_face: SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE),
        multisample_state: SDL_GPUMultisampleState(sample_count: SDL_GPU_SAMPLECOUNT_1),
        target_info: SDL_GPUGraphicsPipelineTargetInfo(
          color_target_descriptions: addr colorTarget, num_color_targets: 1))
      let p = SDL_CreateGPUGraphicsPipeline(dev, addr ci)
      if p == nil:
        raise newException(CatchableError,
          "SDL_CreateGPUGraphicsPipeline failed: " & $SDL_GetError())
      gpu.pipelines[kind][blend] = p

  SDL_ReleaseGPUShader(dev, vs)
  SDL_ReleaseGPUShader(dev, fsColor)
  SDL_ReleaseGPUShader(dev, fsTex)

proc createSampler(gpu: GpuContext) =
  var ci = SDL_GPUSamplerCreateInfo(
    min_filter: SDL_GPU_FILTER_LINEAR,
    mag_filter: SDL_GPU_FILTER_LINEAR,
    mipmap_mode: SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
    address_mode_u: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    address_mode_v: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    address_mode_w: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE)
  gpu.sampler = SDL_CreateGPUSampler(gpu.device, addr ci)
  if gpu.sampler == nil:
    raise newException(CatchableError, "SDL_CreateGPUSampler failed: " & $SDL_GetError())

proc newGpuContext*(window: ptr SDL_Window): GpuContext =
  result = GpuContext(window: window)
  # Requests MSL shaders (the Metal backend).
  result.device = SDL_CreateGPUDevice(
    SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_MSL), false, nil)
  if result.device == nil:
    raise newException(CatchableError, "SDL_CreateGPUDevice failed: " & $SDL_GetError())
  if not SDL_ClaimWindowForGPUDevice(result.device, window):
    raise newException(CatchableError, "ClaimWindowForGPUDevice failed: " & $SDL_GetError())
  result.swFormat = SDL_GetGPUSwapchainTextureFormat(result.device, window)
  result.createSampler()
  result.buildPipelines()

# --- GPU buffer management -------------------------------------------------

proc ensureVbuf(gpu: GpuContext, n: int) =
  if n <= gpu.vbufCap: return
  if gpu.vbuf != nil: SDL_ReleaseGPUBuffer(gpu.device, gpu.vbuf)
  var cap = max(n, 4096)
  var ci = SDL_GPUBufferCreateInfo(
    usage: SDL_GPUBufferUsageFlags(SDL_GPU_BUFFERUSAGE_VERTEX),
    size: Uint32(cap * sizeof(Vertex)))
  gpu.vbuf = SDL_CreateGPUBuffer(gpu.device, addr ci)
  gpu.vbufCap = cap

proc ensureIbuf(gpu: GpuContext, n: int) =
  if n <= gpu.ibufCap: return
  if gpu.ibuf != nil: SDL_ReleaseGPUBuffer(gpu.device, gpu.ibuf)
  var cap = max(n, 8192)
  var ci = SDL_GPUBufferCreateInfo(
    usage: SDL_GPUBufferUsageFlags(SDL_GPU_BUFFERUSAGE_INDEX),
    size: Uint32(cap * sizeof(uint32)))
  gpu.ibuf = SDL_CreateGPUBuffer(gpu.device, addr ci)
  gpu.ibufCap = cap

proc ensureTransfer(gpu: GpuContext, bytes: int) =
  if bytes <= gpu.transferCap: return
  if gpu.transferBuf != nil: SDL_ReleaseGPUTransferBuffer(gpu.device, gpu.transferBuf)
  var cap = max(bytes, 65536)
  var ci = SDL_GPUTransferBufferCreateInfo(
    usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, size: Uint32(cap))
  gpu.transferBuf = SDL_CreateGPUTransferBuffer(gpu.device, addr ci)
  gpu.transferCap = cap

# --- frame / pass recording ------------------------------------------------

proc startPass(gpu: GpuContext, target: ptr SDL_GPUTexture, w, h: int32,
               doClear: bool, clearColor: Color) =
  gpu.passes.add RenderPassRec(
    target: target, w: w, h: h, doClear: doClear, clearColor: clearColor,
    projection: ortho(w, h), cmds: @[])

proc beginFrame*(gpu: GpuContext, winW, winH: int32, background: Color): bool =
  ## Acquire the command buffer + swapchain texture and start the screen pass.
  gpu.vertices.setLen(0)
  gpu.indices.setLen(0)
  gpu.passes.setLen(0)
  gpu.cmd = SDL_AcquireGPUCommandBuffer(gpu.device)
  if gpu.cmd == nil: return false
  var w, h: Uint32
  if not SDL_WaitAndAcquireGPUSwapchainTexture(gpu.cmd, gpu.window, addr gpu.swTex,
                                               addr w, addr h):
    return false
  if gpu.swTex == nil:
    # Window minimized / no swapchain image this frame.
    discard SDL_SubmitGPUCommandBuffer(gpu.cmd)
    gpu.cmd = nil
    return false
  startPass(gpu, gpu.swTex, winW, winH, true, background)
  return true

proc addGeometry*(gpu: GpuContext, kind: PipelineKind, blend: BlendMode,
                  texture: ptr SDL_GPUTexture,
                  verts: openArray[Vertex], idx: openArray[uint32]) =
  ## Append geometry to the current pass, extending the last draw command when
  ## pipeline/blend/texture match (so consecutive same-state draws batch).
  if verts.len == 0 or idx.len == 0: return
  let base = uint32(gpu.vertices.len)
  for v in verts: gpu.vertices.add v
  let first = uint32(gpu.indices.len)
  for i in idx: gpu.indices.add base + i

  template pass: untyped = gpu.passes[^1]
  let n = pass.cmds.len
  if n > 0 and pass.cmds[n-1].kind == kind and pass.cmds[n-1].blend == blend and
     pass.cmds[n-1].texture == texture:
    pass.cmds[n-1].indexCount += uint32(idx.len)
  else:
    pass.cmds.add DrawCmd(kind: kind, blend: blend, texture: texture,
                          firstIndex: first, indexCount: uint32(idx.len))

proc setTarget*(gpu: GpuContext, target: ptr SDL_GPUTexture, w, h: int32) =
  ## Switch the render target (canvas vs screen); preserves existing contents.
  startPass(gpu, target, w, h, false, (0'u8, 0'u8, 0'u8, 255'u8))

proc clearTarget*(gpu: GpuContext, target: ptr SDL_GPUTexture, w, h: int32,
                  color: Color) =
  ## Clear the current target by beginning a fresh clearing pass on it.
  startPass(gpu, target, w, h, true, color)

proc endFrame*(gpu: GpuContext) =
  ## Upload all geometry, then replay every recorded pass, then submit.
  if gpu.cmd == nil: return

  if gpu.vertices.len > 0:
    ensureVbuf(gpu, gpu.vertices.len)
    ensureIbuf(gpu, gpu.indices.len)
    let vBytes = gpu.vertices.len * sizeof(Vertex)
    let iBytes = gpu.indices.len * sizeof(uint32)
    ensureTransfer(gpu, vBytes + iBytes)
    let mapped = cast[ptr UncheckedArray[byte]](
      SDL_MapGPUTransferBuffer(gpu.device, gpu.transferBuf, true))
    copyMem(addr mapped[0], addr gpu.vertices[0], vBytes)
    copyMem(addr mapped[vBytes], addr gpu.indices[0], iBytes)
    SDL_UnmapGPUTransferBuffer(gpu.device, gpu.transferBuf)

    let cp = SDL_BeginGPUCopyPass(gpu.cmd)
    var vsrc = SDL_GPUTransferBufferLocation(transfer_buffer: gpu.transferBuf, offset: 0)
    var vdst = SDL_GPUBufferRegion(buffer: gpu.vbuf, offset: 0, size: Uint32(vBytes))
    SDL_UploadToGPUBuffer(cp, addr vsrc, addr vdst, true)
    var isrc = SDL_GPUTransferBufferLocation(transfer_buffer: gpu.transferBuf, offset: Uint32(vBytes))
    var idst = SDL_GPUBufferRegion(buffer: gpu.ibuf, offset: 0, size: Uint32(iBytes))
    SDL_UploadToGPUBuffer(cp, addr isrc, addr idst, true)
    SDL_EndGPUCopyPass(cp)

  for p in gpu.passes.mitems:
    var cti = SDL_GPUColorTargetInfo(
      texture: p.target,
      clear_color: (if p.doClear:
        SDL_FColor(r: p.clearColor.r.float32 / 255, g: p.clearColor.g.float32 / 255,
                   b: p.clearColor.b.float32 / 255, a: p.clearColor.a.float32 / 255)
      else: SDL_FColor()),
      load_op: (if p.doClear: SDL_GPU_LOADOP_CLEAR else: SDL_GPU_LOADOP_LOAD),
      store_op: SDL_GPU_STOREOP_STORE)
    let rp = SDL_BeginGPURenderPass(gpu.cmd, addr cti, 1, nil)
    SDL_PushGPUVertexUniformData(gpu.cmd, 0, addr p.projection[0],
                                 Uint32(sizeof(p.projection)))
    var vbind = SDL_GPUBufferBinding(buffer: gpu.vbuf, offset: 0)
    var ibind = SDL_GPUBufferBinding(buffer: gpu.ibuf, offset: 0)
    if gpu.vbuf != nil:
      SDL_BindGPUVertexBuffers(rp, 0, addr vbind, 1)
      SDL_BindGPUIndexBuffer(rp, addr ibind, SDL_GPU_INDEXELEMENTSIZE_32BIT)
    for c in p.cmds:
      SDL_BindGPUGraphicsPipeline(rp, gpu.pipelines[c.kind][c.blend])
      if c.kind == pkTextured and c.texture != nil:
        var tsb = SDL_GPUTextureSamplerBinding(texture: c.texture, sampler: gpu.sampler)
        SDL_BindGPUFragmentSamplers(rp, 0, addr tsb, 1)
      SDL_DrawGPUIndexedPrimitives(rp, c.indexCount, 1, c.firstIndex, 0, 0)
    SDL_EndGPURenderPass(rp)

  discard SDL_SubmitGPUCommandBuffer(gpu.cmd)
  gpu.cmd = nil

  # Release transient textures such as rasterized text. SDL_GPU defers the actual
  # free until the GPU is done with them, so this is safe right after submit.
  for t in gpu.tempTextures: SDL_ReleaseGPUTexture(gpu.device, t)
  gpu.tempTextures.setLen(0)

proc addTempTexture*(gpu: GpuContext, tex: ptr SDL_GPUTexture) =
  gpu.tempTextures.add tex

proc createTextureFromPixels*(gpu: GpuContext, pixels: pointer, w, h, pitch: int):
                              ptr SDL_GPUTexture =
  ## Upload tightly-packed RGBA8 pixel data (handling source row pitch) into a
  ## new sampled GPU texture, via a one-off command buffer + copy pass.
  var tci = SDL_GPUTextureCreateInfo(
    type_field: SDL_GPU_TEXTURETYPE_2D,
    format: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
    usage: SDL_GPUTextureUsageFlags(SDL_GPU_TEXTUREUSAGE_SAMPLER),
    width: Uint32(w), height: Uint32(h),
    layer_count_or_depth: 1, num_levels: 1,
    sample_count: SDL_GPU_SAMPLECOUNT_1)
  result = SDL_CreateGPUTexture(gpu.device, addr tci)
  if result == nil:
    raise newException(CatchableError, "SDL_CreateGPUTexture failed: " & $SDL_GetError())

  let bytes = w * h * 4
  var tbci = SDL_GPUTransferBufferCreateInfo(
    usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, size: Uint32(bytes))
  let tb = SDL_CreateGPUTransferBuffer(gpu.device, addr tbci)
  let dst = cast[ptr UncheckedArray[byte]](SDL_MapGPUTransferBuffer(gpu.device, tb, false))
  let src = cast[ptr UncheckedArray[byte]](pixels)
  for row in 0 ..< h:
    copyMem(addr dst[row * w * 4], addr src[row * pitch], w * 4)
  SDL_UnmapGPUTransferBuffer(gpu.device, tb)

  let cmd = SDL_AcquireGPUCommandBuffer(gpu.device)
  let cp = SDL_BeginGPUCopyPass(cmd)
  var srcInfo = SDL_GPUTextureTransferInfo(
    transfer_buffer: tb, offset: 0, pixels_per_row: Uint32(w), rows_per_layer: Uint32(h))
  var region = SDL_GPUTextureRegion(
    texture: result, mip_level: 0, layer: 0, x: 0, y: 0, z: 0,
    w: Uint32(w), h: Uint32(h), d: 1)
  SDL_UploadToGPUTexture(cp, addr srcInfo, addr region, false)
  SDL_EndGPUCopyPass(cp)
  discard SDL_SubmitGPUCommandBuffer(cmd)
  SDL_ReleaseGPUTransferBuffer(gpu.device, tb)

proc createRenderTarget*(gpu: GpuContext, w, h: int32): ptr SDL_GPUTexture =
  ## A texture usable both as a color target (canvas) and as a sampled texture.
  ## Must use the swapchain format so the built-in pipelines can target it.
  var tci = SDL_GPUTextureCreateInfo(
    type_field: SDL_GPU_TEXTURETYPE_2D,
    format: gpu.swFormat,
    usage: SDL_GPUTextureUsageFlags(
      SDL_GPU_TEXTUREUSAGE_SAMPLER or SDL_GPU_TEXTUREUSAGE_COLOR_TARGET),
    width: Uint32(w), height: Uint32(h),
    layer_count_or_depth: 1, num_levels: 1,
    sample_count: SDL_GPU_SAMPLECOUNT_1)
  result = SDL_CreateGPUTexture(gpu.device, addr tci)
  if result == nil:
    raise newException(CatchableError, "SDL_CreateGPUTexture (target) failed: " & $SDL_GetError())

proc destroy*(gpu: GpuContext) =
  let dev = gpu.device
  for kind in PipelineKind:
    for blend in BlendMode:
      if gpu.pipelines[kind][blend] != nil:
        SDL_ReleaseGPUGraphicsPipeline(dev, gpu.pipelines[kind][blend])
  if gpu.sampler != nil: SDL_ReleaseGPUSampler(dev, gpu.sampler)
  if gpu.vbuf != nil: SDL_ReleaseGPUBuffer(dev, gpu.vbuf)
  if gpu.ibuf != nil: SDL_ReleaseGPUBuffer(dev, gpu.ibuf)
  if gpu.transferBuf != nil: SDL_ReleaseGPUTransferBuffer(dev, gpu.transferBuf)
  SDL_ReleaseWindowFromGPUDevice(dev, gpu.window)
  SDL_DestroyGPUDevice(dev)
