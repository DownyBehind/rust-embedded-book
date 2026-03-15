# Summary

<!--

Definition of the organization of this book is still a work in process.

Refer to https://github.com/rust-embedded/book/issues for
more information and coordination

-->

- [소개](./intro/index.md)
  - [하드웨어](./intro/hardware.md)
  - [`no_std`](./intro/no-std.md)
  - [도구 체인](./intro/tooling.md)
  - [설치](./intro/install.md)
    - [리눅스](./intro/install/linux.md)
    - [macOS](./intro/install/macos.md)
    - [윈도우](./intro/install/windows.md)
    - [설치 확인](./intro/install/verify.md)
- [시작하기](./start/index.md)
  - [QEMU](./start/qemu.md)
  - [하드웨어](./start/hardware.md)
  - [메모리 매핑 레지스터](./start/registers.md)
  - [세미호스팅](./start/semihosting.md)
  - [패닉 처리](./start/panicking.md)
  - [예외](./start/exceptions.md)
  - [인터럽트](./start/interrupts.md)
  - [입출력](./start/io.md)
- [주변장치](./peripherals/index.md)
  - [Rust로 첫 시도](./peripherals/a-first-attempt.md)
  - [빌림 검사기](./peripherals/borrowck.md)
  - [싱글턴](./peripherals/singletons.md)
- [정적 보장](./static-guarantees/index.md)
  - [타입 상태 프로그래밍](./static-guarantees/typestate-programming.md)
  - [상태 머신으로서의 주변장치](./static-guarantees/state-machines.md)
  - [설계 계약](./static-guarantees/design-contracts.md)
  - [제로 코스트 추상화](./static-guarantees/zero-cost-abstractions.md)
- [이식성](./portability/index.md)
- [동시성](./concurrency/index.md)
- [컬렉션](./collections/index.md)
- [디자인 패턴](./design-patterns/index.md)
  - [HAL](./design-patterns/hal/index.md)
    - [체크리스트](./design-patterns/hal/checklist.md)
    - [네이밍](./design-patterns/hal/naming.md)
    - [상호운용성](./design-patterns/hal/interoperability.md)
    - [예측 가능성](./design-patterns/hal/predictability.md)
    - [GPIO](./design-patterns/hal/gpio.md)
- [임베디드 C 개발자를 위한 팁](./c-tips/index.md)
    <!-- TODO: Define Sections -->
- [상호운용성](./interoperability/index.md)
  - [Rust 코드에 C 조금 섞기](./interoperability/c-with-rust.md)
  - [C 코드에 Rust 조금 섞기](./interoperability/rust-with-c.md)
- [기타 주제](./unsorted/index.md)
  - [최적화: 속도와 크기 트레이드오프](./unsorted/speed-vs-size.md)
  - [수학 기능 사용하기](./unsorted/math.md)

---

[부록 A: 용어집](./appendix/glossary.md)
