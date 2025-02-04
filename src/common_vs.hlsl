// common data shared among all screenspace shaders

// up to four textures available for sampling
sampler TexBase : register( s0 ); // $basetexture
sampler Tex1    : register( s1 ); // $texture1
sampler Tex2    : register( s2 ); // $texture2
sampler Tex3    : register( s3 ); // $texture3

// normalized dimensions for each texture above
// (x = 1.0 / width, y = 1.0 / height)

// customizable parameters $c0, $c1, $c2, $c3
const float4 Constants0 : register( c0 );
const float4 Constants1 : register( c1 );
const float4 Constants2 : register( c2 );
const float4 Constants3 : register( c3 );

const float4x4 cModelViewProj            : register(c4);
const float4x4 cViewProj                : register(c8);

// interpolated vertex data from vertex shader, do not change
struct VS_INPUT
{
    float4 pos          : POSITION;
    // texture coordinates
    float2 uv           : TEXCOORD0;
    // vertex color (if mesh has one)
    float4 color        : COLOR0;

    float4 normal       : NORMAL;
};

struct VS_OUTPUT
{
    float4 projPos      : POSITION;
    float2 uv           : TEXCOORD0;
    float4 color        : TEXCOORD1;
};
