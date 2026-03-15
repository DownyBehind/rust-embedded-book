# HAL 디자인 패턴 체크리스트

- **네이밍** _(크레이트가 Rust 네이밍 규칙과 일치함)_
  - [ ] 크레이트 이름이 적절함 ([C-CRATE-NAME])
- **상호운용성** _(크레이트가 다른 라이브러리 기능과 자연스럽게 동작함)_
  - [ ] 래퍼 타입이 해제 메서드를 제공함 ([C-FREE])
  - [ ] HAL이 레지스터 접근 크레이트를 reexport함 ([C-REEXPORT-PAC])
  - [ ] 타입이 `embedded-hal` trait를 구현함 ([C-HAL-TRAITS])
- **예측 가능성** _(코드가 읽히는 그대로 동작함)_
  - [ ] 확장 trait 대신 생성자를 사용함 ([C-CTOR])
- **GPIO 인터페이스** _(GPIO 인터페이스가 공통 패턴을 따름)_
  - [ ] 핀 타입이 기본적으로 제로 사이즈 타입임 ([C-ZST-PIN])
  - [ ] 핀/포트 소거(erase) 메서드를 제공함 ([C-ERASED-PIN])
  - [ ] 핀 상태를 타입 파라미터로 인코딩함 ([C-PIN-STATE])

[C-CRATE-NAME]: naming.html#c-crate-name
[C-FREE]: interoperability.html#c-free
[C-REEXPORT-PAC]: interoperability.html#c-reexport-pac
[C-HAL-TRAITS]: interoperability.html#c-hal-traits
[C-CTOR]: predictability.html#c-ctor
[C-ZST-PIN]: gpio.md#c-zst-pin
[C-ERASED-PIN]: gpio.md#c-erased-pin
[C-PIN-STATE]: gpio.md#c-pin-state
