Shader "NewPBR/SHShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1.0,1.0,1.0,1.0)
        _Metallic ("Metallic", Range(0,1)) = 0
        _MetallicMap ("MetallicMap", 2D) = "white" {}
        _NormalMap ("NormalMap", 2D) = "bump" {}
        _Roughness("Roughness",Range(0,1)) = 1
        _AO("AO",Range(0,1)) = 1
        _ClearCoat("ClearCoat",Range(0,1)) = 0
        _ClearCoatRoughness("ClearCoatRoughness",Range(0,1)) = 0
        //_IrradianceMap("IrradianceMap",CUBE) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode"="ForwardBase"}
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            #define CLEAR_COAT 1

            struct appdata
            {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;

				float2 uv2 : TEXCOORD1;
				float2 uv3 : TEXCOORD2;
				float2 uv4 : TEXCOORD3;
				float4 color : COLOR0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worldBinormal : TEXCOORD4;

                float3 SHDiffuse: TEXCOORD5;
            };

            float4 _EnvCoefficients[9];
            sampler2D _MainTex, _MetallicMap, _NormalMap;
            //samplerCUBE _IrradianceMap;
            float4 _MainTex_ST, _MetallicMap_ST, _NormalMap_ST;
            fixed4 _BaseColor;
            float _Metallic, _Roughness, _AO, _ClearCoat, _ClearCoatRoughness;

            float3 fresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
            }

            float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
            {
                float3 temp =  float3(max(1.0 - roughness, F0.x), max(1.0 - roughness, F0.y), max(1.0 - roughness, F0.z));
                return F0 + (temp - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
            }

            float DistributionGGX(float3 N, float3 H, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float NdotH = max(dot(N, H), 0.0);
                float NdotH2 = NdotH * NdotH;

                float nom   = a2;
                float denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = UNITY_PI * denom * denom;

                return nom / denom;
            }

            float GeometrySchlickGGX(float NdotV, float roughness)
            {
                float r = (roughness + 1.0);
                float k = (r*r) / 8.0;

                float nom   = NdotV;
                float denom = NdotV * (1.0 - k) + k;

                return nom / denom;
            }

            float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
            {
                float NdotV = max(dot(N, V), 0.0);
                float NdotL = max(dot(N, L), 0.0);
                float ggx2  = GeometrySchlickGGX(NdotV, roughness);
                float ggx1  = GeometrySchlickGGX(NdotL, roughness);

                return ggx1 * ggx2;
            }

            float2 LUT_Approx(float roughness, float NoV )
            {
                // Adaptation to fit our G term.
                const float4 c0 = { -1, -0.0275, -0.572, 0.022 };
                const float4 c1 = { 1, 0.0425, 1.04, -0.04 };
                float4 r = roughness * c0 + c1;
                float a004 = min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
                float2 AB = float2( -1.04, 1.04 ) * a004 + r.zw;
                return saturate(AB);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBinormal = cross(o.worldNormal, o.worldTangent) * v.tangent.w;

                float3 sh_0 = v.color.rgb;
				float3 sh_1 = float3(v.color.a, v.uv2);
				float3 sh_2 = float3(v.uv3, v.uv4.x);

                float r = (dot(sh_0, float3(_EnvCoefficients[0].r, _EnvCoefficients[1].r, _EnvCoefficients[2].r)) + \
                    dot(sh_1, float3(_EnvCoefficients[3].r, _EnvCoefficients[4].r, _EnvCoefficients[5].r)) + \
                    dot(sh_2, float3(_EnvCoefficients[6].r, _EnvCoefficients[7].r, _EnvCoefficients[8].r)));
				float g = (dot(sh_0, float3(_EnvCoefficients[0].g, _EnvCoefficients[1].g, _EnvCoefficients[2].g)) + \
                    dot(sh_1, float3(_EnvCoefficients[3].g, _EnvCoefficients[4].g, _EnvCoefficients[5].g)) + \
                    dot(sh_2, float3(_EnvCoefficients[6].g, _EnvCoefficients[7].g, _EnvCoefficients[8].g)));
                float b = (dot(sh_0, float3(_EnvCoefficients[0].b, _EnvCoefficients[1].b, _EnvCoefficients[2].b)) + \
                    dot(sh_1, float3(_EnvCoefficients[3].b, _EnvCoefficients[4].b, _EnvCoefficients[5].b)) + \
                    dot(sh_2, float3(_EnvCoefficients[6].b, _EnvCoefficients[7].b, _EnvCoefficients[8].b)));

                o.SHDiffuse = float3(r, b, g) * 0.318;//1/pi

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                col *= _BaseColor;

                float3x3 TBN = float3x3(normalize(i.worldTangent), normalize(i.worldBinormal), normalize(i.worldNormal));
                float3 tangentNormal = UnpackNormal(tex2D(_NormalMap, i.uv));
                float3 normalDir = normalize(mul(TBN, tangentNormal));
                float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                float3 h = normalize(worldLightDir + worldViewDir);
                float roughness = _Roughness;
                float metallic = tex2D(_MetallicMap, i.uv).r * _Metallic;
                //F
                float3 F0 = float3(0.04, 0.04, 0.04);
                F0 = lerp(F0, col.rgb, metallic);
                #if CLEAR_COAT
                   float3 F0RT = sqrt(F0);
                   F0 = (1 - 5 * F0RT) * (1 - 5 * F0RT) / (5 - F0RT) / (5 - F0RT);
                #endif
                //float3 F = fresnelSchlick(max(dot(h, worldViewDir), 0.0), F0);
                float3 F = fresnelSchlickRoughness(max(dot(normalDir, worldViewDir), 0.0), F0, roughness);

                float3 kS = F;
                float3 kD = float3(1.0, 1.0, 1.0) - kS;
                kD *= 1.0 - metallic;

                //SH Diffuse
                float3 diffuse = i.SHDiffuse * col.rgb;

                //IBL Specular
                const float MAX_REFLECTION_LOD = 4.0;
                float3 R = reflect(-worldViewDir, normalDir);
                float3 prefilteredColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R, roughness * MAX_REFLECTION_LOD);
                prefilteredColor = DecodeHDR(float4(prefilteredColor, 1.0), unity_SpecCube0_HDR);
                float2 envBRDF = LUT_Approx(roughness, max(dot(normalDir, worldViewDir), 0.0));
                float3 specularIBL = prefilteredColor * (F * envBRDF.x + envBRDF.y);
                float3 color = kD * diffuse + specularIBL;

                #if CLEAR_COAT
                float Fc = fresnelSchlickRoughness(max(dot(normalDir, worldViewDir), 0.0), 0.04, _ClearCoatRoughness) * _ClearCoat;
                float3 clearCoatPrefilteredColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R, _ClearCoatRoughness * MAX_REFLECTION_LOD);
                float3 clearCoatIBL = clearCoatPrefilteredColor * Fc;
                color = clearCoatIBL + (1 - Fc) * (kD * diffuse + (1 - Fc) * specularIBL);
                #endif

                color *= _AO;

                // HDR tonemapping
                color = color / (color + float3(1.0, 1.0, 1.0));
                // gamma correct
                //color = pow(color, float3(1.0/2.2, 1.0/2.2, 1.0/2.2));

                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }
}
