# KKKIIO/selene_raylib

raylib-based native backend for Selene.

## Install

```bash
moon add KKKIIO/selene_raylib
```

## Enable This Backend

In your native wrapper package:

```moonbit
options(
  overrides: [
    "KKKIIO/selene_raylib/platform_window",
    "KKKIIO/selene_raylib/platform_input",
    "KKKIIO/selene_raylib/platform_render",
    "KKKIIO/selene_raylib/platform_audio",
    "KKKIIO/selene_raylib/platform_asset_io",
  ],
)
```

## Build And Run

```bash
moon run --target native
```
