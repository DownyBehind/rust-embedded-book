# 예외

예외와 인터럽트는 프로세서가 비동기 이벤트와 치명적인 오류(예: 잘못된 명령 실행)를
처리하기 위해 사용하는 하드웨어 메커니즘입니다. 예외는 선점을 수반하며,
이벤트를 일으킨 신호에 반응해 실행되는 예외 핸들러라는 서브루틴을 포함합니다.

`cortex-m-rt` crate는 예외 핸들러를 선언하기 위한 [`exception`] 속성을 제공합니다.

[`exception`]: https://docs.rs/cortex-m-rt-macros/latest/cortex_m_rt_macros/attr.exception.html

```rust,ignore
// Exception handler for the SysTick (System Timer) exception
#[exception]
fn SysTick() {
    // ..
}
```

`exception` 속성을 제외하면 예외 핸들러는 일반 함수처럼 보입니다. 하지만 중요한 차이가 하나 더 있습니다.
`exception` 핸들러는 소프트웨어에서 _직접 호출할 수 없습니다_. 예를 들어 위 예제에서
`SysTick();`를 호출하면 컴파일 오류가 발생합니다.

이 제약은 의도된 것이고, 한 가지 기능을 가능하게 합니다. `exception` 핸들러 _내부에_
선언한 `static mut` 변수는 _안전하게_ 사용할 수 있습니다.

```rust,ignore
#[exception]
fn SysTick() {
    static mut COUNT: u32 = 0;

    // `COUNT` has transformed to type `&mut u32` and it's safe to use
    *COUNT += 1;
}
```

알다시피 함수 안에서 `static mut` 변수를 사용하면 그 함수는
[_재진입 불가능_](<https://en.wikipedia.org/wiki/Reentrancy_(computing)>)해집니다.
재진입 불가능한 함수를 둘 이상의 예외/인터럽트 핸들러나,
`main`과 하나 이상의 예외/인터럽트 핸들러에서 직간접적으로 호출하는 것은 정의되지 않은 동작입니다.

Safe Rust는 절대로 정의되지 않은 동작을 유발해서는 안 되므로, 재진입 불가능한 함수는 원래
`unsafe`여야 합니다. 그런데 방금 `exception` 핸들러 안에서는 `static mut`를 안전하게 쓸 수 있다고 했습니다.
왜 가능할까요? 이유는 `exception` 핸들러가 소프트웨어에서 직접 호출될 수 없기 때문입니다.
즉 재진입 자체가 불가능합니다. 이 핸들러들은 하드웨어에 의해 호출되며,
여기서는 하드웨어가 물리적으로 동시 호출하지 않는다고 가정합니다.

따라서 임베디드 시스템의 예외 핸들러 맥락에서는, 동일한 핸들러가 동시에 호출되지 않는다는 점 덕분에
핸들러 내부에서 `static mut`를 사용해도 재진입 문제가 발생하지 않습니다.

하지만 멀티코어 시스템처럼 여러 프로세서 코어가 동시에 코드를 실행하는 환경에서는 상황이 달라집니다.
각 코어가 자체 예외 핸들러 집합을 가질 수 있더라도, 여러 코어가 같은 예외 핸들러를 동시에 실행하려는 시나리오가 생길 수 있습니다.
이런 환경에서는 핸들러 내부에서도 적절한 동기화 메커니즘을 사용해 공유 자원 접근을 조율해야 합니다.
보통 lock, semaphore, atomic operation 같은 기법을 사용해 데이터 레이스를 막고 무결성을 유지합니다.

> `exception` 속성은 함수 안의 static 변수 정의를 `unsafe` 블록으로 감싸고,
> 같은 이름의 적절한 `&mut` 타입 변수로 변환해 줍니다.
> 그래서 `unsafe` 블록 없이도 `*`로 역참조하여 값에 접근할 수 있습니다.

## 전체 예제

다음 예제는 시스템 타이머를 사용해 대략 1초마다 `SysTick` 예외를 발생시킵니다.
`SysTick` 예외 핸들러는 `COUNT` 변수로 호출 횟수를 기록한 다음,
세미호스팅을 사용해 `COUNT` 값을 호스트 콘솔에 출력합니다.

> **참고**: 이 예제는 어떤 Cortex-M 장치에서도 실행할 수 있으며, QEMU에서도 실행할 수 있습니다.

```rust,ignore
#![deny(unsafe_code)]
#![no_main]
#![no_std]

use panic_halt as _;

use core::fmt::Write;

use cortex_m::peripheral::syst::SystClkSource;
use cortex_m_rt::{entry, exception};
use cortex_m_semihosting::{
    debug,
    hio::{self, HostStream},
};

#[entry]
fn main() -> ! {
    let p = cortex_m::Peripherals::take().unwrap();
    let mut syst = p.SYST;

    // configures the system timer to trigger a SysTick exception every second
    syst.set_clock_source(SystClkSource::Core);
    // this is configured for the LM3S6965 which has a default CPU clock of 12 MHz
    syst.set_reload(12_000_000);
    syst.clear_current();
    syst.enable_counter();
    syst.enable_interrupt();

    loop {}
}

#[exception]
fn SysTick() {
    static mut COUNT: u32 = 0;
    static mut STDOUT: Option<HostStream> = None;

    *COUNT += 1;

    // Lazy initialization
    if STDOUT.is_none() {
        *STDOUT = hio::hstdout().ok();
    }

    if let Some(hstdout) = STDOUT.as_mut() {
        write!(hstdout, "{}", *COUNT).ok();
    }

    // IMPORTANT omit this `if` block if running on real hardware or your
    // debugger will end in an inconsistent state
    if *COUNT == 9 {
        // This will terminate the QEMU process
        debug::exit(debug::EXIT_SUCCESS);
    }
}
```

```console
tail -n5 Cargo.toml
```

```toml
[dependencies]
cortex-m = "0.5.7"
cortex-m-rt = "0.6.3"
panic-halt = "0.2.0"
cortex-m-semihosting = "0.3.1"
```

```text
$ cargo run --release
     Running `qemu-system-arm -cpu cortex-m3 -machine lm3s6965evb (..)
123456789
```

이 예제를 Discovery 보드에서 실행하면 OpenOCD 콘솔에 출력이 나타납니다.
또한 카운트가 9에 도달해도 프로그램은 _멈추지 않습니다_.

## 기본 예외 핸들러

`exception` 속성이 실제로 하는 일은 특정 예외에 대한 기본 예외 핸들러를 *재정의*하는 것입니다.
특정 예외의 핸들러를 재정의하지 않으면 `DefaultHandler` 함수가 이를 처리하며,
기본 구현은 다음과 같습니다.

```rust,ignore
fn DefaultHandler() {
    loop {}
}
```

이 함수는 `cortex-m-rt` crate가 제공하며 `#[no_mangle]`로 표시되어 있어,
"DefaultHandler"에 브레이크포인트를 걸고 _처리되지 않은_ 예외를 잡아낼 수 있습니다.

`exception` 속성을 사용해 이 `DefaultHandler`를 재정의할 수도 있습니다.

```rust,ignore
#[exception]
fn DefaultHandler(irqn: i16) {
    // custom default handler
}
```

`irqn` 인자는 현재 어떤 예외를 처리 중인지를 나타냅니다. 음수이면 Cortex-M 예외를,
0 또는 양수이면 장치 고유 예외, 즉 인터럽트를 처리 중이라는 뜻입니다.

## 하드 폴트 핸들러

`HardFault` 예외는 조금 특별합니다. 프로그램이 잘못된 상태에 들어갔을 때 발생하며,
그 핸들러는 _반환하면 안 됩니다_. 반환하면 정의되지 않은 동작으로 이어질 수 있기 때문입니다.
또한 런타임 crate는 디버깅 편의성을 높이기 위해 사용자 정의 `HardFault` 핸들러를 호출하기 전에
약간의 작업을 수행합니다.

그 결과 `HardFault` 핸들러는 `fn(&ExceptionFrame) -> !` 시그니처를 가져야 합니다.
핸들러 인자는 예외가 발생할 때 스택에 저장된 레지스터를 가리킵니다.
이 레지스터 값은 예외가 발생한 순간의 프로세서 상태 스냅샷이며,
하드 폴트 원인 분석에 유용합니다.

다음은 존재하지 않는 메모리 위치를 읽는 잘못된 연산을 수행하는 예제입니다.

> **참고**: 이 프로그램은 QEMU에서는 예상대로 동작하지 않습니다. 즉, 크래시하지 않습니다.
> `qemu-system-arm -machine lm3s6965evb`는 메모리 load를 검사하지 않고,
> 잘못된 메모리 읽기에 대해 그냥 `0`을 반환하기 때문입니다.

```rust,ignore
#![no_main]
#![no_std]

use panic_halt as _;

use core::fmt::Write;
use core::ptr;

use cortex_m_rt::{entry, exception, ExceptionFrame};
use cortex_m_semihosting::hio;

#[entry]
fn main() -> ! {
    // read a nonexistent memory location
    unsafe {
        ptr::read_volatile(0x3FFF_0000 as *const u32);
    }

    loop {}
}

#[exception]
fn HardFault(ef: &ExceptionFrame) -> ! {
    if let Ok(mut hstdout) = hio::hstdout() {
        writeln!(hstdout, "{:#?}", ef).ok();
    }

    loop {}
}
```

`HardFault` 핸들러는 `ExceptionFrame` 값을 출력합니다. 이 예제를 실행하면
OpenOCD 콘솔에서 대략 다음과 같은 출력을 볼 수 있습니다.

```text
$ openocd
(..)
ExceptionFrame {
    r0: 0x3fff0000,
    r1: 0x00000003,
    r2: 0x080032e8,
    r3: 0x00000000,
    r12: 0x00000000,
    lr: 0x080016df,
    pc: 0x080016e2,
    xpsr: 0x61000000,
}
```

`pc` 값은 예외가 발생한 시점의 Program Counter 값이며,
예외를 유발한 명령을 가리킵니다.

프로그램을 디스어셈블해서 보면 다음과 같습니다.

```text
$ cargo objdump --bin app --release -- -d --no-show-raw-insn --print-imm-hex
(..)
ResetTrampoline:
 8000942:       movw    r0, #0xfffe
 8000946:       movt    r0, #0x3fff
 800094a:       ldr     r0, [r0]
 800094c:       b       #-0x4 <ResetTrampoline+0xa>
```

디스어셈블 결과에서 프로그램 카운터 값 `0x0800094a`를 찾아보면,
load 연산(`ldr r0, [r0]`)이 예외를 유발했다는 것을 알 수 있습니다.
또한 `ExceptionFrame`의 `r0` 필드를 보면, 그 시점의 `r0` 레지스터 값이
`0x3fff_fffe`였음을 알 수 있습니다.
