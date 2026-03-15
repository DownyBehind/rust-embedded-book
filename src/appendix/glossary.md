# 부록 A: 용어집

임베디드 생태계에는 다양한 프로토콜, 하드웨어 구성요소,
벤더별 전용 개념이 존재하며 저마다 고유한 용어와 약어를 사용합니다.
이 용어집은 주요 용어를 정리하고, 더 잘 이해할 수 있도록 참고 자료를 함께 제공합니다.

### BSP

Board Support Crate는 특정 보드에 맞춰 구성된 고수준 인터페이스를 제공합니다.
보통 [HAL](#hal) 크레이트에 의존합니다.
자세한 설명은 [메모리 매핑 레지스터 페이지](../start/registers.md)를 참고하세요.
더 넓은 개요는 [이 영상](https://youtu.be/vLYit_HHPaY)에서 볼 수 있습니다.

### FPU

부동소수점 연산 장치(Floating-point Unit).
부동소수점 수 연산만 수행하는 "수학 프로세서"입니다.

### HAL

Hardware Abstraction Layer 크레이트는 마이크로컨트롤러 기능과 주변장치에 대해
개발자 친화적인 인터페이스를 제공합니다.
보통 [Peripheral Access Crate (PAC)](#pac) 위에 구현됩니다.
[`embedded-hal`](https://crates.io/crates/embedded-hal) trait를 구현하기도 합니다.
자세한 설명은 [메모리 매핑 레지스터 페이지](../start/registers.md)를 참고하세요.
더 넓은 개요는 [이 영상](https://youtu.be/vLYit_HHPaY)에서 볼 수 있습니다.

### I2C

`I²C` 또는 Inter-IC라고도 부릅니다.
단일 집적 회로 내부에서 하드웨어 간 통신을 위한 프로토콜입니다.
자세한 내용은 [여기][i2c]를 참고하세요.

[i2c]: https://en.wikipedia.org/wiki/I2c

### PAC

Peripheral Access Crate는 마이크로컨트롤러 주변장치 접근을 제공합니다.
저수준 크레이트에 속하며,
보통 제공된 [SVD](#svd)에서 직접 생성됩니다(대개 [svd2rust](https://github.com/rust-embedded/svd2rust/) 사용).
[Hardware Abstraction Layer](#hal)는 일반적으로 이 크레이트에 의존합니다.
자세한 설명은 [메모리 매핑 레지스터 페이지](../start/registers.md)를 참고하세요.
더 넓은 개요는 [이 영상](https://youtu.be/vLYit_HHPaY)에서 볼 수 있습니다.

### SPI

Serial Peripheral Interface.
자세한 내용은 [여기][spi]를 참고하세요.

[spi]: https://en.wikipedia.org/wiki/Serial_peripheral_interface

### SVD

System View Description는 마이크로컨트롤러 장치의 프로그래머 관점 구조를 설명하는
XML 파일 형식입니다.
자세한 내용은 [ARM CMSIS 문서](https://www.keil.com/pack/doc/CMSIS/SVD/html/index.html)를 참고하세요.

### UART

Universal asynchronous receiver-transmitter.
자세한 내용은 [여기][uart]를 참고하세요.

[uart]: https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter

### USART

Universal synchronous and asynchronous receiver-transmitter.
자세한 내용은 [여기][usart]를 참고하세요.

[usart]: https://en.wikipedia.org/wiki/Universal_synchronous_and_asynchronous_receiver-transmitter
