# Generated Reconciliation

状态：**Accepted**

## 决策

Selene XAML 根据 XAML、typed ViewModel 和 UI mutation vocabulary 生成每个 View 专用的
reconcile 程序：

```text
committed ViewModel + candidate ViewModel + reconciliation state
                              │
                              ▼
                    validated MutationPlan
                              │ Selene UI Host.apply
                              ▼
              committed ViewModel + reconciliation state
```

Reconcile 不解释通用 XAML descriptor，也不在运行时构造通用增量计算图。XAML 已经在生成期
给出了 field、node、branch 和 collection 的依赖关系；generated code 直接比较 typed value，
维护稳定 identity，并生成 `TreeMutation` batch。

用户的 `compute_view_model` 在 reconcile 之前运行。该函数对 generator opaque，因此每次
Model replacement 都计算完整 candidate ViewModel。增量边界从 candidate ViewModel 开始。

## 从 Rabbita 采用的原则

| Rabbita 机制 | Selene 采用方式 |
| --- | --- |
| `Val` 的显式 dependency edge | XAML 生成 `ViewModel field → node/property targets` |
| `Eq` 相等时停止 change propagation | typed field equality 截断 subtree diff 和 UI mutation |
| `assoc` 用稳定 key 保存 branch | keyed `ItemsControl` 用 key 保存 item identity 和 local state |
| `assoc` 的 epoch mark/sweep | 每次 collection reconcile 标记 retained entry，并清理 stale entry |
| `switch` 更换 tag 时销毁旧 scope | `If` tag 变化时 teardown 旧 branch，再 mount 新 branch |
| VNode kind/tag 相同则复用节点 | node key 与 kind 兼容时保留 Host identity |
| keyed child reorder 保留节点 | 生成 `Move`，不 remove/mount retained item |

Rabbita 的 lazy pull、通用 dirty graph 和直接 DOM patch 保留在其 runtime 层。Selene 使用显式
`replace/apply` transaction、生成期依赖和原子 Host batch，因此不引入 `Val` runtime，也不复制
通用 VDOM walker。

## Reconciliation state

每个 mounted View 的私有 record 保存：

```text
ViewRecord
├── committed Model snapshot
├── committed ViewModel
├── committed NodeSpec snapshot
├── active branch tags
├── keyed item entries and order
└── action routes
```

`committed ViewModel` 是 presentation cache。Branch/item state 负责 identity 和 lifecycle；Host
继续拥有真实 Entity tree。

Keyed item entry 至少包含：

```text
ItemEntry
├── key
├── committed item ViewModel
├── template/node identity
├── local state
└── last_seen_epoch
```

## Transaction

一次 `replace` 或 `apply` 分为五个阶段。

### 1. 构造 candidate

`replace` 直接接收新的 Model snapshot。`apply` 先在旧 Model snapshot 的副本上解释完整 typed
Patch batch。随后调用用户计算，得到 candidate ViewModel。

该阶段不修改 committed View record，也不调用 Host。

### 2. 验证 identity

Generated code 在规划 mutation 前验证所有动态 identity：

- node key 和 item key 非空；
- 同一 collection scope 中 key 唯一；
- parent key 存在，最终 tree 无环；
- 同一 key 的 retained node 具有兼容 kind；
- action route 指向 candidate tree 中存在的 node。

任一验证失败都会丢弃 candidate。

### 3. 比较 value

Generator 为 XAML 实际读取的 ViewModel 字段生成 typed equality gate：

- scalar、String 和 enum 按 value equality；
- nested ViewModel 递归进入发生变化的字段；
- 同一字段绑定多个 target 时只比较一次；
- 相等字段不生成 property mutation，也不进入其静态 subtree；
- 不支持专用 mutation 的属性变化使用 `Update(NodeSpec)`；支持的属性优先生成 `SetText`、
  `SetSource`、`SetEnabled` 等精确 mutation。

`Eq` 必须覆盖下游可观察的全部值。Model 和 ViewModel 使用 immutable snapshot；调用方不能原地
修改已经提交的 Array/Map 后依赖 equality 发现变化。

### 4. 调和 structure

静态 node 使用 generator 分配的稳定 key。显式 `x:Name` 直接形成 identity；template item node
使用 `(template identity, item key, local node identity)` 组成 identity。

同一 key 且 kind 兼容时复用节点。kind 不兼容表示 identity replacement，生成原子
remove/mount，并重置该 node 的 view-local state。

`If` 使用 disposable switch 语义：

- tag 相同：保留 active branch，只 diff branch 内字段；
- tag 不同：规划旧 branch teardown 和新 branch mount；
- inactive branch 默认不缓存；需要 keep-alive 时应引入显式 vocabulary。

Keyed `ItemsControl` 使用 Rabbita `assoc` 风格的 mark/sweep：

```text
epoch += 1
for item in candidate order:
  key = item.key
  reject duplicate key
  reuse old entry or create new entry
  diff retained item ViewModel
  entry.last_seen_epoch = epoch
remove entries whose epoch is stale
compute LIS over retained old indices
walk candidate order from right to left:
  mount new key before anchor
  move retained key outside LIS before anchor
  keep retained key inside LIS
```

相同 key 的 item 更新只替换 item ViewModel，保留 Entity、focus 和 local state。删除 key 会 dispose
整个 item branch；重新加入同一 key 会创建新 branch。

LIS 保存仍具有相对顺序的最长 retained subsequence。反向 anchor planning 在模拟 sibling order
中计算每个 `Move` 的实际 index；单纯在列表头插入或删除 item 不会让其余 item 产生 `Move`。
设旧列表长度为 `m`、新列表长度为 `n`，算法复杂度为 `O(m + n log n)`，空间为 `O(m+n)`。

### 5. Plan、apply、commit

Planner 先生成完整 `MutationPlan`，再按依赖关系排序：

1. destination parent 必须在 child mount/move 前存在；
2. retained child 必须在旧 ancestor remove 前移出；
3. mount 按 parent-before-child；
4. remove 只提交 maximal removed root，并在所有 outgoing move 后执行；
5. property mutation 在 target identity 建立后执行。

Selene UI Host 在应用前使用私有 planned state 验证整个 batch。验证成功后按 mutation 顺序增量
提交：精确属性 mutation 只写目标组件，`Move` 只修改涉及的父子关系，`Mount`/`Remove` 只处理
指定子树；retained 且未变化的 UI component object 保持原 identity。成功后 View 才替换
committed Model、ViewModel、NodeSpec、branch/item state 和 action routes。UI Host 拒绝 batch 时，
全部 committed state 和 Selene UI stores 保持不变。

## Mutation minimality

Generated reconcile 遵守以下最小化规则：

- 新旧 ViewModel 相等：空 batch；
- 只有 leaf field 变化：只更新绑定该 field 的 target；
- retained item value 变化：不 mount/remove item root；
- keyed reorder：保留 LIS，其他 retained key 生成 `Move`；
- branch tag 不变：不 teardown branch；
- 删除 subtree：只 remove 最上层消失节点。

Mutation minimality 以语义正确和 identity 稳定为前提，不要求产生理论上的最短编辑序列。

## 相关决策

- Model ownership 与 replacement：[Model as Input](model-as-input.md)
- 用户计算与 committed ViewModel：[Computed ViewModel](computed-view-model.md)
- View record 与 lifecycle：[View State System](view-state-system.md)
- UI mutation 与 Embedded 调用边界：[Embedded View Package](embedded-view-package.md)
