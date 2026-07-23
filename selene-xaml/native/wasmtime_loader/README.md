# Internal Wasmtime adapter

This crate is the native Component Model runtime behind the MoonBit
`KKKIIO/selene_xaml_runtime/component_loader` package. It is built as a static library
and is not a game-facing Rust API.

The adapter binds the stable Selene Host WIT and the Survivors showcase
business world, instantiates validated `.component.wasm` artifacts, limits
guest execution with fuel, tracks owned views, and forwards normalized tree
mutation batches to the MoonBit Selene Host. A production game generates the
same typed adapter from its own business WIT.

From the repository root:

```bash
cargo build --manifest-path native/wasmtime_loader/Cargo.toml --release
just test-all
```

The final MoonBit application package supplies the static library through its
native `cc-link-flags`; Wasmtime and Rust types do not cross the C ABI.
