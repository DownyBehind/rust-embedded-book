# 컬렉션

프로그램을 작성하다 보면 결국 동적 자료구조(컬렉션)를 사용하고 싶어집니다.
`std`는 [`Vec`], [`String`], [`HashMap`] 같은 공통 컬렉션을 제공합니다.
`std`의 컬렉션 구현은 모두 전역 동적 메모리 할당기(힙)를 사용합니다.

[`Vec`]: https://doc.rust-lang.org/std/vec/struct.Vec.html
[`String`]: https://doc.rust-lang.org/std/string/struct.String.html
[`HashMap`]: https://doc.rust-lang.org/std/collections/struct.HashMap.html

정의상 `core`는 메모리 할당 기능을 포함하지 않으므로,
이 구현들은 `core`에서 사용할 수 없습니다.
대신 컴파일러와 함께 제공되는 `alloc` 크레이트에서 찾을 수 있습니다.

컬렉션이 필요할 때 힙 할당 구현만이 유일한 선택지는 아닙니다.
_고정 용량(fixed capacity)_ 컬렉션을 사용할 수도 있으며,
대표 구현은 [`heapless`] 크레이트에 있습니다.

[`heapless`]: https://crates.io/crates/heapless

이 절에서는 이 두 구현을 살펴보고 비교합니다.

## `alloc` 사용하기

`alloc` 크레이트는 표준 Rust 배포판에 포함되어 있습니다.
`Cargo.toml`에 의존성을 따로 선언하지 않아도 바로 `use`해서 사용할 수 있습니다.

```rust,ignore
#![feature(alloc)]

extern crate alloc;

use alloc::vec::Vec;
```

컬렉션을 사용하려면 먼저 `global_allocator` 속성으로
프로그램이 사용할 전역 할당기를 선언해야 합니다.
선택한 할당기는 [`GlobalAlloc`] trait를 구현해야 합니다.

[`GlobalAlloc`]: https://doc.rust-lang.org/core/alloc/trait.GlobalAlloc.html

설명을 완결적으로 하기 위해 간단한 bump pointer allocator를 구현해
전역 할당기로 사용해 보겠습니다.
다만 실제 프로그램에서는 이 구현 대신,
crates.io의 충분히 검증된 할당기를 사용할 것을 _강력히_ 권장합니다.

```rust,ignore
// bump pointer allocator 구현

use core::alloc::{GlobalAlloc, Layout};
use core::cell::UnsafeCell;
use core::ptr;

use cortex_m::interrupt;

// *단일 코어* 시스템용 bump pointer allocator
struct BumpPointerAlloc {
    head: UnsafeCell<usize>,
    end: usize,
}

unsafe impl Sync for BumpPointerAlloc {}

unsafe impl GlobalAlloc for BumpPointerAlloc {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        // `interrupt::free`는 임계 구역으로,
        // 인터럽트 안에서도 할당기를 안전하게 사용할 수 있게 해 준다.
        interrupt::free(|_| {
            let head = self.head.get();
            let size = layout.size();
            let align = layout.align();
            let align_mask = !(align - 1);

            // 시작 주소를 다음 정렬 경계로 올린다.
            let start = (*head + align - 1) & align_mask;

            if start + size > self.end {
                // null 포인터는 Out Of Memory 상태를 의미한다.
                ptr::null_mut()
            } else {
                *head = start + size;
                start as *mut u8
            }
        })
    }

    unsafe fn dealloc(&self, _: *mut u8, _: Layout) {
        // 이 할당기는 메모리 해제를 지원하지 않는다.
    }
}

// 전역 메모리 할당기 선언
// 주의: `[0x2000_0100, 0x2000_0200]` 메모리 구간이
// 프로그램의 다른 부분에서 사용되지 않음을 사용자가 보장해야 한다.
#[global_allocator]
static HEAP: BumpPointerAlloc = BumpPointerAlloc {
    head: UnsafeCell::new(0x2000_0100),
    end: 0x2000_0200,
};
```

전역 할당기 선택 외에도,
사용자는 _unstable_ `alloc_error_handler` 속성을 사용해
Out Of Memory(OOM) 오류 처리 방식을 정의해야 합니다.

```rust,ignore
#![feature(alloc_error_handler)]

use cortex_m::asm;

#[alloc_error_handler]
fn on_oom(_layout: Layout) -> ! {
    asm::bkpt();

    loop {}
}
```

위 준비가 끝나면 `alloc`의 컬렉션을 사용할 수 있습니다.

```rust,ignore
#[entry]
fn main() -> ! {
    let mut xs = Vec::new();

    xs.push(42);
    assert!(xs.pop(), Some(42));

    loop {
        // ..
    }
}
```

`std` 컬렉션을 써 본 적이 있다면 익숙할 것입니다.
동일한 구현을 사용하기 때문입니다.

## `heapless` 사용하기

`heapless` 컬렉션은 전역 메모리 할당기에 의존하지 않으므로
별도 설정이 필요 없습니다.
컬렉션을 `use`한 뒤 바로 생성하면 됩니다.

```rust,ignore
// heapless version: v0.4.x
use heapless::Vec;
use heapless::consts::*;

#[entry]
fn main() -> ! {
    let mut xs: Vec<_, U8> = Vec::new();

    xs.push(42).unwrap();
    assert_eq!(xs.pop(), Some(42));
    loop {}
}
```

이 컬렉션은 `alloc` 컬렉션과 두 가지 차이가 있습니다.

첫째, 컬렉션 용량을 미리 선언해야 합니다.
`heapless` 컬렉션은 재할당하지 않고 고정 용량을 가지며,
이 용량은 타입 시그니처의 일부입니다.
위 예제에서 `xs`는 최대 8개 원소를 담을 수 있고,
타입 시그니처의 `U8`(참고: [`typenum`])로 이를 나타냅니다.

[`typenum`]: https://crates.io/crates/typenum

둘째, `push`를 포함한 많은 메서드가 `Result`를 반환합니다.
`heapless` 컬렉션은 고정 용량이라 원소 삽입이 실패할 수 있기 때문입니다.
API는 성공/실패를 `Result`로 명시적으로 드러냅니다.
반대로 `alloc` 컬렉션은 용량이 부족하면 힙에서 재할당하여 확장합니다.

v0.4.x 기준으로 `heapless` 컬렉션은 모든 원소를 inline으로 저장합니다.
즉 `let x = heapless::Vec::new();` 같은 코드는 컬렉션을 스택에 배치합니다.
또한 `static` 변수나 힙(`Box<Vec<_, _>>`)에도 배치할 수 있습니다.

## 트레이드오프

힙 할당/재배치 가능한 컬렉션과 고정 용량 컬렉션 중 선택할 때
다음 사항을 고려하세요.

### Out Of Memory와 오류 처리

힙 할당에서는 Out Of Memory가 언제나 가능하며,
컬렉션이 커져야 하는 모든 지점에서 발생할 수 있습니다.
예를 들어 `alloc::Vec.push`는 잠재적으로 OOM을 일으킬 수 있습니다.
즉 일부 연산은 _암묵적으로_ 실패할 수 있습니다.
일부 `alloc` 컬렉션은 `try_reserve`를 제공해 확장 시 OOM 가능성을 점검할 수 있지만,
사용자가 능동적으로 활용해야 합니다.

반대로 `heapless`만 사용하고 다른 용도로 메모리 할당기를 쓰지 않는다면
OOM은 발생하지 않습니다.
대신 컬렉션 용량 초과를 상황별로 처리해야 하며,
`Vec.push` 같은 메서드가 반환하는 `Result`를 모두 다뤄야 합니다.

OOM 실패는 `heapless::Vec.push`의 `Result`를 `unwrap`해서 생기는 실패보다
디버깅이 더 어려울 수 있습니다.
관측된 실패 지점이 실제 원인 지점과 일치하지 않을 수 있기 때문입니다.
예를 들어 다른 컬렉션의 메모리 누수로 할당기가 거의 고갈된 상태라면
`vec.reserve(1)`조차 OOM을 유발할 수 있습니다.
(안전한 Rust에서도 메모리 누수는 가능합니다)

### 메모리 사용량

힙 할당 컬렉션의 메모리 사용량을 추론하기는 어렵습니다.
장수하는 컬렉션의 용량이 런타임에 바뀔 수 있기 때문입니다.
일부 연산은 암묵적으로 재할당을 유발해 메모리 사용을 늘릴 수 있고,
`shrink_to_fit` 같은 메서드는 메모리 사용을 줄일 가능성이 있지만
실제로 줄일지는 할당기 구현에 달려 있습니다.
또한 메모리 단편화로 인해 _겉보기_ 메모리 사용량이 늘 수 있습니다.

반면 고정 용량 컬렉션을 주로 `static` 변수에 두고
콜 스택 최대 크기까지 설정해 두면,
물리 메모리보다 많이 사용하려는 경우 링크 단계에서 탐지할 수 있습니다.

또한 스택에 할당된 고정 용량 컬렉션은 [`-Z emit-stack-sizes`] 플래그로 보고되므로,
[`stack-sizes`] 같은 스택 사용량 분석 도구가 이를 분석에 포함할 수 있습니다.

[`-Z emit-stack-sizes`]: https://doc.rust-lang.org/beta/unstable-book/compiler-flags/emit-stack-sizes.html
[`stack-sizes`]: https://crates.io/crates/stack-sizes

다만 고정 용량 컬렉션은 축소할 수 없으므로,
재배치 가능한 컬렉션보다 로드 팩터(실제 크기/용량 비율)가 낮아질 수 있습니다.

### 최악 실행 시간(WCET)

시간 민감 애플리케이션이나 하드 실시간 애플리케이션을 만든다면,
프로그램 각 부분의 최악 실행 시간에 큰 관심을 가져야 합니다.

`alloc` 컬렉션은 재할당이 가능하므로,
컬렉션이 커질 수 있는 연산의 WCET에는 재할당 시간도 포함됩니다.
이 시간은 컬렉션의 _런타임_ 용량에 따라 달라집니다.
따라서 `alloc::Vec.push` 같은 연산의 WCET를 정확히 정하기가 어렵습니다.
사용 중인 할당기와 런타임 용량 모두에 의존하기 때문입니다.

반면 고정 용량 컬렉션은 재할당이 없어서
연산 실행 시간이 예측 가능합니다.
예를 들어 `heapless::Vec.push`는 상수 시간에 동작합니다.

### 사용 편의성

`alloc`은 전역 할당기 설정이 필요하고 `heapless`는 그렇지 않습니다.
대신 `heapless`는 생성하는 각 컬렉션의 용량을 직접 정해야 합니다.

`alloc` API는 거의 모든 Rust 개발자에게 익숙합니다.
`heapless` API도 `alloc`을 최대한 닮도록 설계되었지만,
명시적 오류 처리 때문에 완전히 같을 수는 없습니다.
일부 개발자에게는 이 명시적 오류 처리가 과하거나 번거롭게 느껴질 수 있습니다.
