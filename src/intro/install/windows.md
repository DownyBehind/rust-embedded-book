# 윈도우

## `arm-none-eabi-gdb`

ARM은 윈도우용 `.exe` 설치 파일을 제공합니다.
[여기][gcc]에서 내려받아 안내에 따라 설치하세요.
설치 마지막 단계에서 "Add path to environment variable" 옵션을 체크하고,
도구가 `%PATH%`에 들어갔는지 확인합니다.

```text
$ arm-none-eabi-gdb -v
GNU gdb (GNU Tools for Arm Embedded Processors 7-2018-q2-update) 8.1.0.20180315-git
(..)
```

[gcc]: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads

## OpenOCD

윈도우용 OpenOCD 공식 바이너리는 없지만,
직접 빌드하고 싶지 않다면 xPack 프로젝트의 바이너리 배포본([openocd])을 사용할 수 있습니다.
설치 안내를 따른 뒤 `%PATH%` 환경 변수에 설치 경로를 추가하세요.
(`C:\Users\USERNAME\AppData\Roaming\xPacks\@xpack-dev-tools\openocd\0.10.0-13.1\.content\bin\`)

[openocd]: https://xpack.github.io/openocd/

다음 명령으로 OpenOCD가 `%PATH%`에 있는지 확인합니다.

```text
$ openocd -v
Open On-Chip Debugger 0.10.0
(..)
```

## QEMU

[공식 사이트][qemu]에서 QEMU를 설치합니다.

[qemu]: https://www.qemu.org/download/#windows

## ST-LINK USB driver

[이 USB 드라이버]도 설치해야 OpenOCD가 동작합니다.
설치 안내를 따르고, 드라이버 아키텍처(32비트/64비트)를 시스템에 맞게 선택하세요.

[this USB driver]: http://www.st.com/en/embedded-software/stsw-link009.html

이상입니다. [다음 섹션]으로 이동하세요.

[next section]: verify.md
