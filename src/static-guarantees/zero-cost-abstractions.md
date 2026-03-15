# 제로 코스트 추상화

타입 상태는 제로 코스트 추상화의 훌륭한 예시이기도 합니다.
즉 일부 동작을 런타임이 아닌 컴파일 타임 실행/분석으로 옮길 수 있다는 뜻입니다.
이 타입 상태들은 실제 데이터를 갖지 않고 마커(marker)로만 사용됩니다.
데이터가 없으므로 런타임 메모리 표현도 없습니다.

```rust,ignore
use core::mem::size_of;

let _ = size_of::<Enabled>();    // == 0
let _ = size_of::<Input>();      // == 0
let _ = size_of::<PulledHigh>(); // == 0
let _ = size_of::<GpioConfig<Enabled, Input, PulledHigh>>(); // == 0
```

## 제로 사이즈 타입

```rust,ignore
struct Enabled;
```

이처럼 정의된 구조체를 제로 사이즈 타입(Zero Sized Types)이라 부릅니다.
실제 데이터를 담고 있지 않기 때문입니다.
컴파일 타임에는 복사/이동/참조가 가능한 "실제 타입"처럼 동작하지만,
최적화 과정에서 완전히 제거됩니다.

다음 코드 조각을 보면,

```rust,ignore
pub fn into_input_high_z(self) -> GpioConfig<Enabled, Input, HighZ> {
    self.periph.modify(|_r, w| w.input_mode().high_z());
    GpioConfig {
        periph: self.periph,
        enabled: Enabled,
        direction: Input,
        mode: HighZ,
    }
}
```

우리가 반환하는 `GpioConfig`는 런타임에 실제로 존재하지 않습니다.
이 함수 호출은 보통 "상수 레지스터 값을 대상 레지스터 위치에 저장"하는
단일 어셈블리 명령 수준으로 축약됩니다.
즉 우리가 만든 타입 상태 인터페이스는 제로 코스트 추상화입니다.
`GpioConfig` 상태 추적을 위해 CPU/RAM/코드 공간을 추가로 쓰지 않으며,
직접 레지스터 접근과 동일한 머신 코드로 컴파일됩니다.

## 중첩

일반적으로 이런 추상화는 원하는 깊이만큼 중첩할 수 있습니다.
구성 요소가 모두 제로 사이즈 타입이라면,
전체 구조는 런타임에 존재하지 않습니다.

복잡하거나 깊게 중첩된 구조에서는
가능한 모든 상태 조합을 수동으로 정의하기 번거로울 수 있습니다.
이 경우 매크로를 사용해 구현 코드를 생성할 수 있습니다.
