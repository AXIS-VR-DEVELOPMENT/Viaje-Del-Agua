Shader "UI/AlwaysOnTop_VR"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Overlay"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest Always
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata_t
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID // <-- ID de instancia para VR
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID // <-- ID de instancia para VR
                UNITY_VERTEX_OUTPUT_STEREO     // <-- Salida estereoscópica
            };

            fixed4 _Color;
            sampler2D _MainTex;

            v2f vert(appdata_t IN)
            {
                v2f OUT;
                UNITY_SETUP_INSTANCE_ID(IN);                  // <-- Prepara el ojo actual
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);           // <-- Copia la instancia
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);   // <-- Asigna la pantalla correcta en VR

                OUT.vertex = UnityObjectToClipPos(IN.vertex);
                OUT.texcoord = IN.texcoord;
                OUT.color = IN.color * _Color;
                return OUT;
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);                  // <-- Reconoce la instancia en fragment
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN); // <-- Sincroniza la textura para el ojo activo

                half4 color = tex2D(_MainTex, IN.texcoord) * IN.color;
                return color;
            }
            ENDCG
        }
    }
}