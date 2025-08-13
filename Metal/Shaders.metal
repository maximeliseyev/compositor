//
//  VertexIn.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 12.08.2025.
//


#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Input/Output Structures

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Parameter Structures

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

// MARK: - Basic Vertex Shader

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Utility Functions

float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// MARK: - Basic Fragment Shaders

// Passthrough shader
fragment float4 passthrough_fragment(VertexOut in [[stage_in]],
                                   texture2d<float> inputTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear,
                                   address::clamp_to_edge);
    return inputTexture.sample(textureSampler, in.texCoord);
}

// Color correction shader
fragment float4 color_correction_fragment(VertexOut in [[stage_in]],
                                        texture2d<float> inputTexture [[texture(0)]],
                                        constant ColorCorrectionParams& params [[buffer(0)]]) {
    
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear,
                                   address::clamp_to_edge);
    float4 color = inputTexture.sample(textureSampler, in.texCoord);
    
    // Exposure
    color.rgb *= pow(2.0, params.exposure);
    
    // Brightness
    color.rgb += params.brightness;
    
    // Lift/Gamma/Gain (LGG color grading)
    color.rgb = max(color.rgb, 0.0);
    color.rgb = pow(color.rgb + params.lift, 1.0 / params.gamma) * params.gain;
    
    // Contrast
    color.rgb = (color.rgb - 0.5) * params.contrast + 0.5;
    
    // Saturation
    float3 gray = float3(dot(color.rgb, float3(0.299, 0.587, 0.114)));
    color.rgb = mix(gray, color.rgb, params.saturation);
    
    // Color temperature
    if (params.temperature != 0.0) {
        float temp = params.temperature * 0.1;
        if (temp > 0.0) {
            // Warmer
            color.r *= 1.0 + temp;
            color.b *= 1.0 - temp * 0.5;
        } else {
            // Cooler
            color.r *= 1.0 + temp * 0.5;
            color.b *= 1.0 - temp;
        }
    }
    
    return color;
}

// MARK: - Blend Mode Functions

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

float3 blendMultiply(float3 base, float3 blend) {
    return base * blend;
}

float3 blendScreen(float3 base, float3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

float3 blendOverlay(float3 base, float3 blend) {
    return select(
        1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
        2.0 * base * blend,
        base < 0.5
    );
}

float3 blendSoftLight(float3 base, float3 blend) {
    return select(
        sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend),
        2.0 * base * blend + base * base * (1.0 - 2.0 * blend),
        base < 0.5
    );
}

float3 blendHardLight(float3 base, float3 blend) {
    return select(
        1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
        2.0 * base * blend,
        blend < 0.5
    );
}

// Merge/Composite shader
fragment float4 merge_fragment(VertexOut in [[stage_in]],
                              texture2d<float> baseTexture [[texture(0)]],
                              texture2d<float> overlayTexture [[texture(1)]],
                              constant MergeParams& params [[buffer(0)]]) {
    
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear,
                                   address::clamp_to_edge);
    
    // Apply offset and scale to overlay texture coordinates
    float2 overlayCoord = (in.texCoord - 0.5) / params.scale + 0.5 + params.offset;
    
    float4 base = baseTexture.sample(textureSampler, in.texCoord);
    float4 overlay = overlayTexture.sample(textureSampler, overlayCoord);
    
    float3 result;
    
    switch (params.blendMode) {
        case MULTIPLY:
            result = blendMultiply(base.rgb, overlay.rgb);
            break;
        case SCREEN:
            result = blendScreen(base.rgb, overlay.rgb);
            break;
        case OVERLAY:
            result = blendOverlay(base.rgb, overlay.rgb);
            break;
        case SOFT_LIGHT:
            result = blendSoftLight(base.rgb, overlay.rgb);
            break;
        case HARD_LIGHT:
            result = blendHardLight(base.rgb, overlay.rgb);
            break;
        case ADD:
            result = base.rgb + overlay.rgb;
            break;
        case SUBTRACT:
            result = base.rgb - overlay.rgb;
            break;
        default: // NORMAL
            result = overlay.rgb;
            break;
    }
    
    // Alpha blending with opacity
    float finalAlpha = overlay.a * params.opacity;
    float3 finalColor = mix(base.rgb, result, finalAlpha);
    
    return float4(finalColor, max(base.a, finalAlpha));
}

// MARK: - Compute Shaders

// Gaussian blur compute shader
kernel void gaussian_blur_compute(texture2d<float, access::read> inTexture [[texture(0)]],
                                 texture2d<float, access::write> outTexture [[texture(1)]],
                                 constant BlurParams& params [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float4 color = float4(0.0);
    float totalWeight = 0.0;
    
    int radius = int(params.radius);
    float2 texelSize = 1.0 / params.textureSize;
    
    // Gaussian blur in specified direction
    for (int i = -radius; i <= radius; i++) {
        float2 offset = params.direction * float(i) * texelSize;
        float2 sampleCoord = (float2(gid) + 0.5) / params.textureSize + offset;
        
        // Clamp coordinates to texture bounds
        sampleCoord = clamp(sampleCoord, 0.0, 1.0);
        
        // Calculate sample position in texture coordinates
        uint2 samplePos = uint2(sampleCoord * params.textureSize);
        
        // Ensure we don't go out of bounds
        samplePos.x = min(samplePos.x, inTexture.get_width() - 1);
        samplePos.y = min(samplePos.y, inTexture.get_height() - 1);
        
        // Gaussian weight
        float weight = exp(-(float(i * i)) / (2.0 * params.radius * params.radius));
        
        color += inTexture.read(samplePos) * weight;
        totalWeight += weight;
    }
    
    outTexture.write(color / totalWeight, gid);
}

// Fast box blur compute shader (alternative to Gaussian)
kernel void box_blur_compute(texture2d<float, access::read> inTexture [[texture(0)]],
                            texture2d<float, access::write> outTexture [[texture(1)]],
                            constant BlurParams& params [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float4 color = float4(0.0);
    int sampleCount = 0;
    
    int radius = int(params.radius);
    
    // Box blur in specified direction
    for (int i = -radius; i <= radius; i++) {
        int2 samplePos = int2(gid) + int2(params.direction * float(i));
        
        // Clamp to texture bounds
        samplePos.x = clamp(samplePos.x, 0, int(inTexture.get_width()) - 1);
        samplePos.y = clamp(samplePos.y, 0, int(inTexture.get_height()) - 1);
        
        color += inTexture.read(uint2(samplePos));
        sampleCount++;
    }
    
    outTexture.write(color / float(sampleCount), gid);
}

// Edge detection compute shader
kernel void edge_detection_compute(texture2d<float, access::read> inTexture [[texture(0)]],
                                  texture2d<float, access::write> outTexture [[texture(1)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    // Sobel edge detection kernel
    float3x3 sobelX = float3x3(
        -1, 0, 1,
        -2, 0, 2,
        -1, 0, 1
    );
    
    float3x3 sobelY = float3x3(
        -1, -2, -1,
         0,  0,  0,
         1,  2,  1
    );
    
    float3 gx = float3(0.0);
    float3 gy = float3(0.0);
    
    // Apply convolution
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            int2 coord = int2(gid) + int2(x, y);
            coord.x = clamp(coord.x, 0, int(inTexture.get_width()) - 1);
            coord.y = clamp(coord.y, 0, int(inTexture.get_height()) - 1);
            
            float3 sample = inTexture.read(uint2(coord)).rgb;
            
            gx += sample * sobelX[y + 1][x + 1];
            gy += sample * sobelY[y + 1][x + 1];
        }
    }
    
    // Calculate magnitude
    float3 magnitude = sqrt(gx * gx + gy * gy);
    float gray = dot(magnitude, float3(0.299, 0.587, 0.114));
    
    outTexture.write(float4(gray, gray, gray, 1.0), gid);
}

// Simple noise generator
kernel void noise_compute(texture2d<float, access::write> outTexture [[texture(0)]],
                         constant float& time [[buffer(0)]],
                         constant float& scale [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float2 coord = float2(gid) * scale + time;
    
    // Simple pseudo-random noise function
    float noise = fract(sin(dot(coord, float2(12.9898, 78.233))) * 43758.5453);
    
    outTexture.write(float4(noise, noise, noise, 1.0), gid);
}

// MARK: - UI Shaders

// UI vertex shader
vertex VertexOut ui_vertex(constant float2* positions [[buffer(0)]],
                          uint vid [[vertex_id]]) {
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.texCoord = positions[vid];
    return out;
}

// UI fragment shader
fragment float4 ui_fragment(VertexOut in [[stage_in]],
                           constant float4& color [[buffer(0)]]) {
    return color;
}

// UI fragment shader with texture
fragment float4 ui_texture_fragment(VertexOut in [[stage_in]],
                                   texture2d<float> texture [[texture(0)]],
                                   constant float4& tintColor [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear,
                                   address::clamp_to_edge);
    
    float4 texColor = texture.sample(textureSampler, in.texCoord);
    return texColor * tintColor;
}
