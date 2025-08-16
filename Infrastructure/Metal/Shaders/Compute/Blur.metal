#include <metal_stdlib>
using namespace metal;
#include "../Utils/Types.metal"

kernel void gaussian_blur_compute(texture2d<float, access::read> inTexture [[texture(0)]],
                                  texture2d<float, access::write> outTexture [[texture(1)]],
                                  constant BlurParams& params [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) { return; }
    float4 color = float4(0.0);
    float totalWeight = 0.0;
    int radius = int(params.radius);
    float2 texelSize = 1.0 / params.textureSize;
    for (int i = -radius; i <= radius; i++) {
        float2 offset = params.direction * float(i) * texelSize;
        float2 sampleCoord = (float2(gid) + 0.5) / params.textureSize + offset;
        sampleCoord = clamp(sampleCoord, 0.0, 1.0);
        uint2 samplePos = uint2(sampleCoord * params.textureSize);
        samplePos.x = min(samplePos.x, inTexture.get_width() - 1);
        samplePos.y = min(samplePos.y, inTexture.get_height() - 1);
        float weight = exp(-(float(i * i)) / (2.0 * params.radius * params.radius));
        color += inTexture.read(samplePos) * weight;
        totalWeight += weight;
    }
    outTexture.write(color / totalWeight, gid);
}

kernel void box_blur_compute(texture2d<float, access::read> inTexture [[texture(0)]],
                             texture2d<float, access::write> outTexture [[texture(1)]],
                             constant BlurParams& params [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) { return; }
    float4 color = float4(0.0);
    int sampleCount = 0;
    int radius = int(params.radius);
    for (int i = -radius; i <= radius; i++) {
        int2 samplePos = int2(gid) + int2(params.direction * float(i));
        samplePos.x = clamp(samplePos.x, 0, int(inTexture.get_width()) - 1);
        samplePos.y = clamp(samplePos.y, 0, int(inTexture.get_height()) - 1);
        color += inTexture.read(uint2(samplePos));
        sampleCount++;
    }
    outTexture.write(color / float(sampleCount), gid);
}


