package metal

// MSL Shaders for SpriteBatch on Metal

MSL_SPRITEBATCH_VERTEX_SHADER_SOURCE :: `
#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    packed_float2 position    [[attribute(0)]];
    packed_float4 color       [[attribute(1)]]; // Assumes uchar4 normalized to float4
    packed_float2 texCoord    [[attribute(2)]];
};

struct VertexOutput {
    float4 clipSpacePosition [[position]];
    float4 color;
    float2 textureCoordinate;
};

struct Uniforms {
    float4x4 projectionMatrix;
};

vertex VertexOutput vertexMain(VertexInput in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(0)]]) {
    VertexOutput out;
    out.clipSpacePosition = uniforms.projectionMatrix * float4(in.position, 0.0, 1.0);
    out.color = in.color; // Pass through color
    out.textureCoordinate = in.texCoord;
    return out;
}
`

MSL_SPRITEBATCH_PIXEL_SHADER_SOURCE :: `
#include <metal_stdlib>
using namespace metal;

struct PixelInput {
    float4 color;
    float2 textureCoordinate;
};

fragment float4 fragmentMain(PixelInput in [[stage_in]],
                             texture2d<float> spriteTexture [[texture(0)]],
                             sampler linearSampler [[sampler(0)]]) {
    float4 texColor = spriteTexture.sample(linearSampler, in.textureCoordinate);
    return texColor * in.color;
}
`
