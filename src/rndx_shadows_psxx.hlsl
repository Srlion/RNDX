#include "common_rounded.hlsl"

float4 main(PS_INPUT i) : COLOR {
    float alpha = calculate_smooth_rounded_alpha(i);
    float4 rect_color = i.color;
    return float4(rect_color.rgb, rect_color.a * alpha);
}
