/***************************************************************************
# Copyright (c) 2018, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
***************************************************************************/
RaytracingAccelerationStructure gRtScene : register(t0);
RWTexture2D<float4> gOutput : register(u0);

cbuffer PerFrame : register(b0)
{
    float3 A;
    float3 B;
    float3 C;
}

float3 linearToSrgb(float3 c)
{
    // Based on http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
    float3 sq1 = sqrt(c);
    float3 sq2 = sqrt(sq1);
    float3 sq3 = sqrt(sq2);
    float3 srgb = 0.662002687 * sq1 + 0.684122060 * sq2 - 0.323583601 * sq3 - 0.0225411470 * c;
    return srgb;
}

struct RayPayload
{
    float3 color;
};

[shader("raygeneration")]
void rayGen()
{
    uint3 launchIndex = DispatchRaysIndex();
    uint3 launchDim = DispatchRaysDimensions();

    float2 crd = float2(launchIndex.xy);
    float2 dims = float2(launchDim.xy);

    float2 d = ((crd/dims) * 2.f - 1.f);
    float aspectRatio = dims.x / dims.y;

    RayDesc ray;
    ray.Origin = float3(0, 0, -2);
    ray.Direction = normalize(float3(d.x * aspectRatio, -d.y, 1));

    ray.TMin = 0;
    ray.TMax = 100000;

    RayPayload payload;
	// TraceRay():
	//     param_1  -  Is the TLAS SRV.
	//     param_2  -  Is the ray flags. These flags allow us to control the traversal behavior,
	//	    		       for example enable back-face culling.
	//     param_3	-  Is the ray-mask. It can be used to cull entire objects when tracing rays.
	//	    		       We will not cover this topic in the tutorials. 0xFF means no culling.
	//     param_4_5 - Are "RayContributionToHitGroupIndex" and "MultiplierForGeometryContributionToHitGroupIndex".
	//	    		       They are used for shader-table indexing. We will cover them in later tutorials, 
	//	    		       for now we will set both to 0.
	//     param_6	 - Is the MissShaderIndex. This index is relative to the base miss-shader index we passed when 
	//	    			   calling DispatchRays(). We only have a single miss-shader, so we will set the index to 0.
	//     param_7	 - Is the RayDesc object we created.
	//     param_8	 - RayPayload object.
	
	// param_4 - Leaving RayContributionToHitGroupIndex as it was (i.e. = 0)
	// param_5 - SETTING MultiplierForGeometryContributionToHitGroupIndex = 1
    TraceRay( gRtScene, 0 /*rayFlags*/, 0xFF, 0 /* ray index*/, 1 /*-HERE-*/, 0, ray, payload );
    float3 col = linearToSrgb(payload.color);
    gOutput[launchIndex.xy] = float4(col, 1);
}

[shader("miss")]
void miss(inout RayPayload payload)
{
    payload.color = float3(0.4, 0.6, 0.2);
}

[shader("closesthit")]
void triangleChs(inout RayPayload payload, in BuiltInTriangleIntersectionAttributes attribs)
{
    float3 barycentrics = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);
    payload.color = A * barycentrics.x + B * barycentrics.y + C * barycentrics.z;
}

[shader("closesthit")]
void planeChs(inout RayPayload payload, in BuiltInTriangleIntersectionAttributes attribs)
{
    payload.color = 0.9f;
}