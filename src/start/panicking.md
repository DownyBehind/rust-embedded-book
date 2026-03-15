# 패닉 처리

패닉은 Rust 언어의 핵심 요소입니다. 인덱싱 같은 내장 연산은 메모리 안전성을 위해
런타임 검사를 수행합니다. 범위를 벗어난 인덱싱을 시도하면 패닉이 발생합니다.

표준 라이브러리 환경에서는 패닉 동작이 정의되어 있습니다. 사용자가 패닉 시 프로그램을
즉시 abort하도록 선택하지 않았다면, 패닉이 발생한 스레드의 스택을 언와인드합니다.

하지만 표준 라이브러리가 없는 프로그램에서는 패닉 동작이 기본적으로 정의되어 있지 않습니다.
이때 `#[panic_handler]` 함수를 선언해 원하는 동작을 선택할 수 있습니다.
이 함수는 프로그램의 의존성 그래프 전체에서 정확히 _한 번만_ 나타나야 하며,
시그니처는 `fn(&PanicInfo) -> !` 이어야 합니다. [`PanicInfo`]는 패닉이 발생한 위치 등의
정보를 담고 있는 구조체입니다.

[`PanicInfo`]: https://doc.rust-lang.org/core/panic/struct.PanicInfo.html

임베디드 시스템은 사용자 대상 장치부터 절대 다운되면 안 되는 안전 필수 시스템까지 다양하기 때문에,
모든 상황에 맞는 단일 패닉 동작은 없습니다. 대신 자주 쓰이는 동작들이 있고, 이는 `#[panic_handler]`
함수를 정의한 crate 형태로 패키징되어 있습니다. 예를 들면 다음과 같습니다.

- [`panic-abort`]. A panic causes the abort instruction to be executed.
- [`panic-halt`]. A panic causes the program, or the current thread, to halt by
  entering an infinite loop.
- [`panic-itm`]. The panicking message is logged using the ITM, an ARM Cortex-M
  specific peripheral.
- [`panic-semihosting`]. The panicking message is logged to the host using the
  semihosting technique.

[`panic-abort`]: https://crates.io/crates/panic-abort
[`panic-halt`]: https://crates.io/crates/panic-halt
[`panic-itm`]: https://crates.io/crates/panic-itm
[`panic-semihosting`]: https://crates.io/crates/panic-semihosting

crates.io에서 [`panic-handler`] 키워드로 검색하면 더 많은 crate를 찾을 수도 있습니다.

[`panic-handler`]: https://crates.io/keywords/panic-handler

프로그램은 해당 crate를 링크하는 것만으로 이 동작들 중 하나를 선택할 수 있습니다.
패닉 동작이 애플리케이션 소스 코드에서 한 줄로 표현된다는 점은 문서화 측면에서도 유용하고,
컴파일 프로파일에 따라 패닉 동작을 바꾸는 데도 활용할 수 있습니다. 예를 들면 다음과 같습니다.

```rust,ignore
#![no_main]
#![no_std]

// dev profile: easier to debug panics; can put a breakpoint on `rust_begin_unwind`
#[cfg(debug_assertions)]
use panic_halt as _;

// release profile: minimize the binary size of the application
#[cfg(not(debug_assertions))]
use panic_abort as _;

// ..
```

이 예제에서는 dev 프로파일(`cargo build`)로 빌드할 때 `panic-halt` crate에 링크하고,
release 프로파일(`cargo build --release`)로 빌드할 때는 `panic-abort` crate에 링크합니다.

> `use panic_abort as _;` 형태는 `panic_abort` panic handler가 최종 실행 파일에 포함되도록 하면서,
> 동시에 이 crate에서 어떤 항목도 명시적으로 사용하지 않을 것임을 컴파일러에 분명히 알리기 위해 사용합니다.
> `as _`가 없으면 사용하지 않는 import라는 경고가 발생합니다.
> 가끔 `extern crate panic_abort` 형태를 볼 수도 있는데, 이는 Rust 2018 이전 스타일이며,
> 지금은 `proc_macro`, `alloc`, `std`, `test` 같은 "sysroot" crate에만 사용하는 것이 맞습니다.

## 예제

다음 예제는 배열 길이를 넘어 인덱싱을 시도합니다. 이 연산은 패닉을 발생시킵니다.

```rust,ignore
#![no_main]
#![no_std]

use panic_semihosting as _;

use cortex_m_rt::entry;

#[entry]
fn main() -> ! {
    let xs = [0, 1, 2];
    let i = xs.len();
    let _y = xs[i]; // out of bounds access

    loop {}
}
```

이 예제는 `panic-semihosting` 동작을 선택했으며, 세미호스팅을 사용해 패닉 메시지를
호스트 콘솔에 출력합니다.

```text
$ cargo run
     Running `qemu-system-arm -cpu cortex-m3 -machine lm3s6965evb (..)
panicked at 'index out of bounds: the len is 3 but the index is 4', src/main.rs:12:13
```

동작을 `panic-halt`로 바꿔 보면, 그 경우에는 아무 메시지도 출력되지 않는다는 점을 확인할 수 있습니다.
