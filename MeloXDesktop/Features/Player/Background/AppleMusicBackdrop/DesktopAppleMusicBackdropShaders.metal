#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

constant uint appleMusicMeshDimension = 41u;
constant uint appleMusicMeshCellCount = 40u;
constant uint appleMusicMeshPointCount = 1681u;
constant uint appleMusicLookupDimension = 64u;

static float cross2D(float2 first, float2 second) {
    return first.x * second.y - first.y * second.x;
}

static float2 solveColumns(float2 xColumn, float2 yColumn, float2 value) {
    float determinant = cross2D(xColumn, yColumn);
    if (abs(determinant) < 0.0000001f) {
        return float2(10000.0f);
    }
    return float2(
        cross2D(value, yColumn) / determinant,
        cross2D(xColumn, value) / determinant
    );
}

static float2 appleMusicMeshDestination(
    device const float2 *meshPositions,
    uint x,
    uint y,
    float weight
) {
    uint index = y * appleMusicMeshDimension + x;
    float2 clipPosition = mix(
        meshPositions[index],
        meshPositions[appleMusicMeshPointCount + index],
        weight
    );
    return float2(
        clipPosition.x * 0.5f + 0.5f,
        0.5f - clipPosition.y * 0.5f
    );
}

struct AppleMusicMeshCell {
    float2 topLeft;
    float2 topRight;
    float2 bottomLeft;
    float2 bottomRight;
};

static AppleMusicMeshCell appleMusicMeshCell(
    device const float2 *meshPositions,
    uint2 cell,
    float weight
) {
    AppleMusicMeshCell result;
    result.topLeft = appleMusicMeshDestination(
        meshPositions,
        cell.x,
        cell.y,
        weight
    );
    result.topRight = appleMusicMeshDestination(
        meshPositions,
        cell.x + 1u,
        cell.y,
        weight
    );
    result.bottomLeft = appleMusicMeshDestination(
        meshPositions,
        cell.x,
        cell.y + 1u,
        weight
    );
    result.bottomRight = appleMusicMeshDestination(
        meshPositions,
        cell.x + 1u,
        cell.y + 1u,
        weight
    );
    return result;
}

static bool appleMusicLocalCoordinates(
    AppleMusicMeshCell cell,
    float2 destination,
    bool upperTriangle,
    thread float2 &local
) {
    if (upperTriangle) {
        local = solveColumns(
            cell.topRight - cell.topLeft,
            cell.bottomRight - cell.topRight,
            destination - cell.topLeft
        );
        return all(local >= -0.00002f)
            && all(local <= 1.00002f)
            && local.x + 0.00002f >= local.y;
    }

    local = solveColumns(
        cell.bottomRight - cell.bottomLeft,
        cell.bottomLeft - cell.topLeft,
        destination - cell.topLeft
    );
    return all(local >= -0.00002f)
        && all(local <= 1.00002f)
        && local.y + 0.00002f >= local.x;
}

static float2 appleMusicInverseMesh(
    float2 destination,
    device const float2 *meshPositions,
    float weight,
    device const uint *lookupOffsets,
    device const ushort *lookupTriangles
) {
    uint2 lookupCell = min(
        uint2(
            floor(
                clamp(destination, 0.0f, 1.0f)
                    * float(appleMusicLookupDimension)
            )
        ),
        uint2(appleMusicLookupDimension - 1u)
    );
    uint lookupIndex =
        lookupCell.y * appleMusicLookupDimension + lookupCell.x;
    uint firstCandidate = lookupOffsets[lookupIndex];
    uint candidateLimit = lookupOffsets[lookupIndex + 1u];
    // Candidates retain Music's index-buffer order. Search back to front:
    // the first containing primitive is exactly the last writer from the
    // forward pass, including folded/overlapping portions of the mesh.
    for (
        uint candidateIndex = candidateLimit;
        candidateIndex > firstCandidate;
    ) {
        --candidateIndex;
        uint triangle = uint(lookupTriangles[candidateIndex]);
        uint linearCell = triangle / 2u;
        uint2 cellIndex = uint2(
            linearCell % appleMusicMeshCellCount,
            linearCell / appleMusicMeshCellCount
        );
        AppleMusicMeshCell cell = appleMusicMeshCell(
            meshPositions,
            cellIndex,
            weight
        );
        float2 solvedLocal;
        if (appleMusicLocalCoordinates(
            cell,
            destination,
            (triangle & 1u) != 0u,
            solvedLocal
        )) {
            return clamp(
                (float2(cellIndex) + solvedLocal)
                    / float(appleMusicMeshCellCount),
                0.0f,
                1.0f
            );
        }
    }
    return clamp(float2(destination.x, 1.0f - destination.y), 0.0f, 1.0f);
}

[[ stitchable ]]
half4 desktopAppleMusicBackdropPinch(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float meshWeight,
    float blackScrimAlpha,
    float usesDarkAppearance,
    float averageLuminosity,
    device const void *meshPositionsData,
    int meshPositionsDataSize,
    device const void *lookupOffsetsData,
    int lookupOffsetsDataSize,
    device const void *lookupTrianglesData,
    int lookupTrianglesDataSize
) {
    // SwiftUI maps each `.data(...)` shader argument to a
    // `device const void *` / `int size_in_bytes` parameter pair.
    // Typed device pointers are rejected during function stitching.
    const device float2 *meshPositions =
        static_cast<const device float2 *>(meshPositionsData);
    const device uint *lookupOffsets =
        static_cast<const device uint *>(lookupOffsetsData);
    const device ushort *lookupTriangles =
        static_cast<const device ushort *>(lookupTrianglesData);

    float2 destination = position / size;
    float2 textureCoordinates = appleMusicInverseMesh(
        destination,
        meshPositions,
        meshWeight,
        lookupOffsets,
        lookupTriangles
    );
    float2 insetTextureCoordinates =
        (textureCoordinates - 0.5f) * 0.8f + 0.5f;
    half3 color = layer.sample(insetTextureCoordinates * size).rgb;

    half luminance = dot(
        color,
        half3(0.3000488h, 0.5898438h, 0.1100464h)
    );
    color = half3(luminance)
        + (color - half3(luminance)) * 2.0h;
    color = min(color, half3(0.9951172h));

    if (usesDarkAppearance > 0.5f) {
        color = mix(
            color,
            half3(0.0h),
            half(clamp(blackScrimAlpha, 0.0f, 1.0f))
        );
        color -= half3(0.02h);
    } else {
        color = mix(color, half3(1.0h), half3(0.25h));
        float lightFactor = averageLuminosity < 0.3f ? 0.38f : 0.08f;
        color += half3(half(lightFactor * 0.05f));
    }
    color = clamp(color, half3(0.07h), half3(0.97h));
    return half4(color, 1.0h);
}
