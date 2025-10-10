#include "common_rounded.hlsl"

float4 main(PS_INPUT i) : COLOR {
    float alpha = calculate_rounded_alpha(i);

    if (alpha <= 0.001f)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    float4 rect_color = USE_TEXTURE == 1 ? tex2D(TexBase, i.uv.xy) * i.color : i.color;
    return float4(rect_color.rgb, rect_color.a * alpha);
}
