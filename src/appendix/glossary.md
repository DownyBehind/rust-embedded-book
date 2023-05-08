# Appendix A: 용어집

임베디드 에코시스템은 다양한 프로토콜, 하드웨어 구성요소 및 공급업체별로 고유한 용어와 약어를 사용하는 것으로 가득합니다.  
이 용어집은 이러한 용어를 더 잘 이해하기 위한 링크와 함께 나열합니다.
.

### BSP

Board Support Crate 는 특정 보드용으로 구성된 인터페이스를 제공합니다.  
이것은 보통 [HAL](#hal) Crate에 의존적입니다.  
이에 대한 좀 더 자세한 내용은 여기를 참고하세요. [memory-mapped registers page](../start/registers.md)  
또는 좀 더 넓은 시각을 위해서 여기를 참고하세요. [this video](https://youtu.be/vLYit_HHPaY).

### FPU

Floating-point Unit. 부동 소수점 숫자에 대해서만 연산을 실행하는 '수학 프로세서'입니다.

### HAL

Hardware Abstraction Layer crate 마이크로컨트롤러의 기능 및 주변 장치에 대한 개발자 친화적인 인터페이스를 제공합니다.  
이것은 보통 [Peripheral Access Crate (PAC)](#pac)의 상위에 구현됩니다.  
이것은 또한 [`embedded-hal`](https://crates.io/crates/embedded-hal) crate의 특성을 구현할 수도 있습니다.  
이에 대한 좀 더 자세한 내용은 여기를 참고하세요. [memory-mapped registers page](../start/registers.md)  
또는 좀 더 넓은 시각을 위해서 여기를 참고하세요. [this video](https://youtu.be/vLYit_HHPaY).

### I2C

때때로 `I²C` 또는 Inter-IC로 언급됩니다. 이것은 단일 직접 회로 내에의 하드웨어 통신을 위한 프로토콜입니다.  
이에 대한 좀 더 자세한 내용은 여기를 참고하세요. [here][i2c]

[i2c]: https://en.wikipedia.org/wiki/I2c

### PAC

Peripheral Access Crate는 마이크로프로세스의 주변장치에 대한 접근을 제공합니다.  
 이것은 로우 레벨 crate 중 하나이며 제공되는 [SVD](#svd)에서 직접적으로 만들어냅니다, 이것을 주로 사용합니다. [svd2rust](https://github.com/rust-embedded/svd2rust/).  
[Hardware Abstraction Layer](#hal)는 보통 이 crate에 의존적입니다.
이에 대한 좀 더 자세한 내용은 여기를 참고하세요. [memory-mapped registers page](../start/registers.md)  
또는 좀 더 넓은 시각을 위해서 여기를 참고하세요. [this video](https://youtu.be/vLYit_HHPaY).

### SPI

Serial Peripheral Interface. 이에 대한 좀 더 자세한 내용은 여기를 참고하세요. [here][spi]

[spi]: https://en.wikipedia.org/wiki/Serial_peripheral_interface

### SVD

System View Description, 마이크로프로세서에 대한 프로그래머의 입장에서 작성한 XML 형식의 파일.  
이에 대한 좀 더 자세한 내용은 여기를 참고하세요.
[the ARM CMSIS documentation site](https://www.keil.com/pack/doc/CMSIS/SVD/html/index.html).

### UART

Universal asynchronous receiver-transmitter.  
 이에 대한 좀 더 자세한 내용은 여기를 참고하세요. [here][uart]

[uart]: https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter

### USART

Universal synchronous and asynchronous receiver-transmitter.  
이에 대한 좀 더 자세한 내용은 여기를 참고하세요. [here][usart]

[usart]: https://en.wikipedia.org/wiki/Universal_synchronous_and_asynchronous_receiver-transmitter
