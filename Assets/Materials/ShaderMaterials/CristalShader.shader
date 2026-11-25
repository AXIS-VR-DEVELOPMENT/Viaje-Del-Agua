Shader "Custom/CristalShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 0.5)
        _HeightColor("Change Color (Blue)", Color) = (0, 0, 1, 0.5)
        _HeightThreshold ("Height Threshold (World Y)", Float) = 0.0
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        _Roughness ("Roughness", Range(0, 1)) = 0.5

        [Header(Underwater Distortion)]
        _DistortionSpeed ("Distortion Speed", Float) = 0.8
        _DistortionFrequency ("Distortion Frequency", Float) = 3.0
        _DistortionStrength ("Distortion Strength", Range(0, 0.02)) = 0.003

        [Header(Background)]
        // ON : conserva agua / UI / otros shaders ya dibujados (usar con la cola por defecto).
        // OFF: reemplaza el fondo con la escena distorsionada (sin imagen doble, pero borra
        //      lo que se dibujó antes; bajar el Render Queue del material a ~2900).
        [Toggle(_KEEP_BACKGROUND)] _KeepBackground ("Keep transparents behind (water / UI)", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent+100"
            "RenderPipeline" = "UniversalPipeline"
        }

        // Con alpha = 1 (modo reemplazo) el fondo desaparece; con alpha = tinte (modo conservar)
        // el framebuffer se mantiene.
        Blend One OneMinusSrcAlpha
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
            #pragma shader_feature_local _KEEP_BACKGROUND
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
                Varyings output = (Varyings)0;

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
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float isUnder = step(IN.positionWS.y, _HeightThreshold);
                half4 tintColor = lerp(_BaseColor, _HeightColor, isUnder);

                // UV normalizada por ojo
                float2 screenUV = GetNormalizedScreenSpaceUV(IN.positionCS);

                // Distorsión (solo bajo el umbral)
                float timeVal = _Time.y * _DistortionSpeed;
                float waveX = sin(timeVal + IN.positionWS.x * _DistortionFrequency + IN.positionWS.y * _DistortionFrequency);
                float waveY = cos(timeVal + IN.positionWS.z * _DistortionFrequency + IN.positionWS.y * _DistortionFrequency);

                float2 waveOffset = float2(waveX, waveY) * _DistortionStrength * isUnder;
                float2 distortedScreenUV = clamp(screenUV + waveOffset, 0.001, 0.999);

                half3 distortedScene = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, distortedScreenUV).rgb;

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

                half3 glassTint = tintColor.rgb * tintColor.a;

            #if defined(_KEEP_BACKGROUND)
                // Conserva lo que ya está en el framebuffer (agua, UI, otros shaders)
                // y le suma solo la diferencia que introduce la distorsión.
                half3 cleanScene = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV).rgb;
                half3 distortionDelta = (distortedScene - cleanScene) * isUnder;

                half3 finalRGB = glassTint + pbrLighting.rgb + distortionDelta * (1.0 - tintColor.a);
                return half4(finalRGB, tintColor.a);
            #else
                // Reemplaza el fondo por la escena distorsionada (alpha = 1 anula el framebuffer).
                half3 finalRGB = distortedScene * (1.0 - tintColor.a) + glassTint + pbrLighting.rgb;
                return half4(finalRGB, 1.0);
            #endif
            }
            ENDHLSL
        }
    }
}