// Built-in solid-color fragment shader: just the interpolated vertex color.
#version 450

layout(location = 0) in vec2 vUV;
layout(location = 1) in vec4 vColor;

layout(location = 0) out vec4 fragColor;

void main() {
  fragColor = vColor;
}
