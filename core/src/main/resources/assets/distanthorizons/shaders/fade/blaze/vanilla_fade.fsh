#version 330
// needed for "layout(location = 0)" required as as of MC 26.3
#extension GL_ARB_separate_shader_objects : require

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

uniform sampler2D uMcDepthTexture;
uniform sampler2D uCombinedMcDhColorTexture;

uniform sampler2D uDhDepthTexture;
uniform sampler2D uDhColorTexture;

layout (std140) uniform fragUniformBlock
{
    bool uOnlyRenderLods;
    
    float uStartFadeBlockDistance;
    float uEndFadeBlockDistance;
    float uMaxLevelHeight;
    
    // inverted model view matrix and projection matrix
    mat4 uDhInvMvmProj;
    mat4 uMcInvMvmProj;

    bool uIsMcReverseZDepth;
    bool uDepthIsZeroToPositiveOne;
};



/** 
 * this method is shared across several shaders,
 * if updated, make sure to update the other versions as well.
 */
vec3 calcViewPosition(float fragmentDepth, mat4 invMvmProj)
{
    // normalized device coordinates
    vec4 ndc = vec4(texCoord.xy, fragmentDepth, 1.0);
    if (uDepthIsZeroToPositiveOne)
    {
        // Z already in [0,1], don't remap
        ndc.xy = ndc.xy * 2.0 - 1.0;
    }
    else
    {
        // UV [0,1] -> NDC [-1,+1]
        ndc.xyz = ndc.xyz * 2.0 - 1.0;
    }

    vec4 eyeCoord = invMvmProj * ndc;
    return eyeCoord.xyz / eyeCoord.w;
}


/**
 * Used to fade out vanilla chunks so the transition
 * between DH and vanilla is smoother.
 */
void main() 
{
    // includes both the vanilla chunks as well as DH
    vec4 combinedMcDhColor = texture(uCombinedMcDhColorTexture, texCoord);
    // just the DH render pass
    vec4 dhColor = texture(uDhColorTexture, texCoord);
    
    // completely remove the MC render pass to only show LODs
    // useful for debugging/troubleshooting, but doesn't improve performance since MC is still rendering
    if (uOnlyRenderLods)
    {
        fragColor = dhColor;
        return;
    }
    
    
    // ignore anything that DH hasn't drawn to
    if (dhColor.a == 0.0f)
    {
        // if not done vanilla clouds will render incorrectly at night
        dhColor = combinedMcDhColor;
    }
    
    float mcFragmentDepth = texture(uMcDepthTexture, texCoord).r;
    float dhFragmentDepth = texture(uDhDepthTexture, texCoord).r;
    vec3 dhVertexWorldPos = calcViewPosition(dhFragmentDepth, uDhInvMvmProj);

    // we only want to fade vanilla rendered objects, not to the sky or LODs
    bool isGround;
    if (uIsMcReverseZDepth)
    {
        isGround = (mcFragmentDepth > 0);
    }
    else
    {
        // a fragment depth of "1" means the fragment wasn't drawn to
        isGround = (mcFragmentDepth < 1.0);
    }
    
	// this is a work around to prevent MC clouds rendering behind DH clouds
    if (dhVertexWorldPos.y > uMaxLevelHeight)
    {
        fragColor = vec4(combinedMcDhColor.rgb, 0.0);
    }
    else if (isGround)
    {
        // fade based on distance from the camera
        vec3 mcVertexWorldPos = calcViewPosition(mcFragmentDepth, uMcInvMvmProj);
        float mcFragmentDistance = length(mcVertexWorldPos.xzy);
        
        
        // Smoothly transition between combinedMcDhColor and uDhColorTexture
        // as the depth increases from the camera
        float fadeStep = smoothstep(uStartFadeBlockDistance, uEndFadeBlockDistance, mcFragmentDistance);

        // kabu: DH の画素がバニラの画素よりずっと奥にあるとき（水・エンティティ・パーティクルの向こうの遠い LOD）は混ぜない。
        // 混ぜると、手前の水などが奥の霧のかかった LOD の色で上書きされ、霧が水より手前に出て見える
        float dhFragmentDistance = length(dhVertexWorldPos.xzy);
        float allowedGap = 16.0 + mcFragmentDistance * 0.1;
        if (dhColor != combinedMcDhColor && dhFragmentDistance > mcFragmentDistance + allowedGap)
        {
            fadeStep = 0.0;
        }

        fragColor = mix(combinedMcDhColor, dhColor, fadeStep);
        fragColor.a = 1.0;
    }
    else
    {
        fragColor = vec4(combinedMcDhColor.rgb, 0.0);
    }
}

