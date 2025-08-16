#include <metal_stdlib>
using namespace metal;
#include "../Utils/Types.metal"
#include "../Utils/Color.metal"

// Basic vertex for textured quads
vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// Color utils moved to ../Utils/Color.metal

// Simple passthrough
fragment float4 passthrough_fragment(VertexOut in [[stage_in]],
                                     texture2d<float> inputTexture [[texture(0)]]) {
    constexpr sampler s(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    return inputTexture.sample(s, in.texCoord);
}

// Color correction fragment
// ColorCorrectionParams moved to ../Utils/Types.metal

fragment float4 color_correction_fragment(VertexOut in [[stage_in]],
                                          texture2d<float> inputTexture [[texture(0)]],
                                          constant ColorCorrectionParams& params [[buffer(0)]]) {
    constexpr sampler s(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    float4 color = inputTexture.sample(s, in.texCoord);

    color.rgb *= pow(2.0, params.exposure);
    color.rgb += params.brightness;
    color.rgb = max(color.rgb, 0.0);
    color.rgb = pow(color.rgb + params.lift, 1.0 / params.gamma) * params.gain;
    color.rgb = (color.rgb - 0.5) * params.contrast + 0.5;
    float3 gray = float3(dot(color.rgb, float3(0.299, 0.587, 0.114)));
    color.rgb = mix(gray, color.rgb, params.saturation);

    if (params.temperature != 0.0) {
        float temp = params.temperature * 0.1;
        if (temp > 0.0) {
            color.r *= 1.0 + temp;
            color.b *= 1.0 - temp * 0.5;
        } else {
            color.r *= 1.0 + temp * 0.5;
            color.b *= 1.0 - temp;
        }
    }
    return color;
}

// UI-only pipeline
vertex VertexOut ui_vertex(constant float2* positions [[buffer(0)]],
                           uint vid [[vertex_id]]) {
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.texCoord = positions[vid];
    return out;
}

fragment float4 ui_fragment(VertexOut in [[stage_in]],
                            constant float4& color [[buffer(0)]]) {
    return color;
}

fragment float4 ui_texture_fragment(VertexOut in [[stage_in]],
                                    texture2d<float> texture [[texture(0)]],
                                    constant float4& tintColor [[buffer(0)]]) {
    constexpr sampler s(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    float4 texColor = texture.sample(s, in.texCoord);
    return texColor * tintColor;
}

// Node quad vertex for rounded-rectangle nodes
vertex VertexOut ui_node_vertex(constant UINodeVertex* vertices [[buffer(0)]],
                                uint vid [[vertex_id]]) {
    VertexOut out;
    out.position = float4(vertices[vid].position, 0.0, 1.0);
    out.texCoord = vertices[vid].uv;
    return out;
}

// Rounded rectangle fragment. 'radius' is in UV units (0..0.5 typical)
fragment float4 ui_rounded_rect_fragment(VertexOut in [[stage_in]],
                                         constant float4& color [[buffer(0)]],
                                         constant float& radius [[buffer(1)]]) {
    float2 uv = in.texCoord; // expected 0..1
    float2 q = abs(uv - 0.5);
    float2 box = float2(0.5 - radius);
    float2 d = max(q - box, 0.0);
    float dist = length(d) - radius;
    float alpha = dist <= 0.0 ? color.a : 0.0;
    return float4(color.rgb, alpha);
}


