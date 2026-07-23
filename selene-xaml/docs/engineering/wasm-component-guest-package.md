# WebAssembly Component Guest Package

状态：**Accepted**

Component emitter 生成独立 MoonBit Guest package，并编译为 `.component.wasm`。Guest 读取与
Embedded emitter 相同的 ViewIR，但拥有独立的 generated runtime source 和 linear memory。

## 边界

```text
business WIT + XAML
        │
        ▼
      ViewIR
        │ Component emitter
        ▼
Component Guest package
   │ import apply(entity, mutations)
   ▼
UI Host WIT ── Component Host ── Selene UI Host
```

Guest 不能访问 Host 进程中的 Selene World、Entity object、UI stores、asset stores 或 EventBus。
Host 只把 Entity 的 UInt ID 作为 WIT value 传入 Guest。

## World 与 Entity identity

一个 Component instance 固定绑定一个 Selene World。Selene Entity ID 在该 World 内单调递增；不同
World 可以拥有相同 UInt ID。Component Host 禁止跨 World 调用同一个 instance，因此 Guest 可以
直接使用 Entity UInt 作为 View state key：

```text
Component instance bound to World W
└── Map[Entity UInt, Guest View record]
    ├── committed Model
    ├── committed computed ViewModel
    ├── committed node/tree snapshot
    ├── active branch and keyed item state
    ├── action routes
    └── visual transition state
```

Guest 不接收 `world-id`，也不能根据 UInt 查询 Entity lifetime。World 绑定和 lifetime validation 都
由 Host 执行。

## WIT interfaces

业务项目拥有 Model、Patch、Event、Action 和 lifecycle WIT：

```wit
interface inventory-ui-api {
  record inventory-model {
    title: string,
    selected-item-id: option<string>,
    items: list<inventory-item>,
  }

  variant inventory-patch {
    items-replace(list<inventory-item>),
    item-upsert(inventory-item),
    item-remove(string),
    item-move(tuple<string, u32>),
  }

  mount: func(entity: u32, model: inventory-model);
  replace: func(entity: u32, model: inventory-model);
  apply: func(entity: u32, patches: list<inventory-patch>);
  handle-event: func(entity: u32, event: ui-event) -> option<inventory-action>;
  update: func();
  unmount: func(entity: u32);
}
```

Selene XAML 只维护通用 UI Host WIT interface：

```wit
interface tree {
  apply: func(
    entity: u32,
    mutations: list<tree-mutation>,
  ) -> result<_, host-error>;
}
```

UI Host WIT 没有 tree resource。Entity 已经提供 UI tree identity 和 lifetime；再增加 resource 会
形成第二套身份，并要求 Host 维护无业务价值的 Entity/resource 映射。

## Lifecycle

### mount

`mount(entity, model)` 拒绝重复 Entity key，计算 candidate ViewModel 和初始 mutation batch，调用
imported `tree.apply(entity, mutations)`。Host 接受完整 batch 后，Guest 才把 record 写入 Map。

### replace 与 apply

`replace` 接收完整 immutable Model；`apply` 接收 typed Patch batch。两者在 Guest memory 中构造
candidate Model/ViewModel 和 mutation plan，Host 接受 batch 后才提交 Guest record。普通更新不会
复制完整 UI tree，也不会重写 retained node 的 Host UI component。

### handle-event

Host 将稳定 node key lower 为业务 `ui-event`，再调用 `handle-event(entity, event)`。Generated route
读取该 Entity 对应的 committed ViewModel 和 action route，返回 `option<Action>`。

### update

Host 每帧完成 Entity lifetime 清理后调用 `update()`。当前没有逐帧 Guest 状态的 generated View
实现为空；未来 visual transition 或 Guest-local scheduler 可以在这个入口推进，并继续通过
`tree.apply(entity, mutations)` 提交增量结果。

### unmount

`unmount(entity)` 删除 Guest Map 中的 record。它不调用 UI Host import；真实 Entity tree 的销毁由
Host 根据 Entity lifetime 完成。重复 unmount 可以安全收敛为空状态。

## Entity GC

Guest 不能调用 `Entity::is_alive()`。Component Host 保存真实 Entity，更新时按以下顺序运行：

1. 在 instance 绑定的 World 中检查 mounted Entity；
2. 对 dead Entity 调用 Guest `unmount(entity-id)`；
3. 清理 Selene UI Host record、children 和 event routes；
4. 调用 Guest `update()`；
5. instance 没有 mounted Entity 后才允许 unload。

## Replacement policy

当前只提供可替换 artifact：先 unmount 旧 instance 的 View，卸载旧 instance，再加载新 artifact 并
使用业务侧提供的 Model 重新 mount。Guest linear memory、Map 和 reconciliation state 不跨 instance
迁移，也不承诺原子热替换。

## Errors and traps

UI Host 对完整 mutation batch 先验证后提交。Guest computation、Canonical ABI conversion、Host
rejection 或 trap 都不能留下半提交的 UI mutation。Host 可以卸载失败 instance；恢复所需的 Model
由业务侧持有。
