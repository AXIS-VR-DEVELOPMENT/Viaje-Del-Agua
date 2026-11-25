Shader "Custom/RadialDissolveURP"
{
    Properties
    {
        [MainTexture] _BaseMap ("Textura Base", 2D) = "white" {}
        [MainColor] _BaseColor ("Color Base", Color) = (1, 1, 1, 1)

        [Header(Propiedades PBR)]
        _Metallic ("Metallic Texture", 2D) = "white" {}
        _MetallicStrength ("Intensidad Metalica", Range(0, 1)) = 1.0
        _Smoothness ("Suavidad (Smoothness)", Range(0, 1)) = 0.5

        [Header(Emision)]
        _EmissionMap ("Mapa de Emision", 2D) = "white" {}
        [HDR] _EmissionColor ("Color de Emision (HDR)", Color) = (0, 0, 0, 1)

        [Header(Control de Disolucion)]
        _DissolveAmount ("Progreso Disolucion", Range(0, 1)) = 0.0
        _MaxRadius ("Radio Maximo de la Malla", Float) = 1.0
        _CenterOffset ("Centro Local (Offset)", Vector) = (0, 0, 0, 0)

        [Header(Patron y Borde Brillante)]
        _NoiseScale ("Escala del Patron", Float) = 4.0
        _NoiseStrength ("Fuerza del Patron", Range(0, 1)) = 0.35
        [HDR] _EdgeColor ("Color del Borde (HDR)", Color) = (0.2, 1.8, 4.5, 1)
        _EdgeWidth ("Grosor del Borde", Range(0.001, 0.25)) = 0.06
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "TransparentCutout" 
            "Queue" = "AlphaTest" 
            "RenderPipeline" = "UniversalPipeline" 
        }

        // Renderiza ambas caras para que al abrirse desde el centro no se vea hueco
        Cull Off

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Habilita GPU Instancing y Single-Pass Instanced / Multiview para VR (Meta Quest)
            #pragma multi_compile_instancing

            // Keywords necesarias para sombras, luces adicionales y reflejos metálicos en URP
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
                float2 uv         : TEXCOORD0;
                float3 positionOS : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_Metallic);
            SAMPLER(sampler_Metallic);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float _MetallicStrength;
                float _Smoothness;
                float4 _EmissionColor;
                float _DissolveAmount;
                float _MaxRadius;
                float4 _CenterOffset;
                float _NoiseScale;
                float _NoiseStrength;
                float4 _EdgeColor;
                float _EdgeWidth;
            CBUFFER_END

            // --- Funciones de Ruido Procedural 3D (FBM) ---
            float hash31(float3 p)
            {
                p = frac(p * 0.1031);
                p += dot(p, p.yzx + 33.33);
                return frac((p.x + p.y) * p.z);
            }

            float noise3D(float3 x)
            {
                float3 i = floor(x);
                float3 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);

                return lerp(
                    lerp(lerp(hash31(i + float3(0, 0, 0)), hash31(i + float3(1, 0, 0)), f.x),
                         lerp(hash31(i + float3(0, 1, 0)), hash31(i + float3(1, 1, 0)), f.x), f.y),
                    lerp(lerp(hash31(i + float3(0, 0, 1)), hash31(i + float3(1, 0, 1)), f.x),
                         lerp(hash31(i + float3(0, 1, 1)), hash31(i + float3(1, 1, 1)), f.x), f.y),
                    f.z
                );
            }

            float fbm3D(float3 p)
            {
                float value = 0.0;
                float amplitude = 0.5;
                for (int i = 0; i < 4; i++)
                {
                    value += amplitude * noise3D(p);
                    p *= 2.05;
                    amplitude *= 0.5;
                }
                return value;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;

                // Inicializa el ID de instancia y el índice de ojo (izquierdo/derecho) antes de transformar vértices
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.positionOS = IN.positionOS.xyz;
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag(Varyings IN, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                // Configura el ojo activo en el fragment shader para reflejos, sombras y UVs de pantalla
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                // 1. Distancia normalizada desde el centro de la malla hacia afuera
                float dist = distance(IN.positionOS, _CenterOffset.xyz);
                float radialMask = dist / max(_MaxRadius, 0.0001);

                // 2. Ruido orgánico 3D para deformar el borde
                float noise = fbm3D(IN.positionOS * _NoiseScale);
                float dissolvePattern = radialMask + (noise - 0.5) * _NoiseStrength;

                // 3. Umbral ajustado para que 0 = 100% visible y 1 = 100% invisible
                float minBound = -_NoiseStrength - _EdgeWidth;
                float maxBound = 1.0 + _NoiseStrength;
                float threshold = lerp(minBound, maxBound, _DissolveAmount);

                float diff = dissolvePattern - threshold;

                // Descarta los píxeles dentro del radio disuelto
                clip(diff);

                // 4. Muestreo de texturas e iluminación PBR (Metallic + Emission)
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half4 metallicSample = SAMPLE_TEXTURE2D(_Metallic, sampler_Metallic, IN.uv);
                half3 emissionSample = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, IN.uv).rgb;

                float3 normalWS = normalize(IN.normalWS) * (isFrontFace ? 1.0 : -1.0);
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);

                InputData inputData = (InputData)0;
                inputData.positionWS = IN.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = viewDirWS;
                inputData.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                inputData.bakedGI = SampleSH(normalWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedo.rgb;
                surfaceData.metallic = metallicSample.r * _MetallicStrength;
                surfaceData.smoothness = metallicSample.a * _Smoothness;
                surfaceData.emission = emissionSample * _EmissionColor.rgb;
                surfaceData.occlusion = 1.0;
                surfaceData.alpha = 1.0;

                half4 pbrColor = UniversalFragmentPBR(inputData, surfaceData);

                // 5. Borde emisivo brillante (se apaga cuando _DissolveAmount es 0)
                float edgeMask = (1.0 - smoothstep(0.0, _EdgeWidth, diff)) * step(0.001, _DissolveAmount);
                float3 finalColor = pbrColor.rgb + (edgeMask * _EdgeColor.rgb);

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}