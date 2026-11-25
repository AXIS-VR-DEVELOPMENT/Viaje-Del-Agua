Shader "UI/RadialDissolve"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1, 1, 1, 1)

        [Header(Control de Disolucion)]
        _DissolveAmount ("Progreso Disolucion", Range(0, 1)) = 0.0
        _Center ("Centro UV (0.5 = Centro)", Vector) = (0.5, 0.5, 0, 0)
        _AspectRatio ("Proporcion Ancho/Alto", Float) = 1.0

        [Header(Patron y Borde Brillante)]
        _NoiseScale ("Escala del Patron", Float) = 6.0
        _NoiseStrength ("Fuerza del Patron", Range(0, 1)) = 0.35
        [HDR] _EdgeColor ("Color del Borde (HDR)", Color) = (0.2, 1.8, 4.5, 1)
        _EdgeWidth ("Grosor del Borde", Range(0.001, 0.25)) = 0.06

        // Propiedades obligatorias para compatibilidad con UI Mask y ScrollView
        [HideInInspector] _StencilComp ("Stencil Comparison", Float) = 8
        [HideInInspector] _Stencil ("Stencil ID", Float) = 0
        [HideInInspector] _StencilOp ("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask ("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask ("Stencil Read Mask", Float) = 255
        [HideInInspector] _ColorMask ("Color Mask", Float) = 15
        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            Name "Default"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // Shader Model 3.0+ es obligatorio para SV_InstanceID en Single-Pass Instanced / Multiview
            #pragma target 3.0

            // Compila las variantes estéreo para VR (Meta Quest)
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP

            struct appdata_t
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex        : SV_POSITION;
                fixed4 color         : COLOR;
                float2 texcoord      : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            fixed4 _Color;
            fixed4 _TextureSampleAdd;
            float4 _ClipRect;
            float4 _MainTex_ST;

            float _DissolveAmount;
            float4 _Center;
            float _AspectRatio;
            float _NoiseScale;
            float _NoiseStrength;
            float4 _EdgeColor;
            float _EdgeWidth;

            // --- Ruido Fractal 2D (FBM) para el borde orgánico ---
            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float noise2D(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float a = hash21(i);
                float b = hash21(i + float2(1.0, 0.0));
                float c = hash21(i + float2(0.0, 1.0));
                float d = hash21(i + float2(1.0, 1.0));

                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float fbm2D(float2 p)
            {
                float value = 0.0;
                float amplitude = 0.5;
                for (int i = 0; i < 4; i++)
                {
                    value += amplitude * noise2D(p);
                    p *= 2.05;
                    amplitude *= 0.5;
                }
                return value;
            }

            v2f vert(appdata_t v)
            {
                v2f OUT;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                OUT.worldPosition = v.vertex;
                OUT.vertex = UnityObjectToClipPos(OUT.worldPosition);
                OUT.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                OUT.color = v.color * _Color;
                return OUT;
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                // Activa el índice de ojo correcto en el fragment shader
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                // 1. Obtiene la imagen/sprite original del Canvas y su transparencia
                half4 color = (tex2D(_MainTex, IN.texcoord) + _TextureSampleAdd) * IN.color;

                // 2. Distancia radial normalizada desde el centro del RectTransform (0 a 1 hasta las esquinas)
                float2 aspectScale = float2(_AspectRatio, 1.0);
                float2 centeredUV = (IN.texcoord - _Center.xy) * aspectScale;
                float maxCornerDist = length(float2(0.5 * _AspectRatio, 0.5));
                float radialMask = length(centeredUV) / max(maxCornerDist, 0.0001);

                // 3. Deformación orgánica con ruido 2D
                float noise = fbm2D(IN.texcoord * aspectScale * _NoiseScale);
                float dissolvePattern = radialMask + (noise - 0.5) * _NoiseStrength;

                // 4. Umbral suavizado para evitar bordes pixelados en UI
                float minBound = -0.5 * _NoiseStrength - 0.02;
                float maxBound = 1.0 + 0.5 * _NoiseStrength + 0.02;
                float threshold = lerp(minBound, maxBound, _DissolveAmount);

                float diff = dissolvePattern - threshold;
                float dissolveAlpha = smoothstep(0.0, 0.015, diff);

                // 5. Borde emisivo brillante solo en el contorno activo
                float edgeMask = (1.0 - smoothstep(0.0, _EdgeWidth, diff)) * step(0.001, _DissolveAmount) * dissolveAlpha;
                color.rgb += edgeMask * _EdgeColor.rgb;
                color.a *= dissolveAlpha;

                #ifdef UNITY_UI_CLIP_RECT
                color.a *= UnityGet2DClipping(IN.worldPosition.xy, _ClipRect);
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip(color.a - 0.001);
                #endif

                return color;
            }
            ENDCG
        }
    }
}