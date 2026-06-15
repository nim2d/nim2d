# Scene

A game is rarely one screen. There is a title, the play field, a pause overlay, a game-over screen, and each wants its own update, draw and input. Folding all of that into a single set of callbacks behind a mode variable turns into a tangle of `if mode == ...` before long. The scene module keeps each screen separate. Each is a [`Scene`](api/scene.md#Scene) with its own state and behavior, and a [`SceneManager`](api/scene.md#SceneManager) decides which one is live and hands it the engine's callbacks. It is opt-in, imported on its own with `import nim2d/scene`, and the core engine does not pull it in.

## Making a scene

A scene is a `ref object of` [`Scene`](api/scene.md#Scene). Give it whatever fields it needs to hold its state, then override the methods for the behavior you want. Every method has a do-nothing default, so a scene only defines the ones it uses.

```nim { .annotate }
import nim2d
import nim2d/scene

type TitleScene = ref object of Scene  # (1)!
  t: float

method enter(s: TitleScene, n: Nim2d) =  # (2)!
  s.t = 0.0

method update(s: TitleScene, n: Nim2d, dt: float) =  # (3)!
  s.t += dt

method draw(s: TitleScene, n: Nim2d) =  # (4)!
  n.clear(14, 16, 28)
  n.print("press Enter to play", 200, 280)

method keydown(s: TitleScene, n: Nim2d, key: Key) =  # (5)!
  if key == Key.enter:
    scenes.switch(PlayScene())
```

1.  Subclass `Scene` and add the fields this screen needs.
2.  Setup hook; here it resets the timer as the scene starts.
3.  Runs each frame; advances the timer by `dt`.
4.  Runs each frame to paint the screen.
5.  Key press while this scene is on top; here it asks the manager to switch.

`enter` and `leave` are the setup and teardown hooks, called as a scene comes and goes. `update` and `draw` run each frame. The input methods, `keydown`, `keyup`, `mousepressed`, `mousereleased`, `mousemove`, `mousewheel`, `textinput` and the three gamepad ones, mirror the engine callbacks one for one, with the scene as the first argument and the engine as the second.

## Wiring the manager

[`newSceneManager`](api/scene.md#newSceneManager) takes the engine and points its update, draw and input callbacks at the scene stack. After that the live scene gets everything on its own, and you do not set those callbacks yourself.

A scene reaches the manager to ask for a change, a [`switch`](api/scene.md#switch) or a [`push`](api/scene.md#push), so in a single-file program the manager is usually a module-level `var` the scenes can see. Assign it, then push the first scene, so the var is live by the time that scene's `enter` runs.

```nim { .annotate }
var scenes: SceneManager  # (1)!
# ... your scene types and their methods ...

scenes = newSceneManager(n2d)  # (2)!
scenes.push(TitleScene())  # (3)!
n2d.play()  # (4)!
```

1.  Module-level so every scene can reach the manager.
2.  Points the engine's update, draw and input at the scene stack.
3.  Pushes the first scene, so its `enter` runs now.
4.  Hands control to the engine's main loop.

`newSceneManager` also takes an optional scene to start with, but that scene's `enter` runs before the manager comes back, so push the first scene yourself like this whenever its `enter` needs to reach the manager.

## Switching, pushing and popping

The manager holds a stack of scenes, and there are three ways to change it.

[`switch`](api/scene.md#switch) replaces the top scene. The old one gets `leave`, the new one gets `enter`. This is the plain move from one screen to another, the title to the play field.

[`push`](api/scene.md#push) lays a new scene on top without removing the one below, and [`pop`](api/scene.md#pop) drops back to it. The scene underneath stays in the stack, which is what a pause screen wants, push it over the game and pop it to resume.

```nim
scenes.push(PauseScene())   # over the game
scenes.pop()                # back to the game
```

The top scene is the one that gets update and input. Draw works differently. It runs over the whole stack from the bottom up, so every scene draws, lowest first. A pushed scene that does not clear the screen shows the scene beneath it, which is how a pause panel appears over the still-visible game. A scene that does clear, as a title or a play scene would, simply paints over whatever was under it.

[`current`](api/scene.md#current) gives the live scene or `nil`, [`count`](api/scene.md#count) is how many are stacked, and [`clear`](api/scene.md#clear) empties the stack, calling `leave` on each from the top down.

The scene example puts this together with a title, a play field and a pause overlay, switching from the title into the game and pushing the pause screen over it.

!!! info "See also"
    The runnable [`scene` example](https://github.com/nim2d/nim2d/blob/master/examples/scene.nim), and the [`scene` API reference](api/scene.md).
