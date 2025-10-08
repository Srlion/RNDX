// this code here is from fuckton of sources
// but was mainly using https://www.shadertoy.com/view/fsdyzB
// then some help came from Svetov/Jaffies (https://github.com/Jaffies)
// and some help from AI lol

#ifndef __COMMON_ROUNDED_HLSL__
#define __COMMON_ROUNDED_HLSL__

#include "common.hlsl"

// Thanks to svetov/jaffies for this hack, to be able to supply constants in two C calls from lua
const float4x4 g_viewProjMatrix : register( c11 );
#define RADIUS g_viewProjMatrix[0]
#define SIZE g_viewProjMatrix[1].xy
#define POWER_PARAMETER g_viewProjMatrix[1].z
#define USE_TEXTURE g_viewProjMatrix[1].w
#define OUTLINE_THICKNESS g_viewProjMatrix[2].x
#define AA g_viewProjMatrix[2].y // Anti-aliasing smoothness (pixels)
#define BLUR_INTENSITY g_viewProjMatrix[2].z // Blur intensity
#define BLUR_VERTICAL Constants0.x
#define START_ANGLE g_viewProjMatrix[2].w // Start angle in radians
#define END_ANGLE g_viewProjMatrix[3].x   // End angle in radians
#define ROTATION g_viewProjMatrix[3].y    // Rotation in radians

#define DEG_TO_RAD 0.01745329251994329576923690768489
#define TWO_PI 6.28318530718


#define GRAD_CENTER           Constants1.xy
#define GRAD_ANGLE            Constants1.z
#define GRAD_MODE             Constants1.w

#define GRAD_SCALE            Constants2.xy
#define GRAD_USE_RAMP         Constants2.z
#define GRAD_TILING           Constants2.w


float apply_tiling(float t)
{
	if (GRAD_TILING < 0.5) {
		
		return saturate(t);
	}
	if (GRAD_TILING < 1.5) {
		
		return frac(t);
	}

	float tt = frac(t * 0.5) * 2.0;
	return 1.0 - abs(tt - 1.0);
}


float2 gradient_centered_pos(float2 screen_pos, float2 rect_half_size)
{
	float2 centered = screen_pos - rect_half_size;
	
	float2 center_px = (GRAD_CENTER - 0.5) * (rect_half_size * 2.0);
	return centered - center_px;
}


float compute_gradient_t(float2 centered_pos)
{
	
	if (GRAD_MODE < 1.5) {
		float s, c;
		sincos(GRAD_ANGLE, s, c);
		float2 dir = float2(c, s);
		float denom = max(1e-5, GRAD_SCALE.x);
		float t = dot(centered_pos, dir) / denom; 
		
		t = t * 0.5 + 0.5;
		return apply_tiling(t);
	}

	
	if (GRAD_MODE < 2.5) {
		float2 scaled = centered_pos / max(1e-5, GRAD_SCALE.xy);
		float t = length(scaled); 
		return apply_tiling(t);
	}

	
	float ang = atan2(centered_pos.y, centered_pos.x) - GRAD_ANGLE;
	float t = ang / TWO_PI + 0.5; 
	return apply_tiling(t);
}

float length_custom(float2 vec) {
    float2 powered = pow(vec, POWER_PARAMETER);
    return pow(dot(powered, 1.0), 1.0 / POWER_PARAMETER);
}

// Rotate a 2D point by given angle (in radians)
float2 rotate_point(float2 p) {
    float s, c;
    sincos(ROTATION, s, c);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
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
    return lerp(linear_cov, smooth_cov, 0.06);
}

float rounded_arc_sdf(float2 p, float2 b, float4 r) {
    float box_dist = rounded_box_sdf(p, b, r);

    if (END_ANGLE - START_ANGLE >= 360.0) {
        return box_dist;
    }

    // Convert to radians and normalize
    float start_rad = fmod(START_ANGLE * DEG_TO_RAD + TWO_PI, TWO_PI);
    float end_rad = fmod(END_ANGLE * DEG_TO_RAD + TWO_PI, TWO_PI);
    float angle = fmod(atan2(p.y, p.x) + TWO_PI, TWO_PI);

    float angular_dist;
    if (angle >= start_rad && angle <= end_rad) {
        angular_dist = -min(angle - start_rad, end_rad - angle) * length(p);
    } else {
        angular_dist = min(abs(angle - start_rad), abs(angle - end_rad)) * length(p);
    }

    return max(box_dist, angular_dist);
}

float calculate_rounded_alpha(PS_INPUT i) {
    float2 screen_pos = i.uv.xy * SIZE;
    float2 rect_half_size = SIZE * 0.5;

    float2 centered_pos = screen_pos - rect_half_size;

    // Apply rotation
    centered_pos = rotate_point(centered_pos);

    float dist_outer = rounded_arc_sdf(centered_pos, rect_half_size, RADIUS);
    float aa_outer = blended_AA(dist_outer, screen_pos);
    if (OUTLINE_THICKNESS < 0)
        return aa_outer;

    float2 inner_half_size = max(rect_half_size - OUTLINE_THICKNESS, 0.0);
    float4 inner_radius = max(RADIUS - OUTLINE_THICKNESS, 0.0);

    float dist_inner = rounded_box_sdf(centered_pos, inner_half_size, inner_radius);
    float aa_inner = blended_AA(dist_inner, screen_pos);
    return aa_outer * (1.0 - aa_inner);
}

float calculate_smooth_rounded_alpha(PS_INPUT i) {
    float2 screen_pos = i.uv.xy * SIZE;
    float2 rect_half_size = SIZE * 0.5;

    float2 centered_pos = screen_pos - rect_half_size;

    // Apply rotation
    centered_pos = rotate_point(centered_pos);

    float dist_outer = rounded_arc_sdf(centered_pos, rect_half_size, RADIUS);
    float aa_outer = 1.0 - smoothstep(0.0, AA, dist_outer + AA);
    if (OUTLINE_THICKNESS < 0)
        return aa_outer;

    // Adjust inner radii and size for outline
    float2 inner_half_size = max(rect_half_size - OUTLINE_THICKNESS, 0.0);
    float4 inner_radius = max(RADIUS - OUTLINE_THICKNESS, 0.0);
    float dist_inner = rounded_box_sdf(centered_pos, inner_half_size, inner_radius);

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
