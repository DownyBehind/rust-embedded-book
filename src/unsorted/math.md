# `#[no_std]`에서 수학 기능 사용하기

제곱근 계산이나 지수 함수처럼 수학 기능을 사용하고 싶고,
전체 표준 라이브러리를 사용할 수 있다면 코드는 다음과 비슷할 것입니다.

```rs
//! 표준 라이브러리를 사용할 수 있을 때의 수학 함수 예제

fn main() {
    let float: f32 = 4.82832;
    let floored_float = float.floor();

    let sqrt_of_four = floored_float.sqrt();

    let sinus_of_four = floored_float.sin();

    let exponential_of_four = floored_float.exp();
    println!("Floored test float {} to {}", float, floored_float);
    println!("The square root of {} is {}", floored_float, sqrt_of_four);
    println!("The sinus of four is {}", sinus_of_four);
    println!(
        "The exponential of four to the base e is {}",
        exponential_of_four
    )
}
```

표준 라이브러리를 사용할 수 없으면 위 함수들을 직접 쓸 수 없습니다.
대신 [`libm`](https://crates.io/crates/libm) 같은 외부 크레이트를 사용할 수 있습니다.
예제 코드는 다음과 같습니다.

```rs
#![no_main]
#![no_std]

use panic_halt as _;

use cortex_m_rt::entry;
use cortex_m_semihosting::{debug, hprintln};
use libm::{exp, floorf, sin, sqrtf};

#[entry]
fn main() -> ! {
    let float = 4.82832;
    let floored_float = floorf(float);

    let sqrt_of_four = sqrtf(floored_float);

    let sinus_of_four = sin(floored_float.into());

    let exponential_of_four = exp(floored_float.into());
    hprintln!("Floored test float {} to {}", float, floored_float).unwrap();
    hprintln!("The square root of {} is {}", floored_float, sqrt_of_four).unwrap();
    hprintln!("The sinus of four is {}", sinus_of_four).unwrap();
    hprintln!(
        "The exponential of four to the base e is {}",
        exponential_of_four
    )
    .unwrap();
    // QEMU 종료
    // 주의: 실제 하드웨어에서 실행하면 OpenOCD 상태를 손상시킬 수 있음
    // debug::exit(debug::EXIT_SUCCESS);

    loop {}
}
```

MCU에서 DSP 신호 처리나 고급 선형대수 같은
더 복잡한 연산이 필요하다면 다음 크레이트가 도움이 될 수 있습니다.

- [CMSIS DSP library binding](https://github.com/jacobrosenthal/cmsis-dsp-sys)
- [`constgebra`](https://crates.io/crates/constgebra)
- [`micromath`](https://github.com/tarcieri/micromath)
- [`microfft`](https://crates.io/crates/microfft)
- [`nalgebra`](https://github.com/dimforge/nalgebra)
