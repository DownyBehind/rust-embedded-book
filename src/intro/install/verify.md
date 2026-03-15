# 설치 확인

이 섹션에서는 필수 도구/드라이버가 올바르게 설치되고 설정되었는지 확인합니다.

Mini-USB 케이블로 노트북/PC를 discovery 보드에 연결합니다.
discovery 보드에는 USB 커넥터가 두 개 있는데,
보드 가장자리 중앙의 "USB ST-LINK" 라벨이 붙은 포트를 사용하세요.

ST-LINK 헤더가 연결되어 있는지도 확인하세요.
아래 그림에서 ST-LINK 헤더가 강조되어 있습니다.

<p align="center">
<img title="Connected discovery board" src="../../assets/verify.jpeg">
</p>

이제 다음 명령을 실행합니다.

```console
openocd -f interface/stlink.cfg -f target/stm32f3x.cfg
```

> **NOTE**: Old versions of openocd, including the 0.10.0 release from 2017, do
> not contain the new (and preferable) `interface/stlink.cfg` file; instead you
> may need to use `interface/stlink-v2.cfg` or `interface/stlink-v2-1.cfg`.

아래와 비슷한 출력이 나오고, 프로그램은 콘솔을 점유한 채 대기해야 합니다.

```text
Open On-Chip Debugger 0.10.0
Licensed under GNU GPL v2
For bug reports, read
        http://openocd.org/doc/doxygen/bugs.html
Info : auto-selecting first available session transport "hla_swd". To override use 'transport select <transport>'.
adapter speed: 1000 kHz
adapter_nsrst_delay: 100
Info : The selected transport took over low-level target control. The results might differ compared to plain JTAG/SWD
none separate
Info : Unable to match requested speed 1000 kHz, using 950 kHz
Info : Unable to match requested speed 1000 kHz, using 950 kHz
Info : clock speed 950 kHz
Info : STLINK v2 JTAG v27 API v2 SWIM v15 VID 0x0483 PID 0x374B
Info : using stlink api v2
Info : Target voltage: 2.919881
Info : stm32f3x.cpu: hardware has 6 breakpoints, 4 watchpoints
```

출력이 완전히 같을 필요는 없지만,
마지막의 breakpoints/watchpoints 관련 줄은 보여야 합니다.
확인되면 OpenOCD 프로세스를 종료하고 [다음 섹션]으로 이동하세요.

[next section]: ../../start/index.md

"breakpoints" 줄이 보이지 않으면 다음 명령 중 하나를 시도해 보세요.

```console
openocd -f interface/stlink-v2.cfg -f target/stm32f3x.cfg
```

```console
openocd -f interface/stlink-v2-1.cfg -f target/stm32f3x.cfg
```

위 명령 중 하나가 동작한다면,
구형 하드웨어 리비전의 discovery 보드를 사용 중이라는 뜻입니다.
큰 문제는 아니지만 이후 설정을 조금 다르게 해야 하므로 기억해 두세요.
[다음 섹션]으로 이동하면 됩니다.

일반 사용자 권한에서 모두 실패한다면 root 권한(예: `sudo openocd ..`)으로 실행해 보세요.
root에서는 동작한다면 [udev rules] 설정이 올바른지 점검하세요.

[udev rules]: linux.md#udev-rules

여기까지 했는데도 OpenOCD가 동작하지 않으면 [an issue]를 열어 주세요.
도와드리겠습니다.

[an issue]: https://github.com/rust-embedded/book/issues
