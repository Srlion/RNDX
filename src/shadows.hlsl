// Based on https://madebyevan.com/shaders/fast-rounded-rectangle-shadows/

#ifndef __SHADOWS_HLSL__
#define __SHADOWS_HLSL__

#include "common_rounded.hlsl"

#define SHADOW_SIGMA g_viewProjMatrix[2].y
#define SHADOW_PAD g_viewProjMatrix[3].z

float2 erf2(float2 x)
{
    float2 s = sign(x), a = abs(x);
    x = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
    x *= x;
    return s - s / (x * x);
}

float gaussian(float x, float sigma)
{
    return 0.39894228 / sigma * exp(-(x * x) / (2.0 * sigma * sigma));
}

float rounded_shadow_x(float x, float y, float sigma, float corner, float2 half_size)
{
    float delta = min(half_size.y - corner - abs(y), 0.0);
    float curved = half_size.x - corner + sqrt(max(0.0, corner * corner - delta * delta));
    float2 integral = 0.5 + 0.5 * erf2((x + float2(-curved, curved)) * (0.70710678 / sigma));
    return integral.y - integral.x;
}

float pick_corner_radius(float2 p, float4 r)
{
    float2 quadrant = step(0.0, p);
    return lerp(
        lerp(r.w, r.x, quadrant.y),
        lerp(r.z, r.y, quadrant.y),
        quadrant.x);
}

float rounded_shadow(float2 p, float2 half_size, float4 radius, float sigma)
{
    float corner = min(pick_corner_radius(p, radius), min(half_size.x, half_size.y));

    float low = p.y - half_size.y;
    float high = p.y + half_size.y;
    float start = clamp(-3.0 * sigma, low, high);
    float end = clamp(3.0 * sigma, low, high);

    float step = (end - start) / 4.0;
    float y = start + step * 0.5;
    float value = 0.0;

    [unroll]
    for (int i = 0; i < 4; i++)
    {
        value += rounded_shadow_x(p.x, p.y - y, sigma, corner, half_size) * gaussian(y, sigma) * step;
        y += step;
    }

    return value;
}

float calculate_shadow(PS_INPUT i)
{
    float2 screen_pos = i.uv * SIZE;
    float2 p = rotate_point(screen_pos - SIZE * 0.5);

    float sigma = max(SHADOW_SIGMA, 0.0001);
    float2 box_half = max(SIZE * 0.5 - SHADOW_PAD, 0.0);

    float shadow = rounded_shadow(p, box_half, RADIUS, sigma);

    // outlined shadows: subtract the blurred inner box -> soft ring
    if (OUTLINE_THICKNESS >= 0)
    {
        float2 inner_half = max(box_half - OUTLINE_THICKNESS, 0.0);
        float4 inner_radius = max(RADIUS - OUTLINE_THICKNESS, 0.0);
        shadow -= rounded_shadow(p, inner_half, inner_radius, sigma);
    }

    return saturate(shadow);
}

#endif // __SHADOWS_HLSL__
