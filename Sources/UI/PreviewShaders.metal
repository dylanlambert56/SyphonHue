#include <metal_stdlib>
using namespace metal;

struct VOut {
    float4 position [[position]];
    float2 uv;
};

vertex VOut preview_vs(uint vid [[vertex_id]]) {
    float2 verts[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0),
    };
    float2 uvs[4] = {
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 1.0),
    };
    VOut o;
    o.position = float4(verts[vid], 0.0, 1.0);
    o.uv = uvs[vid];
    return o;
}

fragment float4 preview_fs(VOut in [[stage_in]],
                           texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    return tex.sample(s, in.uv);
}
