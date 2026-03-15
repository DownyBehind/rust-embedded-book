# `no_std` Rust 환경

임베디드 프로그래밍이라는 말은 매우 넓은 범위의 프로그래밍을 포괄합니다.
RAM과 ROM이 몇 KiB에 불과한 8비트 MCU([ST72325xx](https://www.st.com/resource/en/datasheet/st72325j6.pdf) 같은 기기)부터,
32/64비트 4코어 Cortex-A53 @ 1.4 GHz와 1GB RAM을 가진 Raspberry Pi
([Model B 3+](https://en.wikipedia.org/wiki/Raspberry_Pi#Specifications)) 같은 시스템까지 모두 포함됩니다.
따라서 어떤 타깃과 어떤 용도를 대상으로 하느냐에 따라 코드 작성 시 제약 조건도 달라집니다.

임베디드 프로그래밍 환경은 크게 두 가지로 나눌 수 있습니다.

## Hosted 환경

이런 환경은 일반적인 PC 환경과 상당히 비슷합니다.
즉 [POSIX](https://en.wikipedia.org/wiki/POSIX) 같은 시스템 인터페이스가 제공되어
파일 시스템, 네트워킹, 메모리 관리, 스레드 등 다양한 시스템과 상호작용할 수 있는
기본 기능을 사용할 수 있습니다. 표준 라이브러리는 보통 이런 기본 기능 위에서
동작합니다. RAM/ROM 사용 제한이나 sysroot, 특수 하드웨어 또는 I/O 같은 제약이
추가될 수는 있지만, 전반적인 느낌은 특수 목적의 PC 환경에서 코딩하는 것과 비슷합니다.

## 베어메탈 환경

베어메탈 환경에서는 프로그램이 시작되기 전에 미리 로드된 코드가 없습니다.
운영체제가 제공하는 소프트웨어가 없기 때문에 표준 라이브러리를 그대로 로드할 수
없습니다. 대신 프로그램과 그 프로그램이 사용하는 crate는 오직 하드웨어(베어메탈)만을
이용해 동작해야 합니다. Rust가 표준 라이브러리를 로드하지 않도록 하려면 `no_std`를
사용합니다. 표준 라이브러리의 플랫폼 비종속적인 부분은 [libcore](https://doc.rust-lang.org/core/)를
통해 사용할 수 있습니다. libcore는 임베디드 환경에서 항상 바람직하지는 않은 기능을
제외하고 있습니다. 그중 하나가 동적 메모리 할당을 위한 메모리 할당자입니다. 이런 기능이
필요하다면 이를 제공하는 별도의 crate를 사용하는 경우가 많습니다.

### libstd 런타임

앞에서 설명했듯이 [libstd](https://doc.rust-lang.org/std/)를 사용하려면 일정 수준의 시스템 통합이 필요합니다.
이는 [libstd](https://doc.rust-lang.org/std/)가 단지 OS 추상화에 접근하는 공통 인터페이스만 제공하기 때문이 아니라,
런타임도 함께 제공하기 때문입니다. 이 런타임은 스택 오버플로 보호 설정,
명령줄 인자 처리, 프로그램의 main 함수가 호출되기 전 메인 스레드 생성 같은 일을 담당합니다.
이 런타임 역시 `no_std` 환경에서는 사용할 수 없습니다.

## 요약

`#![no_std]`는 crate 수준의 속성으로, 이 crate가 std crate 대신 core crate에 링크된다는 뜻입니다.
[libcore](https://doc.rust-lang.org/core/) crate는 std crate의 플랫폼 비종속 부분집합으로,
프로그램이 어떤 시스템에서 실행될지를 가정하지 않습니다. 그래서 부동소수점, 문자열,
슬라이스 같은 언어 기본 요소용 API는 물론, 원자 연산이나 SIMD 명령처럼 프로세서 기능을
노출하는 API도 제공합니다. 반면 플랫폼 통합이 필요한 기능에 대한 API는 제공하지 않습니다.
이러한 특성 덕분에 no_std와 [libcore](https://doc.rust-lang.org/core/) 기반 코드는 부트로더,
펌웨어, 커널 같은 부트스트랩(stage 0) 코드 작성에 사용할 수 있습니다.

### 개요

| feature                                      | no_std | std |
| -------------------------------------------- | ------ | --- |
| heap (dynamic memory)                        | \*     | ✓   |
| collections (Vec, BTreeMap, etc)             | \*\*   | ✓   |
| stack overflow protection                    | ✘      | ✓   |
| runs init code before main                   | ✘      | ✓   |
| libstd available                             | ✘      | ✓   |
| libcore available                            | ✓      | ✓   |
| writing firmware, kernel, or bootloader code | ✓      | ✘   |

\* Only if you use the `alloc` crate and use a suitable allocator like [alloc-cortex-m].

\*\* Only if you use the `collections` crate and configure a global default allocator.

\*\* HashMap and HashSet are not available due to a lack of a secure random number generator.

[alloc-cortex-m]: https://github.com/rust-embedded/alloc-cortex-m

## 참고 자료

- [RFC-1184](https://github.com/rust-lang/rfcs/blob/master/text/1184-stabilize-no_std.md)
