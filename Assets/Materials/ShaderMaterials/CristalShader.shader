Shader "Custom/CristalShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _HeightColor("Change Color (Blue)", Color) = (0, 0, 1, 0.5)
        _HeightThreshold ("Height Threshold (World Y)", Float) = 0.0
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        _Roughness ("Roughness", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline" 
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // 1. Activa la compilación para instanciado y renderizado estereoscópico (VR)
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID // 2. ID para identificar la instancia/ojo
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID // 3. Pasa el ID al fragment shader
                UNITY_VERTEX_OUTPUT_STEREO     // 4. Transporta el índice del ojo objetivo
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _HeightColor;
                float _HeightThreshold;
                float _Metallic;
                float _Roughness;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;

                // 5. Inicializa y transfiere los IDs del ojo activo al procesar los vértices
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;

                return output;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 6. Configura la matriz de vista/proyección correcta según el ojo del fragmento actual
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float isAbove = step(IN.positionWS.y,_HeightThreshold);
                half4 finalColor = lerp(_BaseColor, _HeightColor, isAbove);

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = finalColor.rgb;
                surfaceData.alpha = finalColor.a;
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = 1.0 - _Roughness; 
                surfaceData.normalTS = half3(0, 0, 1);

                InputData inputData = (InputData)0;
                inputData.positionWS = IN.positionWS;
                inputData.normalWS = normalize(IN.normalWS);
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                inputData.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);

                return UniversalFragmentPBR(inputData, surfaceData);
            }
            ENDHLSL
        }
    }
}