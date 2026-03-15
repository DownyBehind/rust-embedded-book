# 싱글턴

> 소프트웨어 공학에서 싱글턴 패턴은 클래스의 인스턴스 생성을 하나의 객체로 제한하는 디자인 패턴입니다.
>
> _위키백과: [Singleton Pattern]_

[Singleton Pattern]: https://en.wikipedia.org/wiki/Singleton_pattern

## 왜 그냥 전역 변수를 쓰면 안 될까?

다음을처럼 모든 것을 공개 `static`으로 만들 수도 있습니다.

```rust,ignore
static mut THE_SERIAL_PORT: SerialPort = SerialPort;

fn main() {
    let _ = unsafe {
        THE_SERIAL_PORT.read_speed();
    };
}
```

하지만 이 방식에는 몇 가지 문제가 있습니다.
이것은 변경 가능한 전역 변수이고, Rust에서는 이런 값과의 상호작용이 항상 `unsafe`입니다.
또한 프로그램 전체에서 보이기 때문에 Borrow Checker가 참조와 소유권 추적을 도와주기 어렵습니다.

## Rust에서는 어떻게 할까?

주변장치를 단순 전역 변수로 두는 대신,
각 주변장치를 `Option<T>`로 담는 구조체를 만들 수 있습니다.
여기서는 이름을 `PERIPHERALS`라고 하겠습니다.

```rust,ignore
struct Peripherals {
    serial: Option<SerialPort>,
}
impl Peripherals {
    fn take_serial(&mut self) -> SerialPort {
        let p = replace(&mut self.serial, None);
        p.unwrap()
    }
}
static mut PERIPHERALS: Peripherals = Peripherals {
    serial: Some(SerialPort),
};
```

이 구조체를 사용하면 주변장치 인스턴스를 한 번만 가져오게 만들 수 있습니다.
`take_serial()`을 두 번 이상 호출하면 코드가 패닉을 일으킵니다.

```rust,ignore
fn main() {
    let serial_1 = unsafe { PERIPHERALS.take_serial() };
    // This panics!
    // let serial_2 = unsafe { PERIPHERALS.take_serial() };
}
```

이 구조체 자체와 상호작용할 때는 `unsafe`가 필요하지만,
일단 내부의 `SerialPort`를 꺼낸 뒤에는 `unsafe`도, `PERIPHERALS`도 더 이상 필요하지 않습니다.

이 방식은 `SerialPort`를 `Option`으로 감싸고 `take_serial()`을 한 번 호출해야 하므로
작은 런타임 오버헤드가 있습니다. 하지만 이 초기 비용 덕분에
프로그램 나머지 부분에서 Borrow Checker의 이점을 활용할 수 있습니다.

## 기존 라이브러리 지원

위에서는 직접 `Peripherals` 구조체를 만들었지만,
실제 코드에서는 직접 만들 필요가 없습니다.
`cortex_m` 크레이트에는 이 작업을 대신해 주는 `singleton!()` 매크로가 있습니다.

```rust,ignore
use cortex_m::singleton;

fn main() {
    // OK if `main` is executed only once
    let x: &'static mut bool =
        singleton!(: bool = false).unwrap();
}
```

[cortex_m docs](https://docs.rs/cortex-m/latest/cortex_m/macro.singleton.html)

또한 [`cortex-m-rtic`](https://github.com/rtic-rs/cortex-m-rtic)를 사용하면,
주변장치 정의와 획득 과정이 전부 추상화됩니다.
사용자는 자신이 정의한 항목들이 `Option<T>`가 아닌 형태로 담긴
`Peripherals` 구조체를 바로 전달받습니다.

```rust,ignore
// cortex-m-rtic v0.5.x
#[rtic::app(device = lm3s6965, peripherals = true)]
const APP: () = {
    #[init]
    fn init(cx: init::Context) {
        static mut X: u32 = 0;

        // Cortex-M peripherals
        let core: cortex_m::Peripherals = cx.core;

        // Device specific peripherals
        let device: lm3s6965::Peripherals = cx.device;
    }
}
```

## 그런데 왜 중요할까?

이 싱글턴이 Rust 코드 동작에 어떤 실질적 차이를 만들까요?

```rust,ignore
impl SerialPort {
    const SER_PORT_SPEED_REG: *mut u32 = 0x4000_1000 as _;

    fn read_speed(
        &self // <------ This is really, really important
    ) -> u32 {
        unsafe {
            ptr::read_volatile(Self::SER_PORT_SPEED_REG)
        }
    }
}
```

여기에는 두 가지 중요한 요소가 있습니다.

- 싱글턴을 사용하므로 `SerialPort` 구조체를 얻는 경로가 하나뿐입니다.
- `read_speed()`를 호출하려면 `SerialPort`의 소유권이나 참조를 반드시 가지고 있어야 합니다.

이 두 가지가 결합되면 Borrow Checker 조건을 만족했을 때만 하드웨어 접근이 가능해집니다.
즉, 같은 하드웨어에 대해 동시에 여러 가변 참조를 만드는 상황을 방지할 수 있습니다.

```rust,ignore
fn main() {
    // missing reference to `self`! Won't work.
    // SerialPort::read_speed();

    let serial_1 = unsafe { PERIPHERALS.take_serial() };

    // you can only read what you have access to
    let _ = serial_1.read_speed();
}
```

## 하드웨어를 데이터처럼 다루기

또한 어떤 참조는 가변이고 어떤 참조는 불변이므로,
함수나 메서드가 하드웨어 상태를 바꿀 가능성이 있는지 시그니처만 보고 파악할 수 있습니다.
예를 들어,

다음은 하드웨어 설정을 변경할 수 있습니다.

```rust,ignore
fn setup_spi_port(
    spi: &mut SpiPort,
    cs_pin: &mut GpioPin
) -> Result<()> {
    // ...
}
```

반면 다음은 그렇지 않습니다.

```rust,ignore
fn read_button(gpio: &GpioPin) -> bool {
    // ...
}
```

이 덕분에 코드가 하드웨어를 변경해도 되는지 여부를
런타임이 아니라 **컴파일 타임**에 강제할 수 있습니다.
참고로 이런 방식은 일반적으로 단일 애플리케이션 범위에서 특히 잘 동작합니다.
베어메탈 시스템은 보통 하나의 애플리케이션으로 컴파일되므로,
실무에서 큰 제약이 되지 않는 경우가 많습니다.
