# QEMU

We'll start writing a program for the [LM3S6965], a Cortex-M3 microcontroller.
We have chosen this as our initial target because it [can be emulated](https://wiki.qemu.org/Documentation/Platforms/ARM#Supported_in_qemu-system-arm) using QEMU
so you don't need to fiddle with hardware in this section and we can focus on
the tooling and the development process.

[LM3S6965]: http://www.ti.com/product/LM3S6965

**IMPORTANT**
We'll use the name "app" for the project name in this tutorial.
Whenever you see the word "app" you should replace it with the name you selected
for your project. Or, you could also name your project "app" and avoid the
substitutions.

## Creating a non standard Rust program

We'll use the [`cortex-m-quickstart`] project template to generate a new
project from it. The created project will contain a barebone application: a good
starting point for a new embedded rust application. In addition, the project will
contain an `examples` directory, with several separate applications, highlighting
some of the key embedded rust functionality.

[`cortex-m-quickstart`]: https://github.com/rust-embedded/cortex-m-quickstart

### Using `cargo-generate`

First install cargo-generate

```console
cargo install cargo-generate
```

Then generate a new project

```console
cargo generate --git https://github.com/knurling-rs/app-template
```

```text
 Project Name: app
 Creating project called `app`...
 Done! New project created /tmp/app
```

```console
cd app
```

### Using `git`

Clone the repository

```console
git clone https://github.com/rust-embedded/cortex-m-quickstart app
cd app
```

And then fill in the placeholders in the `Cargo.toml` file

```toml
[package]
authors = ["{{authors}}"] # "{{authors}}" -> "John Smith"
edition = "2018"
name = "{{project-name}}" # "{{project-name}}" -> "app"
version = "0.1.0"

# ..

[[bin]]
name = "{{project-name}}" # "{{project-name}}" -> "app"
test = false
bench = false
```

### Using neither

Grab the latest snapshot of the `cortex-m-quickstart` template and extract it.

```console
curl -LO https://github.com/rust-embedded/cortex-m-quickstart/archive/master.zip
unzip master.zip
mv cortex-m-quickstart-master app
cd app
```

Or you can browse to [`cortex-m-quickstart`], click the green "Clone or
download" button and then click "Download ZIP".

Then fill in the placeholders in the `Cargo.toml` file as done in the second
part of the "Using `git`" version.

## Program Overview

For convenience here are the most important parts of the source code in `src/main.rs`:

```rust,ignore
#![no_std]
#![no_main]

use panic_halt as _;

use cortex_m_rt::entry;

#[entry]
fn main() -> ! {
    loop {
        // your code goes here
    }
}
```

This program is a bit different from a standard Rust program so let's take a
closer look.

`#![no_std]` indicates that this program will _not_ link to the standard crate,
`std`. Instead it will link to its subset: the `core` crate.

`#![no_main]` indicates that this program won't use the standard `main`
interface that most Rust programs use. The main (no pun intended) reason to go
with `no_main` is that using the `main` interface in `no_std` context requires
nightly.

`use panic_halt as _;`. This crate provides a `panic_handler` that defines
the panicking behavior of the program. We will cover this in more detail in the
[Panicking](panicking.md) chapter of the book.

[`#[entry]`][entry] is an attribute provided by the [`cortex-m-rt`] crate that's used
to mark the entry point of the program. As we are not using the standard `main`
interface we need another way to indicate the entry point of the program and
that'd be `#[entry]`.

[entry]: https://docs.rs/cortex-m-rt-macros/latest/cortex_m_rt_macros/attr.entry.html
[`cortex-m-rt`]: https://crates.io/crates/cortex-m-rt

`fn main() -> !`. Our program will be the _only_ process running on the target
hardware so we don't want it to end! We use a [divergent function](https://doc.rust-lang.org/rust-by-example/fn/diverging.html) (the `-> !`
bit in the function signature) to ensure at compile time that'll be the case.

## Cross compiling

First of all we will need the memory layout for the target microcontroller, the
LM3S6965 in our case. Otherwise the build will fail to link the image. Create a
file named `memory.x` at the root of the project and paste the following content:

```text
MEMORY
{
  /* NOTE 1 K = 1 KiBi = 1024 bytes */
  /* TODO Adjust these memory regions to match your device memory layout */
  /* These values correspond to the LM3S6965, one of the few devices QEMU can emulate */
  FLASH : ORIGIN = 0x00000000, LENGTH = 256K
  RAM : ORIGIN = 0x20000000, LENGTH = 64K
}

/* This is where the call stack will be allocated. */
/* The stack is of the full descending type. */
/* You may want to use this variable to locate the call stack and static
   variables in different memory regions. Below is shown the default value */
/* _stack_start = ORIGIN(RAM) + LENGTH(RAM); */

/* You can use this symbol to customize the location of the .text section */
/* If omitted the .text section will be placed right after the .vector_table
   section */
/* This is required only on microcontrollers that store some configuration right
   after the vector table */
/* _stext = ORIGIN(FLASH) + 0x400; */

/* Example of putting non-initialized variables into custom RAM locations. */
/* This assumes you have defined a region RAM2 above, and in the Rust
   sources added the attribute `#[link_section = ".ram2bss"]` to the data
   you want to place there. */
/* Note that the section will not be zero-initialized by the runtime! */
/* SECTIONS {
     .ram2bss (NOLOAD) : ALIGN(4) {
       *(.ram2bss);
       . = ALIGN(4);
     } > RAM2
   } INSERT AFTER .bss;
*/
```

The next step is to _cross_ compile the program for the Cortex-M3 architecture.
That's as simple as running `cargo build --target $TRIPLE` if you know what the
compilation target (`$TRIPLE`) should be. Luckily, the `.cargo/config.toml` in the
template has the answer:

```console
tail -n6 .cargo/config.toml
```

```toml
[build]
# Pick ONE of these compilation targets
# target = "thumbv6m-none-eabi"    # Cortex-M0 and Cortex-M0+
target = "thumbv7m-none-eabi"    # Cortex-M3
# target = "thumbv7em-none-eabi"   # Cortex-M4 and Cortex-M7 (no FPU)
# target = "thumbv7em-none-eabihf" # Cortex-M4F and Cortex-M7F (with FPU)
```

To cross compile for the Cortex-M3 architecture we have to use
`thumbv7m-none-eabi`. That target is not automatically installed when installing
the Rust toolchain, it would now be a good time to add that target to the toolchain,
if you haven't done it yet:

```console
rustup target add thumbv7m-none-eabi
```

Since the `thumbv7m-none-eabi` compilation target has been set as the default in
your `.cargo/config.toml` file, the two commands below do the same:

```console
cargo build --target thumbv7m-none-eabi
cargo build
```

## Inspecting

Now we have a non-native ELF binary in `target/thumbv7m-none-eabi/debug/app`. We
can inspect it using `cargo-binutils`.

With `cargo-readobj` we can print the ELF headers to confirm that this is an ARM
binary.

```console
cargo readobj --bin app -- --file-headers
```

Note that:

# QEMU

이제 Cortex-M3 마이크로컨트롤러인 [LM3S6965]용 프로그램을 작성해 보겠습니다.
이 장의 첫 타깃으로 이 칩을 고른 이유는 QEMU로 [에뮬레이션할 수 있기](https://wiki.qemu.org/Documentation/Platforms/ARM#Supported_in_qemu-system-arm)
때문입니다. 덕분에 이 섹션에서는 실제 하드웨어를 만지지 않고도 도구 체인과 개발 과정에 집중할 수 있습니다.

[LM3S6965]: http://www.ti.com/product/LM3S6965

**중요**
이 튜토리얼에서는 프로젝트 이름으로 "app"을 사용합니다.
문서에서 "app"이라는 단어가 나오면, 여러분이 선택한 프로젝트 이름으로 바꿔 읽으면 됩니다.
혹은 실제 프로젝트 이름을 그냥 "app"으로 정해도 됩니다.

## 비표준 Rust 프로그램 만들기

새 프로젝트를 만들기 위해 [`cortex-m-quickstart`] 프로젝트 템플릿을 사용하겠습니다.
생성된 프로젝트에는 최소한의 애플리케이션이 포함되며, 이는 새로운 임베디드 Rust 애플리케이션의
좋은 출발점이 됩니다. 또한 `examples` 디렉터리도 포함되어, 임베디드 Rust의 핵심 기능을 보여 주는
여러 개의 독립 예제가 함께 제공됩니다.

[`cortex-m-quickstart`]: https://github.com/rust-embedded/cortex-m-quickstart

### `cargo-generate` 사용하기

먼저 cargo-generate를 설치합니다.

```console
cargo install cargo-generate
```

그다음 새 프로젝트를 생성합니다.

```console
cargo generate --git https://github.com/knurling-rs/app-template
```

```text
 Project Name: app
 Creating project called `app`...
 Done! New project created /tmp/app
```

```console
cd app
```

### `git` 사용하기

저장소를 클론합니다.

```console
git clone https://github.com/rust-embedded/cortex-m-quickstart app
cd app
```

그다음 `Cargo.toml` 파일의 플레이스홀더를 채웁니다.

```toml
[package]
authors = ["{{authors}}"] # "{{authors}}" -> "John Smith"
edition = "2018"
name = "{{project-name}}" # "{{project-name}}" -> "app"
version = "0.1.0"

# ..

[[bin]]
name = "{{project-name}}" # "{{project-name}}" -> "app"
test = false
bench = false
```

### 둘 다 사용하지 않는 방법

`cortex-m-quickstart` 템플릿의 최신 스냅샷을 내려받아 압축을 풉니다.

```console
curl -LO https://github.com/rust-embedded/cortex-m-quickstart/archive/master.zip
unzip master.zip
mv cortex-m-quickstart-master app
cd app
```

또는 [`cortex-m-quickstart`] 페이지로 이동해 초록색 "Clone or
download" 버튼을 누르고 "Download ZIP"을 선택해도 됩니다.

그런 다음 "`git` 사용하기" 절의 두 번째 부분에서 했던 것처럼 `Cargo.toml`
파일의 플레이스홀더를 채웁니다.

## 프로그램 개요

편의를 위해 `src/main.rs`의 핵심 부분만 먼저 보면 다음과 같습니다.

```rust,ignore
#![no_std]
#![no_main]

use panic_halt as _;

use cortex_m_rt::entry;

#[entry]
fn main() -> ! {
    loop {
        // your code goes here
    }
}
```

이 프로그램은 일반적인 Rust 프로그램과 조금 다르므로, 하나씩 살펴보겠습니다.

`#![no_std]`는 이 프로그램이 표준 crate인 `std`에 링크되지 않는다는 뜻입니다.
대신 그 부분집합인 `core` crate에 링크됩니다.

`#![no_main]`는 이 프로그램이 대부분의 Rust 프로그램이 사용하는 표준 `main`
인터페이스를 사용하지 않는다는 뜻입니다. `no_main`을 쓰는 주된 이유는 `no_std`
환경에서 표준 `main` 인터페이스를 사용하려면 nightly가 필요하기 때문입니다.

`use panic_halt as _;`는 프로그램의 panic 동작을 정의하는 `panic_handler`를 제공하는
crate를 가져옵니다. 이 부분은 [Panicking](panicking.md) 장에서 더 자세히 다룹니다.

[`#[entry]`][entry]는 [`cortex-m-rt`] crate가 제공하는 속성으로, 프로그램의 진입점을
표시할 때 사용합니다. 표준 `main` 인터페이스를 사용하지 않으므로, 프로그램의 시작점을
나타내는 다른 수단이 필요하고 그것이 바로 `#[entry]`입니다.

[entry]: https://docs.rs/cortex-m-rt-macros/latest/cortex_m_rt_macros/attr.entry.html
[`cortex-m-rt`]: https://crates.io/crates/cortex-m-rt

`fn main() -> !`에서 우리의 프로그램은 타깃 하드웨어 위에서 실행되는 _유일한_ 프로세스이므로
끝나면 안 됩니다. 이를 컴파일 타임에 보장하기 위해 [divergent function](https://doc.rust-lang.org/rust-by-example/fn/diverging.html)
(`-> !` 반환형)을 사용합니다.

## 크로스 컴파일

우선 타깃 마이크로컨트롤러, 여기서는 LM3S6965의 메모리 레이아웃이 필요합니다.
이 정보가 없으면 빌드 시 링크에 실패합니다. 프로젝트 루트에 `memory.x` 파일을 만들고
다음 내용을 붙여 넣으세요.

```text
MEMORY
{
  /* NOTE 1 K = 1 KiBi = 1024 bytes */
  /* TODO Adjust these memory regions to match your device memory layout */
  /* These values correspond to the LM3S6965, one of the few devices QEMU can emulate */
  FLASH : ORIGIN = 0x00000000, LENGTH = 256K
  RAM : ORIGIN = 0x20000000, LENGTH = 64K
}

/* This is where the call stack will be allocated. */
/* The stack is of the full descending type. */
/* You may want to use this variable to locate the call stack and static
   variables in different memory regions. Below is shown the default value */
/* _stack_start = ORIGIN(RAM) + LENGTH(RAM); */

/* You can use this symbol to customize the location of the .text section */
/* If omitted the .text section will be placed right after the .vector_table
   section */
/* This is required only on microcontrollers that store some configuration right
   after the vector table */
/* _stext = ORIGIN(FLASH) + 0x400; */

/* Example of putting non-initialized variables into custom RAM locations. */
/* This assumes you have defined a region RAM2 above, and in the Rust
   sources added the attribute `#[link_section = ".ram2bss"]` to the data
   you want to place there. */
/* Note that the section will not be zero-initialized by the runtime! */
/* SECTIONS {
     .ram2bss (NOLOAD) : ALIGN(4) {
       *(.ram2bss);
       . = ALIGN(4);
     } > RAM2
   } INSERT AFTER .bss;
*/
```

다음 단계는 이 프로그램을 Cortex-M3 아키텍처용으로 _크로스_ 컴파일하는 것입니다.
컴파일 타깃(`$TRIPLE`)만 알고 있다면 `cargo build --target $TRIPLE`을 실행하면 됩니다.
다행히 템플릿의 `.cargo/config.toml`에 답이 들어 있습니다.

```console
tail -n6 .cargo/config.toml
```

```toml
[build]
# Pick ONE of these compilation targets
# target = "thumbv6m-none-eabi"    # Cortex-M0 and Cortex-M0+
target = "thumbv7m-none-eabi"    # Cortex-M3
# target = "thumbv7em-none-eabi"   # Cortex-M4 and Cortex-M7 (no FPU)
# target = "thumbv7em-none-eabihf" # Cortex-M4F and Cortex-M7F (with FPU)
```

Cortex-M3용으로 크로스 컴파일하려면 `thumbv7m-none-eabi`를 사용해야 합니다.
이 타깃은 Rust 툴체인 설치 시 자동으로 추가되지 않으므로, 아직 설치하지 않았다면
지금 추가하는 것이 좋습니다.

```console
rustup target add thumbv7m-none-eabi
```

`thumbv7m-none-eabi`가 `.cargo/config.toml`에서 기본 타깃으로 설정되어 있으므로,
아래 두 명령은 같은 의미입니다.

```console
cargo build --target thumbv7m-none-eabi
cargo build
```

## 바이너리 살펴보기

이제 `target/thumbv7m-none-eabi/debug/app`에 네이티브가 아닌 ELF 바이너리가 생겼습니다.
`cargo-binutils`를 사용해 내용을 확인할 수 있습니다.

`cargo-readobj`를 사용하면 ELF 헤더를 출력하여 이 바이너리가 ARM용임을 확인할 수 있습니다.

```console
cargo readobj --bin app -- --file-headers
```

참고:

- `--bin app`은 `target/$TRIPLE/debug/app` 바이너리를 검사하는 축약형입니다.
- `--bin app`은 필요하다면 바이너리를 자동으로 다시 컴파일합니다.

```text
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF32
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0x0
  Type:                              EXEC (Executable file)
  Machine:                           ARM
  Version:                           0x1
  Entry point address:               0x405
  Start of program headers:          52 (bytes into file)
  Start of section headers:          153204 (bytes into file)
  Flags:                             0x5000200
  Size of this header:               52 (bytes)
  Size of program headers:           32 (bytes)
  Number of program headers:         2
  Size of section headers:           40 (bytes)
  Number of section headers:         19
  Section header string table index: 18
```

`cargo-size`를 사용하면 바이너리의 각 링커 섹션 크기를 출력할 수 있습니다.

```console
cargo size --bin app --release -- -A
```

여기서는 최적화된 버전을 보기 위해 `--release`를 사용합니다.

```text
app  :
section             size        addr
.vector_table       1024         0x0
.text                 92       0x400
.rodata                0       0x45c
.data                  0  0x20000000
.bss                   0  0x20000000
.debug_str          2958         0x0
.debug_loc            19         0x0
.debug_abbrev        567         0x0
.debug_info         4929         0x0
.debug_ranges         40         0x0
.debug_macinfo         1         0x0
.debug_pubnames     2035         0x0
.debug_pubtypes     1892         0x0
.ARM.attributes       46         0x0
.debug_frame         100         0x0
.debug_line          867         0x0
Total              14570
```

> ELF 링커 섹션 다시 보기
>
> - `.text`에는 프로그램 명령어가 들어 있습니다.
> - `.rodata`에는 문자열 같은 상수 값이 들어 있습니다.
> - `.data`에는 초기값이 0이 _아닌_ 정적 할당 변수가 들어 있습니다.
> - `.bss`에는 초기값이 0인 정적 할당 변수가 들어 있습니다.
> - `.vector_table`은 벡터(인터럽트) 테이블을 저장하기 위해 사용하는 _비표준_ 섹션입니다.
> - `.ARM.attributes`와 `.debug_*` 섹션에는 메타데이터가 들어 있으며, 바이너리를 플래시할 때 타깃에 로드되지 않습니다.

**중요**: ELF 파일에는 디버그 정보 같은 메타데이터가 포함되므로, *디스크 상의 크기*는
기기에 플래시되었을 때 실제 차지하는 공간을 정확히 반영하지 않습니다. 바이너리의 진짜 크기는
항상 `cargo-size`로 확인하세요.

`cargo-objdump`를 사용하면 바이너리를 디스어셈블할 수 있습니다.

```console
cargo objdump --bin app --release -- --disassemble --no-show-raw-insn --print-imm-hex
```

> **참고** 위 명령이 `Unknown command line argument` 오류를 내면 다음 이슈를 참고하세요. https://github.com/rust-embedded/book/issues/269

> **참고** 이 출력은 시스템에 따라 다를 수 있습니다. rustc, LLVM, 라이브러리 버전이 다르면 어셈블리 결과도 달라질 수 있습니다. 예제는 짧게 유지하기 위해 일부 명령만 남겼습니다.

```text
app:  file format ELF32-arm-little

Disassembly of section .text:
main:
     400: bl  #0x256
     404: b #-0x4 <main+0x4>

Reset:
     406: bl  #0x24e
     40a: movw  r0, #0x0
     < .. truncated any more instructions .. >

DefaultHandler_:
     656: b #-0x4 <DefaultHandler_>

UsageFault:
     657: strb  r7, [r4, #0x3]

DefaultPreInit:
     658: bx  lr

__pre_init:
     659: strb  r7, [r0, #0x1]

__nop:
     65a: bx  lr

HardFaultTrampoline:
     65c: mrs r0, msp
     660: b #-0x2 <HardFault_>

HardFault_:
     662: b #-0x4 <HardFault_>

HardFault:
     663: <unknown>
```

## 실행하기

이제 QEMU에서 임베디드 프로그램을 실행하는 방법을 보겠습니다. 이번에는 실제로 동작하는
`hello` 예제를 사용합니다. 기본적으로 이 예제는 `[defmt]`와 RTT를 사용해 텍스트를 출력합니다.

[defmt]: https://defmt.ferrous-systems.com/

> **참고** `defmt`는 임베디드 Rust 생태계에서 널리 쓰이는 서드파티(즉 non-core) 의존성입니다.

호스트에서 `defmt`가 만들어 내는 메시지를 읽고 디코드하려면 RTT 출력 전송을 semihosting으로
바꿔야 합니다. 실제 하드웨어에서는 이 작업에 디버그 세션이 필요하지만, QEMU에서는 바로 동작합니다.

의존성을 바꿔 봅시다.

```console
cargo remove defmt-rtt
cargo add defmt-semihosting
```

`src/lib.rs`를 열고 `use defmt_rtt as _;`를 `use defmt_semihosting as _;`로 바꾸세요.

이제 예제를 빌드할 수 있습니다.

```console
cargo build --bin hello
```

출력 바이너리는 다음 위치에 생성됩니다.
`target/thumbv7m-none-eabi/debug/hello`.

이 바이너리를 QEMU에서 실행할 때는 보통 아래 명령이면 충분합니다.

```console
qemu-system-arm \
  -cpu cortex-m3 \
  -machine lm3s6965evb \
  -nographic \
  -semihosting-config enable=on,target=native \
  -kernel target/thumbv7m-none-eabi/debug/hello
```

하지만 여기서는 `defmt`를 사용하므로 호스트가 출력을 그대로 디코드할 수 없습니다.
대신 Ferrous Systems가 만든 [`qemu-run`] 도구를 사용해야 합니다.

[`qemu-run`]: https://github.com/knurling-rs/defmt/tree/main/qemu-run/

```console
git clone git@github.com:knurling-rs/defmt.git
cd defmt/qemu-run/
cargo run -- --machine lm3s6965evb ../qemu-rs/target/thumbv7m-none-eabi/debug/hello
```

```text
Hello, world!
```

이 명령은 텍스트를 출력한 뒤 성공적으로 종료되어야 합니다(종료 코드 = 0).
\*nix에서는 아래 명령으로 확인할 수 있습니다.

```console
echo $?
```

```text
0
```

이제 QEMU 명령을 하나씩 뜯어보겠습니다.

- `qemu-system-arm`. QEMU 에뮬레이터입니다. QEMU 바이너리는 여러 변형이 있는데,
  이것은 _ARM_ 머신의 전체 _시스템_ 에뮬레이션을 수행합니다.

- `-cpu cortex-m3`. QEMU에 Cortex-M3 CPU를 에뮬레이션하라고 지시합니다.
  CPU 모델을 명시하면 일부 잘못된 컴파일을 잡아낼 수 있습니다. 예를 들어 하드웨어 FPU가 있는
  Cortex-M4F용으로 컴파일한 프로그램을 실행하면 QEMU가 실행 중 오류를 냅니다.

- `-machine lm3s6965evb`. LM3S6965 마이크로컨트롤러를 탑재한 LM3S6965EVB 평가 보드를
  에뮬레이션하라고 지시합니다.

- `-nographic`. GUI를 띄우지 않도록 합니다.

- `-semihosting-config (..)`. Semihosting을 활성화합니다. Semihosting을 사용하면 에뮬레이트된
  장치가 호스트의 stdout, stderr, stdin을 사용하거나 호스트에 파일을 만들 수 있습니다.

- `-kernel $file`. 에뮬레이트된 머신에서 어떤 바이너리를 로드하고 실행할지 지정합니다.

이 긴 QEMU 명령을 매번 직접 입력하는 것은 번거롭습니다. 과정을 단순하게 하려면 커스텀 runner를
설정하면 됩니다. `.cargo/config.toml`에는 QEMU를 호출하는 runner가 주석 처리되어 있으니,
이를 활성화해 봅시다.

```console
head -n3 .cargo/config.toml
```

```toml
[target.thumbv7m-none-eabi]
# uncomment this to make `cargo run` execute programs on QEMU
runner = "qemu-system-arm -cpu cortex-m3 -machine lm3s6965evb -nographic -semihosting-config enable=on,target=native -kernel"
```

이 runner는 우리의 기본 컴파일 타깃인 `thumbv7m-none-eabi`에만 적용됩니다.
이제 `cargo run`은 프로그램을 컴파일하고 QEMU에서 바로 실행합니다.

```console
cargo run --example hello --release
```

```text
   Compiling app v0.1.0 (file:///tmp/app)
    Finished release [optimized + debuginfo] target(s) in 0.26s
     Running `qemu-system-arm -cpu cortex-m3 -machine lm3s6965evb -nographic -semihosting-config enable=on,target=native -kernel target/thumbv7m-none-eabi/release/examples/hello`
Hello, world!
```

## 디버깅

디버깅은 임베디드 개발에서 매우 중요합니다. 어떻게 하는지 살펴보겠습니다.

임베디드 장치 디버깅은 기본적으로 _원격_ 디버깅입니다. 디버그하려는 프로그램은
디버거(GDB 또는 LLDB)를 실행하는 머신이 아니라 타깃 장치에서 실행되기 때문입니다.

원격 디버깅은 클라이언트와 서버로 구성됩니다. QEMU 환경에서는 클라이언트가 GDB(또는 LLDB)
프로세스이고, 서버는 임베디드 프로그램도 함께 실행 중인 QEMU 프로세스입니다.

이 섹션에서는 앞에서 이미 컴파일한 `hello` 예제를 사용합니다.

첫 번째 단계는 QEMU를 디버깅 모드로 실행하는 것입니다.

```console
qemu-system-arm \
  -cpu cortex-m3 \
  -machine lm3s6965evb \
  -nographic \
  -semihosting-config enable=on,target=native \
  -gdb tcp::3333 \
  -S \
  -kernel target/thumbv7m-none-eabi/debug/examples/hello
```

이 명령은 콘솔에 아무것도 출력하지 않고 터미널을 점유한 채 대기합니다.
이번에는 두 개의 추가 플래그를 넘겼습니다.

- `-gdb tcp::3333`. TCP 3333 포트에서 GDB 연결을 기다리게 합니다.

- `-S`. 시작 직후 머신을 정지 상태로 둡니다. 이 옵션이 없으면 디버거를 띄우기도 전에
  프로그램이 main 끝까지 실행돼 버릴 수 있습니다.

다음으로 다른 터미널에서 GDB를 실행하고, 예제의 디버그 심볼을 로드하도록 합니다.

```console
gdb-multiarch -q target/thumbv7m-none-eabi/debug/examples/hello
```

**참고**: 설치 장에서 어떤 버전을 설치했는지에 따라 `gdb-multiarch` 대신 다른 GDB를 사용해야 할 수 있습니다.
예를 들어 `arm-none-eabi-gdb` 또는 그냥 `gdb`일 수도 있습니다.

이제 GDB 셸 안에서 TCP 3333 포트에서 대기 중인 QEMU에 연결합니다.

```console
target remote :3333
```

```text
Remote debugging using :3333
Reset () at $REGISTRY/cortex-m-rt-0.6.1/src/lib.rs:473
473     pub unsafe extern "C" fn Reset() -> ! {
```

프로세스가 멈춰 있고 프로그램 카운터가 `Reset`이라는 함수를 가리키는 것을 볼 수 있습니다.
이 함수는 reset handler이며, Cortex-M 코어가 부팅 시 가장 먼저 실행하는 코드입니다.

> 참고: 어떤 환경에서는 위와 같이 `Reset () at $REGISTRY/cortex-m-rt-0.6.1/src/lib.rs:473`가 보이는 대신 다음과 같은 경고가 출력될 수 있습니다.
>
> `core::num::bignum::Big32x40::mul_small () at src/libcore/num/bignum.rs:254`
> `    src/libcore/num/bignum.rs: No such file or directory.`
>
> 이는 알려진 현상입니다. 경고는 무시해도 되며, 대부분의 경우 현재 위치는 Reset()입니다.

이 reset handler는 결국 우리의 main 함수를 호출합니다. 브레이크포인트와 `continue` 명령으로
그 지점까지 이동해 보겠습니다. 먼저 `list` 명령으로 어디에 멈추고 싶은지 코드를 확인합니다.

```console
list main
```

그러면 `examples/hello.rs` 파일의 소스 코드가 표시됩니다.

```text
6       use panic_halt as _;
7
8       use cortex_m_rt::entry;
9       use cortex_m_semihosting::{debug, hprintln};
10
11      #[entry]
12      fn main() -> ! {
13          hprintln!("Hello, world!").unwrap();
14
15          // exit QEMU
```

우리는 "Hello, world!"가 출력되기 직전인 13번째 줄에 브레이크포인트를 걸고 싶습니다.
`break` 명령으로 설정합니다.

```console
break 13
```

이제 `continue` 명령으로 GDB가 main 함수 쪽으로 계속 실행하도록 합니다.

```console
continue
```

```text
Continuing.

Breakpoint 1, hello::__cortex_m_rt_main () at examples\hello.rs:13
13          hprintln!("Hello, world!").unwrap();
```

이제 "Hello, world!"를 출력하는 코드 바로 근처에 왔습니다. `next` 명령으로 한 단계 진행합니다.

```console
next
```

```text
16          debug::exit(debug::EXIT_SUCCESS);
```

이 시점에서 `qemu-system-arm`을 실행 중인 터미널에 "Hello, world!"가 출력되어야 합니다.

```text
$ qemu-system-arm (..)
Hello, world!
```

다시 한 번 `next`를 호출하면 QEMU 프로세스가 종료됩니다.

```console
next
```

```text
[Inferior 1 (Remote target) exited normally]
```

이제 GDB 세션을 종료하면 됩니다.

```console
quit
```
