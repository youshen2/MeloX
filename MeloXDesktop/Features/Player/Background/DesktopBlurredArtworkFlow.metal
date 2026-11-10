#include <metal_stdlib>
using namespace metal;

// GPL-3.0: lladlam/MeloX-Android 9f496319,
// MeloXFlowingLightBackdrop.kt / fillFlowingMeshPixels (constant-flow path).
[[ stitchable ]] half4 desktopBlurredArtworkFlow(
    float2 position, half4 color, float2 size, float phase,
    device const float *values, int count, float saturation, float radius) {
    if (count < 48) return color;
    float2 uv = position / max(size, float2(1));
    float u = uv.x, v = uv.y, t = phase;
    float warpX = sin(v * 3.1 + t) * cos(u * 2.3 - t * .75)
        + .5 * sin((u + v) * 4.9 - t * 1.25);
    float warpY = cos(u * 2.9 - t) * sin(v * 2.6 + t * .5)
        + .5 * cos((u - v) * 5.4 + t);
    float sampleU = u + .15 * warpX;
    float sampleV = v + .15 * warpY;
    sampleU += .15 * .28 * sin(sampleV * 6.7 - t * 1.5);
    sampleV += .15 * .28 * cos(sampleU * 7.1 + t * 1.5);
    float total = .16;
    float3 rgb = float3(values[27], values[28], values[29]) * total;
    // Android's high-quality 48 x 110 field, stretched to the viewport.
    float2 scale = float2(48.0 / 110.0, 1) / max(radius, .01);
    for (int i = 0; i < 9; ++i) {
        float2 center(values[30 + i * 2], values[31 + i * 2]);
        float2 d = (float2(sampleU, sampleV) - center) * scale;
        float falloff = 1 / (1 + dot(d, d) * 4.5);
        float weight = falloff * falloff;
        rgb += float3(values[i * 3], values[i * 3 + 1], values[i * 3 + 2]) * weight;
        total += weight;
    }
    rgb /= total;
    float luminance = dot(rgb, float3(.2126, .7152, .0722));
    rgb = luminance + (rgb - luminance) * saturation;
    return half4(half3(clamp(rgb, 0.0, 1.0)), 1) * color.a;
}
