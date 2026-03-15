# 최적화: 속도와 크기 트레이드오프

누구나 프로그램이 매우 빠르고 매우 작기를 원하지만,
보통 두 특성을 동시에 극대화하기는 어렵습니다.
이 절에서는 `rustc`가 제공하는 최적화 레벨과,
그 레벨이 실행 시간 및 바이너리 크기에 미치는 영향을 다룹니다.

## 최적화 없음

기본값은 최적화 없음입니다.
`cargo build`를 실행하면 development(`dev`) 프로파일을 사용합니다.
이 프로파일은 디버깅에 맞춰져 있어 디버그 정보를 포함하고,
최적화는 켜지지 않습니다. 즉 `-C opt-level=0`을 사용합니다.

적어도 베어메탈 개발에서는 디버그 정보가 Flash/ROM 공간을 차지하지 않으므로
사실상 제로 코스트입니다.
그래서 기본값이 꺼져 있더라도 release 프로파일에서 debuginfo를 켜는 것을 권장합니다.
이렇게 하면 release 빌드 디버깅 시에도 브레이크포인트를 사용할 수 있습니다.

```toml
[profile.release]
# 심볼 정보는 유용하고 Flash 크기도 늘리지 않음
debug = true
```

최적화가 없으면 디버깅이 편합니다.
코드를 한 줄씩 실행하는 느낌으로 추적할 수 있고,
GDB에서 스택 변수와 함수 인자를 `print`하기 쉽습니다.
반대로 최적화된 코드에서는
`$0 = <value optimized out>`처럼 값이 사라져 보일 수 있습니다.

`dev` 프로파일의 가장 큰 단점은 바이너리가 크고 느리다는 점입니다.
특히 크기 문제가 더 자주 발생합니다.
비최적화 바이너리는 수십 KiB의 Flash를 차지할 수 있는데,
타깃 장치에 그만한 공간이 없으면 바이너리가 아예 올라가지 않습니다.

더 작으면서 디버거 친화적인 바이너리를 만들 수 있을까요? 가능합니다.

### 의존성만 최적화

Cargo의 [`profile-overrides`] 기능을 사용하면
의존성의 최적화 레벨만 별도로 덮어쓸 수 있습니다.
이를 활용하면 top crate는 비최적화 상태로 디버깅 친화성을 유지하면서,
의존성만 크기 최적화할 수 있습니다.

다만 제네릭 코드는 정의된 크레이트가 아니라
인스턴스화된 크레이트 쪽에서 최적화될 수 있다는 점에 주의하세요.
애플리케이션에서 제네릭 구조체를 인스턴스화했는데
큰 코드 풋프린트가 생긴다면,
관련 의존성의 최적화 레벨을 올려도 효과가 없을 수 있습니다.

[`profile-overrides`]: https://doc.rust-lang.org/cargo/reference/profiles.html#overrides

Here's an example:

```toml
# Cargo.toml
[package]
name = "app"
# ..

[profile.dev.package."*"] # +
opt-level = "z" # +
```

Without the override:

```text
$ cargo size --bin app -- -A
app  :
section               size        addr
.vector_table         1024   0x8000000
.text                 9060   0x8000400
.rodata               1708   0x8002780
.data                    0  0x20000000
.bss                     4  0x20000000
```

With the override:

```text
$ cargo size --bin app -- -A
app  :
section               size        addr
.vector_table         1024   0x8000000
.text                 3490   0x8000400
.rodata               1100   0x80011c0
.data                    0  0x20000000
.bss                     4  0x20000000
```

이렇게 하면 top crate의 디버깅 편의성을 유지하면서
Flash 사용량을 6 KiB 줄일 수 있습니다.
의존성 내부로 들어가면 `<value optimized out>` 메시지가 다시 보일 수 있지만,
대부분은 의존성보다 top crate를 디버깅하는 경우가 많습니다.
특정 의존성을 디버깅해야 한다면,
`profile-overrides`로 해당 의존성만 최적화 대상에서 제외할 수 있습니다.

```toml
# ..

# `cortex-m-rt` 크레이트는 최적화하지 않음
[profile.dev.package.cortex-m-rt] # +
opt-level = 0 # +

# 대신 나머지 의존성은 최적화
[profile.dev.package."*"]
codegen-units = 1 # better optimizations
opt-level = "z"
```

이제 top crate와 `cortex-m-rt` 모두 디버깅 친화적으로 유지됩니다.

## 속도 최적화

2018-09-18 기준 `rustc`는 속도 최적화 레벨 `opt-level=1`, `2`, `3`을 지원합니다.
`cargo build --release`를 실행하면 기본값인 `opt-level=3` release 프로파일을 사용합니다.

`opt-level=2`와 `3`은 모두 바이너리 크기를 희생해 속도를 높입니다.
단 `3`은 `2`보다 벡터화와 인라이닝을 더 적극적으로 수행합니다.
특히 `opt-level >= 2`에서는 LLVM이 루프 언롤링을 수행합니다.
루프 언롤링은 Flash/ROM 비용이 큰 편이지만
(예: 배열 0 초기화 루프가 26바이트에서 194바이트로 증가),
조건이 맞으면 실행 시간을 절반까지 줄일 수 있습니다.

현재 `opt-level=2`, `3`에서는 루프 언롤링만 별도로 끄는 방법이 없습니다.
비용을 감당하기 어렵다면 크기 최적화 전략을 택해야 합니다.

## 크기 최적화

2018-09-18 기준 `rustc`는 크기 최적화 레벨 `opt-level="s"`, `"z"`를 지원합니다.
이 이름은 clang/LLVM에서 가져온 것으로 직관적이진 않지만,
`"z"`가 `"s"`보다 더 작은 바이너리를 만드는 경향이 있습니다.

release 바이너리를 크기 중심으로 최적화하려면,
아래처럼 `Cargo.toml`의 `profile.release.opt-level`을 변경하면 됩니다.

```toml
[profile.release]
# 또는 "z"
opt-level = "s"
```

이 두 최적화 레벨은 LLVM의 inline threshold(함수 인라이닝 판단 기준)를 크게 낮춥니다.
Rust의 핵심 원칙 중 하나는 제로 코스트 추상화이며,
이 추상화는 newtype과 작은 함수(`deref`, `as_ref` 등)를 많이 활용합니다.
따라서 threshold가 너무 낮으면
죽은 분기 제거, 클로저 호출 인라이닝 같은 최적화 기회를 놓칠 수 있습니다.

크기 최적화 시에는 inline threshold를 조금 높여
바이너리 크기에 변화가 있는지 실험해 볼 가치가 있습니다.
권장 방법은 `.cargo/config.toml`의 rustflags에
`-C inline-threshold`를 추가하는 것입니다.

```toml
# .cargo/config.toml
# cortex-m-quickstart 템플릿 사용을 가정
[target.'cfg(all(target_arch = "arm", target_os = "none"))']
rustflags = [
  # ..
  "-C", "inline-threshold=123", # +
]
```

어떤 값을 써야 할까요?
[Rust 1.29.0 기준 각 최적화 레벨의 inline threshold 값][inline-threshold]은 다음과 같습니다.

[inline-threshold]: https://github.com/rust-lang/rust/blob/1.29.0/src/librustc_codegen_llvm/back/write.rs#L2105-L2122

- `opt-level = 3`은 275
- `opt-level = 2`는 225
- `opt-level = "s"`는 75
- `opt-level = "z"`는 25

크기 최적화 시에는 `225`, `275` 값도 함께 시도해 보는 것을 권장합니다.
