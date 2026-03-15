# 하드웨어

이제 여러분은 도구 체인과 개발 과정에 어느 정도 익숙해졌을 것입니다.
이 섹션에서는 실제 하드웨어로 넘어갑니다. 과정 자체는 대부분 비슷합니다.
바로 시작해 봅시다.

## 하드웨어 파악하기

시작하기 전에 프로젝트 설정에 사용할 타깃 장치의 몇 가지 특성을 먼저 확인해야 합니다.

- ARM 코어 종류. 예: Cortex-M3

- ARM 코어에 FPU가 포함되어 있는가? Cortex-M4**F**, Cortex-M7**F** 코어에는 포함되어 있습니다.

- 타깃 장치에 플래시 메모리와 RAM이 얼마나 있는가? 예: 플래시 256 KiB, RAM 32 KiB

- 플래시 메모리와 RAM은 주소 공간 어디에 매핑되는가? 예: RAM은 흔히 `0x2000_0000`에 위치합니다.

이 정보는 장치의 데이터시트나 레퍼런스 매뉴얼에서 찾을 수 있습니다.

이 섹션에서는 기준 하드웨어로 STM32F3DISCOVERY를 사용합니다.
이 보드에는 STM32F303VCT6 마이크로컨트롤러가 탑재되어 있고, 이 칩은 다음 특성을 가집니다.

- 단정도 FPU를 포함한 Cortex-M4F 코어

- 주소 `0x0800_0000`에 위치한 256 KiB 플래시 메모리

- 주소 `0x2000_0000`에 위치한 40 KiB RAM(다른 RAM 영역도 하나 더 있지만 단순화를 위해 무시합니다)

## 설정하기

새 템플릿 인스턴스부터 다시 시작하겠습니다. `cargo-generate` 없이 이 과정을 어떻게 하는지는
[이전 QEMU 섹션]을 참고하세요.

[이전 QEMU 섹션]: qemu.md

```text
$ cargo generate --git https://github.com/rust-embedded/cortex-m-quickstart
 Project Name: app
 Creating project called `app`...
 Done! New project created /tmp/app

$ cd app
```

첫 번째 단계는 `.cargo/config.toml`에서 기본 컴파일 타깃을 설정하는 것입니다.

```console
tail -n5 .cargo/config.toml
```

```toml
# Pick ONE of these compilation targets
# target = "thumbv6m-none-eabi"    # Cortex-M0 and Cortex-M0+
# target = "thumbv7m-none-eabi"    # Cortex-M3
# target = "thumbv7em-none-eabi"   # Cortex-M4 and Cortex-M7 (no FPU)
target = "thumbv7em-none-eabihf" # Cortex-M4F and Cortex-M7F (with FPU)
```

여기서는 Cortex-M4F 코어를 포함하는 `thumbv7em-none-eabihf`를 사용합니다.

> **참고** 이전 장에서 봤듯이 필요한 타깃은 직접 설치해야 하며, 이것은 새 타깃입니다.
> 따라서 `rustup target add thumbv7em-none-eabihf`로 이 타깃을 꼭 추가하세요.

두 번째 단계는 `memory.x` 파일에 메모리 영역 정보를 입력하는 것입니다.

```text
$ cat memory.x
/* Linker script for the STM32F303VCT6 */
MEMORY
{
  /* NOTE 1 K = 1 KiBi = 1024 bytes */
  FLASH : ORIGIN = 0x08000000, LENGTH = 256K
  RAM : ORIGIN = 0x20000000, LENGTH = 40K
}
```

> **참고** 특정 빌드 타깃에 대해 첫 빌드를 수행한 뒤 `memory.x`를 변경했다면,
> `cargo build` 전에 `cargo clean`을 실행하세요. `cargo build`가 `memory.x`의 변경을
> 제대로 추적하지 못할 수 있습니다.

다시 hello 예제로 시작하되, 먼저 작은 변경 하나를 해야 합니다.

`examples/hello.rs`에서 `debug::exit()` 호출이 주석 처리되어 있거나 제거되어 있는지 확인하세요.
이 코드는 QEMU에서 실행할 때만 사용합니다.

```rust,ignore
#[entry]
fn main() -> ! {
    hprintln!("Hello, world!").unwrap();

    // exit QEMU
    // NOTE do not run this on hardware; it can corrupt OpenOCD state
    // debug::exit(debug::EXIT_SUCCESS);

    loop {}
}
```

이제 이전과 마찬가지로 `cargo build`로 프로그램을 크로스 컴파일하고,
`cargo-binutils`로 바이너리를 살펴볼 수 있습니다. `cortex-m-rt` crate가 칩을 구동하기 위해
필요한 대부분의 초기화 작업을 처리해 주며, 다행히도 거의 모든 Cortex-M CPU는 비슷한 방식으로 부팅합니다.

```console
cargo build --example hello
```

## 디버깅

디버깅 절차는 조금 달라집니다. 사실 처음 단계는 타깃 장치에 따라 달라질 수도 있습니다.
이 섹션에서는 STM32F3DISCOVERY에서 실행 중인 프로그램을 디버깅하는 절차를 보여 줍니다.
이 내용은 참고용이며, 장치별 디버깅 정보는 [Debugonomicon](https://github.com/rust-embedded/debugonomicon)을 참고하세요.

이전과 마찬가지로 원격 디버깅을 사용하고, 클라이언트는 GDB 프로세스입니다.
이번에는 서버 역할을 OpenOCD가 맡습니다.

[verify]: ../intro/install/verify.md

[verify] 섹션에서 했던 것처럼 discovery 보드를 노트북이나 PC에 연결하고,
ST-LINK 헤더가 인식되는지 확인하세요.

터미널에서 `openocd`를 실행해 discovery 보드의 ST-LINK에 연결합니다.
이 명령은 템플릿 루트에서 실행하세요. `openocd`는 어떤 인터페이스 파일과 타깃 파일을 사용할지
지정하는 `openocd.cfg`를 자동으로 읽습니다.

```console
cat openocd.cfg
```

```text
# Sample OpenOCD configuration for the STM32F3DISCOVERY development board

# Depending on the hardware revision you got you'll have to pick ONE of these
# interfaces. At any time only one interface should be commented out.

# Revision C (newer revision)
source [find interface/stlink.cfg]

# Revision A and B (older revisions)
# source [find interface/stlink-v2.cfg]

source [find target/stm32f3x.cfg]
```

> **참고** [verify] 섹션에서 여러분의 discovery 보드가 구형 리비전이라는 것을 확인했다면,
> 이 시점에서 `openocd.cfg`를 수정해 `interface/stlink-v2.cfg`를 사용하도록 바꿔야 합니다.

```text
$ openocd
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
Info : Target voltage: 2.913879
Info : stm32f3x.cpu: hardware has 6 breakpoints, 4 watchpoints
```

다른 터미널에서 GDB도 실행합니다. 이 역시 템플릿 루트에서 실행하세요.

```text
gdb-multiarch -q target/thumbv7em-none-eabihf/debug/examples/hello
```

**참고**: 이전과 마찬가지로 설치 장에서 어떤 GDB를 설치했는지에 따라 `gdb-multiarch` 대신
`arm-none-eabi-gdb` 또는 그냥 `gdb`를 사용해야 할 수도 있습니다.

다음으로 TCP 3333 포트에서 연결을 기다리는 OpenOCD에 GDB를 연결합니다.

```console
(gdb) target remote :3333
Remote debugging using :3333
0x00000000 in ?? ()
```

이제 `load` 명령으로 프로그램을 마이크로컨트롤러에 _플래시_(로드)합니다.

```console
(gdb) load
Loading section .vector_table, size 0x400 lma 0x8000000
Loading section .text, size 0x1518 lma 0x8000400
Loading section .rodata, size 0x414 lma 0x8001918
Start address 0x08000400, load size 7468
Transfer rate: 13 KB/sec, 2489 bytes/write.
```

이제 프로그램이 로드되었습니다. 이 프로그램은 세미호스팅을 사용하므로,
세미호스팅 호출을 하기 전에 OpenOCD에 세미호스팅을 활성화하라고 알려야 합니다.
`monitor` 명령으로 OpenOCD에 명령을 전달할 수 있습니다.

```console
(gdb) monitor arm semihosting enable
semihosting is enabled
```

> `monitor help` 명령을 사용하면 OpenOCD의 모든 명령을 확인할 수 있습니다.

이전과 마찬가지로 브레이크포인트와 `continue` 명령을 사용해 `main`까지 바로 이동할 수 있습니다.

```console
(gdb) break main
Breakpoint 1 at 0x8000490: file examples/hello.rs, line 11.
Note: automatically using hardware breakpoints for read-only addresses.

(gdb) continue
Continuing.

Breakpoint 1, hello::__cortex_m_rt_main_trampoline () at examples/hello.rs:11
11      #[entry]
```

> **참고** 위의 `continue` 명령을 실행한 뒤 GDB가 브레이크포인트에 걸리지 않고 터미널을 점유한 채 멈춘다면,
> `memory.x` 파일의 메모리 영역 정보가 장치에 맞게 올바르게 설정되어 있는지 다시 확인하세요.
> 시작 주소와 길이 둘 다 중요합니다.

`step`으로 main 함수 안으로 들어갑니다.

```console
(gdb) step
halted: PC: 0x08000496
hello::__cortex_m_rt_main () at examples/hello.rs:13
13          hprintln!("Hello, world!").unwrap();
```

`next`로 프로그램을 진행시키면, 다른 로그와 함께 OpenOCD 콘솔에 "Hello, world!"가 출력되어야 합니다.

```console
$ openocd
(..)
Info : halted: PC: 0x08000502
Hello, world!
Info : halted: PC: 0x080004ac
Info : halted: PC: 0x080004ae
Info : halted: PC: 0x080004b0
Info : halted: PC: 0x080004b4
Info : halted: PC: 0x080004b8
Info : halted: PC: 0x080004bc
```

이 메시지는 한 번만 출력됩니다. 프로그램이 19번째 줄의 무한 루프 `loop {}`로 진입하기 직전이기 때문입니다.

이제 `quit` 명령으로 GDB를 종료할 수 있습니다.

```console
(gdb) quit
A debugging session is active.

        Inferior 1 [Remote target] will be detached.

Quit anyway? (y or n)
```

이제 디버깅 단계가 조금 더 많아졌으므로, 이 과정을 `openocd.gdb`라는 하나의 GDB 스크립트로 묶어 두었습니다.
이 파일은 `cargo generate` 단계에서 생성되며, 보통 수정 없이 그대로 동작합니다. 내용을 살펴봅시다.

```console
cat openocd.gdb
```

```text
target extended-remote :3333

# print demangled symbols
set print asm-demangle on

# detect unhandled exceptions, hard faults and panics
break DefaultHandler
break HardFault
break rust_begin_unwind

monitor arm semihosting enable

load

# start the process but immediately halt the processor
stepi
```

이제 `<gdb> -x openocd.gdb target/thumbv7em-none-eabihf/debug/examples/hello`를 실행하면
GDB가 즉시 OpenOCD에 연결되고, 세미호스팅을 활성화하고, 프로그램을 로드하고, 실행을 시작합니다.

또는 `<gdb> -x openocd.gdb`를 커스텀 runner로 등록해 `cargo run`이 프로그램을 빌드하는 동시에
GDB 세션도 시작하게 만들 수 있습니다. 이 runner는 `.cargo/config.toml`에 이미 들어 있지만 주석 처리되어 있습니다.

```console
head -n10 .cargo/config.toml
```

```toml
[target.thumbv7m-none-eabi]
# uncomment this to make `cargo run` execute programs on QEMU
# runner = "qemu-system-arm -cpu cortex-m3 -machine lm3s6965evb -nographic -semihosting-config enable=on,target=native -kernel"

[target.'cfg(all(target_arch = "arm", target_os = "none"))']
# uncomment ONE of these three option to make `cargo run` start a GDB session
# which option to pick depends on your system
runner = "arm-none-eabi-gdb -x openocd.gdb"
# runner = "gdb-multiarch -x openocd.gdb"
# runner = "gdb -x openocd.gdb"
```

```text
$ cargo run --example hello
(..)
Loading section .vector_table, size 0x400 lma 0x8000000
Loading section .text, size 0x1e70 lma 0x8000400
Loading section .rodata, size 0x61c lma 0x8002270
Start address 0x800144e, load size 10380
Transfer rate: 17 KB/sec, 3460 bytes/write.
(gdb)
```

```text
$ cat memory.x
/* Linker script for the STM32F303VCT6 */
MEMORY
{
  /* NOTE 1 K = 1 KiBi = 1024 bytes */
  FLASH : ORIGIN = 0x08000000, LENGTH = 256K
  RAM : ORIGIN = 0x20000000, LENGTH = 40K
}
```

> **NOTE**: If you for some reason changed the `memory.x` file after you had made
> the first build of a specific build target, then do `cargo clean` before
> `cargo build`, because `cargo build` may not track updates of `memory.x`.

We'll start with the hello example again, but first we have to make a small
change.

In `examples/hello.rs`, make sure the `debug::exit()` call is commented out or
removed. It is used only for running in QEMU.

```rust,ignore
#[entry]
fn main() -> ! {
    hprintln!("Hello, world!").unwrap();

    // exit QEMU
    // NOTE do not run this on hardware; it can corrupt OpenOCD state
    // debug::exit(debug::EXIT_SUCCESS);

    loop {}
}
```

You can now cross compile programs using `cargo build`
and inspect the binaries using `cargo-binutils` as you did before. The
`cortex-m-rt` crate handles all the magic required to get your chip running,
as helpfully, pretty much all Cortex-M CPUs boot in the same fashion.

```console
cargo build --example hello
```

## Debugging

Debugging will look a bit different. In fact, the first steps can look different
depending on the target device. In this section we'll show the steps required to
debug a program running on the STM32F3DISCOVERY. This is meant to serve as a
reference; for device specific information about debugging check out [the
Debugonomicon](https://github.com/rust-embedded/debugonomicon).

As before we'll do remote debugging and the client will be a GDB process. This
time, however, the server will be OpenOCD.

As done during the [verify] section connect the discovery board to your laptop /
PC and check that the ST-LINK header is populated.

[verify]: ../intro/install/verify.md

On a terminal run `openocd` to connect to the ST-LINK on the discovery board.
Run this command from the root of the template; `openocd` will pick up the
`openocd.cfg` file which indicates which interface file and target file to use.

```console
cat openocd.cfg
```

```text
# Sample OpenOCD configuration for the STM32F3DISCOVERY development board

# Depending on the hardware revision you got you'll have to pick ONE of these
# interfaces. At any time only one interface should be commented out.

# Revision C (newer revision)
source [find interface/stlink.cfg]

# Revision A and B (older revisions)
# source [find interface/stlink-v2.cfg]

source [find target/stm32f3x.cfg]
```

> **NOTE** If you found out that you have an older revision of the discovery
> board during the [verify] section then you should modify the `openocd.cfg`
> file at this point to use `interface/stlink-v2.cfg`.

```text
$ openocd
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
Info : Target voltage: 2.913879
Info : stm32f3x.cpu: hardware has 6 breakpoints, 4 watchpoints
```

On another terminal run GDB, also from the root of the template.

```text
gdb-multiarch -q target/thumbv7em-none-eabihf/debug/examples/hello
```

**NOTE**: like before you might need another version of gdb instead of `gdb-multiarch` depending
on which one you installed in the installation chapter. This could also be
`arm-none-eabi-gdb` or just `gdb`.

Next connect GDB to OpenOCD, which is waiting for a TCP connection on port 3333.

```console
(gdb) target remote :3333
Remote debugging using :3333
0x00000000 in ?? ()
```

Now proceed to _flash_ (load) the program onto the microcontroller using the
`load` command.

```console
(gdb) load
Loading section .vector_table, size 0x400 lma 0x8000000
Loading section .text, size 0x1518 lma 0x8000400
Loading section .rodata, size 0x414 lma 0x8001918
Start address 0x08000400, load size 7468
Transfer rate: 13 KB/sec, 2489 bytes/write.
```

The program is now loaded. This program uses semihosting so before we do any
semihosting call we have to tell OpenOCD to enable semihosting. You can send
commands to OpenOCD using the `monitor` command.

```console
(gdb) monitor arm semihosting enable
semihosting is enabled
```

> You can see all the OpenOCD commands by invoking the `monitor help` command.

Like before we can skip all the way to `main` using a breakpoint and the
`continue` command.

```console
(gdb) break main
Breakpoint 1 at 0x8000490: file examples/hello.rs, line 11.
Note: automatically using hardware breakpoints for read-only addresses.

(gdb) continue
Continuing.

Breakpoint 1, hello::__cortex_m_rt_main_trampoline () at examples/hello.rs:11
11      #[entry]
```

> **NOTE** If GDB blocks the terminal instead of hitting the breakpoint after
> you issue the `continue` command above, you might want to double check that
> the memory region information in the `memory.x` file is correctly set up
> for your device (both the starts _and_ lengths).

Step into the main function with `step`.

```console
(gdb) step
halted: PC: 0x08000496
hello::__cortex_m_rt_main () at examples/hello.rs:13
13          hprintln!("Hello, world!").unwrap();
```

After advancing the program with `next` you should see "Hello, world!" printed on the OpenOCD console,
among other stuff.

```console
$ openocd
(..)
Info : halted: PC: 0x08000502
Hello, world!
Info : halted: PC: 0x080004ac
Info : halted: PC: 0x080004ae
Info : halted: PC: 0x080004b0
Info : halted: PC: 0x080004b4
Info : halted: PC: 0x080004b8
Info : halted: PC: 0x080004bc
```

The message is only displayed once as the program is about to enter the infinite loop defined in line 19: `loop {}`

You can now exit GDB using the `quit` command.

```console
(gdb) quit
A debugging session is active.

        Inferior 1 [Remote target] will be detached.

Quit anyway? (y or n)
```

Debugging now requires a few more steps so we have packed all those steps into a
single GDB script named `openocd.gdb`. The file was created during the `cargo generate` step, and should work without any modifications. Let's have a peek:

```console
cat openocd.gdb
```

```text
target extended-remote :3333

# print demangled symbols
set print asm-demangle on

# detect unhandled exceptions, hard faults and panics
break DefaultHandler
break HardFault
break rust_begin_unwind

monitor arm semihosting enable

load

# start the process but immediately halt the processor
stepi
```

Now running `<gdb> -x openocd.gdb target/thumbv7em-none-eabihf/debug/examples/hello` will immediately connect GDB to
OpenOCD, enable semihosting, load the program and start the process.

Alternatively, you can turn `<gdb> -x openocd.gdb` into a custom runner to make
`cargo run` build a program _and_ start a GDB session. This runner is included
in `.cargo/config.toml` but it's commented out.

```console
head -n10 .cargo/config.toml
```

```toml
[target.thumbv7m-none-eabi]
# uncomment this to make `cargo run` execute programs on QEMU
# runner = "qemu-system-arm -cpu cortex-m3 -machine lm3s6965evb -nographic -semihosting-config enable=on,target=native -kernel"

[target.'cfg(all(target_arch = "arm", target_os = "none"))']
# uncomment ONE of these three option to make `cargo run` start a GDB session
# which option to pick depends on your system
runner = "arm-none-eabi-gdb -x openocd.gdb"
# runner = "gdb-multiarch -x openocd.gdb"
# runner = "gdb -x openocd.gdb"
```

```text
$ cargo run --example hello
(..)
Loading section .vector_table, size 0x400 lma 0x8000000
Loading section .text, size 0x1e70 lma 0x8000400
Loading section .rodata, size 0x61c lma 0x8002270
Start address 0x800144e, load size 10380
Transfer rate: 17 KB/sec, 3460 bytes/write.
(gdb)
```
