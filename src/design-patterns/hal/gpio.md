# GPIO 인터페이스 권장사항

<a id="c-zst-pin"></a>

## Pin types are zero-sized by default (C-ZST-PIN)

HAL이 노출하는 GPIO 인터페이스는
각 인터페이스/포트의 모든 핀에 대해 전용 제로 사이즈 타입을 제공해야 합니다.
모든 핀 할당이 정적으로 알려진 경우,
이는 제로 코스트 GPIO 추상화로 이어집니다.

각 GPIO 인터페이스 또는 포트는
모든 핀이 담긴 구조체를 반환하는 `split` 메서드를 구현해야 합니다.

예시:

```rust
pub struct PA0;
pub struct PA1;
// ...

pub struct PortA;

impl PortA {
    pub fn split(self) -> PortAPins {
        PortAPins {
            pa0: PA0,
            pa1: PA1,
            // ...
        }
    }
}

pub struct PortAPins {
    pub pa0: PA0,
    pub pa1: PA1,
    // ...
}
```

<a id="c-erased-pin"></a>

## Pin types provide methods to erase pin and port (C-ERASED-PIN)

핀 타입은 타입 소거(type erasure) 메서드를 제공해
속성 정보를 컴파일 타임에서 런타임으로 옮길 수 있어야 하며,
애플리케이션에서 더 유연하게 사용할 수 있어야 합니다.

예시:

```rust
/// Port A, pin 0.
pub struct PA0;

impl PA0 {
    pub fn erase_pin(self) -> PA {
        PA { pin: 0 }
    }
}

/// A pin on port A.
pub struct PA {
    /// The pin number.
    pin: u8,
}

impl PA {
    pub fn erase_port(self) -> Pin {
        Pin {
            port: Port::A,
            pin: self.pin,
        }
    }
}

pub struct Pin {
    port: Port,
    pin: u8,
    // (these fields can be packed to reduce the memory footprint)
}

enum Port {
    A,
    B,
    C,
    D,
}
```

<a id="c-pin-state"></a>

## Pin state should be encoded as type parameters (C-PIN-STATE)

핀은 칩/패밀리에 따라 다른 특성으로 입력 또는 출력 모드로 설정될 수 있습니다.
이 상태는 타입 시스템에 인코딩되어,
잘못된 상태의 핀 사용을 방지해야 합니다.

추가적인 칩 특화 상태(예: 구동 강도)도
추가 타입 파라미터를 사용해 같은 방식으로 인코딩할 수 있습니다.

핀 상태 변경 메서드는 `into_input`, `into_output` 형태로 제공해야 합니다.

또한 핀을 이동시키지 않고 일시적으로 다른 상태로 재설정할 수 있는
`with_{input,output}_state` 메서드를 제공해야 합니다.

다음 메서드는 모든 핀 타입에 제공되어야 합니다.
(즉 소거된 핀 타입과 비소거 핀 타입이 동일 API를 제공해야 함)

- `pub fn into_input<N: InputState>(self, input: N) -> Pin<N>`
- `pub fn into_output<N: OutputState>(self, output: N) -> Pin<N>`
- ```ignore
  pub fn with_input_state<N: InputState, R>(
      &mut self,
      input: N,
      f: impl FnOnce(&mut PA1<N>) -> R,
  ) -> R
  ```
- ```ignore
  pub fn with_output_state<N: OutputState, R>(
      &mut self,
      output: N,
      f: impl FnOnce(&mut PA1<N>) -> R,
  ) -> R
  ```

핀 상태는 sealed trait로 제한되어야 합니다.
HAL 사용자에게는 자체 상태를 추가할 필요가 없어야 합니다.
이 trait는 핀 상태 API 구현에 필요한 HAL 특화 메서드를 제공할 수 있습니다.

예시:

```rust
# use std::marker::PhantomData;
mod sealed {
    pub trait Sealed {}
}

pub trait PinState: sealed::Sealed {}
pub trait OutputState: sealed::Sealed {}
pub trait InputState: sealed::Sealed {
    // ...
}

pub struct Output<S: OutputState> {
    _p: PhantomData<S>,
}

impl<S: OutputState> PinState for Output<S> {}
impl<S: OutputState> sealed::Sealed for Output<S> {}

pub struct PushPull;
pub struct OpenDrain;

impl OutputState for PushPull {}
impl OutputState for OpenDrain {}
impl sealed::Sealed for PushPull {}
impl sealed::Sealed for OpenDrain {}

pub struct Input<S: InputState> {
    _p: PhantomData<S>,
}

impl<S: InputState> PinState for Input<S> {}
impl<S: InputState> sealed::Sealed for Input<S> {}

pub struct Floating;
pub struct PullUp;
pub struct PullDown;

impl InputState for Floating {}
impl InputState for PullUp {}
impl InputState for PullDown {}
impl sealed::Sealed for Floating {}
impl sealed::Sealed for PullUp {}
impl sealed::Sealed for PullDown {}

pub struct PA1<S: PinState> {
    _p: PhantomData<S>,
}

impl<S: PinState> PA1<S> {
    pub fn into_input<N: InputState>(self, input: N) -> PA1<Input<N>> {
        todo!()
    }

    pub fn into_output<N: OutputState>(self, output: N) -> PA1<Output<N>> {
        todo!()
    }

    pub fn with_input_state<N: InputState, R>(
        &mut self,
        input: N,
        f: impl FnOnce(&mut PA1<N>) -> R,
    ) -> R {
        todo!()
    }

    pub fn with_output_state<N: OutputState, R>(
        &mut self,
        output: N,
        f: impl FnOnce(&mut PA1<N>) -> R,
    ) -> R {
        todo!()
    }
}

// `PA`, `Pin`, 기타 핀 타입도 동일 패턴을 따른다.
```
