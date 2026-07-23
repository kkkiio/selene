# `selene-xaml generate`

`generate` compiles one XAML document and one typed business contract into a
MoonBit Embedded View package.

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

## Arguments

```text
selene-xaml generate <view.xaml>
  --mbti <contract.mbti>
  --out-dir <package-directory>
  [--dry-run]
```

| Argument | Meaning |
| --- | --- |
| `<view.xaml>` | The single XAML document to compile. |
| `--mbti <path>` | MoonBit public interface used as the business contract. |
| `--out-dir <path>` | Directory containing the generated package and its ownership lock. |
| `--dry-run` | Run parsing, lowering, emission, and formatting, then print the output plan without writing files. |

`--mbti` is required, may appear only once, and requires a value. Embedded View
packages import `KKKIIO/selene` directly.

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

External `ResourceDictionary Source` documents are discovered recursively. Their
canonical paths and content hashes are recorded as imported sidecars, so changing
only a design-token dictionary still invalidates the generated package
deterministically.

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
