# 세미호스팅

세미호스팅은 임베디드 장치가 호스트에서 I/O를 수행할 수 있게 해 주는 메커니즘이며,
주로 호스트 콘솔에 로그 메시지를 출력하는 데 사용됩니다. 세미호스팅은 디버그 세션만 있으면
되고 사실상 그 외에는 거의 아무것도 필요하지 않기 때문에(추가 배선도 필요 없습니다)
매우 편리합니다. 단점은 매우 느리다는 점입니다. 사용하는 하드웨어 디버거(예: ST-Link)에 따라
각 쓰기 작업이 수 밀리초씩 걸릴 수 있습니다.

[`cortex-m-semihosting`] crate는 Cortex-M 장치에서 세미호스팅 작업을 수행할 수 있는 API를 제공합니다.
아래 프로그램은 "Hello, world!"의 세미호스팅 버전입니다.

[`cortex-m-semihosting`]: https://crates.io/crates/cortex-m-semihosting

```rust,ignore
#![no_main]
#![no_std]

use panic_halt as _;

use cortex_m_rt::entry;
use cortex_m_semihosting::hprintln;

#[entry]
fn main() -> ! {
    hprintln!("Hello, world!").unwrap();

    loop {}
}
```

이 프로그램을 실제 하드웨어에서 실행하면 OpenOCD 로그 안에서 "Hello, world!" 메시지를 볼 수 있습니다.

```text
$ openocd
(..)
Hello, world!
(..)
```

다만 먼저 GDB에서 OpenOCD의 세미호스팅을 활성화해야 합니다.

```console
(gdb) monitor arm semihosting enable
semihosting is enabled
```

QEMU는 세미호스팅 연산을 이해하므로, 위 프로그램은 디버그 세션을 시작하지 않아도
`qemu-system-arm`에서 그대로 동작합니다. 다만 세미호스팅 지원을 켜려면 QEMU에
`-semihosting-config` 플래그를 전달해야 합니다. 이 플래그는 템플릿의 `.cargo/config.toml`
파일에 이미 포함되어 있습니다.

```text
$ # this program will block the terminal
$ cargo run
     Running `qemu-system-arm (..)
Hello, world!
```

QEMU 프로세스를 종료하는 데 사용할 수 있는 `exit` 세미호스팅 연산도 있습니다.
중요: 실제 하드웨어에서는 `debug::exit`를 사용하면 **안 됩니다**. 이 함수는 OpenOCD 세션을
망가뜨릴 수 있으며, OpenOCD를 다시 시작하기 전까지 추가 디버깅이 불가능해질 수 있습니다.

```rust,ignore
#![no_main]
#![no_std]

use panic_halt as _;

use cortex_m_rt::entry;
use cortex_m_semihosting::debug;

#[entry]
fn main() -> ! {
    let roses = "blue";

    if roses == "red" {
        debug::exit(debug::EXIT_SUCCESS);
    } else {
        debug::exit(debug::EXIT_FAILURE);
    }

    loop {}
}
```

```text
$ cargo run
     Running `qemu-system-arm (..)

$ echo $?
1
```

마지막 팁 하나를 더 보겠습니다. panic 동작을 `exit(EXIT_FAILURE)`로 설정할 수 있습니다.
이렇게 하면 QEMU에서 실행할 수 있는 `no_std` run-pass 테스트를 작성할 수 있습니다.

편의를 위해 `panic-semihosting` crate는 "exit" 기능을 제공합니다. 이를 활성화하면
panic 메시지를 호스트 stderr에 기록한 뒤 `exit(EXIT_FAILURE)`를 호출합니다.

```rust,ignore
#![no_main]
#![no_std]

use panic_semihosting as _; // features = ["exit"]

use cortex_m_rt::entry;
use cortex_m_semihosting::debug;

#[entry]
fn main() -> ! {
    let roses = "blue";

    assert_eq!(roses, "red");

    loop {}
}
```

```text
$ cargo run
     Running `qemu-system-arm (..)
panicked at 'assertion failed: `(left == right)`
  left: `"blue"`,
 right: `"red"`', examples/hello.rs:15:5

$ echo $?
1
```

**참고**: `panic-semihosting`에서 이 기능을 활성화하려면 `Cargo.toml`의 의존성 섹션에서
`panic-semihosting` 항목을 다음과 같이 수정하세요.

```toml
panic-semihosting = { version = "VERSION", features = ["exit"] }
```

여기서 `VERSION`은 원하는 버전입니다. 의존성 feature에 대한 자세한 내용은 Cargo 책의
[`specifying dependencies`] 섹션을 참고하세요.

[`specifying dependencies`]: https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html
