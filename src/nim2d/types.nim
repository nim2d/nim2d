## Core nim2d types.
##
## This module holds data only. The behaviour lives in the backend renderer and
## the public modules. Keeping it this way leaves the dependency graph acyclic,
## since `types` is imported by everything and itself depends only on the SDL
## shim and the transform math.

import backend/sdl
import transform

type
  Color* = tuple[r, g, b, a: uint8]

  Vec2* = tuple[x, y: float]

  Vertex* = object
    ## One batched vertex: pixel-space position, texcoords, normalized color.
    x*, y*: float32
    u*, v*: float32
    r*, g*, b*, a*: float32

  BlendMode* = enum
    bmNone, bmAlpha, bmAdd, bmMod

  PipelineKind* = enum
    pkColored, pkTextured

  # --- Drawables -----------------------------------------------------------

  Drawable* = ref object of RootObj

  Filter* = enum
    ## Texture sampling: smooth (the default) or sharp, for pixel art.
    filLinear, filNearest
  Wrap* = enum
    ## How texcoords outside 0..1 are handled.
    wrapClamp, wrapRepeat, wrapMirror

  Texture* = ref object of Drawable
    tex*: ptr SDL_GPUTexture
    width*: int32
    height*: int32
    tint*: Color          ## color/alpha modulation applied when drawn
    filter*: Filter       ## linear by default
    wrap*: Wrap           ## clamp by default

  Image* = ref object of Texture

  Canvas* = ref object of Texture
    ## A render target (GPU texture created with COLOR_TARGET usage).
    depth*: ptr SDL_GPUTexture   ## paired depth-stencil target, only when stencil is enabled

  Quad* = object
    ## A rectangular sub-region of a texture, as texcoords plus its pixel size.
    u0*, v0*, u1*, v1*: float32
    w*, h*: float32

  Font* = ref object
    engine*: pointer      ## TTF_TextEngine (GPU text engine)
    font*: pointer        ## TTF_Font (nil for a bitmap/image font)
    size*: cint
    img*: Image           ## glyph sheet, set for a bitmap/image font
    glyphSet*: string     ## the characters, in image order
    glyphX*, glyphW*: seq[int32]  ## each glyph's x and width in the sheet
    imgH*: int32          ## glyph height (the sheet height)
    spacing*: int32       ## pixels added between glyphs

  Shader* = ref object
    ## A user fragment shader compiled into one pipeline per blend mode, with an
    ## optional fragment uniform buffer filled by `send`.
    pipelines*: array[BlendMode, ptr SDL_GPUGraphicsPipeline]
    uniform*: seq[byte]
    hasUniform*: bool

  Scissor* = object
    on*: bool
    x*, y*, w*, h*: int32

  Filesystem* = ref object
    ## A small virtual filesystem: a writable save directory, a read-only source
    ## directory, and extra read directories added with `mount`. The behaviour
    ## lives in the filesystem module.
    saveDir*: string
    sourceDir*: string
    mounts*: seq[string]
    identitySet*: bool

  # --- GPU context ---------------------------------------------------------

  DrawCmd* = object
    ## A run of indices sharing pipeline/blend/texture/scissor/shader state.
    kind*: PipelineKind
    blend*: BlendMode
    texture*: ptr SDL_GPUTexture
    sampler*: ptr SDL_GPUSampler
    shader*: Shader
    scissor*: Scissor
    stencil*: uint8
    firstIndex*: uint32
    indexCount*: uint32

  RenderPassRec* = object
    ## One render pass: a target texture plus the draws recorded against it.
    ## (A new pass is started whenever the render target or clear changes.)
    target*: ptr SDL_GPUTexture
    depth*: ptr SDL_GPUTexture
    w*: int32
    h*: int32
    doClear*: bool
    clearColor*: Color
    projection*: array[16, float32]
    cmds*: seq[DrawCmd]

  GpuContext* = ref object
    device*: ptr SDL_GPUDevice
    window*: ptr SDL_Window
    swFormat*: SDL_GPUTextureFormat   ## swapchain format; render targets must match it
    shaderFormat*: SDL_GPUShaderFormat  ## MSL or SPIR-V, chosen from the device backend
    sampler*: ptr SDL_GPUSampler        ## default sampler (linear, clamp)
    samplers*: array[Filter, array[Wrap, ptr SDL_GPUSampler]]  ## cache for other combos
    ssFactor*: int32                    ## supersample factor for anti-aliasing (1 = off)
    ssTex*: ptr SDL_GPUTexture          ## the high-res offscreen target when supersampling
    ssW*, ssH*: int32                   ## supersample target size
    frameW*, frameH*: int32             ## logical frame size, for the downscale blit
    stencilEnabled*: bool               ## whether the depth-stencil machinery is built
    depthFormat*: SDL_GPUTextureFormat  ## chosen depth-stencil format
    screenDepth*, ssDepth*: ptr SDL_GPUTexture  ## depth-stencil targets for screen/SS
    screenDepthW*, screenDepthH*: int32 ## size the screen depth target was made at
    stencilMode*: uint8                 ## 0 none, 1 write the mask, 2 test against it
    stencilWritePipe*: ptr SDL_GPUGraphicsPipeline
    stencilTestPipes*: array[PipelineKind, array[BlendMode, ptr SDL_GPUGraphicsPipeline]]
    whiteTex*: ptr SDL_GPUTexture     ## 1x1 white, bound when a shader draw has no texture
    pipelines*: array[PipelineKind, array[BlendMode, ptr SDL_GPUGraphicsPipeline]]

    # CPU-side geometry for the whole frame (deferred upload)
    vertices*: seq[Vertex]
    indices*: seq[uint32]

    # GPU buffers (grown on demand)
    vbuf*: ptr SDL_GPUBuffer
    ibuf*: ptr SDL_GPUBuffer
    vbufCap*: int
    ibufCap*: int
    transferBuf*: ptr SDL_GPUTransferBuffer
    transferCap*: int

    # Per-frame state
    cmd*: ptr SDL_GPUCommandBuffer
    swTex*: ptr SDL_GPUTexture
    passes*: seq[RenderPassRec]
    tempTextures*: seq[ptr SDL_GPUTexture]  ## released after the frame submits

    # Current transform, baked into vertices as they are added
    transform*: Transform
    transformStack*: seq[Transform]

    # Current scissor and shader, recorded into each draw command
    curScissor*: Scissor
    curShader*: Shader

  # --- Engine --------------------------------------------------------------

  Nim2d* = ref object
    width*: int32
    height*: int32
    gpu*: GpuContext
    background*: Color
    color*: Color
    font*: Font
    fs*: Filesystem
    blend*: BlendMode
    running*: bool

    # timing
    perfFreq*: uint64
    lastCounter*: uint64
    dt*: float
    fps*: float

    # Callbacks
    load*: proc(nim2d: Nim2d)
    draw*: proc(nim2d: Nim2d)
    quit*: proc(nim2d: Nim2d)
    update*: proc(nim2d: Nim2d, dt: float)
    keydown*: proc(nim2d: Nim2d, scancode: SDL_Scancode)
    keyup*: proc(nim2d: Nim2d, scancode: SDL_Scancode)
    mousemove*: proc(nim2d: Nim2d, x, y, dx, dy: float)
    mousepressed*: proc(nim2d: Nim2d, x, y: float, button, clicks: uint8)
    mousereleased*: proc(nim2d: Nim2d, x, y: float, button, clicks: uint8)
    mousewheel*: proc(nim2d: Nim2d, x, y: float)
    textinput*: proc(nim2d: Nim2d, text: string)
    gamepadpressed*: proc(nim2d: Nim2d, id: SDL_JoystickID, button: SDL_GamepadButton)
    gamepadreleased*: proc(nim2d: Nim2d, id: SDL_JoystickID, button: SDL_GamepadButton)
    gamepadaxis*: proc(nim2d: Nim2d, id: SDL_JoystickID, axis: SDL_GamepadAxis, value: float)
    touchpressed*: proc(nim2d: Nim2d, id: int64, x, y, pressure: float)
    touchmoved*: proc(nim2d: Nim2d, id: int64, x, y, pressure: float)
    touchreleased*: proc(nim2d: Nim2d, id: int64, x, y, pressure: float)

    # Window events
    window_shown*: proc(nim2d: Nim2d)
    window_hidden*: proc(nim2d: Nim2d)
    window_moved*: proc(nim2d: Nim2d)
    window_resized*: proc(nim2d: Nim2d)
    window_minimized*: proc(nim2d: Nim2d)
    window_maximized*: proc(nim2d: Nim2d)
    window_restored*: proc(nim2d: Nim2d)
    window_enter*: proc(nim2d: Nim2d)
    window_leave*: proc(nim2d: Nim2d)
    window_focus_gained*: proc(nim2d: Nim2d)
    window_focus_lost*: proc(nim2d: Nim2d)
    window_close*: proc(nim2d: Nim2d)
