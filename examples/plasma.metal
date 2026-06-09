#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct U
{
    float4 u;
};

struct main0_out
{
    float4 fragColor [[color(0)]];
};

struct main0_in
{
    float2 vUV [[user(locn0)]];
    float4 vColor [[user(locn1)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant U& ub [[buffer(0)]], texture2d<float> tex [[texture(0)]], sampler texSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float t = ub.u.x;
    float2 res = float2(ub.u.y, ub.u.z);
    float2 p = (gl_FragCoord.xy / res) * 6.0;
    float v = ((sin(p.x + t) + sin(p.y + t)) + sin((p.x + p.y) + t)) + sin(length(p) + t);
    float3 col = float3(0.5) + (cos(float3(t + v) + float3(0.0, 2.0, 4.0)) * 0.5);
    out.fragColor = (float4(col, 1.0) * in.vColor) * tex.sample(texSmplr, in.vUV);
    return out;
}

