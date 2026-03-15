# 도구 설치

이 페이지에는 몇 가지 도구에 대한 운영체제 공통 설치 지침이 정리되어 있습니다.

### Rust 툴체인

[https://rustup.rs](https://rustup.rs)의 안내를 따라 rustup을 설치하세요.

**참고** 컴파일러 버전이 `1.31` 이상인지 확인하세요. `rustc -V` 결과의 날짜는 아래 예시보다 최신이어야 합니다.

```text
$ rustc -V
rustc 1.31.1 (b6c32da9b 2018-12-18)
```

기본 설치는 대역폭과 디스크 사용량을 줄이기 위해 네이티브 컴파일만 지원합니다.
ARM Cortex-M 아키텍처에 대한 크로스 컴파일 지원을 추가하려면 아래 타깃 중 하나를 선택하세요.
이 책의 예제에서 사용하는 STM32F3DISCOVERY 보드에는 `thumbv7em-none-eabihf` 타깃을 사용합니다.
[어떤 Cortex-M을 써야 하는지 확인하기](https://developer.arm.com/ip-products/processors/cortex-m#c-7d3b69ce-5b17-4c9e-8f06-59b605713133)

Cortex-M0, M0+, M1 (ARMv6-M 아키텍처):

```console
rustup target add thumbv6m-none-eabi
```

Cortex-M3 (ARMv7-M 아키텍처):

```console
rustup target add thumbv7m-none-eabi
```

Cortex-M4, M7 without hardware floating point (ARMv7E-M 아키텍처):

```console
rustup target add thumbv7em-none-eabi
```

Cortex-M4F, M7F with hardware floating point (ARMv7E-M 아키텍처):

```console
rustup target add thumbv7em-none-eabihf
```

Cortex-M23 (ARMv8-M 아키텍처):

```console
rustup target add thumbv8m.base-none-eabi
```

Cortex-M33, M35P (ARMv8-M 아키텍처):

```console
rustup target add thumbv8m.main-none-eabi
```

Cortex-M33F, M35PF with hardware floating point (ARMv8-M 아키텍처):

```console
rustup target add thumbv8m.main-none-eabihf
```

### `cargo-binutils`

```text
cargo install cargo-binutils

rustup component add llvm-tools
```

WINDOWS: Visual Studio 2019용 C++ Build Tools가 선행 설치되어 있어야 합니다. https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=BuildTools&rel=16

### `cargo-generate`

이후 템플릿으로부터 프로젝트를 생성할 때 사용합니다.

```console
cargo install cargo-generate
```

참고: 일부 리눅스 배포판(예: Ubuntu)에서는 `cargo-generate` 설치 전에 `libssl-dev`, `pkg-config` 패키지를 먼저 설치해야 할 수 있습니다.

### 운영체제별 지침

이제 사용 중인 운영체제에 맞는 지침을 따르세요.

- [Linux](install/linux.md)
- [Windows](install/windows.md)
- [macOS](install/macos.md)
