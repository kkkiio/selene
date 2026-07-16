# AGENTS.md

## Domain Language

- **Runtime modules** — The published `selene-core`, `selene-webgpu`, and `selene-raylib` modules consumed by games.
- **Editor modules** — Workspace-only editor shared, frontend, service, and specification modules excluded from fork releases.
- **Examples** — Demo and Pages modules under `examples`, `examples-web`, and `examples-native` that are never published.
- **Fork release** — A synchronized release of the three `KKKIIO` runtime modules to Mooncakes.

## Policies & Mandatory Rules

### Changelog

- Update `docs/CHANGELOG.md` for every user-visible code or release-workflow change.
- Keep `## [Unreleased]` at the top and use only `Added`, `Changed`, `Fixed`, and `Removed` subsections.
- Before running `python3 publish.py <x.y.z>`, move released items into `## [<x.y.z>] - YYYY-MM-DD` and leave a new empty `Unreleased` section.

### Release Scope

- Publish only `selene-core`, `selene-webgpu`, and `selene-raylib` when creating a fork release.
- Keep the release order `selene-core -> selene-webgpu -> selene-raylib` and require warning-free checks.
- Never publish `examples`, editor modules, or editor specifications from `publish.py`.

### Compatibility Policy

- Treat the project as a 0.x API with zero stability guarantees.
- Prefer direct migrations and current-state code over compatibility layers.
- Document intentional breaking changes in `docs/CHANGELOG.md` and the final response.

## Project Structure Guide

### Repo Structure & Important Files

```text
.
├── selene-core/             # Cross-backend runtime module: KKKIIO/selene
├── selene-webgpu/           # Browser backend module: KKKIIO/selene_webgpu
├── selene-raylib/           # Native backend module: KKKIIO/selene_raylib
├── selene-editor-*/         # Workspace-only editor modules
├── selene-editor-specs/     # Workspace-only editor specifications
├── examples/                # Shared demo logic and assets
├── examples-web/            # WebGPU demo launchers
├── examples-native/         # Raylib demo launchers
├── docs/CHANGELOG.md        # Release notes and Unreleased changes
├── moon.work                # Local workspace membership
├── publish.py               # Runtime Mooncakes release pipeline
└── publish_pages.py         # GitHub Pages build pipeline
```

## Operation Guide

### Validate Runtime Modules

Run the same warning-strict checks used by the release pipeline:

```bash
moon -C selene-core check . --target js --deny-warn
moon -C selene-core check . --target native --deny-warn
moon -C selene-webgpu check . --target js --deny-warn
moon -C selene-raylib check . --target native --deny-warn
```

### Publish a Fork Release

Prepare a matching changelog version section, then run:

```bash
python3 publish.py <x.y.z>
```

The pipeline rewrites runtime module versions, synchronizes internal runtime dependencies in examples, publishes in dependency order, and finishes with `moon update`. It preserves the new versions instead of restoring old manifests.

### Publish Pages

Build `examples-web` release artifacts before running:

```bash
python3 publish_pages.py
```

Use `python3 publish_pages.py clean` when a clean Pages output is required.
