## Core nim2d types.
##
## This module holds data only. The behaviour lives in the backend renderer and
## the public modules. Keeping it this way leaves the dependency graph acyclic,
## since `types` is imported by everything and itself depends only on the SDL
## shim and the transform math.

import backend/sdl

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

  Texture* = ref object of Drawable
    tex*: ptr SDL_GPUTexture
    width*: int32
    height*: int32
    tint*: Color          ## color/alpha modulation applied when drawn

  Image* = ref object of Texture

  Canvas* = ref object of Texture
    ## A render target (GPU texture created with COLOR_TARGET usage).

  Font* = ref object
    engine*: pointer      ## TTF_TextEngine (GPU text engine)
    font*: pointer        ## TTF_Font
    size*: cint

  # --- GPU context ---------------------------------------------------------

  DrawCmd* = object
    ## A run of indices sharing pipeline/blend/texture state.
    kind*: PipelineKind
    blend*: BlendMode
    texture*: ptr SDL_GPUTexture
    firstIndex*: uint32
    indexCount*: uint32

  RenderPassRec* = object
    ## One render pass: a target texture plus the draws recorded against it.
    ## (A new pass is started whenever the render target or clear changes.)
    target*: ptr SDL_GPUTexture
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
    sampler*: ptr SDL_GPUSampler
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

  # --- Engine --------------------------------------------------------------

  Nim2d* = ref object
    width*: int32
    height*: int32
    gpu*: GpuContext
    background*: Color
    color*: Color
    font*: Font
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
