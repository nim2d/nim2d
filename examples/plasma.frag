// Fragment shader for the shader example, authored once in GLSL and compiled
// offline to plasma.spv (Vulkan), plasma.metal (Metal) and plasma.dxil (Direct3D
// 12) so the example runs cross-platform. Regenerate with the same tools as the
// built-in shaders (the DXIL step needs a DXC-enabled shadercross):
//   glslc       -fshader-stage=fragment plasma.frag -o plasma.spv
//   shadercross plasma.spv -s SPIRV -d MSL  -t fragment -e main -o plasma.metal
//   shadercross plasma.spv -s SPIRV -d DXIL -t fragment -e main -o plasma.dxil
//
// The vertex stage hands `vUV` at location 0 and `vColor` at location 1; the
// uniform (set 3) holds time in x and the resolution in y, z.
#version 450

layout(location = 0) in vec2 vUV;
layout(location = 1) in vec4 vColor;
layout(location = 0) out vec4 fragColor;

layout(set = 2, binding = 0) uniform sampler2D tex;
layout(set = 3, binding = 0) uniform U { vec4 u; } ub;

void main() {
  float t = ub.u.x;
  vec2 res = vec2(ub.u.y, ub.u.z);
  vec2 p = gl_FragCoord.xy / res * 6.0;
  float v = sin(p.x + t) + sin(p.y + t) + sin((p.x + p.y) + t) + sin(length(p) + t);
  vec3 col = 0.5 + 0.5 * cos(t + v + vec3(0.0, 2.0, 4.0));
  fragColor = vec4(col, 1.0) * vColor * texture(tex, vUV);
}
