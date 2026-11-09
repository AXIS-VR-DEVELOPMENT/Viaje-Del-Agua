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
        _DistortionSpeed ("Distortion Speed", Float) = 2.0
        _DistortionFrequency ("Distortion Frequency", Float) = 8.0
        _DistortionStrength ("Distortion Strength", Range(0, 0.1)) = 0.015
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

            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            // Incluimos la librería para capturar el fondo de la pantalla
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
                float4 positionSS : TEXCOORD2; // Coordenadas de pantalla para muestrear el fondo
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

                // Transforma la posición de clip space a coordenadas de pantalla
                output.positionSS = ComputeScreenPos(output.positionCS);

                return output;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float isAbove = step(IN.positionWS.y, _HeightThreshold);
                half4 tintColor = lerp(_BaseColor, _HeightColor, isAbove);

                // 1. Obtener coordenadas de pantalla (UVs)
                float2 screenUV = IN.positionSS.xy / IN.positionSS.w;

                // 2. Calcular las ondas tipo agua con Seno y Coseno basándonos en el tiempo y posición mundial
                float waveX = sin(_Time.y * _DistortionSpeed + IN.positionWS.x * _DistortionFrequency + IN.positionWS.y * _DistortionFrequency);
                float waveY = cos(_Time.y * _DistortionSpeed + IN.positionWS.z * _DistortionFrequency + IN.positionWS.y * _DistortionFrequency);
                
                // La distorsión se aplica únicamente cuando 'isAbove' se activa (1.0)
                float2 waveOffset = float2(waveX, waveY) * _DistortionStrength * isAbove;
                float2 distortedScreenUV = screenUV + waveOffset;

                // 3. Muestrear lo que hay detrás del objeto aplicando la distorsión
                half3 sceneColor = SampleSceneColor(distortedScreenUV);

                // 4. Configurar iluminación PBR
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

                // 5. Mezclar el fondo distorsionado con el tinte azul y los destellos/reflejos PBR
                half3 backgroundWithTint = lerp(sceneColor, sceneColor * tintColor.rgb, tintColor.a);
                half3 finalRGB = backgroundWithTint + pbrLighting.rgb * surfaceData.alpha;

                return half4(finalRGB, 1.0);
            }
            ENDHLSL
        }
    }
}