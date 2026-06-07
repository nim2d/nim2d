# Build configuration for nim2d (Nim 2.x + SDL3 / SDL_GPU).
#
# The dinau/sdl3_nim binding loads SDL via `dynlib "libSDL3.so"`, which does not
# exist on macOS (the library is libSDL3.dylib). We therefore link SDL3 (and the
# satellite libs) directly with --dynlibOverride instead of dlopen-ing them.

switch("path", "src")
switch("mm", "orc")

when defined(macosx):
  const brew = "/opt/homebrew"
  switch("dynlibOverride", "SDL3")
  switch("dynlibOverride", "SDL3_image")
  switch("dynlibOverride", "SDL3_ttf")
  switch("passC", "-I" & brew & "/include")
  switch("passL", "-L" & brew & "/lib")
  switch("passL", "-lSDL3")
  switch("passL", "-lSDL3_image")
  switch("passL", "-lSDL3_ttf")
elif defined(linux):
  # CI / Linux: SDL3 is typically installed under /usr/local (built from source).
  switch("dynlibOverride", "SDL3")
  switch("dynlibOverride", "SDL3_image")
  switch("dynlibOverride", "SDL3_ttf")
  switch("passC", "-I/usr/local/include")
  switch("passL", "-L/usr/local/lib -lSDL3 -lSDL3_image -lSDL3_ttf")
