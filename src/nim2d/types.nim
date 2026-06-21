## Core nim2d types.
##
## This module is mostly data, with the behaviour living in the backend renderer
## and the public modules. The two exceptions are the device-liveness flag and
## the `=destroy` hooks for the texture, font and shader resources, which Nim
## wants in the same module as the type they belong to. It stays a leaf of the
## dependency graph, since `types` is imported by everything and itself depends
## only on the SDL shims and the transform math.

import backend/sdl
import backend/sdlttf
import transform

type
  Color* = tuple[r, g, b, a: uint8]
    ## A color as four bytes from 0 to 255. The color module adds named
    ## constants and the `rgb`, `gray` and hex constructors.

  Vec2* = tuple[x, y: float]
    ## The (x, y) float pair used for positions throughout nim2d. The math
    ## module gives it the usual vector operators, and because it is a plain
    ## tuple they work on bare literals like `(10.0, 20.0)` too.

  Vertex* = object
    ## One batched vertex: pixel-space position, texcoords, normalized color.
    x*, y*: float32
    u*, v*: float32
    r*, g*, b*, a*: float32

  BlendMode* = enum
    ## How drawing mixes with what is already on the target: no blending,
    ## ordinary alpha blending, additive (brightens, good for glow), or
    ## multiplicative (darkens).
    bmNone
    bmAlpha
    bmAdd
    bmMod

  Key* {.pure.} = enum
    ## A keyboard key, delivered to the keydown and keyup callbacks and accepted
    ## by `isDown`. Use it qualified, like `Key.escape`, `Key.space` or `Key.a`.
    ## Keys without a name here arrive as `Key.unknown`.
    unknown
    a
    b
    c
    d
    e
    f
    g
    h
    i
    j
    k
    l
    m
    n
    o
    p
    q
    r
    s
    t
    u
    v
    w
    x
    y
    z
    one
    two
    three
    four
    five
    six
    seven
    eight
    nine
    zero
    f1
    f2
    f3
    f4
    f5
    f6
    f7
    f8
    f9
    f10
    f11
    f12
    space
    enter
    escape
    tab
    backspace
    delete
    left
    right
    up
    down
    lshift
    rshift
    lctrl
    rctrl
    lalt
    ralt
    home
    End
    pageUp
    pageDown
    minus
    equals
    comma
    period
    slash
    backslash
    grave
    semicolon
    apostrophe
    leftBracket
    rightBracket

  MouseButton* {.pure.} = enum
    ## A mouse button, delivered to the mousepressed and mousereleased callbacks.
    left
    right
    middle
    x1
    x2

  GamepadId* = SDL_JoystickID
    ## Identifies a connected controller, handed to the gamepad callbacks and
    ## the polling procs. Opaque; you do not build one yourself.

  GamepadButton* {.pure.} = enum
    ## A controller button, delivered to the gamepad callbacks and accepted by
    ## isGamepadDown. The face buttons are named by position: south/east/west/
    ## north are A/B/X/Y on an Xbox-style pad.
    unknown
    south
    east
    west
    north
    back
    guide
    start
    leftStick
    rightStick
    leftShoulder
    rightShoulder
    dpadUp
    dpadDown
    dpadLeft
    dpadRight

  GamepadAxis* {.pure.} = enum
    ## A controller axis, delivered to the gamepadaxis callback and accepted by
    ## gamepadAxis. Sticks run -1 to 1, triggers 0 to 1.
    unknown
    leftX
    leftY
    rightX
    rightY
    leftTrigger
    rightTrigger

  PipelineKind* = enum
    ## Which built-in pipeline a draw uses: plain vertex colors or a texture.
    pkColored
    pkTextured

  # --- Drawables -----------------------------------------------------------
  DrawableObj = object of RootObj
  Drawable* = ref DrawableObj ## The base of everything that can be drawn to the screen.

  Filter* = enum
    ## Texture sampling: smooth (the default) or sharp, for pixel art.
    filLinear
    filNearest

  Wrap* = enum
    ## How texcoords outside 0..1 are handled.
    wrapClamp
    wrapRepeat
    wrapMirror

  TextureObj = object of DrawableObj
    tex*: ptr SDL_GPUTexture
    width*: int32
    height*: int32
    tint*: Color ## color/alpha modulation applied when drawn
    filter*: Filter ## linear by default
    wrap*: Wrap ## clamp by default

  Texture* = ref TextureObj
    ## A GPU texture with its size and sampling state. Images and canvases are
    ## both textures, which is why they draw the same way. Its texture frees
    ## itself when the texture is collected; `destroy` frees it early.

  ImageObj = object of TextureObj
  Image* = ref ImageObj ## A texture loaded from a file or uploaded from an ImageData.

  CanvasObj = object of TextureObj
    depth*: ptr SDL_GPUTexture
      ## paired depth-stencil target, only when stencil is enabled

  Canvas* = ref CanvasObj
    ## A render target (GPU texture created with COLOR_TARGET usage). It frees
    ## its color target, and the paired depth target when present, on
    ## collection; `destroy` frees them early.

  Quad* = object
    ## A rectangular sub-region of a texture, as texcoords plus its pixel size.
    u0*, v0*, u1*, v1*: float32
    w*, h*: float32

  FontObj = object
    engine*: pointer ## TTF_TextEngine (GPU text engine)
    font*: pointer ## TTF_Font (nil for a bitmap/image font)
    size*: cint
    img*: Image ## glyph sheet, set for a bitmap/image font
    glyphSet*: string ## the characters, in image order
    glyphX*, glyphW*: seq[int32] ## each glyph's x and width in the sheet
    imgH*: int32 ## glyph height (the sheet height)
    spacing*: int32 ## pixels added between glyphs

  Font* = ref FontObj
    ## A font for `print`: either a TrueType font opened through SDL_ttf, or a
    ## bitmap font built from a glyph sheet by `newImageFont`. Its handles free
    ## themselves when the font is collected; `destroy` frees them early.

  ShaderObj = object
    pipelines*: array[BlendMode, ptr SDL_GPUGraphicsPipeline]
    uniform*: seq[byte]
    hasUniform*: bool

  Shader* = ref ShaderObj
    ## A user fragment shader compiled into one pipeline per blend mode, with an
    ## optional fragment uniform buffer filled by `send`. Its pipelines free
    ## themselves when the shader is collected; `destroy` frees them early.

  Scissor* = object ## A clip rectangle in render-target pixels, off when `on` is false.
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
    ## The renderer's state: the GPU device, pipelines, samplers, the geometry
    ## accumulated for the current frame, and the transform stack. Owned by the
    ## engine; games normally never touch it directly.
    device*: ptr SDL_GPUDevice
    window*: ptr SDL_Window
    swFormat*: SDL_GPUTextureFormat ## swapchain format; render targets must match it
    shaderFormat*: SDL_GPUShaderFormat ## MSL or SPIR-V, chosen from the device backend
    sampler*: ptr SDL_GPUSampler ## default sampler (linear, clamp)
    samplers*: array[Filter, array[Wrap, ptr SDL_GPUSampler]] ## cache for other combos
    ssFactor*: int32 ## supersample factor for anti-aliasing (1 = off)
    ssTex*: ptr SDL_GPUTexture ## the high-res offscreen target when supersampling
    ssW*, ssH*: int32 ## supersample target size
    frameW*, frameH*: int32 ## logical frame size, for the downscale blit
    stencilEnabled*: bool ## whether the depth-stencil machinery is built
    depthFormat*: SDL_GPUTextureFormat ## chosen depth-stencil format
    screenDepth*, ssDepth*: ptr SDL_GPUTexture ## depth-stencil targets for screen/SS
    screenDepthW*, screenDepthH*: int32 ## size the screen depth target was made at
    stencilMode*: uint8 ## 0 none, 1 write the mask, 2 test against it
    stencilWritePipe*: ptr SDL_GPUGraphicsPipeline
    stencilTestPipes*:
      array[PipelineKind, array[BlendMode, ptr SDL_GPUGraphicsPipeline]]
    whiteTex*: ptr SDL_GPUTexture ## 1x1 white, bound when a shader draw has no texture
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
    tempTextures*: seq[ptr SDL_GPUTexture] ## released after the frame submits

    # Current transform, baked into vertices as they are added
    transform*: Transform
    transformStack*: seq[Transform]

    # Current scissor and shader, recorded into each draw command
    curScissor*: Scissor
    curShader*: Shader

  # --- Engine --------------------------------------------------------------
  Nim2d* = ref object
    ## The engine: the window, the renderer, the current draw state, timing,
    ## and the callbacks the main loop dispatches to. Make one with `newNim2d`,
    ## assign the callbacks you care about, and hand it to `play`.
    width*: int32
    height*: int32
    gpu*: GpuContext
    background*: Color
    color*: Color
    font*: Font
    fs*: Filesystem
    blend*: BlendMode
    running*: bool
    teardownRan*: bool ## set once teardown has run, so it never runs twice

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
    keydown*: proc(nim2d: Nim2d, key: Key)
    keyup*: proc(nim2d: Nim2d, key: Key)
    mousemove*: proc(nim2d: Nim2d, x, y, dx, dy: float)
    mousepressed*: proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8)
    mousereleased*: proc(nim2d: Nim2d, x, y: float, button: MouseButton, clicks: uint8)
    mousewheel*: proc(nim2d: Nim2d, x, y: float)
    textinput*: proc(nim2d: Nim2d, text: string)
    gamepadpressed*: proc(nim2d: Nim2d, id: GamepadId, button: GamepadButton)
    gamepadreleased*: proc(nim2d: Nim2d, id: GamepadId, button: GamepadButton)
    gamepadaxis*: proc(nim2d: Nim2d, id: GamepadId, axis: GamepadAxis, value: float)
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

# --- resource lifetime -------------------------------------------------------

var gpuLiveDevice*: ptr SDL_GPUDevice
  ## The live GPU device. The renderer sets this when the context is created and
  ## clears it on teardown. Device-bound destructors check it first, so a font,
  ## shader or other resource collected after the engine has shut down frees
  ## nothing and the device's own teardown reclaims it instead. This sidesteps
  ## the unspecified order in which ORC frees globals at exit.

proc `=destroy`(o: var TextureObj) =
  # A GPU texture. Releasing it needs a live device, so a destructor that runs
  # after the engine has shut down frees nothing and the device's own teardown
  # reclaims it. Images add no handle, so they inherit this hook.
  if gpuLiveDevice != nil and o.tex != nil:
    SDL_ReleaseGPUTexture(gpuLiveDevice, o.tex)
    o.tex = nil

proc `=destroy`(o: var CanvasObj) =
  # A canvas owns its color target and, with stencil on, a paired depth target.
  # A derived =destroy does not run the base one, so free both handles here.
  if gpuLiveDevice != nil:
    if o.tex != nil:
      SDL_ReleaseGPUTexture(gpuLiveDevice, o.tex)
      o.tex = nil
    if o.depth != nil:
      SDL_ReleaseGPUTexture(gpuLiveDevice, o.depth)
      o.depth = nil

proc `=destroy`(o: var FontObj) =
  # A TrueType handle and, for a bitmap font, an internal glyph-sheet texture.
  # Releasing the texture needs a live device; closing the TTF font does not,
  # but gating the whole thing keeps a late destructor a clean no-op.
  if gpuLiveDevice != nil:
    if o.font != nil:
      TTF_CloseFont(cast[ptr TTF_Font](o.font))
    if o.img != nil and o.img.tex != nil:
      SDL_ReleaseGPUTexture(gpuLiveDevice, o.img.tex)
      o.img.tex = nil
  # A custom destructor takes over field teardown, so free the managed ones.
  `=destroy`(o.img)
  `=destroy`(o.glyphSet)
  `=destroy`(o.glyphX)
  `=destroy`(o.glyphW)

proc `=destroy`(o: var ShaderObj) =
  if gpuLiveDevice != nil:
    for blend in BlendMode:
      if o.pipelines[blend] != nil:
        SDL_ReleaseGPUGraphicsPipeline(gpuLiveDevice, o.pipelines[blend])
        o.pipelines[blend] = nil
  `=destroy`(o.uniform)
