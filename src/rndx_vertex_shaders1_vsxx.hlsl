#include "common_vs.hlsl"

VS_OUTPUT main( const VS_INPUT v )
{
    VS_OUTPUT o = ( VS_OUTPUT )0;

    o.projPos.xyzw = mul( float4( v.pos.xyz, 1.0f ), cModelViewProj );
    o.uv = v.uv;
    o.color.rgba = v.color.rgba;

    return o;
}
