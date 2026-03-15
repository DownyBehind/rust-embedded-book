# 사용할 하드웨어 살펴보기

이제 앞으로 다룰 하드웨어에 익숙해져 봅시다.

## STM32F3DISCOVERY("F3")

<p align="center">
<img title="F3" src="../assets/f3.jpg">
</p>

이 보드에는 무엇이 들어 있을까요?

- A [STM32F303VCT6](https://www.st.com/en/microcontrollers/stm32f303vc.html) 마이크로컨트롤러. 이 마이크로컨트롤러에는 다음이 포함됩니다.
  - 단정도 부동소수점 연산을 하드웨어로 지원하고 최대 72 MHz로 동작하는 단일 코어 ARM Cortex-M4F 프로세서

  - 256 KiB의 "플래시" 메모리. (1 KiB = 2**10** bytes)

  - 48 KiB의 RAM

  - 타이머, I2C, SPI, USART 같은 다양한 내장 주변장치

  - 보드 양옆 헤더 두 줄을 통해 접근할 수 있는 범용 입출력(GPIO) 및 기타 핀들

  - "USB USER"라고 표시된 USB 포트를 통해 접근하는 Mini-USB 인터페이스

- [LSM303DLHC](https://www.st.com/en/mems-and-sensors/lsm303dlhc.html) 칩의 일부인 [가속도계](https://en.wikipedia.org/wiki/Accelerometer)

- [LSM303DLHC](https://www.st.com/en/mems-and-sensors/lsm303dlhc.html) 칩의 일부인 [자력계](https://en.wikipedia.org/wiki/Magnetometer)

- [L3GD20](https://www.pololu.com/file/0J563/L3GD20.pdf) 칩의 일부인 [자이로스코프](https://en.wikipedia.org/wiki/Gyroscope)

- 나침반 모양으로 배치된 사용자 LED 8개

- 두 번째 마이크로컨트롤러 [STM32F103](https://www.st.com/en/microcontrollers/stm32f103cb.html). 이 마이크로컨트롤러는 실제로 온보드 프로그래머/디버거의 일부이며 "USB ST-LINK"라는 Mini-USB 포트에 연결되어 있습니다.

보드의 기능 목록과 더 자세한 사양은 [STMicroelectronics](https://www.st.com/en/evaluation-tools/stm32f3discovery.html) 웹사이트를 참고하세요.

주의할 점이 하나 있습니다. 보드에 외부 신호를 인가하려면 조심해야 합니다. STM32F303VCT6의 핀 정격 전압은 3.3V입니다. 자세한 내용은 [매뉴얼의 6.2 Absolute maximum ratings 섹션](https://www.st.com/resource/en/datasheet/stm32f303vc.pdf)을 참고하세요.
