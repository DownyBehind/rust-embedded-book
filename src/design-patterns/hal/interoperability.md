# 상호운용성

<a id="c-free"></a>

## Wrapper types provide a destructor method (C-FREE)

HAL이 제공하는 non-`Copy` 래퍼 타입은
래퍼를 소비하고 생성에 사용된 원시 주변장치(및 필요한 경우 기타 객체)를
되돌려주는 `free` 메서드를 제공해야 합니다.

필요하다면 이 메서드는 주변장치를 종료하고 리셋해야 합니다.
`free`가 반환한 원시 주변장치로 `new`를 다시 호출할 때,
예상치 못한 주변장치 상태 때문에 실패해서는 안 됩니다.

HAL 타입 생성에 다른 non-`Copy` 객체(예: I/O 핀)가 필요하다면,
그 객체도 `free`에서 함께 해제되어 반환되어야 합니다.
이 경우 `free`는 튜플을 반환해야 합니다.

예시:

```rust
# pub struct TIMER0;
pub struct Timer(TIMER0);

impl Timer {
    pub fn new(periph: TIMER0) -> Self {
        Self(periph)
    }

    pub fn free(self) -> TIMER0 {
        self.0
    }
}
```

<a id="c-reexport-pac"></a>

## HALs reexport their register access crate (C-REEXPORT-PAC)

HAL은 [svd2rust]가 생성한 PAC 위에 작성할 수도 있고,
원시 레지스터 접근을 제공하는 다른 크레이트 위에 작성할 수도 있습니다.
HAL은 기반으로 사용하는 레지스터 접근 크레이트를
항상 crate root에서 reexport해야 합니다.

PAC는 실제 크레이트 이름과 무관하게 `pac`라는 이름으로 reexport하는 것이 좋습니다.
HAL 이름만으로도 어떤 PAC를 대상으로 하는지 충분히 드러나야 하기 때문입니다.

[svd2rust]: https://github.com/rust-embedded/svd2rust

<a id="c-hal-traits"></a>

## Types implement the `embedded-hal` traits (C-HAL-TRAITS)

HAL이 제공하는 타입은
[`embedded-hal`] 크레이트에서 적용 가능한 trait를 모두 구현해야 합니다.

하나의 타입에 여러 trait를 함께 구현해도 됩니다.

[`embedded-hal`]: https://github.com/rust-embedded/embedded-hal
