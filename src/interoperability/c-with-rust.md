# Rust 코드에 C 조금 섞기

Rust 프로젝트 안에서 C/C++를 사용하는 일은 크게 두 부분으로 나뉩니다.

- 노출된 C API를 Rust에서 사용할 수 있게 래핑하기
- Rust 코드와 통합될 수 있도록 C/C++ 코드를 빌드하기

C++는 Rust 컴파일러가 안정적으로 타깃할 수 있는 ABI가 없으므로,
Rust와 C/C++를 함께 사용할 때는 `C` ABI를 사용하는 것을 권장합니다.

## 인터페이스 정의

Rust에서 C/C++ 코드를 사용하기 전에,
링크된 코드에 어떤 데이터 타입과 함수 시그니처가 있는지 Rust 쪽에 정의해야 합니다.
C/C++에서는 이런 정보를 헤더 파일(`.h`, `.hpp`)로 포함하지만,
Rust에서는 이를 수동으로 번역하거나 도구로 생성해야 합니다.

먼저 C/C++ 정의를 Rust로 수동 번역하는 방법을 봅니다.

### C 함수와 데이터 타입 래핑

보통 C/C++ 라이브러리는 공개 인터페이스에서 사용하는 타입/함수를
헤더 파일로 제공합니다. 예시는 다음과 같습니다.

```C
/* File: cool.h */
typedef struct CoolStruct {
    int x;
    int y;
} CoolStruct;

void cool_function(int i, char c, CoolStruct* cs);
```

이를 Rust로 번역하면 다음과 같습니다.

```rust,ignore
/* File: cool_bindings.rs */
#[repr(C)]
pub struct CoolStruct {
    pub x: cty::c_int,
    pub y: cty::c_int,
}

extern "C" {
    pub fn cool_function(
        i: cty::c_int,
        c: cty::c_char,
        cs: *mut CoolStruct
    );
}
```

각 구성 요소를 하나씩 살펴보겠습니다.

```rust,ignore
#[repr(C)]
pub struct CoolStruct { ... }
```

기본적으로 Rust는 `struct`의 필드 순서, 패딩, 크기를 C와 동일하게 보장하지 않습니다.
C 코드와 호환성을 보장하려면 `#[repr(C)]`를 붙여,
구조체 메모리 배치를 C 규칙으로 강제해야 합니다.

```rust,ignore
pub x: cty::c_int,
pub y: cty::c_int,
```

C/C++의 `int`, `char`는 플랫폼에 따라 표현이 달라질 수 있으므로,
`cty`에 정의된 기본 타입을 사용하는 것이 좋습니다.
이 타입들은 C 타입을 Rust 타입에 안전하게 매핑합니다.

```rust,ignore
extern "C" { pub fn cool_function( ... ); }
```

이 선언은 C ABI를 사용하는 `cool_function`의 시그니처를 정의합니다.
함수 본문은 정의하지 않았으므로,
실제 구현은 다른 곳에서 제공되거나 정적 라이브러리로 링크되어야 합니다.

```rust,ignore
    i: cty::c_int,
    c: cty::c_char,
    cs: *mut CoolStruct
```

앞서와 마찬가지로 함수 인자 타입도 C 호환 타입으로 정의합니다.
가독성을 위해 인자 이름도 원본과 맞추는 편이 좋습니다.

여기서 새로 보이는 타입은 `*mut CoolStruct`입니다.
C에는 Rust의 참조(`&mut CoolStruct`) 개념이 없기 때문에 raw pointer를 사용합니다.
이 포인터 역참조는 `unsafe`이며 `null`일 수도 있으므로,
C/C++와 상호작용할 때 Rust 수준의 안전 보장을 유지하도록 주의해야 합니다.

### 인터페이스 자동 생성

수동 생성은 번거롭고 실수하기 쉬우므로,
[bindgen] 도구로 자동 변환하는 방법을 많이 사용합니다.
사용법은 [bindgen user's manual]을 참고하고,
일반적인 흐름은 다음과 같습니다.

1. Rust에서 사용할 C/C++ 인터페이스/타입 헤더를 모읍니다.
2. `bindings.h`를 만들고 1번에서 모은 파일을 `#include "..."`로 포함합니다.
3. Feed this `bindings.h` file, along with any compilation flags used to compile
   your code into `bindgen`. Tip: use `Builder.ctypes_prefix("cty")` /
   `--ctypes-prefix=cty` and `Builder.use_core()` / `--use-core` to make the generated code `#![no_std]` compatible.
4. `bindgen`이 생성한 Rust 코드를 터미널 출력으로 내보냅니다.
   이 출력을 `bindings.rs` 같은 파일로 리디렉션해 프로젝트에서 사용할 수 있습니다.
   생성된 타입에 `cty` 접두사가 붙었다면 [`cty`](https://crates.io/crates/cty) 크레이트를 함께 사용해야 합니다.

[bindgen]: https://github.com/rust-lang/rust-bindgen
[bindgen user's manual]: https://rust-lang.github.io/rust-bindgen/

## C/C++ 코드 빌드

Rust 컴파일러는 C/C++ 코드(또는 C 인터페이스를 노출하는 타 언어 코드)를
직접 컴파일하지 못하므로,
Rust 외 코드는 미리 컴파일해 두어야 합니다.

임베디드 프로젝트에서는 보통 C/C++ 코드를
`cool-library.a` 같은 정적 아카이브로 빌드해,
최종 링크 단계에서 Rust 코드와 결합합니다.

사용하려는 라이브러리가 이미 정적 아카이브로 배포된다면,
직접 다시 빌드할 필요는 없습니다.
위에서 설명한 대로 헤더를 변환하고,
컴파일/링크 시점에 정적 아카이브를 포함하면 됩니다.

소스 프로젝트 형태라면 C/C++ 코드를 정적 라이브러리로 빌드해야 합니다.
기존 빌드 시스템(`make`, `CMake` 등)을 호출하거나,
필요한 컴파일 절차를 `cc` 크레이트 방식으로 옮기면 됩니다.
두 방식 모두에서 `build.rs` 스크립트가 필요합니다.

### Rust `build.rs` 빌드 스크립트

`build.rs` 스크립트는 Rust 문법으로 작성한 파일이며,
프로젝트 의존성이 빌드된 뒤, 프로젝트 본체 빌드 전에
컴파일 머신에서 실행됩니다.

전체 레퍼런스는 [여기](https://doc.rust-lang.org/cargo/reference/build-scripts.html)에서 볼 수 있습니다.
`build.rs`는 [bindgen]을 통한 코드 생성,
`Make` 같은 외부 빌드 시스템 호출,
`cc` 크레이트로 C/C++ 직접 컴파일 등에 유용합니다.

### 외부 빌드 시스템 호출

외부 프로젝트/빌드 시스템이 복잡한 경우,
[`std::process::Command`]로 다른 빌드 시스템을 호출하는 것이 가장 단순할 수 있습니다.
상대 경로 이동 후 `make library` 같은 고정 명령을 실행하고,
결과 정적 라이브러리를 `target` 빌드 디렉터리의 적절한 위치로 복사하면 됩니다.

크레이트가 `no_std` 임베디드 플랫폼을 타깃하더라도,
`build.rs`는 크레이트를 컴파일하는 호스트 머신에서만 실행됩니다.
즉 호스트에서 실행 가능한 Rust 크레이트는 자유롭게 사용할 수 있습니다.

[`std::process::Command`]: https://doc.rust-lang.org/std/process/struct.Command.html

### `cc` 크레이트로 C/C++ 코드 빌드

의존성/복잡도가 낮거나,
기존 빌드 시스템을 정적 라이브러리 출력으로 바꾸기 어려운 프로젝트라면
호스트 컴파일러를 Rust 스타일로 다루게 해 주는 [`cc` crate] 사용이 더 쉬울 수 있습니다.

[`cc` crate]: https://github.com/alexcrichton/cc-rs

단일 C 파일을 정적 라이브러리 의존성으로 컴파일하는 가장 단순한 경우,
[`cc` crate]를 사용하는 `build.rs` 예시는 다음과 같습니다.

```rust,ignore
fn main() {
    cc::Build::new()
        .file("src/foo.c")
        .compile("foo");
}
```

`build.rs`는 패키지 루트에 둡니다.
그러면 `cargo build`가 패키지 빌드 전에 `build.rs`를 컴파일/실행하고,
`libfoo.a` 정적 아카이브를 생성해 `target` 디렉터리에 배치합니다.
