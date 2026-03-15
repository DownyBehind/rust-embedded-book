# 임베디드 C 개발자를 위한 팁

이 장은 Rust를 시작하려는 숙련된 임베디드 C 개발자에게 유용한 다양한 팁을 모아 둔 것입니다.
특히 C에서 익숙했던 방식이 Rust에서는 어떻게 달라지는지에 초점을 맞춥니다.

## 프리프로세서

임베디드 C에서는 프리프로세서를 다양한 용도로 자주 사용합니다.

- `#ifdef`를 이용한 컴파일 타임 코드 선택
- 컴파일 타임 배열 크기 계산 및 상수 연산
- 공통 패턴 단순화를 위한 매크로(함수 호출 오버헤드 회피)

Rust에는 프리프로세서가 없기 때문에,
위 용도 대부분은 다른 방식으로 해결합니다.
이 절에서는 프리프로세서 대안을 다룹니다.

### 컴파일 타임 코드 선택

Rust에서 `#ifdef ... #endif`에 가장 가까운 기능은 [Cargo features]입니다.
C 프리프로세서보다 더 명시적이며,
가능한 feature를 크레이트별로 선언하고 on/off로 관리합니다.
feature는 의존성 선언 시 활성화되며 additive하게 동작합니다.
즉 의존성 트리의 어느 크레이트든 특정 feature를 켜면,
그 크레이트의 모든 사용자에게 해당 feature가 적용됩니다.

[Cargo features]: https://doc.rust-lang.org/cargo/reference/manifest.html#the-features-section

예를 들어 신호처리 프리미티브 라이브러리 크레이트가 있다고 합시다.
각 컴포넌트는 컴파일 시간이 더 들거나 큰 상수 테이블을 포함할 수 있습니다.
이때 `Cargo.toml`에서 컴포넌트별 Cargo feature를 선언할 수 있습니다.

```toml
[features]
FIR = []
IIR = []
```

그리고 코드에서 `#[cfg(feature="FIR")]`로 포함 여부를 제어합니다.

```rust
/// In your top-level lib.rs

#[cfg(feature="FIR")]
pub mod fir;

#[cfg(feature="IIR")]
pub mod iir;
```

동일한 방식으로 feature가 _꺼져 있을 때만_ 포함하거나,
여러 feature 조합에 따라 조건부 포함도 가능합니다.

또한 Rust는 `target_arch`처럼 자동으로 설정되는 조건도 제공합니다.
아키텍처별 코드 선택에 유용합니다.
조건부 컴파일 전체 기능은 Rust 레퍼런스의
[conditional compilation] 장을 참고하세요.

[conditional compilation]: https://doc.rust-lang.org/reference/conditional-compilation.html

조건부 컴파일은 다음 문장/블록 하나에만 적용됩니다.
현재 스코프에서 블록으로 묶기 어렵다면 `cfg` 속성을 여러 번 써야 할 수 있습니다.
다만 대부분은 코드를 그대로 두고 최적화 단계에서 dead code를 제거하게 맡기는 편이 낫습니다.
개발자와 사용자 모두 단순해지고,
컴파일러도 미사용 코드 제거를 대체로 잘 수행합니다.

### 컴파일 타임 크기와 계산

Rust는 컴파일 타임 평가가 보장되는 `const fn`을 지원합니다.
그래서 배열 크기처럼 상수가 필요한 위치에 사용할 수 있습니다.
앞서 본 feature와 함께 쓰면 다음과 같습니다.

```rust
const fn array_size() -> usize {
    #[cfg(feature="use_more_ram")]
    { 1024 }
    #[cfg(not(feature="use_more_ram"))]
    { 128 }
}

static BUF: [u32; array_size()] = [0u32; array_size()];
```

`const fn`은 Rust 1.31 시점부터 stable에 도입되어,
문서나 활용 사례가 상대적으로 적었습니다.
작성 시점 기준으로 기능 제한도 있었지만,
이후 릴리스에서 허용 범위가 점차 확장되어 왔습니다.

### 매크로

Rust는 매우 강력한 [macro system]을 제공합니다.
C 프리프로세서가 소스 텍스트를 거의 그대로 치환하는 데 비해,
Rust 매크로는 더 높은 추상화 레벨에서 동작합니다.
Rust 매크로는 크게 *declarative(macros by example)*와 *procedural macros*로 나뉩니다.
전자는 더 단순하고 흔하며,
함수 호출처럼 보이지만 완전한 표현식/문장/아이템/패턴으로 확장될 수 있습니다.
procedural macro는 더 복잡하지만,
임의의 Rust 문법을 새로운 Rust 문법으로 변환할 수 있는 강력한 확장 지점을 제공합니다.

[macro system]: https://doc.rust-lang.org/book/ch19-06-macros.html

일반적으로 C 프리프로세서 매크로를 쓰던 자리는
declarative macro로 대체 가능한지 먼저 검토하는 것이 좋습니다.
이 매크로는 크레이트 내부에 정의해 자체 사용하거나 외부로 export할 수 있습니다.
다만 완전한 표현식/문장/아이템/패턴으로 확장되어야 하므로,
변수 이름의 일부만 치환하거나 리스트 일부만 생성하는 C식 사용법은 그대로 적용되지 않습니다.

Cargo feature와 마찬가지로 매크로가 정말 필요한지도 점검해 보세요.
많은 경우 일반 함수가 더 이해하기 쉽고,
인라이닝 결과도 매크로와 동일해질 수 있습니다.
`#[inline]`, `#[inline(always)]` [attributes]로 추가 제어도 가능하지만,
컴파일러는 같은 크레이트 함수 인라이닝을 보통 잘 처리하므로
무리한 강제는 오히려 성능 저하를 부를 수 있습니다.

[attributes]: https://doc.rust-lang.org/reference/attributes.html#inline-attribute

Rust 매크로 전체를 여기서 다루기는 범위를 벗어나므로,
자세한 내용은 공식 문서를 참고하세요.

## 빌드 시스템

대부분의 Rust 크레이트는 Cargo로 빌드합니다(필수는 아님).
Cargo는 전통적 빌드 시스템의 여러 어려운 문제를 해결해 줍니다.
다만 빌드 과정을 커스터마이즈하고 싶을 수 있으며,
이를 위해 Cargo는 [`build.rs` scripts]를 제공합니다.
이 스크립트는 필요에 따라 Cargo 빌드 시스템과 상호작용할 수 있습니다.

[`build.rs` scripts]: https://doc.rust-lang.org/cargo/reference/build-scripts.html

`build.rs`의 대표 사용 사례:

- 빌드 날짜, Git 커밋 해시 같은 정보를 실행 파일에 내장
- 선택된 feature나 로직에 따라 링크 스크립트를 빌드 타임 생성
- Cargo 빌드 설정 변경
- 추가 정적 라이브러리 링크

현재는 post-build 스크립트를 직접 지원하지 않으므로,
빌드 산출물 자동 변환이나 빌드 정보 출력 같은 작업은 별도 방식이 필요합니다.

### 크로스 컴파일

Cargo를 쓰면 크로스 컴파일도 단순해집니다.
대부분은 `--target thumbv6m-none-eabi`를 지정하고,
`target/thumbv6m-none-eabi/debug/myapp`에서 실행 파일을 찾으면 됩니다.

Rust가 네이티브 지원하지 않는 플랫폼이라면,
해당 타깃용 `libcore`를 직접 빌드해야 합니다.
이 경우 [Xargo]를 Cargo 대체 도구로 사용해
`libcore` 자동 빌드를 수행할 수 있습니다.

[Xargo]: https://github.com/japaric/xargo

## 반복자 vs 배열 인덱스 접근

C에서는 보통 배열을 인덱스로 직접 접근합니다.

```c
int16_t arr[16];
int i;
for(i=0; i<sizeof(arr)/sizeof(arr[0]); i++) {
    process(arr[i]);
}
```

Rust에서는 이것이 안티패턴일 수 있습니다.
인덱스 접근은 경계 검사 비용이 들고,
컴파일러 최적화를 방해할 수 있습니다.
중요한 차이점은 Rust는 메모리 안전성을 위해 out-of-bounds를 검사하지만,
C는 배열 범위를 벗어난 접근도 그대로 허용한다는 점입니다.

대신 반복자를 사용하세요.

```rust,ignore
let arr = [0u16; 16];
for element in arr.iter() {
    process(*element);
}
```

반복자는 C에서 직접 구현해야 하는 다양한 기능을 제공합니다.
예: chaining, zip, enumerate, 최소/최대 탐색, 합계 계산 등.
메서드 체이닝도 가능해 데이터 처리 코드를 읽기 좋게 만들 수 있습니다.

자세한 내용은 [Iterators in the Book], [Iterator documentation]를 참고하세요.

[Iterators in the Book]: https://doc.rust-lang.org/book/ch13-02-iterators.html
[Iterator documentation]: https://doc.rust-lang.org/core/iter/trait.Iterator.html

## 참조 vs 포인터

Rust에도 포인터([_raw pointers_])가 있지만,
역참조가 항상 `unsafe`로 간주되므로 특정 상황에서만 사용합니다.
포인터 뒤의 값에 대해 Rust가 일반적인 안전 보장을 제공할 수 없기 때문입니다.

[_raw pointers_]: https://doc.rust-lang.org/book/ch19-01-unsafe-rust.html#dereferencing-a-raw-pointer

대부분의 경우 `&`로 표시하는 _참조_ 또는 `&mut`로 표시하는 *가변 참조*를 사용합니다.
참조도 포인터처럼 역참조해 내부 값에 접근하지만,
Rust 소유권 시스템의 핵심 요소입니다.
같은 값에 대해 같은 시점에
"가변 참조 하나" 또는 "불변 참조 여러 개"만 허용됩니다.

실무적으로는 데이터에 가변 접근이 정말 필요한지 더 신중히 판단해야 합니다.
C는 기본이 가변이고 `const`를 명시해야 하지만,
Rust는 반대로 기본이 불변입니다.

raw pointer가 여전히 필요한 대표 상황은 하드웨어 직접 상호작용입니다.
(예: 버퍼 포인터를 DMA 주변장치 레지스터에 기록)
또한 메모리 매핑 레지스터 읽기/쓰기를 위해
주변장치 접근 크레이트 내부 구현에서도 raw pointer가 사용됩니다.

## Volatile 접근

C에서는 변수에 `volatile`을 붙여,
접근 사이에 값이 바뀔 수 있음을 컴파일러에 알립니다.
임베디드에서는 메모리 매핑 레지스터 처리에 자주 사용됩니다.

Rust에서는 변수 자체에 `volatile`을 붙이지 않고,
[`core::ptr::read_volatile`], [`core::ptr::write_volatile`]를 사용해
volatile 접근을 수행합니다.
이 메서드는 `*const T` 또는 `*mut T`(앞서 본 raw pointer)를 받아
volatile 읽기/쓰기를 수행합니다.

[`core::ptr::read_volatile`]: https://doc.rust-lang.org/core/ptr/fn.read_volatile.html
[`core::ptr::write_volatile`]: https://doc.rust-lang.org/core/ptr/fn.write_volatile.html

예를 들어 C에서는 다음과 같이 작성할 수 있습니다.

```c
volatile bool signalled = false;

void ISR() {
    // Signal that the interrupt has occurred
    signalled = true;
}

void driver() {
    while(true) {
        // Sleep until signalled
        while(!signalled) { WFI(); }
        // Reset signalled indicator
        signalled = false;
        // Perform some task that was waiting for the interrupt
        run_task();
    }
}
```

Rust에서 동등한 코드는 각 접근마다 volatile 메서드를 사용합니다.

```rust,ignore
static mut SIGNALLED: bool = false;

#[interrupt]
fn ISR() {
    // Signal that the interrupt has occurred
    // (In real code, you should consider a higher level primitive,
    //  such as an atomic type).
    unsafe { core::ptr::write_volatile(&mut SIGNALLED, true) };
}

fn driver() {
    loop {
        // Sleep until signalled
        while unsafe { !core::ptr::read_volatile(&SIGNALLED) } {}
        // Reset signalled indicator
        unsafe { core::ptr::write_volatile(&mut SIGNALLED, false) };
        // Perform some task that was waiting for the interrupt
        run_task();
    }
}
```

이 코드에서 주목할 점:
* `&mut SIGNALLED`는 `*mut T`를 요구하는 함수에 전달할 수 있습니다.
        `&mut T`가 자동으로 `*mut T`로 변환되기 때문입니다(`*const T`도 동일).
    * `read_volatile`/`write_volatile`는 `unsafe`함수이므로`unsafe` 블록이 필요합니다.
안전한 사용을 보장할 책임은 프로그래머에게 있으며,
자세한 내용은 해당 메서드 문서를 참고하세요.

실제로는 이 함수들을 직접 호출할 일은 많지 않습니다.
대부분 고수준 라이브러리가 대신 처리해 주기 때문입니다.
메모리 매핑 주변장치의 volatile 접근은 PAC류 크레이트가 자동 구현하고,
동시성 프리미티브는 더 나은 추상화가 존재합니다([Concurrency chapter] 참고).

[Concurrency chapter]: ../concurrency/index.md

## Packed와 Aligned 타입

임베디드 C에서는 하드웨어/프로토콜 요구에 맞추기 위해
변수 정렬(alignment)이나 구조체 packed 배치를 컴파일러에 지정하는 일이 흔합니다.

Rust에서는 struct/union의 `repr` 속성으로 이를 제어합니다.
기본 배치는 레이아웃 보장이 없으므로,
하드웨어나 C와 상호운용하는 코드에는 적합하지 않습니다.
컴파일러가 필드 순서를 바꾸거나 패딩을 넣을 수 있고,
동작은 Rust 버전에 따라 달라질 수도 있습니다.

```rust
struct Foo {
    x: u16,
    y: u8,
    z: u16,
}

fn main() {
    let v = Foo { x: 0, y: 0, z: 0 };
    println!("{:p} {:p} {:p}", &v.x, &v.y, &v.z);
}

// 0x7ffecb3511d0 0x7ffecb3511d4 0x7ffecb3511d2
// 패킹 효율을 위해 필드 순서가 x, z, y로 바뀜.
```

C와 호환 가능한 레이아웃을 보장하려면 `repr(C)`를 사용합니다.

```rust
#[repr(C)]
struct Foo {
    x: u16,
    y: u8,
    z: u16,
}

fn main() {
    let v = Foo { x: 0, y: 0, z: 0 };
    println!("{:p} {:p} {:p}", &v.x, &v.y, &v.z);
}

// 0x7fffd0d84c60 0x7fffd0d84c62 0x7fffd0d84c64
// 필드 순서가 보존되고 레이아웃이 안정적으로 유지됨.
// `z`는 2바이트 정렬이 필요하므로 `y`와 `z` 사이에 1바이트 패딩이 생김.
```

packed 표현을 보장하려면 `repr(packed)`를 사용합니다.

```rust
#[repr(packed)]
struct Foo {
    x: u16,
    y: u8,
    z: u16,
}

fn main() {
    let v = Foo { x: 0, y: 0, z: 0 };
    // 참조는 항상 정렬되어야 하므로,
    // 필드 주소 확인에는 `&v.x` 대신 `std::ptr::addr_of!()`로 raw pointer를 얻어 사용한다.
    let px = std::ptr::addr_of!(v.x);
    let py = std::ptr::addr_of!(v.y);
    let pz = std::ptr::addr_of!(v.z);
    println!("{:p} {:p} {:p}", px, py, pz);
}

// 0x7ffd33598490 0x7ffd33598492 0x7ffd33598493
// `y`와 `z` 사이 패딩이 없어 `z`는 비정렬 상태가 됨.
```

`repr(packed)`를 사용하면 타입 정렬도 `1`로 설정됩니다.

특정 정렬을 지정하려면 `repr(align(n))`을 사용합니다.
`n`은 정렬 바이트 수이며 2의 거듭제곱이어야 합니다.

```rust
#[repr(C)]
#[repr(align(4096))]
struct Foo {
    x: u16,
    y: u8,
    z: u16,
}

fn main() {
    let v = Foo { x: 0, y: 0, z: 0 };
    let u = Foo { x: 0, y: 0, z: 0 };
    println!("{:p} {:p} {:p}", &v.x, &v.y, &v.z);
    println!("{:p} {:p} {:p}", &u.x, &u.y, &u.z);
}

// 0x7ffec909a000 0x7ffec909a002 0x7ffec909a004
// 0x7ffec909b000 0x7ffec909b002 0x7ffec909b004
// `u`, `v` 인스턴스가 4096바이트 경계에 배치됨.
// 주소 끝의 `000`으로 확인 가능.
```

`repr(C)`와 `repr(align(n))`은 함께 사용해
정렬 + C 호환 레이아웃을 얻을 수 있습니다.
반면 `repr(align(n))`과 `repr(packed)`의 동시 사용은 허용되지 않습니다.
(`repr(packed)`가 정렬을 `1`로 고정하기 때문)
또한 `repr(packed)` 타입 안에 `repr(align(n))` 타입을 포함하는 것도 허용되지 않습니다.

타입 레이아웃 상세 내용은 Rust Reference의 [type layout] 장을 참고하세요.

[type layout]: https://doc.rust-lang.org/reference/type-layout.html

## 추가 자료

- 이 책의 관련 장:
  - [Rust 코드에 C 조금 섞기](../interoperability/c-with-rust.md)
  - [C 코드에 Rust 조금 섞기](../interoperability/rust-with-c.md)
- [The Rust Embedded FAQs](https://docs.rust-embedded.org/faq.html)
- [Rust Pointers for C Programmers](http://blahg.josefsipek.net/?p=580)
- [I used to use pointers - now what?](https://github.com/diwic/reffers-rs/blob/master/docs/Pointers.md)
