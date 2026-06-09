## A playground for the system, window and mouse controls. It shows what the
## platform reports and lets you drive the window and the cursor from the
## keyboard. ESC quits.

import std/[os, strutils]
import nim2d

const
  W = 760
  H = 560

let n2d = newNim2d("nim2d - system", 100, 80, W.cint, H.cint, (16'u8, 18'u8, 26'u8, 255'u8))
let font = newFont(getAppDir() / "font.ttf", 18)
let fontBig = newFont(getAppDir() / "font.ttf", 26)
let fontSmall = newFont(getAppDir() / "font.ttf", 15)

var
  mx, my = 0.0           # last polled cursor position
  rdx, rdy = 0.0         # accumulated relative motion (when relative mode is on)
  pasted = ""            # last text read from the clipboard
  status = "ready"       # the last action taken
  vsync = true           # vertical sync state

n2d.mousemove = proc(nim2d: Nim2d, x, y, dx, dy: float) =
  mx = x
  my = y
  if nim2d.isRelativeMode():
    rdx += dx
    rdy += dy

n2d.keydown = proc(nim2d: Nim2d, sc: Key) =
  case sc
  of Key.escape: nim2d.running = false
  of Key.f:
    nim2d.setFullscreen(not nim2d.isFullscreen)
    status = "toggled fullscreen"
  of Key.r:
    let on = not nim2d.isRelativeMode()
    nim2d.setRelativeMode(on)
    rdx = 0; rdy = 0
    status = "relative mouse " & (if on: "on" else: "off")
  of Key.g:
    let on = not nim2d.isMouseGrabbed()
    nim2d.setMouseGrabbed(on)
    status = "mouse grab " & (if on: "on" else: "off")
  of Key.h:
    let vis = not isMouseVisible()
    setMouseVisible(vis)
    status = "cursor " & (if vis: "shown" else: "hidden")
  of Key.m: nim2d.minimize(); status = "minimized (restore from the dock)"
  of Key.x: nim2d.maximize(); status = "maximized"
  of Key.z: nim2d.restore(); status = "restored"
  of Key.one: nim2d.setSize(640, 480); status = "resized to 640x480"
  of Key.two: nim2d.setSize(760, 560); status = "resized to 760x560"
  of Key.three: nim2d.setSize(1024, 640); status = "resized to 1024x640"
  of Key.c:
    setClipboardText("nim2d was here")
    status = "copied to the clipboard"
  of Key.v:
    pasted = (if hasClipboardText(): getClipboardText() else: "(empty)")
    status = "pasted from the clipboard"
  of Key.w:
    nim2d.setMousePosition(nim2d.getWidth.float / 2, nim2d.getHeight.float / 2)
    status = "warped the cursor to the center"
  of Key.b:
    nim2d.showMessageBox("nim2d", "A simple message box from love.window.")
    status = "showed a message box"
  of Key.u:
    discard openURL("https://github.com/beshrkayali/nim2d")
    status = "opened the project page in the browser"
  of Key.y:
    vsync = not vsync
    nim2d.setVSync(vsync)
    status = "vsync " & (if vsync: "on" else: "off")
  else: discard

proc kv(y: float, k, v: string) =
  n2d.setColor(120, 140, 190)
  n2d.print(k, 30, y)
  n2d.setColor(225, 230, 240)
  n2d.print(v, 230, y)

n2d.draw = proc(nim2d: Nim2d) =
  let power = getPowerInfo()
  let (dw, dh) = getDesktopDimensions()
  let (ww, wh) = nim2d.getSize()

  nim2d.setFont(fontBig)
  nim2d.setColor(235, 240, 255)
  nim2d.print("system & window", 30, 24)

  nim2d.setFont(font)
  nim2d.setColor(150, 200, 120)
  nim2d.print("SYSTEM", 30, 80)
  kv(108, "os", getOS())
  kv(134, "cpu cores", $getProcessorCount())
  kv(160, "power", power.state & "  " &
      (if power.percent >= 0: $power.percent & "%" else: "n/a"))
  kv(186, "desktop", $dw & " x " & $dh)

  nim2d.setColor(150, 200, 120)
  nim2d.print("WINDOW", 30, 232)
  kv(260, "size", $ww & " x " & $wh)
  kv(286, "fullscreen", (if nim2d.isFullscreen: "yes" else: "no"))
  kv(312, "dpi/vsync/fps", formatFloat(nim2d.getDPIScale, ffDecimal, 2) &
      "  " & (if vsync: "vsync" else: "no-vsync") & "  " & $int(nim2d.getFPS))

  nim2d.setColor(150, 200, 120)
  nim2d.print("MOUSE", 30, 332)
  if nim2d.isRelativeMode():
    kv(360, "relative", "on   d = " & $rdx.int & ", " & $rdy.int)
  else:
    kv(360, "position", $mx.int & ", " & $my.int)
  kv(386, "grabbed", (if nim2d.isMouseGrabbed: "yes" else: "no"))
  kv(412, "cursor", (if isMouseVisible(): "shown" else: "hidden"))
  kv(438, "clipboard", (if pasted.len > 0: pasted else: "(press V to read)"))

  nim2d.setColor(255, 210, 120)
  nim2d.print(status, 30, 482)

  nim2d.setFont(fontSmall)
  nim2d.setColor(120, 130, 160)
  nim2d.print("F fullscreen   Y vsync   R relative   G grab   H cursor   W warp   B msgbox", 30, 514)
  nim2d.print("M/X/Z minimize maximize restore   1/2/3 resize   C copy   V paste   U url", 30, 532)

n2d.play()
