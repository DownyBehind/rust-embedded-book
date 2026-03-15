# 첫 번째 시도

## 레지스터

모든 Cortex-M 프로세서 코어에는 간단한 타이머 주변장치인 `SysTick`이 들어 있습니다.
보통 이런 정보는 칩 제조사의 데이터시트나 *Technical Reference Manual*에서 찾지만,
이 예제는 모든 ARM Cortex-M 코어에 공통이므로 [ARM reference manual]을 보겠습니다.
여기에는 레지스터가 네 개 있습니다.

[ARM reference manual]: http://infocenter.arm.com/help/topic/com.arm.doc.dui0553a/Babieigh.html

| Offset | Name       | Description                 | Width   |
| ------ | ---------- | --------------------------- | ------- |
| 0x00   | SYST_CSR   | Control and Status Register | 32 bits |
| 0x04   | SYST_RVR   | Reload Value Register       | 32 bits |
| 0x08   | SYST_CVR   | Current Value Register      | 32 bits |
| 0x0C   | SYST_CALIB | Calibration Value Register  | 32 bits |

## C 스타일 접근

Rust에서도 C와 동일하게 `struct`로 레지스터 묶음을 표현할 수 있습니다.

```rust,ignore
#[repr(C)]
struct SysTick {
    pub csr: u32,
    pub rvr: u32,
    pub cvr: u32,
    pub calib: u32,
}
```

`#[repr(C)]` 한정자는 Rust 컴파일러에게 이 구조체를 C 컴파일러와 동일한 방식으로 배치하라고 지시합니다.
이것은 매우 중요합니다. Rust는 구조체 필드 재배치를 허용할 수 있지만 C는 그렇지 않기 때문입니다.
컴파일러가 필드를 조용히 재배치했다면 디버깅이 얼마나 어려울지 상상해 보세요.
이 한정자를 붙이면 위 표와 일치하는 4개의 32비트 필드를 갖게 됩니다.
다만 이 `struct`만으로는 아직 쓸 수 없고, 실제 변수(포인터)가 필요합니다.

```rust,ignore
let systick = 0xE000_E010 as *mut SysTick;
let time = unsafe { (*systick).cvr };
```

## Volatile 접근

하지만 위 접근에는 몇 가지 문제가 있습니다.

1. 주변장치에 접근할 때마다 `unsafe`를 사용해야 합니다.
2. 어떤 레지스터가 읽기 전용인지, 읽기/쓰기 가능한지 표현할 방법이 없습니다.
3. 프로그램 어디서든 이 구조체를 통해 하드웨어에 접근할 수 있습니다.
4. 무엇보다도, 실제로는 의도대로 동작하지 않을 수 있습니다.

문제는 컴파일러가 매우 똑똑하다는 점입니다.
같은 RAM 위치에 연속으로 두 번 쓴다면, 컴파일러는 첫 번째 쓰기를 생략할 수 있습니다.
C에서는 변수에 `volatile`을 붙여 모든 읽기/쓰기가 실제로 일어나도록 보장합니다.
Rust에서는 변수 자체가 아니라 *접근*을 volatile로 표시합니다.

```rust,ignore
let systick = unsafe { &mut *(0xE000_E010 as *mut SysTick) };
let time = unsafe { core::ptr::read_volatile(&mut systick.cvr) };
```

이로써 네 가지 문제 중 하나는 해결했지만, `unsafe` 코드는 오히려 더 늘었습니다.
다행히 이를 도와주는 서드파티 크레이트 [`volatile_register`]가 있습니다.

[`volatile_register`]: https://crates.io/crates/volatile_register

```rust,ignore
use volatile_register::{RW, RO};

#[repr(C)]
struct SysTick {
    pub csr: RW<u32>,
    pub rvr: RW<u32>,
    pub cvr: RW<u32>,
    pub calib: RO<u32>,
}

fn get_systick() -> &'static mut SysTick {
    unsafe { &mut *(0xE000_E010 as *mut SysTick) }
}

fn get_time() -> u32 {
    let systick = get_systick();
    systick.cvr.read()
}
```

이제 `read`/`write` 메서드를 통해 volatile 접근이 자동으로 수행됩니다.
쓰기는 여전히 `unsafe`지만, 하드웨어는 본질적으로 변경 가능한 상태 집합이므로
컴파일러가 그 쓰기가 안전한지 일반적으로 알 수 없습니다. 따라서 합리적인 기본값입니다.

## Rust 래퍼

이 `struct`를 사용자 입장에서 안전하게 호출할 수 있는 상위 API로 감싸야 합니다.
드라이버 작성자는 `unsafe` 코드의 정확성을 직접 검증하고,
사용자는 세부 구현을 몰라도 되는 안전한 API를 제공받는 방식입니다.

One example might be:

```rust,ignore
use volatile_register::{RW, RO};

pub struct SystemTimer {
    p: &'static mut RegisterBlock
}

#[repr(C)]
struct RegisterBlock {
    pub csr: RW<u32>,
    pub rvr: RW<u32>,
    pub cvr: RW<u32>,
    pub calib: RO<u32>,
}

impl SystemTimer {
    pub fn new() -> SystemTimer {
        SystemTimer {
            p: unsafe { &mut *(0xE000_E010 as *mut RegisterBlock) }
        }
    }

    pub fn get_time(&self) -> u32 {
        self.p.cvr.read()
    }

    pub fn set_reload(&mut self, reload_value: u32) {
        unsafe { self.p.rvr.write(reload_value) }
    }
}

pub fn example_usage() -> String {
    let mut st = SystemTimer::new();
    st.set_reload(0x00FF_FFFF);
    format!("Time is now 0x{:08x}", st.get_time())
}
```

하지만 이 접근에도 문제가 있습니다.
다음 코드는 컴파일러 입장에서 완전히 허용됩니다.

```rust,ignore
fn thread1() {
    let mut st = SystemTimer::new();
    st.set_reload(2000);
}

fn thread2() {
    let mut st = SystemTimer::new();
    st.set_reload(1000);
}
```

`set_reload`의 `&mut self`는 _그 특정_ `SystemTimer` 인스턴스에
다른 참조가 없는지만 보장합니다. 하지만 동일한 주변장치를 가리키는
두 번째 `SystemTimer` 생성 자체는 막지 못합니다.

작성자가 충분히 주의를 기울이면 동작할 수 있지만,
코드가 여러 모듈, 여러 드라이버, 여러 개발자, 여러 날짜에 걸쳐 확장되면
이런 중복 인스턴스 실수는 점점 더 쉽게 발생합니다.
