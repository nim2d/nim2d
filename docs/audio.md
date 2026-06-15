# Audio

A sound is a [`Source`](api/audio.md#Source). You load one from a file and then play it, pause it, change its volume and so on. Loading takes a kind: a static source decodes all the way into memory, which suits short effects you play often, and a streaming source decodes as it plays, which suits music. WAV, OGG, MP3, FLAC and tracker files all work, since SDL_mixer does the decoding.

```nim { .annotate }
let music = n2d.newSource("music.ogg", stStream)  # (1)!
let shot = n2d.newSource("shot.wav", stStatic)    # (2)!
music.setLooping(true)                            # (3)!
music.play()                                      # (4)!
```

1.  Load music as a streaming source, decoded as it plays.
2.  Load a short effect as a static source, decoded fully into memory.
3.  Make it repeat when it reaches the end.
4.  Start it.

The controls are what you would expect. [`play`](api/audio.md#play) starts a source, or restarts it if it is already going, [`pause`](api/audio.md#pause) and [`resume`](api/audio.md#resume) hold and continue it, [`stop`](api/audio.md#stop) ends it and rewinds, and [`rewind`](api/audio.md#rewind) and [`seek`](api/audio.md#seek) move the position, with [`tell`](api/audio.md#tell) reporting it in seconds. [`isPlaying`](api/audio.md#isPlaying) and [`isPaused`](api/audio.md#isPaused) report the state, and [`duration`](api/audio.md#duration) is the length in seconds.

[`setVolume`](api/audio.md#setVolume) sets a source's loudness, 0 silent to 1 full, with values above 1 amplifying. [`setPitch`](api/audio.md#setPitch) changes its pitch, which also changes its speed since the two move together, and [`setLooping`](api/audio.md#setLooping) decides whether it repeats. When a source is done for good, [`destroy`](api/audio.md#destroy) stops it and frees its data.

For positional sound, [`setPosition`](api/audio.md#setPosition) places a source in space so it pans left or right and fades with distance, and [`clearPosition`](api/audio.md#clearPosition) turns that off. The listener sits at the origin by default, [`setListenerPosition`](api/audio.md#setListenerPosition) moves it, which shifts every positioned source to match, and [`getListenerPosition`](api/audio.md#getListenerPosition) reads it back. On the engine itself, `setVolume` is the master volume over everything and [`stopAll`](api/audio.md#stopAll) stops every source at once.

```nim
shot.setPosition(playerX - enemyX, 0)
shot.play()
```

If the machine has no audio device, which is the usual case on a build server, audio quietly turns itself off and every call here does nothing, so the same code still runs. [`audioAvailable`](api/audio.md#audioAvailable) tells you whether sound is on.

!!! info "See also"
    The runnable [`audio` example](https://github.com/nim2d/nim2d/blob/master/examples/audio.nim), and the [`audio` API reference](api/audio.md).
