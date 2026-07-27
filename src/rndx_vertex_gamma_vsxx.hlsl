#include "common_vs.hlsl"

VS_OUTPUT main(const VS_INPUT v)
{
    VS_OUTPUT o = (VS_OUTPUT)0;

    o.projPos.xyzw = mul(float4(v.pos.xyz, 1.0f), cModelViewProj);
    o.uv = v.uv;
    o.color.rgb = pow(max(v.color.rgb, 0.0), 2.2);
    o.color.a = v.color.a;

    return o;
}
