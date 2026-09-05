#include <metal_stdlib>
using namespace metal;

static float2 appleMusicWarpSlice(
    device const ushort2 *field,
    uint dimension,
    uint phase,
    float2 grid
) {
    uint2 lower = uint2(floor(grid));
    uint2 upper = min(lower + 1u, uint2(dimension - 1u));
    float2 fraction = fract(grid);
    uint offset = phase * dimension * dimension;
    return mix(
        mix(float2(field[offset + lower.y * dimension + lower.x]),
            float2(field[offset + lower.y * dimension + upper.x]), fraction.x),
        mix(float2(field[offset + upper.y * dimension + lower.x]),
            float2(field[offset + upper.y * dimension + upper.x]), fraction.x),
        fraction.y
    ) / 65535.0f;
}

static float2 appleMusicWarpCoordinates(
    float2 destination,
    float weight,
    float2 fieldSize,
    device const ushort2 *field
) {
    uint dimension = uint(fieldSize.x);
    float phase = clamp(weight, 0.0f, 1.0f) * (fieldSize.y - 1.0f);
    uint lower = uint(floor(phase));
    uint upper = min(lower + 1u, uint(fieldSize.y) - 1u);
    float2 grid = clamp(destination, 0.0f, 1.0f) * float(dimension - 1u);
    return mix(
        appleMusicWarpSlice(field, dimension, lower, grid),
        appleMusicWarpSlice(field, dimension, upper, grid),
        fract(phase)
    );
}

static float2 inverseRotation(float2 point, float2 rotation) {
    return float2(
        point.x * rotation.x + point.y * rotation.y,
        point.y * rotation.x - point.x * rotation.y
    );
}

static float2 artworkCoordinates(
    float2 position,
    float2 rotation,
    float2 translation,
    float side
) {
    return inverseRotation(inverseRotation(position, rotation) - translation, rotation)
        / side + 0.5f;
}

static half3 appleMusicArtworkColor(
    float2 destination,
    float2 size,
    texture2d<half> artwork,
    device const float *rotations
) {
    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 position = (destination - 0.5f) * size;
    float side = max(size.x, size.y);
    // A diagonal-sized base covers every rotation and every window aspect
    // ratio. The upper layers feather into it instead of exposing rectangle
    // edges, which baking a blur into the source alone cannot soften.
    float2 baseUV = artworkCoordinates(position, float2(rotations[0], rotations[1]),
                                       float2(0.0f), length(size));
    half3 color = artwork.sample(textureSampler, baseUV).rgb;
    for (uint index = 1; index < 3; ++index) {
        float2 translation = index == 1 ? float2(-0.5f, -0.7f) : float2(-0.95f, 0.7f);
        float2 uv = artworkCoordinates(position,
            float2(rotations[index * 2], rotations[index * 2 + 1]),
            translation * size.x * 0.5f, side);
        float edge = min(min(uv.x, uv.y), min(1.0f - uv.x, 1.0f - uv.y));
        half alpha = half(smoothstep(0.0f, 0.12f, edge));
        color = mix(color, artwork.sample(textureSampler, uv).rgb, alpha);
    }
    return color;
}

static half4 appleMusicBackdropColor(
    float2 position,
    float2 size,
    texture2d<half> artwork,
    float meshWeight,
    float blackScrimAlpha,
    float usesDarkAppearance,
    device const float *rotations,
    float2 fieldSize,
    device const ushort2 *field
) {
    float2 uv = appleMusicWarpCoordinates(position / size, meshWeight, fieldSize, field);
    uv = (uv - 0.5f) * 0.8f + 0.5f;
    half3 color = appleMusicArtworkColor(uv, size, artwork, rotations);
    half luminance = dot(color, half3(0.3000488h, 0.5898438h, 0.1100464h));
    // Preserve the two original saturation stages (1.3 × 2) in this pass.
    color = half3(luminance) + (color - half3(luminance)) * 2.6h;
    color = min(color, half3(0.9951172h));
    if (usesDarkAppearance > 0.5f) {
        color *= half(1.0f - clamp(blackScrimAlpha, 0.0f, 1.0f));
        color -= half3(0.02h);
        color = max(color, half3(0.0h));
        // White player chrome needs headroom even with an almost white cover.
        // Compress only highlights, scaling RGB together to retain the tint.
        // Squared RGB is a cheap, conservative luminance estimate in this
        // range; this adds no texture reads or additional rendering pass.
        half brightness = dot(color * color, half3(0.2126h, 0.7152h, 0.0722h));
        half excess = max(brightness - 0.11h, 0.0h);
        half mappedBrightness = 0.11h + excess / (1.0h + excess / 0.04h);
        color *= sqrt(min(mappedBrightness / max(brightness, 0.0001h), 1.0h));
    } else {
        color = mix(color, half3(1.0h), 0.25h) + half3(0.004h);
    }
    return half4(clamp(color, half3(0.07h), half3(0.97h)), 1.0h);
}

[[ stitchable ]]
half4 desktopAppleMusicBackdrop(
    float2 position,
    half4 sourceColor,
    float2 size,
    texture2d<half> artwork,
    float meshWeight,
    float blackScrimAlpha,
    float usesDarkAppearance,
    device const float *rotations,
    int rotationCount,
    float2 fieldSize,
    device const void *fieldData,
    int fieldDataSize
) {
    return appleMusicBackdropColor(position, size, artwork, meshWeight,
        blackScrimAlpha, usesDarkAppearance, rotations, fieldSize,
        static_cast<const device ushort2 *>(fieldData)) * sourceColor.a;
}

// The same color function renders a bounded texture off the UI thread.
// Only the compact uniforms change per frame; the inverse field stays on GPU.
kernel void desktopAppleMusicBackdropFrame(
    texture2d<half> artwork [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    device const float *parameters [[buffer(0)]],
    device const ushort2 *field [[buffer(1)]],
    uint2 position [[thread_position_in_grid]]
) {
    if (position.x >= output.get_width() || position.y >= output.get_height()) return;
    float2 size(parameters[0], parameters[1]);
    half4 color = appleMusicBackdropColor(float2(position) + 0.5f, size, artwork,
        parameters[2], parameters[3], parameters[4], parameters + 7,
        float2(parameters[5], parameters[6]), field);
    output.write(color, position);
}
