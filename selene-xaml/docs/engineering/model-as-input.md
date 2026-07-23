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
item 和 enum shape，生成 typed View input，并通过静态 import 引用业务 package 的 nominal type。

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

## State ownership

业务侧始终保留 authoritative Model。需要跨 View 重建保留的状态按以下规则放置：

| 状态 | owner |
| --- | --- |
| 业务事实、存档和用户设置 | Model |
| 物化展示值 | Computed ViewModel，可重新计算 |
| focus、scroll、输入光标 | View Host，可按 stable key 在 View swap 时恢复 |
| Entity、branch 和 keyed item identity | View record，卸载时释放 |

## Considered Alternatives

### Mutable Model alias

View 直接保留外部可变 object 的 alias 可以减少一次构造，但旧 snapshot 会随外部 mutation
一起变化，equality、rollback 和 keyed identity 都失去可靠基准。为了恢复正确性还需要 defensive
copy。选定 contract 使用 immutable snapshot。

### 每次传入完整 Model

Full replacement 的 API 最简单，也能作为丢失 Patch 后的 resync。日常更新采用它会让
transaction 同时保留 old/new snapshot，并对完整 Model 重新计算。选定方案保留 `replace`
作为显式 resync，常规更新使用 typed Patch。

### 在 View boundary 深拷贝 mutable input

每次 deep copy 可以建立可靠 snapshot，但分配量与完整 Model 大小相关，也无法利用 Host 已知的
变化路径。选定方案把 immutability 放进 Model contract，并用 typed Patch 构造 candidate；boundary
copy 只属于具体 adapter 的必要 value conversion。

## 相关决策

- 用户计算代码、物化 ViewModel 与 diff：[Computed ViewModel](computed-view-model.md)
- View 的私有调和状态：[View State System](view-state-system.md)
