# WebAssembly Component test matrix

The matrix exercises the runnable Survivors Component showcase without making
the test directory own its source or screenshots. The Component, browser entry
and reference images all live under `examples/wasm-component`; this directory
only documents the cross-target verification command.

Run the semantic Component builds from the repository root:

```bash
just test-all
```

This validates WIT fingerprints, MoonBit Wasm builds, Component packaging, JCO
transpilation, the native loader, mock-host behavior, and browser readiness.
Stable behavior baselines remain the semantic ECS/store tests.
