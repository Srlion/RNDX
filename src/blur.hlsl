// https://www.shadertoy.com/view/ltScRG and thanks to Jaffies!
#include "common_rounded.hlsl"

static const int samples = 32;
static const int LOD = 3;
static const int sLOD = 1 << LOD;
static const float sigma = float(samples * 2) * 0.25;
static const float gaussian_denom = 1.0 / (6.28 * sigma * sigma);

static const float2 bilinearOffsets[32] = {
    float2(0.25, 0.25),  float2(-0.25, 0.25),
    float2(0.25, -0.25), float2(-0.25, -0.25),
    float2(0.75, 0.75),  float2(-0.75, 0.75),
    float2(0.75, -0.75), float2(-0.75, -0.75),
    float2(1.25, 1.25),  float2(-1.25, 1.25),
    float2(1.25, -1.25), float2(-1.25, -1.25),
    float2(0.5, 0.0),    float2(0.0, 0.5),
    float2(-0.5, 0.0),   float2(0.0, -0.5),

    float2(1.75, 1.75),  float2(-1.75, 1.75),
    float2(1.75, -1.75), float2(-1.75, -1.75),
    float2(2.25, 2.25),  float2(-2.25, 2.25),
    float2(2.25, -2.25), float2(-2.25, -2.25),
    float2(1.0, 0.0),    float2(0.0, 1.0),
    float2(-1.0, 0.0),   float2(0.0, -1.0),
    float2(1.5, 0.5),    float2(-1.5, 0.5),
    float2(1.5, -0.5),   float2(-1.5, -0.5)
};

static const float bilinearWeights[32] = {
    0.38, 0.38, 0.38, 0.38,
    0.18, 0.18, 0.18, 0.18,
    0.06, 0.06, 0.06, 0.06,
    0.12, 0.12, 0.12, 0.12,

    0.04, 0.04, 0.04, 0.04,
    0.02, 0.02, 0.02, 0.02,
    0.16, 0.16, 0.16, 0.16,
    0.08, 0.08, 0.08, 0.08
};

float gaussian(float2 i)
{
    i /= sigma;
    return exp(-0.5 * dot(i, i)) * gaussian_denom;
}

float4 blur(float2 uv)
{
    float4 colorAccum = 0;
    float weightAccum = 0.0;

    [unroll] for (int i = 0; i < samples; i++)
    {
        float2 offset = bilinearOffsets[i] * sLOD;
        float weight = bilinearWeights[i];
        float4 sample = tex2Dlod(TexBase, float4(uv + Tex1Size * offset, 0, LOD));
        colorAccum += sample * weight;
        weightAccum += weight;
    }

    return colorAccum / weightAccum;
}
