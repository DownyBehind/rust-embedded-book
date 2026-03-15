# macOS

필요한 도구는 [Homebrew] 또는 [MacPorts]로 설치할 수 있습니다.

[Homebrew]: http://brew.sh/
[MacPorts]: https://www.macports.org/

## [Homebrew]로 도구 설치

```text
$ # GDB
$ brew install arm-none-eabi-gdb

$ # OpenOCD
$ brew install openocd

$ # QEMU
$ brew install qemu
```

> **참고** OpenOCD가 비정상 종료된다면 최신 버전을 설치해야 할 수 있습니다.

```text
$ brew install --HEAD openocd
```

## [MacPorts]로 도구 설치

```text
$ # GDB
$ sudo port install arm-none-eabi-gcc

$ # OpenOCD
$ sudo port install openocd

$ # QEMU
$ sudo port install qemu
```

이상입니다. [다음 섹션]으로 이동하세요.

[next section]: verify.md
