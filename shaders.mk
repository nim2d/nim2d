# Built-in shader compilation, included by the main Makefile so `make shaders`
# works. The shaders are authored in GLSL under shaders/ and compiled to SPIR-V
# (Vulkan) and MSL (Metal) blobs in src/nim2d/backend/shaders/, which are
# committed. This only runs when a shader source changes; an ordinary build uses
# the committed blobs and needs none of the tools below.
#
# It needs glslc (from shaderc: `brew install shaderc`) and the SDL_shadercross
# CLI. shadercross has no Homebrew package, so build it from source once. We only
# target Metal and Vulkan, so the DirectX compiler is left off, which keeps the
# build small (DXC is huge). Build SPIRV-Cross first, then shadercross against it:
#
#   git clone --depth 1 https://github.com/KhronosGroup/SPIRV-Cross
#   cmake -S SPIRV-Cross -B SPIRV-Cross/build -DCMAKE_BUILD_TYPE=Release \
#     -DSPIRV_CROSS_SHARED=ON -DSPIRV_CROSS_ENABLE_TESTS=OFF \
#     -DCMAKE_INSTALL_PREFIX=/tmp/scprefix
#   cmake --build SPIRV-Cross/build && cmake --install SPIRV-Cross/build
#
#   git clone --depth 1 https://github.com/libsdl-org/SDL_shadercross
#   cmake -S SDL_shadercross -B SDL_shadercross/build -DCMAKE_BUILD_TYPE=Release \
#     -DSDLSHADERCROSS_DXC=OFF -DSDLSHADERCROSS_VENDORED=OFF \
#     -DSDLSHADERCROSS_CLI=ON -DSDLSHADERCROSS_SHARED=OFF -DSDLSHADERCROSS_STATIC=ON \
#     -DSDLSHADERCROSS_INSTALL=OFF -DCMAKE_PREFIX_PATH="/tmp/scprefix;/opt/homebrew"
#   cmake --build SDL_shadercross/build
#
# Then point make at the CLI and the SPIRV-Cross runtime library (on macOS the
# CLI loads libspirv-cross-c-shared from there):
#
#   SHADERCROSS=/abs/path/SDL_shadercross/build/shadercross \
#   DYLD_LIBRARY_PATH=/tmp/scprefix/lib \
#   make shaders

.PHONY: shaders

shaders:
	bash bin/gen-shaders.sh
