#include <metal_stdlib>
using namespace metal;
#include "../Utils/Types.metal"

kernel void edge_detection_compute(texture2d<float, access::read> inTexture [[texture(0)]],
                                   texture2d<float, access::write> outTexture [[texture(1)]],
                                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) { return; }

    float3x3 sobelX = float3x3(-1, 0, 1,
                               -2, 0, 2,
                               -1, 0, 1);
    float3x3 sobelY = float3x3(-1, -2, -1,
                                0,  0,  0,
                                1,  2,  1);

    float3 gx = float3(0.0);
    float3 gy = float3(0.0);

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

    float3 magnitude = sqrt(gx * gx + gy * gy);
    float gray = dot(magnitude, float3(0.299, 0.587, 0.114));
    outTexture.write(float4(gray, gray, gray, 1.0), gid);
}


