## Built-in shaders for the 2D batch renderer.
##
## These are Metal Shading Language (MSL) sources, compiled at runtime by the
## Metal backend of SDL_GPU.
##
## A couple of conventions come from the SDL_GPU Metal resource model. Vertex
## attributes come in via [[stage_in]], from the pipeline layout. Uniform buffers
## start at [[buffer(0)]]. Fragment textures sit at [[texture(0)]] and samplers
## at [[sampler(0)]].

const VertexShaderMSL* = """
#include <metal_stdlib>
using namespace metal;

struct VSInput {
    float2 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
    float4 color    [[attribute(2)]];
};
struct VSOutput {
    float4 position [[position]];
    float2 uv;
    float4 color;
};
struct Uniforms { float4x4 mvp; };

vertex VSOutput vertexMain(VSInput in [[stage_in]],
                           constant Uniforms& u [[buffer(0)]]) {
    VSOutput out;
    out.position = u.mvp * float4(in.position, 0.0, 1.0);
    out.uv = in.uv;
    out.color = in.color;
    return out;
}
"""

const FragmentColorMSL* = """
#include <metal_stdlib>
using namespace metal;

struct VSOutput {
    float4 position [[position]];
    float2 uv;
    float4 color;
};

fragment float4 fragmentColor(VSOutput in [[stage_in]]) {
    return in.color;
}
"""

const FragmentTextureMSL* = """
#include <metal_stdlib>
using namespace metal;

struct VSOutput {
    float4 position [[position]];
    float2 uv;
    float4 color;
};

fragment float4 fragmentTexture(VSOutput in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                sampler samp [[sampler(0)]]) {
    return tex.sample(samp, in.uv) * in.color;
}
"""
