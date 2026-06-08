# Build configuration for nim2d (Nim 2.x + SDL3 / SDL_GPU).
#
# The dinau/sdl3_nim binding loads SDL via a `dynlib` pragma. We override that so
# SDL3 and the satellite libraries link directly instead of being dlopen'd, which
# also means the dynamic library name does not have to match the platform. The
# libraries must be present at build time.
#
# The install prefix defaults to the usual per-platform location but can be
# pointed elsewhere with the NIM2D_SDL_PREFIX environment variable, which is how
# CI builds against a prefix it controls.

switch("path", "src")
switch("mm", "orc")
switch("threads", "on")   # for the thread module; on by default, set for clarity

proc linkSdl(prefix: string) =
  switch("dynlibOverride", "SDL3")
  switch("dynlibOverride", "SDL3_image")
  switch("dynlibOverride", "SDL3_ttf")
  switch("dynlibOverride", "SDL3_mixer")
  switch("passC", "-I" & prefix & "/include")
  switch("passL", "-L" & prefix & "/lib")
  switch("passL", "-lSDL3")
  switch("passL", "-lSDL3_image")
  switch("passL", "-lSDL3_ttf")
  switch("passL", "-lSDL3_mixer")

when defined(macosx):
  linkSdl(getEnv("NIM2D_SDL_PREFIX", "/opt/homebrew"))
elif defined(windows):
  linkSdl(getEnv("NIM2D_SDL_PREFIX", "C:/sdl3"))
elif defined(linux):
  linkSdl(getEnv("NIM2D_SDL_PREFIX", "/usr/local"))
