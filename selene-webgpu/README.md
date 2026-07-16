# KKKIIO/selene_webgpu

WebGPU backend for Selene web builds.

## Install

```bash
moon add KKKIIO/selene_webgpu
```

## Enable This Backend

In your web wrapper package:

```moonbit
options(
  overrides: [
    "KKKIIO/selene_webgpu/platform_window",
    "KKKIIO/selene_webgpu/platform_input",
    "KKKIIO/selene_webgpu/platform_render",
    "KKKIIO/selene_webgpu/platform_audio",
    "KKKIIO/selene_webgpu/platform_asset_io",
  ],
)
```

## Build And Run

```bash
moon build --target js --release
python3 -m http.server 8000
```

Open `http://localhost:8000`.
