#include "shadows.hlsl"

float4 main(PS_INPUT i) : COLOR
{
    float shadow = calculate_shadow(i);

    if (shadow <= 0.002)
        discard;

    return float4(i.color.rgb, i.color.a * shadow);
}
