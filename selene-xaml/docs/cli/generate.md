# `selene-xaml generate`

`generate` compiles one XAML document and one typed business contract into a
MoonBit package. The selected contract determines whether the output is an
Embedded View package or a WebAssembly Component Guest package.

## Embedded View package

Generate the public MoonBit interface for the business model package first:

```bash
moon -C your_game info src/model --target js
```

Then pass the generated `.mbti` to `selene-xaml`:

```mooncram
$ selene-xaml generate your_game/ui/inventory.xaml \
>   --mbti your_game/src/model/pkg.generated.mbti \
>   --out-dir your_game/src/inventory_view
generated 5 files in your_game/src/inventory_view
```

On success, the output directory contains:

```mooncram
$ LC_ALL=C ls -1 your_game/src/inventory_view
moon.pkg
selene-xaml.lock.json
state.generated.mbt
view.generated.mbt
view.generated.mbt.map.json
```

The generated package references the nominal business types declared by the
`.mbti`; it does not copy those types into the View package.

## Component Guest package

Pass either one WIT file or a directory containing `.wit` files:

```mooncram
$ selene-xaml generate your_game/ui/component.xaml \
>   --wit your_game/wit \
>   --out-dir your_game/src/inventory_component
generated 3 Component Guest files in your_game/src/inventory_component
```

When `--wit` names a directory, `generate` reads its direct `.wit` children in
filename order. An empty WIT directory is rejected.

On success, the generator-owned output is:

```mooncram
$ LC_ALL=C ls -1 your_game/src/inventory_component
guest.generated.mbt
guest.generated.mbt.map.json
selene-xaml.lock.json
```

The Component project owns `moon.pkg`, generated WIT bindings, and the final
`.component.wasm`. `selene-xaml generate` does not run `wit-bindgen`, Moon
builds, `wasm-tools`, or `jco`.

## Arguments

```text
selene-xaml generate <view.xaml>
  (--mbti <contract.mbti> | --wit <wit-file-or-directory>)
  --out-dir <package-directory>
  [--dry-run]
```

| Argument | Meaning |
| --- | --- |
| `<view.xaml>` | The single XAML document to compile. |
| `--mbti <path>` | Generate an Embedded View package using a MoonBit public interface as the business contract. |
| `--wit <path>` | Generate a Component Guest package using one WIT file or a directory of WIT files. |
| `--out-dir <path>` | Directory containing the generated package and its ownership lock. |
| `--dry-run` | Run parsing, lowering, emission, and formatting, then print the output plan without writing files. |

Exactly one of `--mbti` and `--wit` is required. Each option may appear only
once and requires a value. Embedded View packages import `KKKIIO/selene`
directly.

## Preview without writing

Use `--dry-run` to validate the complete generation request and inspect its
output set without creating or updating the output directory:

```mooncram
$ selene-xaml generate your_game/ui/inventory.xaml \
>   --mbti your_game/src/model/pkg.generated.mbti \
>   --out-dir your_game/src/inventory_view_preview \
>   --dry-run
would generate 5 files in your_game/src/inventory_view_preview
  moon.pkg
  state.generated.mbt
  view.generated.mbt
  view.generated.mbt.map.json
  selene-xaml.lock.json
```

## Output ownership

`selene-xaml.lock.json` records the inputs and files owned by the generator.
Subsequent runs update generator-owned files while preserving other files in
the output directory. Generation is deterministic for identical inputs and is
committed as one package update after parsing, lowering, emission, and
formatting succeed. Output hashes describe the generated result; editing an
owned file does not block the next generation, which overwrites that file.

Commit generated `.mbt` files and the ownership lock. This repository also
commits source maps for first-party examples as generator regression artifacts;
downstream projects may choose their own source-map policy.

## Diagnostics

The command validates XAML syntax, the supported XAML profile, Selene
vocabulary, namescopes, static scalar values, bindings, actions, and the
selected business contract. Diagnostics are written to stderr and retain XAML
source locations where available.

The MoonBit compiler performs the final check of generated business member
access and target types. The generated `.mbt.map.json` lets those compiler
diagnostics point back to the corresponding XAML expression.
