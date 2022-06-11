Shader "Custom/reflection"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _BumpMap ("NormalMap", 2D) = "bump" {} // 노말맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _MaskMap ("MaskMap", 2D) = "white" {} // 마스크맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _Cube ("Cubemap", Cube) = "" {} // 큐브맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM

        // Lambert 라이트 기본형으로 시작
        #pragma surface surf Lambert noambient // 환경광(Ambient Light) 제거

        sampler2D _MainTex;
        sampler2D _BumpMap; // 노멀맵 텍스쳐를 담는 샘플러 변수
        sampler2D _MaskMap; // 마스크맵 텍스쳐를 담는 샘플러 변수
        samplerCUBE _Cube; // 큐브맵 텍스쳐를 담는 전용 샘플러 변수인 samplerCUBE 선언

        struct Input
        {
            float2 uv_MainTex;
            float2 uv_BumpMap; // 노멀맵 텍스쳐의 uv 좌표값 구조체에 정의
            float2 uv_MaskMap; // 마스크맵 텍스쳐의 uv 좌표값 구조체에 정의
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

            INTERNAL_DATA // 탄젠트 공간 노멀 벡터(UnpackNormal 에서 구해주는 값)를 월드 공간의 픽셀 노멀 벡터로 변환하기 위해 필요한 키워드 지정!
        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            // 마스크맵을 샘플링하여 물체의 원색상 (Albedo) 를 100%로 보여줄 영역과 반사광 (큐브맵 텍스쳐) 을 100%로 보여줄 영역을 구분할거임.
            float4 m = tex2D(_MaskMap, IN.uv_MaskMap);

            // Albedo 텍스쳐 (물체의 원 색상) 적용
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex);

            // 포토샵에서 임의로 만든 마스크맵의 검정색 부분의 r채널은 0, 흰색 부분의 r채널은 1임. 
            // -> 이 값을 1에서 빼줘서 뒤집었으니, 검정색 부분은 1이 되서 Albedo (물체의 원 색상)가 100% 반영되고,
            // 흰색 부분은 0이 되서 물체의 원색상이 0%, 즉 아예 안 보이게 됨.
            o.Albedo = c.rgb * (1 - m.r); 

            o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap)); // UnpackNormal() 로 노말맵 텍스쳐로부터 탄젠트 공간 노멀 벡터(나중에 <셰이더 코딩 입문>에서 자세히 배울 예정)를 구함.

            // 큐브맵 텍스쳐 (반사광) 적용
            float4 re = texCUBE(_Cube, WorldReflectionVector(IN, o.Normal)); // 큐브맵 텍스쳐의 텍셀값을 샘플링해오는 함수 texCUBE() 사용 + WorldReflectionVector() 내장함수로 월드공간 픽셀 노멀로 변환된 노멀벡터를 적용한 반사벡터를 구함(하단 필기 참고)

            // 위에 Albedo와는 정 반대로, 마스크맵의 검정색 부분 r채널 0, 흰색 부분 r채널 1을 그대로 곱해서
            // 검정색 부분은 큐브맵 텍스쳐 (반사광)이 0%, 즉 아예 안보이게 되고,
            // 흰색 부분은 큐브맵 텍스쳐 (반사광)이 100% 반영될거임.
            o.Emission = re.rgb * m.r; 
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

/*
    WorldReflectionVector()

    이 함수를 통해서 우리가 이루려는 목표가 뭐냐면,
    '노말맵 텍스쳐의 노말벡터가 적용된 반사벡터'를 구해서
    큐브맵 텍스쳐를 샘플링해오고 싶은 것임.

    이게 뭔 말이냐, 반사벡터는 알다시피 조명벡터와 노멀벡터로 구하잖아?
    즉, 노멀벡터에 따라서 반사되는 방향이 달라진다는 거임.

    그냥 거울처럼 매끈한 반사가 아니라,
    노멀맵에 정의된 울퉁불퉁한 표면과 질감의 노멀벡터를 따라서
    반사벡터의 방향을 약간씩 틀어줌으로써,
    질감(노멀맵)과 반사광(월드공간 반사벡터)를 동시에
    구현하고 싶다는 거지.

    그러면 그냥 노멀맵을 원래 하던대로 UnpackNormal() 해줘서
    o.Normal 에 넣어주면 끝 아닌가?
    -> 이렇게 하면 에러가 남. 왜냐하면, UnpackNormal 은 '탄젠트 공간' 노멀벡터인데,
    worldRefl 은 '월드 공간' 반사벡터이다보니, 서로 좌표계가 달라서
    에러가 발생하는 것이지.


    이를 해결하려면 2가지 절차가 필요함.


    1. 먼저 Input 구조체에 INTERNAL_DATA 라는 키워드를 붙여서
    UnpackNormal() 함수로부터 얻은 탄젠트 공간 노멀벡터를
    월드공간 픽셀 노멀벡터로 변환하는 작업이 필요함.

    즉, 탄젠트 공간 -> 월드공간으로 좌표계를 맞춰주는 것이지.

    WorldReflectionVector(Input, o.Normal) 이 내장함수에
    해당 키워드를 붙여준 Input 구조체와 탄젠트공간 노멀벡터를
    인자로 넣어주면 1번의 변환작업을 자동으로 해줌.


    2. 그 다음, WorldReflectionVector() 내장함수는
    변환된 월드공간 픽셀 노멀벡터를 이용해서 
    월드공간 반사벡터인 worldRefl 의 반사방향을
    변환된 노멀벡터를 따라 적절하게 재조정 해주겠지.

    -> 인제 이렇게 재조정된 반사벡터를 리턴받아서
    texCUBE() 내장함수로부터 큐브맵 텍스쳐를 샘플링해오면
    노말맵의 질감과 큐브맵의 반사가 동시에 적용되어 렌더링될 것임!
*/