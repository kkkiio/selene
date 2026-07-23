# JavaScript Component Host adapter

Browser games and the repository examples share this Component Host integration:

- [`host-runtime.js`](host-runtime.js) is the Host WIT registration boundary
  linked by JCO output;
- [`testing/mock-tree-host.js`](testing/mock-tree-host.js) is the deterministic
  semantic host used by Component acceptance tests;
- [`selene-tree-host.js`](selene-tree-host.js) adapts the same registry to the
  browser bridge installed by `KKKIIO/selene_xaml_runtime/component_host`;
- [`ui-component-loader.js`](ui-component-loader.js) validates required host
  capabilities and separates module `load/unload` from Entity `mount/unmount`.

The JavaScript Loader is the browser/JCO implementation. Native MoonBit games
use `KKKIIO/selene_xaml_runtime/component_loader`: its public API owns a loaded
module bound to one Selene World and exposes `load`, `mount`, `replace`, `apply`,
`handle_event`, `update`, `unmount`, and `unload`. The package calls an internal
Wasmtime static runtime; game code does not call Rust or Wasmtime APIs.

The checked-in native runtime contains the generated typed Wasmtime adapters
for these two business WIT worlds. A game package needs the equivalent adapter
generated from its own business WIT; the stable shared part is the Selene Host
WIT, Host callbacks, lifecycle policy, and MoonBit Loader surface. Artifact
replacement unmounts and unloads the old instance before loading the new one.
