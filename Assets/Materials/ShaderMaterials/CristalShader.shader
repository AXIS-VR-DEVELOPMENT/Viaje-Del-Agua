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
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            // Se dibuja ANTES que el agua / UI (cola 3000) para que ellos se pinten encima
            "Queue" = "Transparent-100"
            "RenderPipeline" = "UniversalPipeline"
        }

        // El shader compone él mismo el fondo (escena distorsionada + tinte),
        // así que reemplaza el framebuffer en vez de mezclarse con él.
        // Esto elimina la imagen doble en VR.
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

                // Una sola muestra de la escena opaca (ya distorsionada). Sin delta, sin leer el framebuffer.
                half3 sceneColor = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, distortedScreenUV).rgb;

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

                // Composición manual: escena * (1 - alpha) + tinte * alpha + iluminación
                half3 finalRGB = sceneColor * (1.0 - tintColor.a)
                               + tintColor.rgb * tintColor.a
                               + pbrLighting.rgb;

                return half4(finalRGB, 1.0);
            }
            ENDHLSL
        }
    }
}