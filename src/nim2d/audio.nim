## Loading and playing sounds.
##
## One mixer opens against the default playback device when the engine starts. A
## `Source` is a loaded sound bound to its own track, static when it decodes
## fully into memory for short effects, streaming when it decodes as it plays for
## music. Sources carry the usual controls: play, pause, resume, stop, rewind,
## seek and tell, volume, pitch, looping, and a 3D position for panning and
## distance.
##
## Pitch and speed move together through the track's frequency ratio; there is
## no independent time stretch. SDL_mixer keeps its listener at the origin, so
## a movable listener is emulated by offsetting each positioned source by the
## stored listener position.
##
## If no audio device opens (a headless or CI machine), the mixer stays off and
## every call here becomes a safe no-op, so a game still builds and runs.

import types
import backend/sdl
import backend/sdlmixer

const SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK = SDL_AudioDeviceID(0xFFFFFFFF'u32)

type
  SourceType* = enum
    ## Static decodes fully into memory for short sounds; stream decodes as it
    ## plays for music.
    stStatic
    stStream

  SourceObj = object
    audio: ptr MIX_Audio
    track: ptr MIX_Track
    kind: SourceType
    looping: bool
    volume: float
    pitch: float
    positioned: bool
    wx, wy, wz: float ## world position, used for the listener offset

  Source* = ref SourceObj
    ## A playable sound: a loaded `MIX_Audio` bound to its own `MIX_Track`.
    ## `destroy` frees its track and audio, and anything still loaded is freed
    ## when the engine's audio shuts down, so you do not have to track them by
    ## hand.

var
  gMixer: ptr MIX_Mixer = nil
  gInitTried = false
  gListener: tuple[x, y, z: float] = (0.0, 0.0, 0.0)
  gPositioned: seq[Source] = @[]
  gSources: seq[Source] = @[]

proc `=destroy`(o: var SourceObj) =
  # The mixer owns the track and audio; once it is gone (after shutdownAudio) it
  # has freed them already, so a late destructor frees nothing. gMixer is the
  # audio-liveness flag, the audio analogue of the renderer's gpuLiveDevice.
  if gMixer != nil:
    if o.track != nil:
      MIX_DestroyTrack(o.track)
    if o.audio != nil:
      MIX_DestroyAudio(o.audio)

# --- lifecycle -------------------------------------------------------------

proc initAudio*(nim2d: Nim2d) =
  ## Open the audio device and the mixer. Called once by `newNim2d`. If no device
  ## is available it leaves audio off rather than failing, and it is safe to call
  ## again as a no-op. Audio reopens cleanly after `shutdownAudio`.
  if gMixer != nil:
    return # already open
  if gInitTried:
    return # tried once with no device, do not keep retrying
  gInitTried = true
  if not MIX_Init():
    return
  let m = MIX_CreateMixerDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)
  if m == nil:
    MIX_Quit()
    return
  gMixer = m

proc shutdownAudio*(nim2d: Nim2d) =
  ## Stop all sound, destroy the mixer and close the device. Called from the
  ## `play` teardown. Destroying the mixer also frees every track and sound, so
  ## the handles outstanding sources hold are dropped here to keep later calls
  ## on them, and `destroy`, safe no-ops.
  if gMixer != nil:
    discard MIX_StopAllTracks(gMixer, 0)
    MIX_DestroyMixer(gMixer)
    gMixer = nil
    MIX_Quit()
  for s in gSources:
    s.track = nil
    s.audio = nil
    s.positioned = false
  gSources.setLen(0)
  gPositioned.setLen(0)
  gInitTried = false

proc audioAvailable*(nim2d: Nim2d): bool =
  ## Whether an audio device opened. False on machines with no sound output.
  gMixer != nil

# --- sources ---------------------------------------------------------------

proc newSource*(nim2d: Nim2d, filename: string, kind: SourceType = stStatic): Source =
  ## Load a sound from a file. WAV, OGG, MP3, FLAC and tracker formats decode
  ## through SDL_mixer. With audio off this returns a source whose controls do
  ## nothing.
  result = Source(kind: kind, volume: 1.0, pitch: 1.0)
  if gMixer == nil:
    return
  result.audio = MIX_LoadAudio(gMixer, filename.cstring, kind == stStatic)
  if result.audio == nil:
    raise newException(
      IOError, "could not load audio '" & filename & "': " & $SDL_GetError()
    )
  result.track = MIX_CreateTrack(gMixer)
  if result.track == nil:
    MIX_DestroyAudio(result.audio)
    result.audio = nil
    raise
      newException(CatchableError, "could not create audio track: " & $SDL_GetError())
  discard MIX_SetTrackAudio(result.track, result.audio)
  gSources.add result

proc play*(src: Source) =
  ## Start the source from the beginning, or restart it if already playing.
  ## The loop count is set through the play options, because setting it on a
  ## stopped track has no lasting effect.
  if src.track == nil:
    return
  let props = SDL_CreateProperties()
  discard SDL_SetNumberProperty(
    props, MIX_PROP_PLAY_LOOPS_NUMBER.cstring, Sint64(if src.looping: -1 else: 0)
  )
  discard MIX_PlayTrack(src.track, props)
  SDL_DestroyProperties(props)

proc pause*(src: Source) =
  ## Pause playback, keeping the current position.
  if src.track != nil:
    discard MIX_PauseTrack(src.track)

proc resume*(src: Source) =
  ## Resume a paused source from where it stopped.
  if src.track != nil:
    discard MIX_ResumeTrack(src.track)

proc stop*(src: Source) =
  ## Stop playback and reset the position to the start.
  if src.track == nil:
    return
  discard MIX_StopTrack(src.track, 0)
  discard MIX_SetTrackPlaybackPosition(src.track, 0)

proc rewind*(src: Source) =
  ## Seek back to the start without stopping.
  if src.track != nil:
    discard MIX_SetTrackPlaybackPosition(src.track, 0)

proc seek*(src: Source, seconds: float) =
  ## Jump to a position in seconds.
  if src.track == nil:
    return
  let frames = MIX_TrackMSToFrames(src.track, Sint64(seconds * 1000))
  discard MIX_SetTrackPlaybackPosition(src.track, frames)

proc tell*(src: Source): float =
  ## The current playback position in seconds.
  if src.track == nil:
    return 0.0
  let frames = MIX_GetTrackPlaybackPosition(src.track)
  MIX_TrackFramesToMS(src.track, frames).float / 1000.0

proc isPlaying*(src: Source): bool =
  ## True while the source is actively mixing (not stopped, not paused).
  src.track != nil and MIX_TrackPlaying(src.track) and not MIX_TrackPaused(src.track)

proc isPaused*(src: Source): bool =
  ## True while the source is paused.
  src.track != nil and MIX_TrackPaused(src.track)

proc setVolume*(src: Source, volume: float) =
  ## Set per-source gain, 0.0 silent to 1.0 full; values above 1.0 amplify.
  src.volume = volume
  if src.track != nil:
    discard MIX_SetTrackGain(src.track, volume.cfloat)

proc getVolume*(src: Source): float =
  ## The source's current gain.
  src.volume

proc setPitch*(src: Source, pitch: float) =
  ## Set the playback speed and pitch together, 1.0 is normal. There is no
  ## independent time stretch.
  src.pitch = pitch
  if src.track != nil:
    discard MIX_SetTrackFrequencyRatio(src.track, pitch.cfloat)

proc getPitch*(src: Source): float =
  ## The source's current pitch/speed ratio.
  src.pitch

proc setLooping*(src: Source, loop: bool) =
  ## Loop forever when true, play once when false.
  src.looping = loop
  if src.track != nil:
    discard MIX_SetTrackLoops(src.track, (if loop: -1.cint else: 0.cint))

proc isLooping*(src: Source): bool =
  ## Whether the source loops.
  src.looping

proc duration*(src: Source): float =
  ## Length of the sound in seconds, or -1 if unknown or infinite.
  if src.audio == nil:
    return -1.0
  let frames = MIX_GetAudioDuration(src.audio)
  if frames < 0:
    return -1.0
  MIX_AudioFramesToMS(src.audio, frames).float / 1000.0

# --- positional audio ------------------------------------------------------

func listenerRelative*(wx, wy, wz, lx, ly, lz: float): tuple[x, y, z: float] =
  ## A source's position relative to the listener, with screen y (down) flipped
  ## to the mixer's y (up). Used to emulate a movable listener.
  (wx - lx, -(wy - ly), wz - lz)

proc applyPosition(src: Source) =
  if src.track == nil or not src.positioned:
    return
  let r =
    listenerRelative(src.wx, src.wy, src.wz, gListener.x, gListener.y, gListener.z)
  var p = MIX_Point3D(x: r.x.cfloat, y: r.y.cfloat, z: r.z.cfloat)
  discard MIX_SetTrack3DPosition(src.track, addr p)

proc setPosition*(src: Source, x, y: float, z: float = 0) =
  ## Place the source in space for distance attenuation and stereo panning,
  ## relative to the listener.
  src.wx = x
  src.wy = y
  src.wz = z
  if not src.positioned:
    src.positioned = true
    gPositioned.add src
  src.applyPosition()

proc clearPosition*(src: Source) =
  ## Turn off positional mixing for this source.
  if not src.positioned:
    return
  src.positioned = false
  let i = gPositioned.find(src)
  if i >= 0:
    gPositioned.delete(i)
  if src.track != nil:
    discard MIX_SetTrack3DPosition(src.track, nil)

proc destroy*(src: Source) =
  ## Stop the source and free its track and audio data.
  if src.positioned:
    let i = gPositioned.find(src)
    if i >= 0:
      gPositioned.delete(i)
    src.positioned = false
  let si = gSources.find(src)
  if si >= 0:
    gSources.delete(si)
  if src.track != nil:
    MIX_DestroyTrack(src.track)
    src.track = nil
  if src.audio != nil:
    MIX_DestroyAudio(src.audio)
    src.audio = nil

# --- master / listener -----------------------------------------------------

proc setVolume*(nim2d: Nim2d, volume: float) =
  ## Master gain applied to everything the mixer outputs.
  if gMixer != nil:
    discard MIX_SetMixerGain(gMixer, volume.cfloat)

proc getVolume*(nim2d: Nim2d): float =
  ## The master gain.
  if gMixer != nil:
    MIX_GetMixerGain(gMixer).float
  else:
    1.0

proc stopAll*(nim2d: Nim2d) =
  ## Stop every playing source at once.
  if gMixer != nil:
    discard MIX_StopAllTracks(gMixer, 0)

proc setListenerPosition*(nim2d: Nim2d, x, y: float, z: float = 0) =
  ## Move the listener. Every positioned source is re-offset so panning follows.
  gListener = (x, y, z)
  for s in gPositioned:
    s.applyPosition()

proc getListenerPosition*(nim2d: Nim2d): tuple[x, y, z: float] =
  ## The current listener position.
  gListener
