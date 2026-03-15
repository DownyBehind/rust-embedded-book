# 네이밍

<a id="c-crate-name"></a>

## The crate is named appropriately (C-CRATE-NAME)

HAL 크레이트는 지원 대상 칩 또는 칩 패밀리 이름을 따라야 합니다.
레지스터 접근 크레이트와 구분할 수 있도록 이름은 `-hal`로 끝나야 합니다.
이름에 밑줄(`_`)은 사용하지 말고 대시(`-`)를 사용해야 합니다.
