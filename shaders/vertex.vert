// Built-in batch-renderer vertex shader. One source, compiled offline to SPIR-V
// (Vulkan) and MSL (Metal) by `make shaders`. The set/binding numbers follow the
// SDL_GPU resource model: vertex uniform buffers live in descriptor set 1.
#version 450

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec4 color;

layout(location = 0) out vec2 vUV;
layout(location = 1) out vec4 vColor;

layout(set = 1, binding = 0) uniform Uniforms {
  mat4 mvp;
} u;

void main() {
  gl_Position = u.mvp * vec4(position, 0.0, 1.0);
  vUV = uv;
  vColor = color;
}
