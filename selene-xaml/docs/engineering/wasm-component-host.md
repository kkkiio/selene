# WebAssembly Component Host

状态：**Accepted**

Component Host 运行在 Selene 进程中，加载业务 `.component.wasm`，绑定业务项目拥有的 WIT
world，并实现通用 UI Host WIT。它不解释业务 Model、Patch 或 Action。

## Runtime boundary

```text
game integration
    │ Entity + business WIT values
    ▼
Component Host ── generated WIT bindings ── Component Guest
    ▲                                      │ apply(entity-id, mutations)
    └──────────── UI Host WIT adapter ─────┘
                         │
                         ▼
                  Selene UI Host
```

Component Host 包含 loader/runtime、业务 WIT bindings 和 UI Host WIT adapter。WIT bindings 根据业务
项目的 interface 生成；Host 核心只负责调用，不需要业务字段信息，也不生成 typed business adapter。

## World binding

每个 Component instance 在创建时记录当前 `world.id()`，其全部 lifecycle 调用必须发生在同一个
World。这个约束使 Guest 收到的 `u32` Entity ID 在 instance 内唯一：

```text
Loaded Component instance
├── bound World ID
├── runtime store and generated WIT bindings
└── mounted Host records keyed by real Selene Entity
    ├── Entity UInt sent to Guest
    ├── Selene UI Host record
    └── child Entity → stable node key routes
```

Selene 的 generator 位于每个 World 的 Entity store 中。单个 World 内 ID 单调递增；不同 World 可
以 `0` 开始并产生相同 ID。Host 不允许这些 ID 进入同一个 Component instance。

## Public lifecycle

以 native loader 的通用 JSON/WIT value API 为例：

```moonbit
let component = NativeUiComponent::load(kind, artifact_path)
component.mount(entity, wit_model)
component.replace(entity, wit_model)
component.apply(entity, wit_patches)
let action = component.handle_event(entity, wit_event)
component.update()
component.unmount(entity)
component.unload()
```

Entity 是 mounted View 的唯一身份。Component ABI 不再创建 business View resource 或 Host tree
resource。Component module/artifact handle 只表示已加载代码，不能替代 Entity。

## mount

`mount(entity, model)`：

1. 验证 instance 属于当前 World，Entity alive 且尚未挂载；
2. 在 UI Host adapter 中登记真实 Entity 与其 UInt；
3. lower Model 并调用 Guest `mount(entity.id(), model)`；
4. Guest 计算初始 mutation batch，并 import `tree.apply(entity.id(), mutations)`；
5. UI Host adapter 找回真实 Entity，Selene UI Host 验证并创建 children；
6. Guest 与 Host 都成功后记录 mounted Entity。

任何步骤失败都会删除本次登记。已提交 mutation 的 Host failure path 由 Selene UI Host 的 batch
atomicity 保证不会留下部分 tree。

## UI Host WIT

```wit
interface tree {
  apply: func(
    entity: u32,
    mutations: list<tree-mutation>,
  ) -> result<_, host-error>;
}
```

adapter 在 instance 绑定的 World 中把 UInt 映射回已经登记的真实 Entity。Guest 不能提交未登记、
dead 或属于其他 World 的 Entity ID。

Selene UI Host 对 batch 的 planned state 完整验证。验证成功后按 mutation 顺序增量提交：精确属性
mutation 只写目标 component，`Move` 只重排涉及的 hierarchy，`Mount`/`Remove` 只处理指定子树。
retained 且未变化的 UI component 保持原 object identity。

## update 与 Entity GC

Host update 运行在 instance 绑定的 World：

1. 遍历该 instance 的 mounted Entity；
2. 对 `!entity.is_alive()` 的记录调用 Guest `unmount(entity.id())`；
3. 让 Selene UI Host 删除 children、UI stores 和 raw event routes；
4. 删除 Host mounted record；
5. 调用 Guest `update()`。

显式 `unmount(entity)` 执行相同清理，但不销毁业务拥有的 root Entity。所有 Entity 清理完成后才
允许 `unload()`。

## Event routing

Selene raw event 通过 child Entity 找到 root Entity 和 stable node key。Host lower 为业务 WIT
event，调用 `handle-event(root.id(), event)`，再把 `option<Action>` 返回给业务 integration。业务
项目自行决定是否发布到 Selene EventBus。

## Artifact replacement

当前采用 unload/load replacement：业务侧保留 authoritative Model，先 unmount 旧 instance，随后
unload，再加载新 artifact 并重新 mount。Host 不迁移 Guest linear memory、ViewModel 或
reconciliation Map，也不提供 staging tree 和原子 swap。

## Native and browser

| platform | execution | Entity bridge |
| --- | --- | --- |
| native | Wasmtime Component API | MoonBit 在调用 Guest 前登记真实 Entity，Rust binding 传 `u32` |
| browser | JCO transpiled module | Selene JS bridge登记真实 Entity，JCO export 接收 number |

两条路径执行相同的 World binding、Entity GC、business lifecycle 和 UI mutation validation。

## Sandbox and limits

Host 只链接 WIT world 声明的 imports，默认不提供 filesystem、network 或任意 Host memory access；
同时限制 memory、fuel/epoch、每帧调用数、tree size 和 mutation payload，并验证 artifact hash、WIT
fingerprint 与 capability set。Guest trap 的影响限制在当前 instance。
