// this code here is from fuckton of sources
// but was mainly using https://www.shadertoy.com/view/fsdyzB
// then some help came from Svetov/Jaffies (https://github.com/Jaffies)
// and some help from AI lol

#ifndef __COMMON_ROUNDED_HLSL__
#define __COMMON_ROUNDED_HLSL__

#include "common.hlsl"

#define RADIUS Constants0
#define SIZE Constants1.xy
#define POWER_PARAMETER Constants1.z
#define USE_TEXTURE Constants1.w
#define OUTLINE_THICKNESS Constants2.x
#define AA Constants2.y // Anti-aliasing smoothness (pixels)

float length_custom(float2 vec) {
    float2 powered = pow(vec, POWER_PARAMETER);
    return pow(dot(powered, 1.0), 1.0 / POWER_PARAMETER);
}

float rounded_box_sdf(float2 p, float2 b, float4 r) {
    float2 quadrant = step(0.0, p.xy);
    float radius = lerp(
        lerp(r.w, r.x, quadrant.y),
        lerp(r.z, r.y, quadrant.y),
        quadrant.x
    );
    float2 q = abs(p) - b + radius;
    float2 q_clamped = max(q, 0.0);
    float len = length_custom(q_clamped);
    return min(max(q.x, q.y), 0.0) + len - radius;
}

// Thanks to https://bohdon.com/docs/smooth-sdf-shape-edges/ awesome article
float uv_filter_width_bias(float dist, float2 uv) {
    float2 dpos = fwidth(uv);
    float fw = max(dpos.x, dpos.y);
    float biasedSDF = dist + 0.5 * fw;
    return saturate(1.0 - biasedSDF / fw);
}

float blended_AA(float dist, float2 uv) {
    float linear_cov = uv_filter_width_bias(dist, uv);
    float smooth_cov = 1.0 - smoothstep(0.0, 1, dist + 1);
    return lerp(linear_cov, smooth_cov, 0.07);
}

float calculate_rounded_alpha(PS_INPUT i) {
    float2 screen_pos = i.uv.xy * SIZE;
    float2 rect_half_size = SIZE * 0.5;

    // Compute outer SDF distance (original radii)
    float dist_outer = rounded_box_sdf(screen_pos - rect_half_size, rect_half_size, RADIUS);
    float aa_outer = blended_AA(dist_outer, screen_pos);
    if (OUTLINE_THICKNESS < 0)
        return aa_outer;

    float2 inner_half_size = max(rect_half_size - OUTLINE_THICKNESS, 0.0);
    float4 inner_radius = max(RADIUS - OUTLINE_THICKNESS, 0.0);

    // Check if inner shape would collapse to a point, some filled shapes if using max outline thickness would have a small dot in the center
    // if (all(inner_half_size <= 0.0) && all(inner_radius <= 0.0))
    //     return alpha_outer; // Fallback to filled when outline is too thick

    float dist_inner = rounded_box_sdf(screen_pos - rect_half_size, inner_half_size, inner_radius);
    float aa_inner = blended_AA(dist_inner, screen_pos);
    return aa_outer * (1.0 - aa_inner);
}

float calculate_smooth_rounded_alpha(PS_INPUT i) {
    float2 screen_pos = i.uv.xy * SIZE;
    float2 rect_half_size = SIZE * 0.5;

    // Compute outer SDF distance (original radii)
    float dist_outer = rounded_box_sdf(screen_pos - rect_half_size, rect_half_size, RADIUS);

    float aa_outer = 1.0 - smoothstep(0.0, AA, dist_outer + AA);
    if (OUTLINE_THICKNESS < 0)
        return aa_outer;

    // Adjust inner radii and size for outline
    float2 inner_half_size = max(rect_half_size - OUTLINE_THICKNESS, 0.0);
    float4 inner_radius = max(RADIUS - OUTLINE_THICKNESS, 0.0);
    float dist_inner = rounded_box_sdf(screen_pos - rect_half_size, inner_half_size, inner_radius);

    float aa_inner = 1.0 - smoothstep(0.0, AA, dist_inner + AA);
    return aa_outer * (1.0 - aa_inner);
}

/* filter width bias, we could use it later
float apply_AA(float dist) {
    float fw = fwidth(dist);
    dist += 0.5 * fw; // bias
    float aa_linear = saturate(1.0 - dist / fw);
    return aa_linear;
}
*/

#endif // __COMMON_ROUNDED_HLSL__
