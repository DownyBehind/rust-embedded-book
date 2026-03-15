# 타입 상태 프로그래밍

[typestates] 개념은 객체의 현재 상태 정보를
그 객체의 타입에 인코딩하는 방식을 설명합니다.
다소 난해하게 들릴 수 있지만,
Rust에서 [Builder Pattern]을 사용해 봤다면 이미 타입 상태 프로그래밍을 시작한 것입니다.

[typestates]: https://en.wikipedia.org/wiki/Typestate_analysis
[Builder Pattern]: https://doc.rust-lang.org/1.0.0/style/ownership/builders.html

```rust
pub mod foo_module {
    #[derive(Debug)]
    pub struct Foo {
        inner: u32,
    }

    pub struct FooBuilder {
        a: u32,
        b: u32,
    }

    impl FooBuilder {
        pub fn new(starter: u32) -> Self {
            Self {
                a: starter,
                b: starter,
            }
        }

        pub fn double_a(self) -> Self {
            Self {
                a: self.a * 2,
                b: self.b,
            }
        }

        pub fn into_foo(self) -> Foo {
            Foo {
                inner: self.a + self.b,
            }
        }
    }
}

fn main() {
    let x = foo_module::FooBuilder::new(10)
        .double_a()
        .into_foo();

    println!("{:#?}", x);
}
```

이 예제에서는 `Foo` 객체를 직접 생성할 방법이 없습니다.
원하는 `Foo`를 얻으려면 먼저 `FooBuilder`를 만들고 올바르게 초기화해야 합니다.

이 간단한 예제는 두 가지 상태를 인코딩합니다.

- `FooBuilder`: "미설정" 또는 "설정 진행 중" 상태
- `Foo`: "설정 완료" 또는 "사용 준비 완료" 상태

## 강한 타입 시스템

Rust는 [Strong Type System]을 갖고 있기 때문에,
`into_foo()`를 호출하지 않고 `FooBuilder`를 `Foo`로 바꾸거나
`Foo` 인스턴스를 "마법처럼" 만드는 쉬운 우회 방법이 없습니다.
또한 `into_foo()`를 호출하면 원래 `FooBuilder`가 소비되므로,
새 인스턴스를 만들지 않으면 재사용할 수 없습니다.

[Strong Type System]: https://en.wikipedia.org/wiki/Strong_and_weak_typing

이 방식 덕분에 시스템 상태를 타입으로 표현하고,
상태 전이에 필요한 동작을 타입 변환 메서드에 포함할 수 있습니다.
`FooBuilder`를 만든 뒤 `Foo`로 바꾸는 과정 자체가
기본적인 상태 머신 단계를 밟는 것과 같습니다.
