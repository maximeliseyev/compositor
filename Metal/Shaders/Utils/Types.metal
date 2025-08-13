#include <metal_stdlib>
using namespace metal;

// Shared vertex I/O for UI pipelines
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// UI node vertex layout for rounded-rect rendering
struct UINodeVertex {
    float2 position; // NDC
    float2 uv;       // 0..1 across the quad
};

// Parameter blocks
struct BlurParams {
    float radius;
    float2 direction;      // (1,0) for horizontal, (0,1) for vertical
    float2 textureSize;
    int samples;
};

struct ColorCorrectionParams {
    float exposure;
    float contrast;
    float saturation;
    float3 gamma;
    float3 lift;
    float3 gain;
    float temperature;
    float brightness;
};

struct MergeParams {
    float opacity;
    uint blendMode;
    float2 offset;
    float2 scale;
};


