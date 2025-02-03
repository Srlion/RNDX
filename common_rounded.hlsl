// this code here is from fuckton of sources
// but was mainly using https://www.shadertoy.com/view/fsdyzB
// then some help came from Svetov/Jaffies (https://github.com/Jaffies)
// and some help from AI lol
#include "common.hlsl"

#define RADIUS Constants0
#define SIZE Constants1.xy
#define POWER_PARAMETER Constants1.z
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

float calculate_rounded_alpha(PS_INPUT i) {
    float2 screen_pos = i.uv.xy * SIZE;
    float2 rect_half_size = SIZE * 0.5;

    // Compute outer SDF distance (original radii)
    float distance_outer = rounded_box_sdf(screen_pos - rect_half_size, rect_half_size, RADIUS);

    // Adjust inner radii and size for outline
    float2 inner_half_size = max(rect_half_size - OUTLINE_THICKNESS, 0.0);
    float4 inner_radius = max(RADIUS - OUTLINE_THICKNESS, 0.0);
    float distance_inner = rounded_box_sdf(screen_pos - rect_half_size, inner_half_size, inner_radius);

    // Offset SDF distances by AA to implicitly increase visual radius
    float adjusted_distance_outer = distance_outer + AA;
    float adjusted_distance_inner = distance_inner + AA;

    // Compute alpha with smoothstep (like Shadertoy's edge softness)
    float alpha_outer = 1.0 - smoothstep(0.0, AA, adjusted_distance_outer);
    float alpha_inner = 1.0 - smoothstep(0.0, AA, adjusted_distance_inner);

    // Combine results (outer alpha minus inner alpha)
    return alpha_outer * (1.0 - alpha_inner);
}
