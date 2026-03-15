# 메모리 매핑 레지스터

임베디드 시스템은 일반적인 Rust 코드를 실행하고 RAM 안에서 데이터를 옮기는 것만으로는 한계가 있습니다.
LED를 깜박이게 하거나, 버튼 입력을 감지하거나, 외부 주변장치와 어떤 버스로 통신하는 등
시스템 안팎으로 정보를 주고받으려면 주변장치와 그 주변장치의 '메모리 매핑 레지스터' 세계로 들어가야 합니다.

마이크로컨트롤러 주변장치에 접근하는 데 필요한 코드가 이미 작성되어 있는 경우가 많습니다.
보통 다음 수준 중 하나에 해당합니다.

<p align="center">
<img title="Common crates" src="../assets/crates.png">
</p>

- 마이크로아키텍처 crate: 마이크로컨트롤러가 사용하는 프로세서 코어에 공통인 유용한 루틴과,
  그 코어를 사용하는 모든 마이크로컨트롤러에 공통인 주변장치를 다룹니다. 예를 들어 [cortex-m] crate는
  모든 Cortex-M 기반 마이크로컨트롤러에서 동일한 인터럽트 활성화/비활성화 함수를 제공하며,
  모든 Cortex-M에 포함된 `SysTick` 주변장치 접근도 제공합니다.
- Peripheral Access Crate (PAC): 특정 마이크로컨트롤러 부품 번호에 정의된 다양한 메모리 매핑 레지스터를 감싼 얇은 래퍼입니다.
  예를 들어 Texas Instruments Tiva-C TM4C123 계열용 [tm4c123x], STMicro STM32F30x 계열용 [stm32f30x]가 있습니다.
  이 계층에서는 마이크로컨트롤러 Technical Reference Manual에 나온 동작 지침을 따라 레지스터를 직접 다루게 됩니다.
- HAL crate: [embedded-hal]에 정의된 공통 trait를 구현하는 방식으로,
  특정 프로세서에 대해 더 사용하기 쉬운 API를 제공합니다. 예를 들어 적절한 GPIO 핀과 baud rate를 받는
  `Serial` 생성자와, 데이터를 보내기 위한 `write_byte` 같은 함수를 제공할 수 있습니다.
  [embedded-hal]에 대해서는 [Portability] 장을 참고하세요.
- Board crate: HAL crate보다 한 단계 더 올라가, 사용 중인 특정 개발 보드에 맞게 주변장치와 GPIO 핀을
  미리 구성해 둡니다. STM32F3DISCOVERY 보드용 [stm32f3-discovery]가 대표적인 예입니다.

[cortex-m]: https://crates.io/crates/cortex-m
[tm4c123x]: https://crates.io/crates/tm4c123x
[stm32f30x]: https://crates.io/crates/stm32f30x
[embedded-hal]: https://crates.io/crates/embedded-hal
[Portability]: ../portability/index.md
[stm32f3-discovery]: https://crates.io/crates/stm32f3-discovery
[Discovery]: https://rust-embedded.github.io/discovery/

## Board crate

임베디드 Rust가 처음이라면 board crate는 완벽한 출발점입니다. 학습 초기에 부담스러울 수 있는
하드웨어 세부 사항을 잘 추상화해 주고, LED를 켜고 끄는 일 같은 기본 작업을 쉽게 만들어 줍니다.
다만 제공하는 기능은 보드마다 차이가 큽니다. 이 책은 하드웨어 비종속성을 유지하는 것이 목표이므로,
board crate 자체는 자세히 다루지 않습니다.

STM32F3DISCOVERY 보드로 실험해 보고 싶다면 [stm32f3-discovery] board crate를 강력히 추천합니다.
이 crate는 보드 LED 깜박이기, 나침반 접근, 블루투스 등 다양한 기능을 제공합니다.
[Discovery] 책은 board crate 사용법에 대한 훌륭한 입문 자료입니다.

하지만 아직 전용 board crate가 없는 시스템을 다루고 있거나,
기존 crate가 제공하지 않는 기능이 필요하다면, 더 아래 계층인 마이크로아키텍처 crate부터 시작해 봅시다.

## 마이크로아키텍처 crate

모든 Cortex-M 기반 마이크로컨트롤러에 공통으로 있는 SysTick 주변장치를 살펴보겠습니다.
[cortex-m] crate에서 꽤 저수준의 API를 찾을 수 있고, 사용법은 다음과 같습니다.

```rust,ignore
#![no_std]
#![no_main]
use cortex_m::peripheral::{syst, Peripherals};
use cortex_m_rt::entry;
use panic_halt as _;

#[entry]
fn main() -> ! {
    let peripherals = Peripherals::take().unwrap();
    let mut systick = peripherals.SYST;
    systick.set_clock_source(syst::SystClkSource::Core);
    systick.set_reload(1_000);
    systick.clear_current();
    systick.enable_counter();
    while !systick.has_wrapped() {
        // Loop
    }

    loop {}
}
```

`SYST` 구조체의 함수들은 ARM Technical Reference Manual에 정의된 이 주변장치의 기능과 상당히 가깝게 대응됩니다.
하지만 이 API에는 'X 밀리초 동안 지연하기' 같은 고수준 기능은 없습니다. 그런 동작은 우리가 `while` 루프로 직접 구현해야 합니다.
또한 `Peripherals::take()`를 호출하기 전에는 `SYST` 구조체에 접근할 수 없다는 점에 주목하세요.
이 함수는 프로그램 전체에 `SYST` 구조체가 하나만 존재하도록 보장하는 특별한 루틴입니다.
자세한 내용은 [Peripherals] 섹션을 참고하세요.

[Peripherals]: ../peripherals/index.md

## Peripheral Access Crate(PAC) 사용하기

모든 Cortex-M에 포함된 기본 주변장치만으로는 임베디드 소프트웨어 개발을 충분히 진행할 수 없습니다.
언젠가는 우리가 사용하는 특정 마이크로컨트롤러에 특화된 코드를 작성해야 합니다.
이 예제에서는 Texas Instruments의 TM4C123, 즉 80MHz Cortex-M4와 256 KiB 플래시를 가진 칩을 사용한다고 가정하겠습니다.
이 칩을 활용하기 위해 [tm4c123x] crate를 가져오겠습니다.

```rust,ignore
#![no_std]
#![no_main]

use panic_halt as _; // panic handler

use cortex_m_rt::entry;
use tm4c123x;

#[entry]
pub fn init() -> (Delay, Leds) {
    let cp = cortex_m::Peripherals::take().unwrap();
    let p = tm4c123x::Peripherals::take().unwrap();

    let pwm = p.PWM0;
    pwm.ctl.write(|w| w.globalsync0().clear_bit());
    // Mode = 1 => Count up/down mode
    pwm._2_ctl.write(|w| w.enable().set_bit().mode().set_bit());
    pwm._2_gena.write(|w| w.actcmpau().zero().actcmpad().one());
    // 528 cycles (264 up and down) = 4 loops per video line (2112 cycles)
    pwm._2_load.write(|w| unsafe { w.load().bits(263) });
    pwm._2_cmpa.write(|w| unsafe { w.compa().bits(64) });
    pwm.enable.write(|w| w.pwm4en().set_bit());
}

```

`PWM0` 주변장치 접근 방식은 앞서 `SYST`에 접근했던 것과 거의 동일합니다. 차이는 `tm4c123x::Peripherals::take()`를 호출했다는 점뿐입니다.
이 crate는 [svd2rust]로 자동 생성되었기 때문에, 레지스터 필드 접근 함수가 숫자 인자 대신 closure를 받습니다.
코드가 길어 보일 수 있지만, Rust 컴파일러는 이를 바탕으로 많은 검사를 수행하면서도,
최종적으로는 손으로 쓴 어셈블리에 가까운 머신 코드를 생성할 수 있습니다.
한편 자동 생성 코드가 어떤 accessor 함수에 대해 가능한 모든 인자가 유효한지 판별할 수 없는 경우
(예를 들어 SVD는 레지스터가 32비트라고 정의했지만 그 32비트 값 중 일부가 특별한 의미를 갖는지는 설명하지 않는 경우),
그 함수는 `unsafe`로 표시됩니다. 위 예제에서 `bits()` 함수로 `load`와 `compa` 하위 필드를 설정하는 부분이 그 예입니다.

### 읽기

`read()` 함수는 이 칩의 제조사 SVD 파일에 정의된 대로,
해당 레지스터 안의 여러 하위 필드에 대한 읽기 전용 접근을 제공하는 객체를 반환합니다.
이 특정 칩의 특정 주변장치, 특정 레지스터에 대한 `R` 반환 타입이 어떤 함수를 제공하는지는
[tm4c123x 문서][tm4c123x documentation R]에서 확인할 수 있습니다.

```rust,ignore
if pwm.ctl.read().globalsync0().is_set() {
    // Do a thing
}
```

### 쓰기

`write()` 함수는 하나의 인자를 받는 closure를 받습니다. 보통 이 인자를 `w`라고 부릅니다.
이 인자를 통해 제조사 SVD 파일에 정의된 대로, 레지스터의 여러 하위 필드에 읽기/쓰기 접근이 가능합니다.
이 역시 해당 칩의 해당 주변장치, 해당 레지스터에서 `w`가 제공하는 함수 목록은
[tm4c123x 문서][tm4c123x documentation W]에서 확인할 수 있습니다.
주의할 점은 우리가 설정하지 않은 모든 하위 필드도 기본값으로 덮어써진다는 것입니다.
즉, 기존 레지스터 내용은 사라집니다.

```rust,ignore
pwm.ctl.write(|w| w.globalsync0().clear_bit());
```

### 수정하기

레지스터의 특정 하위 필드 하나만 바꾸고 나머지 필드는 그대로 두고 싶다면 `modify` 함수를 사용합니다.
이 함수는 두 개의 인자를 받는 closure를 사용하며, 보통 `r`과 `w`라고 부릅니다.
`r`은 현재 레지스터 내용을 읽는 데, `w`는 그 내용을 수정하는 데 사용합니다.

```rust,ignore
pwm.ctl.modify(|r, w| w.globalsync0().clear_bit());
```

`modify` 함수는 여기서 closure의 장점을 잘 보여 줍니다. C에서는 보통 임시 변수에 읽어 온 뒤,
적절한 비트를 수정하고 다시 써야 합니다. 이 과정에는 실수할 여지가 큽니다.

```C
uint32_t temp = pwm0.ctl.read();
temp |= PWM0_CTL_GLOBALSYNC0;
pwm0.ctl.write(temp);
uint32_t temp2 = pwm0.enable.read();
temp2 |= PWM0_ENABLE_PWM4EN;
pwm0.enable.write(temp); // Uh oh! Wrong variable!
```

[svd2rust]: https://crates.io/crates/svd2rust
[tm4c123x documentation R]: https://docs.rs/tm4c123x/0.7.0/tm4c123x/pwm0/ctl/struct.R.html
[tm4c123x documentation W]: https://docs.rs/tm4c123x/0.7.0/tm4c123x/pwm0/ctl/struct.W.html

## HAL crate 사용하기

칩용 HAL crate는 보통 PAC가 노출하는 raw 구조체에 대해 커스텀 Trait를 구현하는 방식으로 동작합니다.
이 trait는 단일 주변장치에는 `constrain()`, 여러 핀을 가진 GPIO 포트 같은 대상에는 `split()` 함수를 제공하는 경우가 많습니다.
이 함수는 하위 raw 주변장치 구조체를 소비하고, 더 고수준 API를 가진 새로운 객체를 반환합니다.
이 API는 예를 들어 Serial 포트의 `new` 함수가 어떤 `Clock` 구조체를 빌리도록 강제할 수도 있습니다.
그리고 그 `Clock` 구조체는 PLL을 설정하고 클럭 주파수를 구성하는 함수를 호출해야만 생성됩니다.
이 방식 덕분에 클럭 설정 없이 Serial 포트 객체를 만들거나,
baud rate를 클럭 tick으로 잘못 변환하는 일이 정적으로 불가능해집니다.
일부 crate는 각 GPIO 핀이 가질 수 있는 상태에 대한 특수 trait를 정의해,
사용자가 핀을 주변장치에 넘기기 전에 적절한 상태(예: 올바른 Alternate Function Mode)로 바꾸도록 강제하기도 합니다.
이 모든 것이 런타임 비용 없이 이뤄집니다.

예제를 보겠습니다.

```rust,ignore
#![no_std]
#![no_main]

use panic_halt as _; // panic handler

use cortex_m_rt::entry;
use tm4c123x_hal as hal;
use tm4c123x_hal::prelude::*;
use tm4c123x_hal::serial::{NewlineMode, Serial};
use tm4c123x_hal::sysctl;

#[entry]
fn main() -> ! {
    let p = hal::Peripherals::take().unwrap();
    let cp = hal::CorePeripherals::take().unwrap();

    // Wrap up the SYSCTL struct into an object with a higher-layer API
    let mut sc = p.SYSCTL.constrain();
    // Pick our oscillation settings
    sc.clock_setup.oscillator = sysctl::Oscillator::Main(
        sysctl::CrystalFrequency::_16mhz,
        sysctl::SystemClock::UsePll(sysctl::PllOutputFrequency::_80_00mhz),
    );
    // Configure the PLL with those settings
    let clocks = sc.clock_setup.freeze();

    // Wrap up the GPIO_PORTA struct into an object with a higher-layer API.
    // Note it needs to borrow `sc.power_control` so it can power up the GPIO
    // peripheral automatically.
    let mut porta = p.GPIO_PORTA.split(&sc.power_control);

    // Activate the UART.
    let uart = Serial::uart0(
        p.UART0,
        // The transmit pin
        porta
            .pa1
            .into_af_push_pull::<hal::gpio::AF1>(&mut porta.control),
        // The receive pin
        porta
            .pa0
            .into_af_push_pull::<hal::gpio::AF1>(&mut porta.control),
        // No RTS or CTS required
        (),
        (),
        // The baud rate
        115200_u32.bps(),
        // Output handling
        NewlineMode::SwapLFtoCRLF,
        // We need the clock rates to calculate the baud rate divisors
        &clocks,
        // We need this to power up the UART peripheral
        &sc.power_control,
    );

    loop {
        writeln!(uart, "Hello, World!\r\n").unwrap();
    }
}
```
