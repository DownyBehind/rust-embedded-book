# 소개

임베디드 러스트 북에 오신 것을 환영합니다. 이 책은 마이크로컨트롤러 같은
"베어메탈" 임베디드 시스템에서 Rust 프로그래밍 언어를 사용하는 방법을 다루는
입문서입니다.

## 임베디드 Rust는 누구를 위한가

임베디드 Rust는 Rust 언어가 제공하는 고수준 개념과 안전성 보장을 활용하면서
임베디드 프로그래밍을 하고 싶은 모든 사람을 위한 선택지입니다.
([Who Rust Is For](https://doc.rust-lang.org/book/ch00-00-introduction.html)도 참고하세요)

## 범위

이 책의 목표는 다음과 같습니다.

- 개발자가 임베디드 Rust 개발을 빠르게 시작하도록 돕습니다. 즉,
  개발 환경을 어떻게 구성하는지 다룹니다.

- 임베디드 개발에서 Rust를 활용하는 *현재*의 모범 사례를 공유합니다. 즉,
  Rust 언어 기능을 어떻게 활용해야 더 정확한 임베디드 소프트웨어를 작성할 수
  있는지 설명합니다.

- 경우에 따라 요리책(cookbook) 역할을 합니다. 예를 들어,
  하나의 프로젝트에서 C와 Rust를 어떻게 섞어 쓸 수 있는지 다룹니다.

이 책은 가능한 한 일반적인 내용을 다루지만, 독자와 저자 모두가 내용을 따라가기
쉽도록 예제는 ARM Cortex-M 아키텍처를 기준으로 작성되어 있습니다. 다만 독자가
이 아키텍처에 익숙하다고 가정하지 않으며, 필요한 경우 해당 아키텍처에 특화된
세부 사항을 함께 설명합니다.

## 이 책의 대상 독자

이 책은 임베디드 배경이 있거나 Rust 배경이 있는 독자를 모두 대상으로 합니다.
하지만 임베디드 Rust에 관심이 있는 사람이라면 누구나 이 책에서 얻어갈 수 있는
내용이 있다고 믿습니다. 사전 지식이 부족하다면 "가정 및 선수 지식" 섹션을 먼저
읽고 필요한 배경을 보완해 보세요. 읽는 경험이 훨씬 좋아집니다. 또한
"추가 자료" 섹션에서 보충 학습에 도움이 되는 자료를 찾을 수 있습니다.

### 가정 및 선수 지식

- Rust 프로그래밍 언어 사용에 익숙하고, 데스크톱 환경에서 Rust 애플리케이션을
  작성, 실행, 디버깅해 본 경험이 있다고 가정합니다. 또한 이 책은 Rust 2018을
  기준으로 작성되었으므로 [2018 edition]의 관용구에도 익숙해야 합니다.

[2018 edition]: https://doc.rust-lang.org/edition-guide/

- C, C++, Ada 등 다른 언어로 임베디드 시스템을 개발/디버깅한 경험이 있고,
  다음과 같은 개념에 익숙하다고 가정합니다.
  - 크로스 컴파일
  - 메모리 매핑 주변장치
  - 인터럽트
  - I2C, SPI, 시리얼 등 일반적인 인터페이스

### 추가 자료

위에서 언급한 내용이 익숙하지 않거나 특정 주제를 더 깊게 알고 싶다면,
다음 자료가 도움이 될 수 있습니다.

| 주제                            | 자료                                                                                                                                                                                   | 설명                                                                   |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Rust                            | [Rust Book](https://doc.rust-lang.org/book/)                                                                                                                                           | Rust가 아직 익숙하지 않다면 이 책을 먼저 읽는 것을 강력히 권장합니다.  |
| Rust, Embedded                  | [Discovery Book](https://docs.rust-embedded.org/discovery/)                                                                                                                            | 임베디드 프로그래밍이 처음이라면 이 책이 더 좋은 출발점일 수 있습니다. |
| Rust, Embedded                  | [Embedded Rust Bookshelf](https://docs.rust-embedded.org)                                                                                                                              | Rust Embedded WG에서 제공하는 여러 자료를 한곳에서 볼 수 있습니다.     |
| Rust, Embedded                  | [Embedonomicon](https://docs.rust-embedded.org/embedonomicon/)                                                                                                                         | Rust 임베디드 개발의 저수준 세부 내용을 다룹니다.                      |
| Rust, Embedded                  | [embedded FAQ](https://docs.rust-embedded.org/faq.html)                                                                                                                                | 임베디드 Rust 관련 자주 묻는 질문을 모아 둔 문서입니다.                |
| Rust, Embedded                  | [Comprehensive Rust: Bare Metal](https://google.github.io/comprehensive-rust/bare-metal.html)                                                                                          | 베어메탈 Rust 개발을 위한 4일 과정 강의 자료입니다.                    |
| Interrupts                      | [Interrupt](https://en.wikipedia.org/wiki/Interrupt)                                                                                                                                   | -                                                                      |
| Memory-mapped IO/Peripherals    | [Memory-mapped I/O](https://en.wikipedia.org/wiki/Memory-mapped_I/O)                                                                                                                   | -                                                                      |
| SPI, UART, RS232, USB, I2C, TTL | [Stack Exchange about SPI, UART, and other interfaces](https://electronics.stackexchange.com/questions/37814/usart-uart-rs232-usb-spi-i2c-ttl-etc-what-are-all-of-these-and-how-do-th) | -                                                                      |

### 번역본

이 책은 자원봉사자들의 도움으로 여러 언어로 번역되고 있습니다. 번역본을 이
목록에 추가하고 싶다면 PR을 열어 주세요.

- [Japanese](https://tomoyuki-nakabayashi.github.io/book/)
  ([repository](https://github.com/tomoyuki-nakabayashi/book))

- [Chinese](https://xxchang.github.io/book/)
  ([repository](https://github.com/XxChang/book))

## 이 책을 읽는 방법

이 책은 기본적으로 앞에서 뒤로 순서대로 읽는 것을 가정합니다. 뒤쪽 장은 앞에서
소개한 개념을 바탕으로 진행되며, 앞 장에서 간단히 언급한 주제를 뒤 장에서 더
깊이 다루기도 합니다.

이 책의 대부분 예제는 STMicroelectronics의 [STM32F3DISCOVERY] 보드를 기준으로
설명합니다. 이 보드는 ARM Cortex-M 아키텍처 기반이며, 기본 동작은 같은 계열 CPU에서
대체로 유사합니다. 다만 주변장치나 기타 구현 세부 사항은 벤더마다, 심지어 같은
벤더의 마이크로컨트롤러 패밀리 내에서도 달라질 수 있습니다.

그래서 이 책의 예제를 직접 따라 해 보려면 [STM32F3DISCOVERY] 보드를 준비하는 것을
권장합니다.

[STM32F3DISCOVERY]: http://www.st.com/en/evaluation-tools/stm32f3discovery.html

## 기여 방법

이 책의 작업은 [this repository]에서 조율되며, 주로 [resources team]이 유지보수합니다.

[this repository]: https://github.com/rust-embedded/book
[resources team]: https://github.com/rust-embedded/wg#the-resources-team

책의 설명을 따라가기 어렵거나, 어떤 섹션이 충분히 명확하지 않다고 느껴진다면
그것도 버그입니다. [the issue tracker]에 이슈로 알려 주세요.

[the issue tracker]: https://github.com/rust-embedded/book/issues/

오탈자 수정이나 내용 보강 PR은 언제든 환영합니다.

## 이 자료 재사용

이 책은 다음 라이선스로 배포됩니다.

- 코드 샘플과 책에 포함된 독립 Cargo 프로젝트는 [MIT License]와
  [Apache License v2.0] 이중 라이선스를 따릅니다.
- 본문, 그림, 다이어그램 등 서술 자료는 Creative Commons [CC-BY-SA v4.0]
  라이선스를 따릅니다.

[MIT License]: https://opensource.org/licenses/MIT
[Apache License v2.0]: http://www.apache.org/licenses/LICENSE-2.0
[CC-BY-SA v4.0]: https://creativecommons.org/licenses/by-sa/4.0/legalcode

요약하면, 이 책의 텍스트나 이미지를 활용하려면 다음이 필요합니다.

- 적절한 출처 표기(예: 슬라이드에 책 이름과 해당 페이지 링크 표기)
- [CC-BY-SA v4.0] 라이선스 링크 제공
- 변경 사항이 있다면 그 사실을 명시하고, 변경 결과물도 동일 라이선스로 공개

이 책이 도움이 되었다면 알려 주시면 큰 힘이 됩니다.
