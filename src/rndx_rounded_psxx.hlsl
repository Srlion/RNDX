#include "common_rounded.hlsl"


float3 apply_gradient(PS_INPUT i, float3 base_rgb)
{
    if (GRAD_MODE < 0.5) {
        return base_rgb;
    }

    float2 screen_pos = i.uv.xy * SIZE;
    float2 rect_half_size = SIZE * 0.5;
    float2 centered = gradient_centered_pos(screen_pos, rect_half_size);
   
    centered = rotate_point(centered);
    float t = compute_gradient_t(centered);

    if (GRAD_USE_RAMP > 0.5) {
       
        float4 ramp = tex2D(Tex2, float2(t, 0.5));
        return ramp.rgb;
    } else {
     
        return lerp(base_rgb * 0.0, base_rgb, t);
    }
}

float4 main(PS_INPUT i) : COLOR {
    float alpha = calculate_rounded_alpha(i);
    if (alpha <= 0.0f)
        discard;

    float4 col = (USE_TEXTURE == 1) ? tex2D(TexBase, i.uv.xy) * i.color : i.color;
    float3 grad_rgb = apply_gradient(i, col.rgb);
    return float4(grad_rgb, col.a * alpha);
}
