// Built-in textured fragment shader: sample the texture, tint by vertex color.
// The combined sampler lives in descriptor set 2 (fragment samplers) per the
// SDL_GPU resource model.
#version 450

layout(location = 0) in vec2 vUV;
layout(location = 1) in vec4 vColor;

layout(location = 0) out vec4 fragColor;

layout(set = 2, binding = 0) uniform sampler2D tex;

void main() {
  fragColor = texture(tex, vUV) * vColor;
}
