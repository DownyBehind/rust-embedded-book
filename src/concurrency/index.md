# 동시성

동시성은 프로그램의 서로 다른 부분이 서로 다른 시점에 실행되거나,
실행 순서가 뒤섞일 수 있을 때 발생합니다.
임베디드 맥락에서는 보통 다음을 포함합니다.

- 관련 인터럽트가 발생할 때마다 실행되는 인터럽트 핸들러
- 마이크로프로세서가 프로그램 여러 부분을 번갈아 실행하는 다양한 멀티스레딩 형태
- 일부 시스템에서 각 코어가 동시에 서로 다른 코드를 실행하는 멀티코어 프로세서

많은 임베디드 프로그램이 인터럽트를 다뤄야 하므로,
동시성 이슈는 결국 마주치게 됩니다.
또한 미묘하고 까다로운 버그가 많이 생기는 영역이기도 합니다.
다행히 Rust는 올바른 코드를 작성할 수 있도록
여러 추상화와 안전성 보장을 제공합니다.

## 동시성이 없는 경우

임베디드 프로그램에서 가장 단순한 동시성 모델은
"동시성이 아예 없는 모델"입니다.
소프트웨어는 하나의 메인 루프만 계속 실행되고,
인터럽트는 전혀 사용하지 않습니다.
문제에 따라서는 이것이 가장 적합할 때도 많습니다.
보통 루프는 입력을 읽고, 처리하고, 출력을 쓰는 형태입니다.

```rust,ignore
#[entry]
fn main() {
    let peripherals = setup_peripherals();
    loop {
        let inputs = read_inputs(&peripherals);
        let outputs = process(inputs);
        write_outputs(&peripherals, outputs);
    }
}
```

동시성이 없으므로 프로그램 각 부분 간 데이터 공유나
주변장치 접근 동기화를 걱정할 필요가 없습니다.
이처럼 단순한 접근으로 해결 가능하다면 매우 좋은 해법입니다.

## 전역 가변 데이터

일반 Rust 애플리케이션과 달리 임베디드에서는
힙에 데이터를 만들고 새 스레드로 참조를 넘기는 방식을
항상 여유롭게 쓰기 어렵습니다.
대신 인터럽트 핸들러는 언제든 호출될 수 있고,
공유 메모리에 접근하는 방법을 알고 있어야 합니다.
가장 낮은 수준에서는 인터럽트 핸들러와 메인 코드가 함께 참조할
_정적으로 할당된_ 가변 메모리가 필요합니다.

Rust에서 이런 [`static mut`] 변수는 읽기/쓰기가 항상 unsafe입니다.
특별한 주의 없이 사용하면 레이스 컨디션이 발생할 수 있기 때문입니다.
즉 변수 접근 도중 인터럽트가 끼어들어 같은 변수에 접근할 수 있습니다.

[`static mut`]: https://doc.rust-lang.org/book/ch19-01-unsafe-rust.html#accessing-or-modifying-a-mutable-static-variable

이 동작이 얼마나 미묘한 오류를 만들 수 있는지 보기 위해,
1초 동안 입력 신호의 상승 에지 개수를 세는
주파수 카운터 예제를 보겠습니다.

```rust,ignore
static mut COUNTER: u32 = 0;

#[entry]
fn main() -> ! {
    set_timer_1hz();
    let mut last_state = false;
    loop {
        let state = read_signal_level();
        if state && !last_state {
            // DANGER - Not actually safe! Could cause data races.
            unsafe { COUNTER += 1 };
        }
        last_state = state;
    }
}

#[interrupt]
fn timer() {
    unsafe { COUNTER = 0; }
}
```

매초 타이머 인터럽트는 카운터를 0으로 되돌립니다.
그 사이 메인 루프는 신호를 계속 측정하며,
low에서 high로 바뀌는 순간 카운터를 증가시킵니다.
`COUNTER`가 `static mut`이므로 접근에 `unsafe`가 필요하며,
이는 컴파일러에 "정의되지 않은 동작을 만들지 않겠다"고 약속하는 뜻입니다.

레이스 컨디션을 찾으셨나요?
`COUNTER` 증가 연산은 원자적(atomic)이라고 보장되지 않습니다.
대부분 플랫폼에서 로드(load) -> 증가 -> 저장(store)으로 나뉩니다.
로드 후 저장 전에 인터럽트가 발생하면,
인터럽트에서 0으로 초기화한 결과가 복귀 후 덮어써져 무시될 수 있습니다.
결과적으로 해당 구간에서 전이 횟수를 실제보다 많이 세게 됩니다.

## 임계 구역(Critical Sections)

데이터 레이스를 막으려면 어떻게 해야 할까요?
간단한 방법은 인터럽트를 비활성화한 구간인
*임계 구역*을 사용하는 것입니다.
`main`에서 `COUNTER` 접근을 임계 구역으로 감싸면,
카운터 증가가 끝날 때까지 타이머 인터럽트가 실행되지 않음을 보장할 수 있습니다.

```rust,ignore
static mut COUNTER: u32 = 0;

#[entry]
fn main() -> ! {
    set_timer_1hz();
    let mut last_state = false;
    loop {
        let state = read_signal_level();
        if state && !last_state {
            // New critical section ensures synchronised access to COUNTER
            cortex_m::interrupt::free(|_| {
                unsafe { COUNTER += 1 };
            });
        }
        last_state = state;
    }
}

#[interrupt]
fn timer() {
    unsafe { COUNTER = 0; }
}
```

이 예제에서는 `cortex_m::interrupt::free`를 사용했지만,
다른 플랫폼에도 임계 구역 실행 메커니즘이 있습니다.
개념적으로는 인터럽트를 끄고 코드를 실행한 뒤 다시 켜는 것과 같습니다.

타이머 인터럽트 안에는 임계 구역이 필요하지 않았는데,
이유는 두 가지입니다.

    * `COUNTER`에 0을 쓰는 연산은 읽기-수정-쓰기 형태가 아니므로 레이스 영향이 없습니다.
    * 인터럽트 핸들러는 `main` 스레드에 의해 선점되지 않습니다.

만약 `COUNTER`를 서로 선점 가능한 여러 인터럽트 핸들러가 공유한다면,
각 핸들러에도 임계 구역이 필요할 수 있습니다.

이 방법은 당장의 문제를 해결하지만,
여전히 주의 깊게 검토해야 하는 unsafe 코드가 남고,
불필요하게 임계 구역을 사용할 수도 있습니다.
임계 구역은 인터럽트 처리를 잠시 멈추므로
코드 크기 증가, 인터럽트 지연(latency) 증가,
지터(jitter) 증가 같은 비용이 따릅니다.
시스템에 따라 문제가 될 수도 있고 아닐 수도 있지만,
일반적으로는 최소화하는 편이 좋습니다.

중요한 점은 임계 구역이 인터럽트 차단은 보장해도,
멀티코어 시스템에서의 상호 배제를 보장하지는 않는다는 것입니다.
다른 코어는 인터럽트 없이도 같은 메모리에 접근할 수 있습니다.
멀티코어에서는 더 강한 동기화 프리미티브가 필요합니다.

## 원자적 접근(Atomic Access)

일부 플랫폼은 읽기-수정-쓰기 연산을 보장하는
특수 원자 명령어를 제공합니다.
Cortex-M 기준으로 `thumbv6`(Cortex-M0, M0+)는
원자적 load/store만 제공하고,
`thumbv7`(Cortex-M3 이상)는 전체 CAS(Compare and Swap)를 제공합니다.

CAS는 "모든 인터럽트 비활성화"라는 강한 방법의 대안이 됩니다.
증가 연산을 시도했다가 중간에 간섭이 있으면 자동으로 재시도할 수 있기 때문입니다.
이 원자 연산은 멀티코어에서도 안전합니다.

```rust,ignore
use core::sync::atomic::{AtomicUsize, Ordering};

static COUNTER: AtomicUsize = AtomicUsize::new(0);

#[entry]
fn main() -> ! {
    set_timer_1hz();
    let mut last_state = false;
    loop {
        let state = read_signal_level();
        if state && !last_state {
            // Use `fetch_add` to atomically add 1 to COUNTER
            COUNTER.fetch_add(1, Ordering::Relaxed);
        }
        last_state = state;
    }
}

#[interrupt]
fn timer() {
    // Use `store` to write 0 directly to COUNTER
    COUNTER.store(0, Ordering::Relaxed)
}
```

이번에는 `COUNTER`가 안전한 `static` 변수입니다.
`AtomicUsize` 덕분에 인터럽트를 비활성화하지 않아도
인터럽트 핸들러와 메인 스레드에서 모두 안전하게 수정할 수 있습니다.
가능하다면 이 방식이 더 좋지만,
플랫폼에 따라 지원되지 않을 수도 있습니다.

[`Ordering`]에 대한 참고:
이 값은 컴파일러/하드웨어의 명령 재정렬 방식과 캐시 가시성에 영향을 줍니다.
단일 코어 플랫폼이라고 가정하면,
이 경우 `Relaxed`가 충분하며 가장 효율적인 선택입니다.
더 엄격한 ordering을 쓰면 컴파일러가 원자 연산 주변에 메모리 배리어를 삽입합니다.
원자 연산을 어떤 목적으로 쓰느냐에 따라 필요할 수도, 아닐 수도 있습니다.
원자 모델의 세부 사항은 복잡하므로 별도 자료를 참고하는 편이 좋습니다.

원자 연산과 ordering의 자세한 내용은 [nomicon]을 참고하세요.

[`Ordering`]: https://doc.rust-lang.org/core/sync/atomic/enum.Ordering.html
[nomicon]: https://doc.rust-lang.org/nomicon/atomics.html

## Abstractions, Send, and Sync

None of the above solutions are especially satisfactory. They require `unsafe`
blocks which must be very carefully checked and are not ergonomic. Surely we
Rust에서는 더 나은 방법이 있습니다.

카운터를 안전한 인터페이스로 추상화하면,
코드의 다른 위치에서 안전하게 재사용할 수 있습니다.
이 예제에서는 임계 구역 기반 카운터를 사용하지만,
원자 연산으로도 거의 동일한 방식의 추상화를 만들 수 있습니다.

```rust,ignore
use core::cell::UnsafeCell;
use cortex_m::interrupt;

// Our counter is just a wrapper around UnsafeCell<u32>, which is the heart
// of interior mutability in Rust. By using interior mutability, we can have
// COUNTER be `static` instead of `static mut`, but still able to mutate
// its counter value.
struct CSCounter(UnsafeCell<u32>);

const CS_COUNTER_INIT: CSCounter = CSCounter(UnsafeCell::new(0));

impl CSCounter {
    pub fn reset(&self, _cs: &interrupt::CriticalSection) {
        // By requiring a CriticalSection be passed in, we know we must
        // be operating inside a CriticalSection, and so can confidently
        // use this unsafe block (required to call UnsafeCell::get).
        unsafe { *self.0.get() = 0 };
    }

    pub fn increment(&self, _cs: &interrupt::CriticalSection) {
        unsafe { *self.0.get() += 1 };
    }
}

// Required to allow static CSCounter. See explanation below.
unsafe impl Sync for CSCounter {}

// COUNTER is no longer `mut` as it uses interior mutability;
// therefore it also no longer requires unsafe blocks to access.
static COUNTER: CSCounter = CS_COUNTER_INIT;

#[entry]
fn main() -> ! {
    set_timer_1hz();
    let mut last_state = false;
    loop {
        let state = read_signal_level();
        if state && !last_state {
            // No unsafe here!
            interrupt::free(|cs| COUNTER.increment(cs));
        }
        last_state = state;
    }
}

#[interrupt]
fn timer() {
    // We do need to enter a critical section here just to obtain a valid
    // cs token, even though we know no other interrupt could pre-empt
    // this one.
    interrupt::free(|cs| COUNTER.reset(cs));

    // We could use unsafe code to generate a fake CriticalSection if we
    // really wanted to, avoiding the overhead:
    // let cs = unsafe { interrupt::CriticalSection::new() };
}
```

`unsafe` 코드를 신중하게 설계한 추상화 내부로 옮겼고,
애플리케이션 코드에서는 더 이상 `unsafe` 블록이 필요하지 않게 됐습니다.

이 설계는 애플리케이션이 `CriticalSection` 토큰을 넘기도록 강제합니다.
이 토큰은 `interrupt::free`로만 안전하게 생성되므로,
토큰 전달을 요구하는 것만으로 실제 잠금 코드를 직접 작성하지 않고도
임계 구역 내부에서 동작함을 보장할 수 있습니다.
이 보장은 컴파일러가 정적으로 제공하므로 `cs` 관련 런타임 오버헤드는 없습니다.
카운터가 여러 개여도 같은 `cs`를 공유하면 되므로,
중첩 임계 구역을 여러 번 만들 필요가 없습니다.

여기서 Rust 동시성의 중요한 주제인 [`Send`와 `Sync`] trait가 등장합니다.
요약하면 어떤 타입이 다른 스레드로 안전하게 이동 가능하면 Send,
여러 스레드에서 안전하게 공유 가능하면 Sync입니다.
임베디드에서는 인터럽트를 애플리케이션 코드와 별도 스레드처럼 간주하므로,
인터럽트와 메인 코드가 함께 접근하는 변수는 Sync여야 합니다.

[`Send`와 `Sync`]: https://doc.rust-lang.org/nomicon/send-and-sync.html

Rust의 대부분 타입은 이 trait들을 컴파일러가 자동으로 유도합니다.
하지만 `CSCounter`는 [`UnsafeCell`]을 포함하므로 Sync가 아니며,
따라서 `static CSCounter`를 바로 만들 수 없습니다.
`static` 변수는 여러 스레드에서 접근될 수 있으므로 _반드시_ Sync여야 합니다.

[`UnsafeCell`]: https://doc.rust-lang.org/core/cell/struct.UnsafeCell.html

`CSCounter`가 실제로 스레드 간 공유에 안전하다는 점을 컴파일러에 알리기 위해,
Sync trait를 명시적으로 구현합니다.
앞서 임계 구역을 사용할 때와 마찬가지로,
이 방식은 단일 코어 플랫폼에서만 안전합니다.
멀티코어라면 추가적인 안전 장치가 필요합니다.

## 뮤텍스(Mutex)

카운터 문제에 특화된 유용한 추상화를 만들었지만,
동시성에는 널리 쓰이는 공통 추상화가 더 있습니다.

대표적인 *동기화 프리미티브*가 뮤텍스(mutual exclusion)입니다.
뮤텍스는 카운터 같은 변수에 대한 배타적 접근을 보장합니다.
스레드는 뮤텍스를 잠그기(lock/acquire) 시도하고,
즉시 성공하거나, 잠금 해제를 기다리며 블록되거나,
잠금을 얻지 못했다는 오류를 반환받습니다.
잠금을 보유한 동안에는 보호된 데이터에 접근할 수 있고,
작업이 끝나면 잠금을 해제(unlock/release)해 다른 스레드가 획득하게 합니다.
Rust에서는 보통 [`Drop`] trait를 사용해 스코프 종료 시 잠금이 항상 해제되도록 구현합니다.

[`Drop`]: https://doc.rust-lang.org/core/ops/trait.Drop.html

인터럽트 핸들러에서 뮤텍스를 쓰는 일은 까다롭습니다.
인터럽트 핸들러가 블록되는 것은 일반적으로 허용되지 않으며,
메인 스레드의 잠금 해제를 기다리며 블록되면 특히 치명적입니다.
그 경우 *데드락*이 발생합니다.
(실행이 인터럽트 핸들러에 묶여 메인 스레드가 잠금을 해제할 기회를 얻지 못함)
데드락은 unsafe로 분류되지는 않지만,
안전한 Rust에서도 충분히 발생할 수 있습니다.

이 문제를 피하려면,
카운터 예제처럼 잠금을 위해 임계 구역을 요구하는 뮤텍스를 사용할 수 있습니다.
잠금 유지 시간과 임계 구역 지속 시간이 같다면,
뮤텍스의 lock/unlock 상태를 별도로 추적하지 않아도
감싼 변수에 대한 배타 접근을 보장할 수 있습니다.

실제로 `cortex_m` 크레이트가 이 방식을 제공합니다.
카운터도 다음처럼 작성할 수 있습니다.

```rust,ignore
use core::cell::Cell;
use cortex_m::interrupt::Mutex;

static COUNTER: Mutex<Cell<u32>> = Mutex::new(Cell::new(0));

#[entry]
fn main() -> ! {
    set_timer_1hz();
    let mut last_state = false;
    loop {
        let state = read_signal_level();
        if state && !last_state {
            interrupt::free(|cs|
                COUNTER.borrow(cs).set(COUNTER.borrow(cs).get() + 1));
        }
        last_state = state;
    }
}

#[interrupt]
fn timer() {
    // We still need to enter a critical section here to satisfy the Mutex.
    interrupt::free(|cs| COUNTER.borrow(cs).set(0));
}
```

여기서는 [`Cell`]을 사용합니다.
`Cell`과 `RefCell`은 안전한 내부 가변성을 제공하는 도구입니다.
이미 본 `UnsafeCell`은 내부 가변성의 최하위 레이어로,
unsafe 코드에서만 값에 대한 여러 가변 참조를 가능하게 합니다.
`Cell`은 `UnsafeCell`과 유사하지만 안전한 인터페이스를 제공합니다.
현재 값을 복사해 읽거나 통째로 교체만 허용하고 참조 자체는 내주지 않습니다.
또한 Sync가 아니므로 스레드 간 공유도 불가능합니다.
이 제약 덕분에 안전하지만, `static`은 Sync여야 하므로
`Cell`을 단독으로 `static`에 둘 수는 없습니다.

[`Cell`]: https://doc.rust-lang.org/core/cell/struct.Cell.html

그런데 위 예제가 동작하는 이유는 무엇일까요?
`Mutex<T>`는 `T`가 Send이면(예: `Cell`) Sync를 구현할 수 있습니다.
임계 구역 내부에서만 내용 접근을 허용하기 때문에 안전하게 가능합니다.
결과적으로 unsafe 코드 없이도 안전한 카운터를 만들 수 있습니다.

이 방식은 카운터의 `u32` 같은 단순 타입에는 매우 좋습니다.
그렇다면 Copy가 아닌 더 복잡한 타입은 어떨까요?
임베디드에서 아주 흔한 예가 주변장치 구조체이며,
보통 Copy가 아닙니다. 이런 경우 `RefCell`을 사용할 수 있습니다.

## 주변장치 공유

`svd2rust` 같은 도구로 생성된 디바이스 크레이트는
주변장치 구조체 인스턴스가 동시에 하나만 존재하도록 강제해
안전한 주변장치 접근을 제공합니다.
이 방식은 안전하지만,
메인 스레드와 인터럽트 핸들러에서 같은 주변장치를 함께 접근하기는 어렵게 만듭니다.

주변장치 접근을 안전하게 공유하려면 앞서 본 `Mutex`를 사용할 수 있습니다.
여기에 [`RefCell`]도 필요합니다.
`RefCell`은 런타임 검사로 주변장치 참조가 한 번에 하나만 나가도록 보장합니다.
단순 `Cell`보다 오버헤드는 크지만,
복사본이 아니라 참조를 공유하는 상황에서는 필요한 비용입니다.

[`RefCell`]: https://doc.rust-lang.org/core/cell/struct.RefCell.html

마지막으로 메인 코드에서 초기화한 주변장치를
공유 변수로 옮겨 넣는 과정도 필요합니다.
이를 위해 처음에는 `None`으로 두고,
나중에 실제 주변장치 인스턴스를 넣는 `Option`을 사용합니다.

```rust,ignore
use core::cell::RefCell;
use cortex_m::interrupt::{self, Mutex};
use stm32f4::stm32f405;

static MY_GPIO: Mutex<RefCell<Option<stm32f405::GPIOA>>> =
    Mutex::new(RefCell::new(None));

#[entry]
fn main() -> ! {
    // Obtain the peripheral singletons and configure it.
    // This example is from an svd2rust-generated crate, but
    // most embedded device crates will be similar.
    let dp = stm32f405::Peripherals::take().unwrap();
    let gpioa = &dp.GPIOA;

    // Some sort of configuration function.
    // Assume it sets PA0 to an input and PA1 to an output.
    configure_gpio(gpioa);

    // Store the GPIOA in the mutex, moving it.
    interrupt::free(|cs| MY_GPIO.borrow(cs).replace(Some(dp.GPIOA)));
    // We can no longer use `gpioa` or `dp.GPIOA`, and instead have to
    // access it via the mutex.

    // Be careful to enable the interrupt only after setting MY_GPIO:
    // otherwise the interrupt might fire while it still contains None,
    // and as-written (with `unwrap()`), it would panic.
    set_timer_1hz();
    let mut last_state = false;
    loop {
        // We'll now read state as a digital input, via the mutex
        let state = interrupt::free(|cs| {
            let gpioa = MY_GPIO.borrow(cs).borrow();
            gpioa.as_ref().unwrap().idr.read().idr0().bit_is_set()
        });

        if state && !last_state {
            // Set PA1 high if we've seen a rising edge on PA0.
            interrupt::free(|cs| {
                let gpioa = MY_GPIO.borrow(cs).borrow();
                gpioa.as_ref().unwrap().odr.modify(|_, w| w.odr1().set_bit());
            });
        }
        last_state = state;
    }
}

#[interrupt]
fn timer() {
    // This time in the interrupt we'll just clear PA0.
    interrupt::free(|cs| {
        // We can use `unwrap()` because we know the interrupt wasn't enabled
        // until after MY_GPIO was set; otherwise we should handle the potential
        // for a None value.
        let gpioa = MY_GPIO.borrow(cs).borrow();
        gpioa.as_ref().unwrap().odr.modify(|_, w| w.odr1().clear_bit());
    });
}
```

내용이 많으니 중요한 줄만 나눠서 보겠습니다.

```rust,ignore
static MY_GPIO: Mutex<RefCell<Option<stm32f405::GPIOA>>> =
    Mutex::new(RefCell::new(None));
```

공유 변수는 이제 `Option`을 담은 `RefCell`을 다시 `Mutex`로 감싼 형태입니다.
`Mutex`는 임계 구역에서만 접근을 허용해 변수를 Sync로 만들어 줍니다.
(`RefCell` 단독으로는 Sync가 아님)
`RefCell`은 참조 기반 내부 가변성을 제공하고,
`Option`은 초기엔 비워 두었다가 나중에 실제 값을 옮겨 넣을 수 있게 해 줍니다.
주변장치 싱글턴은 정적으로 접근할 수 없고 런타임에만 획득되므로 이 단계가 필요합니다.

```rust,ignore
interrupt::free(|cs| MY_GPIO.borrow(cs).replace(Some(dp.GPIOA)));
```

임계 구역 안에서 뮤텍스의 `borrow()`를 호출하면 `RefCell` 참조를 얻고,
`replace()`로 새 값을 `RefCell` 안으로 이동시킬 수 있습니다.

```rust,ignore
interrupt::free(|cs| {
    let gpioa = MY_GPIO.borrow(cs).borrow();
    gpioa.as_ref().unwrap().odr.modify(|_, w| w.odr1().set_bit());
});
```

마지막으로 `MY_GPIO`를 안전하고 동시성 친화적으로 사용합니다.
임계 구역은 인터럽트 개입을 막고 뮤텍스를 빌릴 수 있게 해 줍니다.
이후 `RefCell`이 `&Option<GPIOA>`를 제공하며,
참조가 스코프를 벗어날 때까지 빌림 상태를 추적합니다.
스코프를 벗어나면 더 이상 빌려진 상태가 아님을 반영합니다.

`&Option`에서 `GPIOA`를 직접 이동시킬 수는 없으므로,
`as_ref()`로 `&Option<&GPIOA>`로 바꾼 뒤 `unwrap()`하여
주변장치를 조작할 수 있는 `&GPIOA`를 얻습니다.

공유 자원에 가변 참조가 필요하다면 `borrow_mut`와 `deref_mut`를 사용해야 합니다.
다음 코드는 TIM2 타이머 예제입니다.

```rust,ignore
use core::cell::RefCell;
use core::ops::DerefMut;
use cortex_m::interrupt::{self, Mutex};
use cortex_m::asm::wfi;
use stm32f4::stm32f405;

static G_TIM: Mutex<RefCell<Option<Timer<stm32::TIM2>>>> =
	Mutex::new(RefCell::new(None));

#[entry]
fn main() -> ! {
    let mut cp = cm::Peripherals::take().unwrap();
    let dp = stm32f405::Peripherals::take().unwrap();

    // Some sort of timer configuration function.
    // Assume it configures the TIM2 timer, its NVIC interrupt,
    // and finally starts the timer.
    let tim = configure_timer_interrupt(&mut cp, dp);

    interrupt::free(|cs| {
        G_TIM.borrow(cs).replace(Some(tim));
    });

    loop {
        wfi();
    }
}

#[interrupt]
fn timer() {
    interrupt::free(|cs| {
        if let Some(ref mut tim)) =  G_TIM.borrow(cs).borrow_mut().deref_mut() {
            tim.start(1.hz());
        }
    });
}

```

휴, 안전하긴 하지만 코드가 조금 번거롭습니다.
더 나은 방법이 있을까요?

## RTIC

대안 중 하나는 Real Time Interrupt-driven Concurrency의 약자인 [RTIC framework]입니다.
RTIC는 정적 우선순위를 강제하고 `static mut` 변수("리소스") 접근을 추적해,
공유 자원이 항상 안전하게 접근되도록 정적으로 보장합니다.
항상 임계 구역에 들어가거나(`RefCell`처럼) 참조 카운팅을 쓰는 오버헤드가 필요 없고,
데드락 부재 보장, 매우 낮은 시간/메모리 오버헤드 같은 장점이 있습니다.

[RTIC framework]: https://github.com/rtic-rs/cortex-m-rtic

이 프레임워크는 메시지 패싱 같은 기능도 제공해
명시적 공유 상태 필요성을 줄여 줍니다.
또한 특정 시점에 태스크를 스케줄링할 수 있어
주기적 태스크 구현에도 활용할 수 있습니다.
자세한 내용은 [the documentation]을 참고하세요.

[the documentation]: https://rtic.rs

## 실시간 운영체제(RTOS)

임베디드 동시성의 또 다른 대표 모델은 RTOS(실시간 운영체제)입니다.
Rust에서의 사례는 아직 상대적으로 적지만,
전통적인 임베디드 개발에서는 널리 사용됩니다.
오픈소스 예로 [FreeRTOS], [ChibiOS]가 있습니다.
이 RTOS들은 여러 애플리케이션 스레드 실행을 지원하며,
스레드가 자발적으로 제어권을 넘기거나(협력형 멀티태스킹),
주기 타이머/인터럽트 기반으로(선점형 멀티태스킹) CPU가 스레드를 전환합니다.
보통 뮤텍스와 기타 동기화 프리미티브를 제공하고,
DMA 엔진 같은 하드웨어 기능과도 함께 동작합니다.

[FreeRTOS]: https://freertos.org/
[ChibiOS]: http://chibios.org/

작성 시점 기준으로 Rust RTOS 예제는 많지 않지만,
흥미로운 영역이므로 앞으로 발전을 지켜볼 만합니다.

## 멀티코어

임베디드 프로세서에서 2개 이상 코어를 갖는 경우가 점점 늘고 있으며,
이는 동시성 복잡도를 한 단계 더 높입니다.
임계 구역을 사용하는 예제(`cortex_m::interrupt::Mutex` 포함)는
다른 실행 주체가 인터럽트 스레드뿐이라고 가정하지만,
멀티코어에서는 더 이상 성립하지 않습니다.
대신 멀티코어용 동기화 프리미티브(SMP, symmetric multi-processing)가 필요합니다.

이 경우 보통 앞서 본 원자 명령어를 사용하며,
처리 시스템이 모든 코어에 대해 원자성을 유지해 줍니다.

이 주제를 자세히 다루는 것은 현재 이 책 범위를 벗어나지만,
큰 패턴 자체는 단일 코어 경우와 유사합니다.
