# Model as Input

状态：**Accepted**

## 决策

用户定义并持有 Model，Host 将当前 Model 作为 View package 的输入。View 可以保存最近一次
成功提交的输入 snapshot 以支持增量更新，但不取得业务状态的所有权。

```text
user-owned Model
       │ snapshot / typed patch
       ▼
compiled View package
       │ typed Action
       ▼
      Host
```

Model 表示脱离当前 UI 仍然成立的业务事实，例如玩家状态、库存、关卡和选中项 ID。展示文本、
格式化结果、过滤、排序和布局条件由
[Computed ViewModel](computed-view-model.md) 计算。

## 输入 contract

Model contract 应满足以下约束：

- 字段和 variant 使用业务语义；
- collection item 提供稳定 key；
- 传入 View 的值是 immutable snapshot；
- 已提交的 object、Array 和 Map 不再通过 alias 原地修改；
- 需要在 artifact replacement 后恢复的业务值进入 Model；
- Patch 描述业务数据的增量变化；
- Action 描述 View 可以发送给 Host 的用户意图。

Host 是 Model 的唯一 authoritative owner。View 收到 Action 后不直接修改业务 Model；Host
处理 Action、产生新 Model 或 Patch，再驱动 View 更新。

## Immutable snapshot

Model 的公开语义是不可变值。Generator 应拒绝公开 `mut` field、`Ref`、Entity 和其他 runtime
handle。Collection 在提交后冻结；频繁更新的 collection 优先使用 persistent representation
或 typed Patch，使新 snapshot 与旧 snapshot 共享未变化部分。

Generated equality 先检查 reference identity，再比较发生变化的字段。相同 nested identity 可以
截断 generated diff 和 reconcile；按 scope memoize 的计算还可以复用 item ViewModel、Entity
和 local state。单一 opaque `compute_view_model(Model)` 仍会先执行完整计算。

不可变 contract 不限制 adapter 的私有存储实现。Adapter 可以使用 persistent collection、
chunked copy-on-write 或 transaction journal，只要 committed snapshot 对 View 保持不可变，并且
Host rejection 可以完整回滚。

## Generator input

用户通过 `.mbti` 向 generator 提供 Model schema。Generator 读取公开 type、field、collection
item 和 enum shape，生成 typed View input 与 native/component adapter。Adapter 负责跨 package
或 WIT nominal type 的转换，不改变 Model 语义。

没有自定义展示计算时，默认 ViewModel 与 Model 具有相同的数据 shape，直接字段 binding
不需要额外 boilerplate。自定义计算不扩张 Model contract。

## 运行时

```text
mount(Model)
    └── compute ViewModel → mount tree → commit Model/ViewModel snapshot

replace(Model)
    └── compute candidate ViewModel → reconcile → Host apply → commit

apply(Patch)
    └── update candidate Model snapshot → compute → reconcile → commit
```

计算、校验或 UI mutation 失败时，View 保留上一次 committed snapshot；View record 持有的 Model
不受影响。

## Wasm Component memory

WIT record、list 和 variant 是按值传递的 interface type；Canonical ABI 将小值展平，较大的值
通过 linear-memory pointer lowering。它们不提供跨独立 component memory 的长期 object sharing。
WIT `resource` 才使用间接 handle 与明确 lifetime。参见
[Canonical ABI](https://component-model.bytecodealliance.org/advanced/canonical-abi.html) 和
[WIT resource](https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md#item-resource)。

因此，immutable Model 本身不能消除 full Model 跨 WIT boundary 时的 lift、adapter conversion
和 guest allocation。它的内存收益来自 guest 内部省去 defensive copy，以及后续 snapshot 的
结构共享。

Component view 使用以下更新策略：

```text
mount(full Model)         initial snapshot
apply(small typed Patch)  normal update path
replace(full Model)       explicit resync path
```

Guest 在 Model/ViewModel 层只长期保存 committed snapshot，另行保存必要的 reconciliation
state。Patch 构造共享旧数据的 candidate；Selene UI Host 接受 mutation batch 后立即提交 candidate 并释放
旧引用。默认 `ViewModel = Model` 时，两者共享同一 guest value，不保存重复的物化数据。

Full replacement 的瞬时内存包含 old/new Model、old/candidate ViewModel 和 MutationPlan。Typed
Patch 可以把 ABI payload 和 candidate Model 的额外内存限制在变化路径。Candidate ViewModel
只有采用结构共享或 scoped computation 时才获得同样收益；每次完整重建仍需要 `O(ViewModel)`
瞬时内存。Typed Patch 是大 Model 的默认更新方式。

## Artifact replacement

业务侧保留 authoritative Model。替换 artifact 时先 unmount 并卸载旧 Component instance，再加载
新 artifact，用该 Model 重新 mount。

Guest linear memory 和 reconciliation state 不跨 instance 迁移。新 View 需要 Model 中不存在的
业务事实或新的 Action case 时，业务 WIT、Host integration 与 Guest 一起升级。

需要跨更新保留的状态按以下规则放置：

| 状态 | owner |
| --- | --- |
| 业务事实、存档和用户设置 | Model |
| 物化展示值 | Computed ViewModel，可重新计算 |
| focus、scroll、输入光标 | 当前不跨 replacement 保留 |
| Entity、branch 和 keyed item identity | 卸载时释放，新 instance 重建 |

## Considered Alternatives

### Mutable Model alias

View 直接保留外部可变 object 的 alias 可以减少一次构造，但旧 snapshot 会随外部 mutation
一起变化，equality、rollback 和 keyed identity 都失去可靠基准。为了恢复正确性还需要 defensive
copy。选定 contract 使用 immutable snapshot。

### 每次传入完整 Model

Full replacement 的 API 最简单，也能作为丢失 Patch 后的 resync。日常更新采用它会让 WIT
value、adapter 和 guest 每次处理完整数据，并在 transaction 中同时保留 old/new snapshot。
选定方案保留 `replace` 作为显式 resync，常规更新使用 typed Patch。

### Host-owned Model resource

把 Model 暴露成 WIT `resource` 可以让 guest 只保存 handle。ViewModel computation 随后需要大量
Host getter call，或仍然请求一份 bulk snapshot；前者增加 ABI 往返并削弱 snapshot consistency，
后者重新引入完整 value transfer。选定方案让 guest 持有 immutable value snapshot；Entity identity
以绑定 World 内的 `u32` 传递，lifetime 仍由 Host 验证。

### 在 View boundary 深拷贝 mutable input

每次 deep copy 可以建立可靠 snapshot，但分配量与完整 Model 大小相关，也无法利用 Host 已知的
变化路径。选定方案把 immutability 放进 Model contract，并用 typed Patch 构造 candidate；boundary
copy 只属于具体 adapter 的必要 value conversion。

## 相关决策

- 用户计算代码、物化 ViewModel 与 diff：[Computed ViewModel](computed-view-model.md)
- View 的私有调和状态：[View State System](view-state-system.md)
- Component memory 与 replacement：[Wasm Component Guest Package](wasm-component-guest-package.md)
