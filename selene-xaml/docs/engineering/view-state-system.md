# View State and Lifecycle

状态：**Accepted**

View runtime state 由 generated package 私有持有。游戏只使用 Entity-based generated API
和 typed EventBus，不查询 View record 或 runtime handle。

## Embedded View record

Embedded generated package 以根 Selene Entity 为 key 保存私有 record：

```text
Embedded View record
├── committed Model
├── committed computed ViewModel
├── committed node/tree snapshot
├── branch and keyed-item reconciliation state
└── node identity and action routes
```

`mount(entity, model)` 计算初始 ViewModel/tree，Host 提交成功后才写入 record。
`replace` 和 `apply` 先构造 candidate Model/ViewModel/mutation plan，完整验证并应用
Host batch 后才更新 committed record。任何失败都保留上一次成功状态。

销毁根 Entity 就是销毁 Embedded View。Selene lifecycle 级联清理 UI children 和
stores，generated plugin 删除已死 Entity 对应的私有 record。

## Identity and reconciliation

Embedded runtime 遵守 ViewIR 确定的 identity policy：

- authored node 使用 stable node ID；
- keyed item 使用 template node ID 与 item key 组合身份；
- retained item 保留 Host identity 和 focus；
- conditional branch 只在 condition 变化时 teardown/mount；
- Patch batch 按顺序作用于 candidate Model，duplicate/missing key 在 commit 前拒绝。

Runtime 不重新解析 XAML、binding path 或 Action 名称。详细 mutation algorithm 见
[Generated Reconciliation](generated-reconciliation.md)。
