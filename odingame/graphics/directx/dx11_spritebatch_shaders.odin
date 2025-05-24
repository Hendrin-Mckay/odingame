package directx11

// HLSL Shaders for SpriteBatch on DirectX 11

HLSL_SPRITEBATCH_VERTEX_SHADER_SOURCE :: `
// HLSL Vertex Shader for SpriteBatch

cbuffer PerFrameConstants : register(b0) {
    matrix ProjectionView;
};

struct VertexInput {
    float2 In_Position  : POSITION;
    float4 In_Color     : COLOR;    // Changed from COLOR0
    float2 In_TexCoord  : TEXCOORD; // Changed from TEXCOORD0
};

struct VertexOutput {
    float4 SvPosition   : SV_POSITION;
    float4 Color        : COLOR0;    // Output to pixel shader still COLOR0
    float2 TexCoord     : TEXCOORD0; // Output to pixel shader still TEXCOORD0
};

VertexOutput VSMain(VertexInput input) {
    VertexOutput output;
    output.SvPosition = mul(ProjectionView, float4(input.In_Position, 0.0f, 1.0f));
    output.Color = input.In_Color;
    output.TexCoord = input.In_TexCoord;
    return output;
}
`

HLSL_SPRITEBATCH_PIXEL_SHADER_SOURCE :: `
// HLSL Pixel Shader for SpriteBatch

Texture2D    SpriteTexture : register(t0);
SamplerState SpriteSampler : register(s0); 

struct PixelInput {
    float4 SvPosition   : SV_POSITION;
    float4 Color        : COLOR0;
    float2 TexCoord     : TEXCOORD0;
};

float4 PSMain(PixelInput input) : SV_TARGET {
    float4 texColor = SpriteTexture.Sample(SpriteSampler, input.TexCoord);
    return texColor * input.Color;
}
`
