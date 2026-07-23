# Survivors Web example

Survivors demonstrates a compact `XAML → typed View → Selene WebGPU` HUD with
conditional panels, keyed selections, state replacement, patches, and typed
actions.

## Installation

Install MoonBit and the dependencies declared by `moon.mod`.

## Usage

Regenerate the typed View after changing the model or XAML:

```bash
moon -C examples/survivors info src/model --target js
moon run src/cmd/selene-xaml --target native -- generate \
  examples/survivors/survivors.xaml \
  --mbti examples/survivors/src/model/pkg.generated.mbti \
  --out-dir examples/survivors/src/view
```

Build the JS app and serve the repository root:

```bash
moon -C examples/survivors build src/app --target js --release
python3 -m http.server 8000
```

Open `http://localhost:8000/examples/survivors/web/`. The generated View and
layout assertions run for both JS and native backends from
`tests/target-matrix`; the example itself stays focused on the Web workflow.
