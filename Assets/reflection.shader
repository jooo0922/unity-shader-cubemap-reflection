Shader "Custom/reflection"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Cube ("Cubemap", Cube) = "" {} // 큐브맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM

        // Lambert 라이트 기본형으로 시작
        #pragma surface surf Lambert noambient // 환경광(Ambient Light) 제거

        sampler2D _MainTex;
        samplerCUBE _Cube; // 큐브맵 텍스쳐를 담는 전용 샘플러 변수인 samplerCUBE 선언

        struct Input
        {
            float2 uv_MainTex;
            float3 worldRefl; 
            /*
                큐브맵 텍스쳐는 3차원 공간에 맵핑되는 텍스쳐임.

                따라서, 해당 텍스쳐가 환경광이 될 것이고, 
                물체의 각 표면(프래그먼트)로 환경광이 들어온다고 가정했을 때,

                어느 프래그먼트에 도달해서 어느 쪽으로 반사를 시키는지,
                즉 '반사벡터'를 알아야 큐브맵 텍스쳐에서 어떤 부분을 샘플링하여
                물체의 표면(프래그먼트)에 적용할 지 알 수 있겠찌

                그래서 큐브맵 텍스쳐는 UV좌표값으로
                반사벡터를 사용함.
            */
        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
            o.Albedo = 0;

            float4 re = texCUBE(_Cube, IN.worldRefl); // 큐브맵 텍스쳐의 텍셀값을 샘플링해오는 함수 texCUBE() 사용
            o.Emission = re.rgb; 
            /*
                큐브맵 텍스쳐의 최종 텍셀값은 o.Emission 프로퍼티에 할당함.

                o.Albedo 는 물체의 원 색상이고,
                o.Emission 은 물체로부터 발산되는 빛에 해당함.

                한편, 큐브맵 텍스쳐로부터 적용한 환경광(반사광)은
                상식적으로 생각해봐도 물체의 원 색상은 아니잖아? '반사광'이니까

                반면, 주변의 이미지가 물체로 닿아서 반사시키는 빛은
                물체로부터 발산되는 빛의 한 종류로도 볼 수 있으니
                o.Emission 에 넣어서 계산해주는 게 더 적합하겠지.
            */

            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}

/*
    큐브맵 텍스쳐 사용 시 o.Albedo 와 o.Emission 의 비율값

    위에서 말했듯이,
    o.Albedo 는 물체의 원 색상,
    o.Emission 은 '반사광'을 포함해 물체로부터 발산되는 빛
    이라고 했었지.

    그런데, 물체의 원 색상도 어느 정도 값이 있고,
    반사광도 어느 정도 값이 있어서
    둘이 합해져서 조명값이 1을 훨씬 넘는 결과가 나오면
    결과적으로 하얗게 떠보이는 렌더링이 되어버림.

    그래서, 물체가 어느 정도 반사가 되는 재질이냐를
    결정하기 위해서 o.Albedo 와 o.Emission 에 적절한 비율값을
    곱해줘야 함.

    한 50% 정도 반사되는 재질이다 라고 하면
    Albedo 와 Emission 각각에 0.5 씩 곱해주면 되고,

    금속이나 거울처럼 100% 반사되는 재질이다 라고 하면
    Albedo 는 0 으로 초기화해버리는 게 맞겠지.

    이렇게 해야, Albedo (즉, 디퓨즈 라이팅)은 0%
    Emission(즉, 스펙큘러 라이팅)은 100% 인 이미지가 나오니까!
*/