# AGENTS.md

## Fork Maintenance
- This repository is the long-lived `kkkiio/selene` fork of `moonbit-community/selene`; its `main` branch is maintained and released independently.
- For fixes and toolchain migrations that also apply upstream, keep each change in a separate commit so it is ready for an upstream PR, and include the commit in fork `main` without waiting. Only open the upstream PR when explicitly asked by the user.
- Keep fork-only namespace, package metadata, release scope, and Maple dependency changes separate from upstreamable commits.
- Follow upstream's rolling/nightly MoonBit toolchain policy; do not pin Selene to an older stable toolchain merely to avoid migrations.

## Changelog
- Always update `docs/CHANGELOG.md` and keep `## [Unreleased]` at the top.
- Use only `Added` / `Changed` / `Fixed` / `Removed`.
- Before `python3 publish.py x.y.z`, move released items from `Unreleased` into `## [x.y.z] - YYYY-MM-DD`, then keep a new empty `Unreleased`.

## `publish.py`
- Release only: `python3 publish.py x.y.z`; it will fail if the changelog has no matching version header.
- Publish only `KKKIIO/selene`, `KKKIIO/selene_xaml`, `KKKIIO/selene_webgpu`, and `KKKIIO/selene_raylib`.
- Release order is fixed: `selene-core -> selene-xaml -> selene-webgpu -> selene-raylib`; all checks must be warning-free.

## `publish_pages.py`
- Pages: `python3 publish_pages.py` (or `python3 publish_pages.py clean`), with the `examples-web` release build already in `_build`.

## Release Manifest Behavior
- Publish flow rewrites each release module's `moon.mod` version and internal Selene dependencies to `@x.y.z`.
- Publish flow also syncs `examples`, `examples-web`, and `examples-native` internal Selene dependencies to `@x.y.z`.
- Release pipeline finishes with `moon update` for release and example modules; it does not restore old dependencies.

## Scope
- `examples`, editor modules, and editor specifications are workspace-only and are not published packages.
