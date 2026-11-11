Shader "Custom/CristalShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _HeightColor("Change Color (Blue)", Color) = (0, 0, 1, 0.5)
        _HeightThreshold ("Height Threshold (World Y)", Float) = 0.0
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        _Roughness ("Roughness", Range(0, 1)) = 0.5

        [Header(Underwater Distortion)]
        _DistortionSpeed ("Distortion Speed", Float) = 0.8
        _DistortionFrequency ("Distortion Frequency", Float) = 3.0
        _DistortionStrength ("Distortion Strength", Range(0, 0.002)) = 0.0001
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent"
            "Queue" = "Transparent+100" 
            "RenderPipeline" = "UniversalPipeline" 
        }

        Blend One Zero
        ZWrite Off
        Cull Back

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _HeightColor;
                float _HeightThreshold;
                float _Metallic;
                float _Roughness;
                float _DistortionSpeed;
                float _DistortionFrequency;
                float _DistortionStrength;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;

                output.positionSS = ComputeScreenPos(output.positionCS);

                return output;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float isAbove = step(IN.positionWS.y, _HeightThreshold);
                half4 tintColor = lerp(_BaseColor, _HeightColor, isAbove);

                // Normalización de coordenadas de pantalla seguras
                float2 screenUV = IN.positionSS.xy / max(IN.positionSS.w, 0.0001);

                // Cálculo de distorsión
                float timeVal = _Time.y * _DistortionSpeed;
                float waveX = sin(timeVal + IN.positionWS.x * _DistortionFrequency + IN.positionWS.y * _DistortionFrequency);
                float waveY = cos(timeVal + IN.positionWS.z * _DistortionFrequency + IN.positionWS.y * _DistortionFrequency);
                
                float2 waveOffset = float2(waveX, waveY) * _DistortionStrength * isAbove;

                // FIX PARA MOBILE: clamp para restringir las UVs dentro de la pantalla [0.001, 0.999]
                float2 distortedScreenUV = clamp(screenUV + waveOffset, 0.001, 0.999);

                // Muestreo del fondo opaco
                half3 sceneColor = SampleSceneColor(distortedScreenUV);

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = tintColor.rgb;
                surfaceData.alpha = tintColor.a;
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = 1.0 - _Roughness; 
                surfaceData.normalTS = half3(0, 0, 1);

                InputData inputData = (InputData)0;
                inputData.positionWS = IN.positionWS;
                inputData.normalWS = normalize(IN.normalWS);
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                inputData.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);

                half4 pbrLighting = UniversalFragmentPBR(inputData, surfaceData);

                half3 finalRGB = lerp(sceneColor, sceneColor * tintColor.rgb, tintColor.a) + pbrLighting.rgb;

                return half4(finalRGB, 1.0);
            }
            ENDHLSL
        }
    }
}