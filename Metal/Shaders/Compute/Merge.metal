#include <metal_stdlib>
using namespace metal;
#include "../Utils/Types.metal"

enum BlendMode : uint {
    NORMAL = 0,
    MULTIPLY = 1,
    SCREEN = 2,
    OVERLAY = 3,
    SOFT_LIGHT = 4,
    HARD_LIGHT = 5,
    ADD = 6,
    SUBTRACT = 7
};

// MergeParams is defined in ../Utils/Types.metal

float3 blendMultiply(float3 base, float3 blend) { return base * blend; }
float3 blendScreen(float3 base, float3 blend)  { return 1.0 - (1.0 - base) * (1.0 - blend); }
float3 blendOverlay(float3 base, float3 blend) { return select(1.0 - 2.0 * (1.0 - base) * (1.0 - blend), 2.0 * base * blend, base < 0.5); }
float3 blendSoftLight(float3 base, float3 blend) { return select(sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend), 2.0 * base * blend + base * base * (1.0 - 2.0 * blend), base < 0.5); }
float3 blendHardLight(float3 base, float3 blend) { return select(1.0 - 2.0 * (1.0 - base) * (1.0 - blend), 2.0 * base * blend, blend < 0.5); }

fragment float4 merge_fragment(float4 position [[position]],
                               float2 texCoord [[user(texcoord)]],
                               texture2d<float> baseTexture [[texture(0)]],
                               texture2d<float> overlayTexture [[texture(1)]],
                               constant MergeParams& params [[buffer(0)]]) {
    constexpr sampler s(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    float2 overlayCoord = (texCoord - 0.5) / params.scale + 0.5 + params.offset;
    float4 base = baseTexture.sample(s, texCoord);
    float4 overlay = overlayTexture.sample(s, overlayCoord);
    float3 result;
    switch (params.blendMode) {
        case MULTIPLY:   result = blendMultiply(base.rgb, overlay.rgb); break;
        case SCREEN:     result = blendScreen(base.rgb, overlay.rgb); break;
        case OVERLAY:    result = blendOverlay(base.rgb, overlay.rgb); break;
        case SOFT_LIGHT: result = blendSoftLight(base.rgb, overlay.rgb); break;
        case HARD_LIGHT: result = blendHardLight(base.rgb, overlay.rgb); break;
        case ADD:        result = base.rgb + overlay.rgb; break;
        case SUBTRACT:   result = base.rgb - overlay.rgb; break;
        default:         result = overlay.rgb; break; // NORMAL
    }
    float finalAlpha = overlay.a * params.opacity;
    float3 finalColor = mix(base.rgb, result, finalAlpha);
    return float4(finalColor, max(base.a, finalAlpha));
}


