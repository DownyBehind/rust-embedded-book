# C 코드에 Rust 조금 섞기

C/C++ 프로젝트 안에서 Rust 코드를 사용하는 일은 주로 두 부분으로 구성됩니다.

- Rust에서 C 친화적인 API 만들기
- Rust 프로젝트를 외부 빌드 시스템에 포함하기

`cargo`, `meson`을 제외한 대부분의 빌드 시스템은
Rust 네이티브 지원이 제한적입니다.
그래서 대개는 크레이트와 의존성 빌드에 `cargo`를 직접 쓰는 편이 가장 단순합니다.

## 프로젝트 설정

평소처럼 새 `cargo` 프로젝트를 생성합니다.

일반 Rust 타깃 대신 시스템 라이브러리를 출력하도록
`cargo`에 지시하는 설정이 있습니다.
필요하면 크레이트 이름과 다른 라이브러리 출력 이름도 지정할 수 있습니다.

```toml
[lib]
name = "your_crate"
crate-type = ["cdylib"]      # Creates dynamic lib
# crate-type = ["staticlib"] # Creates static lib
```

## `C` API 만들기

C++에는 Rust 컴파일러가 안정적으로 타깃할 ABI가 없으므로,
이종 언어 상호운용에서는 `C` ABI를 사용합니다.
C/C++ 프로젝트 안에서 Rust를 쓰는 경우도 동일합니다.

### `#[no_mangle]`

Rust 컴파일러는 심볼 이름을 네이티브 링커 기대와 다르게 맹글링합니다.
따라서 Rust 바깥에서 사용할 함수를 내보낼 때는
컴파일러에 맹글링하지 말라고 명시해야 합니다.

### `extern "C"`

기본적으로 Rust 함수는 Rust ABI를 사용합니다.
(이 ABI도 안정화되지 않음)
외부 노출 FFI API를 만들 때는 시스템 ABI를 쓰도록
컴파일러에 알려야 합니다.

플랫폼에 따라 특정 ABI 버전을 지정해야 할 수 있으며,
관련 내용은 [여기](https://doc.rust-lang.org/reference/items/external-blocks.html)에 있습니다.

---

위 요소를 합치면 대략 다음과 같은 함수가 됩니다.

```rust,ignore
#[no_mangle]
pub extern "C" fn rust_function() {

}
```

Rust 프로젝트에서 C 코드를 사용할 때와 마찬가지로,
데이터를 애플리케이션이 이해하는 형태로 변환해야 합니다.

## 링크와 프로젝트 통합

여기까지가 문제의 절반입니다.
그럼 실제로 어떻게 연결해서 사용할까요?

**이 부분은 프로젝트/빌드 시스템에 크게 의존합니다.**

`cargo`는 플랫폼/설정에 따라
`my_lib.so`, `my_lib.dll`, `my_lib.a` 같은 파일을 만듭니다.
이 라이브러리를 빌드 시스템에서 링크하면 됩니다.

C에서 Rust 함수를 호출하려면
함수 시그니처를 선언한 헤더 파일이 필요합니다.

Rust FFI API의 모든 함수는 헤더에 대응 선언이 있어야 합니다.

```rust,ignore
#[no_mangle]
pub extern "C" fn rust_function() {}
```

위 함수는 C 헤더에서 다음처럼 선언됩니다.

```C
void rust_function();
```

etc.

이 과정을 자동화하는 [cbindgen] 도구가 있습니다.
Rust 코드를 분석해 C/C++ 프로젝트용 헤더를 생성해 줍니다.

[cbindgen]: https://github.com/eqrion/cbindgen

여기까지 준비되면 C에서 Rust 함수를 쓰는 일은
헤더를 include하고 함수를 호출하는 것으로 끝납니다.

```C
#include "my-rust-project.h"
rust_function();
```
