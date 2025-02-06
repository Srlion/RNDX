// The MIT License
// Copyright © 2015 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.shadertoy.com/view/Xd33Rf
#include "common_rounded.hlsl"

static const float w[8] = {0.026109, 0.034202, 0.043219, 0.052683, 0.061948, 0.070266, 0.076883, 0.081149};
static const float o[8] = {15.5, 13.5, 11.5, 9.5, 7.5, 5.5, 3.5, 1.5};

float3 horizontal_blur(float2 uv)
{
    float2 texture_dimensions = 1.0 / TexBaseSize;

    float3 blr = float3(0.0, 0.0, 0.0);

    [unroll] for(int j=0; j<8; j++) {
        blr += w[j] * tex2D(TexBase, (uv + float2(-o[j], 0.0)) / texture_dimensions).rgb;
    }

    blr += 0.041312 * tex2D(TexBase, (uv + float2(0.0, 0.0)) / texture_dimensions).rgb;

    [unroll] for(j=7; j>=0; j--) {
        blr += w[j] * tex2D(TexBase, (uv + float2(o[j], 0.0)) / texture_dimensions).rgb;
    }

    blr /= 0.93423; // Normalize

    return blr;
}

float3 vertical_blur(float2 uv)
{
    float2 texture_dimensions = 1.0 / TexBaseSize;

    float3 blr = float3(0.0, 0.0, 0.0);

    [unroll] for(int j=0; j<8; j++) {
        blr += w[j] * tex2D(TexBase, (uv + float2(0.0, -o[j])) / texture_dimensions).rgb;
    }

    blr += 0.041312 * tex2D(TexBase, (uv + float2(0.0, 0.0)) / texture_dimensions).rgb;

    [unroll] for(j=7; j>=0; j--) {
        blr += w[j] * tex2D(TexBase, (uv + float2(0.0, o[j])) / texture_dimensions).rgb;
    }

    blr /= 0.93423; // Normalize

    return blr;
}
