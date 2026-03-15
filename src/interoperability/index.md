# 상호운용성

Rust와 C 코드 간 상호운용성은
두 언어 사이에서 데이터를 변환하는 작업에 달려 있습니다.
이를 위해 `stdlib`에는
[`std::ffi`](https://doc.rust-lang.org/std/ffi/index.html)
전용 모듈이 제공됩니다.

`std::ffi`는 `char`, `int`, `long` 같은
C 기본 타입 정의를 제공합니다.
또한 문자열 같은 복합 타입 변환 유틸리티도 제공하며,
`&str`과 `String`을 더 다루기 쉽고 안전한 C 타입으로 매핑할 수 있습니다.

Rust 1.30 이후에는 메모리 할당이 필요한지 여부에 따라
`std::ffi` 기능을 `core::ffi` 또는 `alloc::ffi`에서 사용할 수 있습니다.
[`cty`] 크레이트와 [`cstr_core`] 크레이트도
유사한 기능을 제공합니다.

[`cstr_core`]: https://crates.io/crates/cstr_core
[`cty`]: https://crates.io/crates/cty

| Rust 타입        | 중간 타입 | C 타입         |
| ---------------- | --------- | -------------- |
| `String`         | `CString` | `char *`       |
| `&str`           | `CStr`    | `const char *` |
| `()`             | `c_void`  | `void`         |
| `u32` 또는 `u64` | `c_uint`  | `unsigned int` |
| 기타             | ...       | ...            |

C 기본 타입 값은 대응되는 Rust 타입으로,
또는 그 반대로 사용할 수 있습니다.
전자가 후자의 타입 별칭(type alias)이기 때문입니다.
예를 들어 아래 코드는 `unsigned int`가 32비트인 플랫폼에서 컴파일됩니다.

```rust,ignore
fn foo(num: u32) {
    let c_num: c_uint = num;
    let r_num: u32 = c_num;
}
```

## 다른 빌드 시스템과의 상호운용

임베디드 프로젝트에 Rust를 포함할 때 흔한 요구사항은
기존 빌드 시스템(make, cmake 등)과 Cargo를 함께 사용하는 것입니다.

이에 대한 예제와 사용 사례는 이슈 트래커의
[issue #61]에 모으고 있습니다.

[issue #61]: https://github.com/rust-embedded/book/issues/61

## RTOS와의 상호운용

FreeRTOS, ChibiOS 같은 RTOS와 Rust 통합은 아직 진행 중인 주제입니다.
특히 Rust에서 RTOS 함수를 호출하는 부분이 까다로울 수 있습니다.

현재 공개적으로 Rust<->RTOS 상호운용을 지원하는 프로젝트는 다음과 같습니다.

- [Zephyr Project](https://docs.zephyrproject.org/latest/develop/languages/rust/index.html)

관련 예제와 사용 사례는 이슈 트래커의
[issue #62]에 모으고 있습니다.

[issue #62]: https://github.com/rust-embedded/book/issues/62
