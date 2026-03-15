# 리눅스

아래는 몇 가지 리눅스 배포판에서 사용할 설치 명령입니다.

## 패키지

- Ubuntu 18.04 이상 / Debian stretch 이상

> **참고** ARM Cortex-M 프로그램 디버깅에는 `gdb-multiarch` 명령을 사용합니다.

<!-- Debian stretch -->
<!-- GDB 7.12 -->
<!-- OpenOCD 0.9.0 -->
<!-- QEMU 2.8.1 -->

<!-- Ubuntu 18.04 -->
<!-- GDB 8.1 -->
<!-- OpenOCD 0.10.0 -->
<!-- QEMU 2.11.1 -->

```console
sudo apt install gdb-multiarch openocd qemu-system-arm
```

- Ubuntu 14.04, 16.04

> **참고** ARM Cortex-M 프로그램 디버깅에는 `arm-none-eabi-gdb` 명령을 사용합니다.

<!-- Ubuntu 14.04 -->
<!-- GDB 7.6 (!) -->
<!-- OpenOCD 0.7.0 (?) -->
<!-- QEMU 2.0.0 (?) -->

```console
sudo apt install gdb-arm-none-eabi openocd qemu-system-arm
```

- Fedora 27 이상

<!-- Fedora 27 -->
<!-- GDB 7.6 (!) -->
<!-- OpenOCD 0.10.0 -->
<!-- QEMU 2.10.2 -->

```console
sudo dnf install gdb openocd qemu-system-arm
```

- Arch Linux

> **참고** ARM Cortex-M 프로그램 디버깅에는 `arm-none-eabi-gdb` 명령을 사용합니다.

```console
sudo pacman -S arm-none-eabi-gdb qemu-system-arm openocd
```

## udev 규칙

이 규칙을 적용하면 root 권한 없이도 Discovery 보드에서 OpenOCD를 사용할 수 있습니다.

`/etc/udev/rules.d/70-st-link.rules` 파일을 만들고 아래 내용을 넣으세요.

```text
# STM32F3DISCOVERY rev A/B - ST-LINK/V2
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", TAG+="uaccess"

# STM32F3DISCOVERY rev C+ - ST-LINK/V2-1
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", TAG+="uaccess"
```

그다음 아래 명령으로 udev 규칙을 다시 로드합니다.

```console
sudo udevadm control --reload-rules
```

보드가 이미 연결되어 있었다면 한 번 분리했다가 다시 연결하세요.

다음 명령으로 권한을 확인할 수 있습니다.

```console
lsusb
```

아래와 비슷한 출력이 보여야 합니다.

```text
(..)
Bus 001 Device 018: ID 0483:374b STMicroelectronics ST-LINK/V2.1
(..)
```

bus와 device 번호를 확인하세요.
이 번호로 `/dev/bus/usb/<bus>/<device>` 경로를 만들고 다음처럼 확인합니다.

```console
ls -l /dev/bus/usb/001/018
```

```text
crw-------+ 1 root root 189, 17 Sep 13 12:34 /dev/bus/usb/001/018
```

```console
getfacl /dev/bus/usb/001/018 | grep user
```

```text
user::rw-
user:you:rw-
```

권한 문자열 뒤의 `+`는 확장 권한이 있다는 뜻입니다.
`getfacl` 출력에서 사용자 `you`가 이 장치를 사용할 수 있음을 확인할 수 있습니다.

이제 [다음 섹션]으로 이동하세요.

[next section]: verify.md
