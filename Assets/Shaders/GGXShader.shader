Shader "NewPBR/GGXShader"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1.0,1.0,1.0,1.0)
        _Metallic ("Metallic", Range(0,1)) = 0
        _MetallicMap ("MetallicMap", 2D) = "white" {}
        _NormalMap ("NormalMap", 2D) = "bump" {}
        _Roughness("Roughness",Range(0,1)) = 1
        _AO("AO",Range(0,1)) = 1
        _ClearCoat("ClearCoat",Range(0,1)) = 0
        _ClearCoatRoughness("ClearCoatRoughness",Range(0,1)) = 0
        _IrradianceMap("IrradianceMap",CUBE) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode"="ForwardBase" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "UnityImageBasedLighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                fixed4 color : COLOR;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worldBinormal : TEXCOORD4;
            };

            sampler2D _MainTex, _MetallicMap, _NormalMap;
            samplerCUBE _IrradianceMap;
            float4 _MainTex_ST, _MetallicMap_ST, _NormalMap_ST;
            fixed4 _BaseColor;
            float _Metallic, _Roughness, _AO, _ClearCoat, _ClearCoatRoughness;

            float3 fresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
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
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 col = _BaseColor;
                float3 Lo = float3(0,0,0);

                float3x3 TBN = float3x3(normalize(i.worldTangent), normalize(i.worldBinormal), normalize(i.worldNormal));
                float3 tangentNormal = UnpackNormal(tex2D(_NormalMap, i.uv));
                float3 normalDir = normalize(mul(TBN, tangentNormal));
                float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                float3 h = normalize(worldLightDir + worldViewDir);

                // float dist = distance(i.worldPos, _WorldSpaceLightPos0.xyz);
                // float atten = 1.0 / (dist * dist);
                float atten = 1.0;
                fixed3 radiance = _LightColor0.rgb * atten;
                float metallic = tex2D(_MetallicMap, i.uv).r * _Metallic;
                //F
                float3 F0 = float3(0.04, 0.04, 0.04);
                F0 = lerp(F0, col.rgb, metallic);
                //if(_ClearCoat > 0) {
                   //float3 F0RT = sqrt(F0);
                   //F0 = (1 - 5 * F0RT) * (1 - 5 * F0RT) / (5 - F0RT) / (5 - F0RT);
                //}
                float3 F = fresnelSchlick(max(dot(h, worldViewDir), 0.0), F0);
                //D
                float roughness = _Roughness;
                float NDF = DistributionGGX(normalDir, h, roughness);
                //G
                float G = GeometrySmith(normalDir, worldViewDir, worldLightDir, roughness);
                //BRDF
                float3 nom = NDF * G * F;
                float denom = 4.0 * max(dot(normalDir, worldViewDir), 0.0) * max(dot(normalDir, worldLightDir), 0.0) + 0.001;
                float3 specular = nom / denom;

                float3 kS = F;
                float3 kD = float3(1.0, 1.0, 1.0) - kS;
                kD *= 1.0 - metallic;

                float NdotL = max(dot(normalDir, worldLightDir), 0.0);
                Lo += (kD * col.rgb / UNITY_PI + specular) * radiance * NdotL;

                //以下为IBL
                const float MAX_REFLECTION_LOD = 4.0;
                float3 irradiance = texCUBE(_IrradianceMap, normalDir).rgb;
                //irradiance = DecodeHDR(float4(irradiance, 1.0), unity_SpecCube0_HDR);
                float3 diffuseIBL = irradiance * col.rgb;

                float3 R = reflect(-worldViewDir, normalDir);
                float3 prefilteredColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R, roughness * MAX_REFLECTION_LOD);
                prefilteredColor = DecodeHDR(float4(prefilteredColor, 1.0), unity_SpecCube0_HDR);
                float2 envBRDF = LUT_Approx(roughness, max(dot(normalDir, worldViewDir), 0.0));
                float3 specularIBL = prefilteredColor * (F * envBRDF.x + envBRDF.y);
                float3 ambient = kD * diffuseIBL + specularIBL;

                //clear coat
                float clearCoatPerceptualRoughness = clamp(_ClearCoatRoughness, 0.089, 1.0);
                float clearCoatRoughness = clearCoatPerceptualRoughness * clearCoatPerceptualRoughness;

                float Dc = DistributionGGX(normalDir, h, clearCoatRoughness);
                float Gc = GeometrySmith(normalDir, worldViewDir, worldLightDir, clearCoatRoughness);
                float Fc = fresnelSchlick(max(dot(h, worldViewDir), 0.0), 0.04) * _ClearCoat;
                float kC = Dc * Gc * Fc;

                float2 envClearCoatBRDF = LUT_Approx(clearCoatRoughness, max(dot(normalDir, worldViewDir), 0.0));
                float3 clearCoatIBL = prefilteredColor * Fc;

                Lo = float3(0.0, 0.0, 0.0);//无直接光照
                float3 color = ambient + Lo;
                //float3 color = Lo;
                //float3 Fd = kD * col.rgb / UNITY_PI;
                //float3 Fr = specular;
                //float3 color = ((Fd + Fr * (1.0 - Fc)) * (1.0 - Fc) + kC)  * radiance * NdotL;
                //float3 color = clearCoatIBL + sqrt(1 - Fc) * ambient;
                color *= _AO;

                // HDR tonemapping
                color = color / (color + float3(1.0, 1.0, 1.0));
                // gamma correct
                color = pow(color, float3(1.0/2.2, 1.0/2.2, 1.0/2.2));

                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }
}
