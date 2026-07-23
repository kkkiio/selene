# Computed ViewModel

状态：**Accepted**

## 决策

ViewModel 是用户计算代码产生的物化展示结果：

```text
ViewModel = compute_view_model(Model)
```

`compute_view_model` 是 business contract package 中的普通 MoonBit 代码。Embedded
generated package 静态 import 它；Component Guest 使用 Guest 侧可编译的对应
computation。XAML binding 只读取 ViewModel 字段；reconcile 比较前后两个
ViewModel，不分析用户函数体。

没有自定义计算时，generator 提供语义等价于 identity projection 的默认实现，ViewModel
与 Model 具有相同的数据 shape。

## 用户计算

用户可以定义 ViewModel shape，并在计算函数中使用格式化、聚合、过滤、排序和条件逻辑：

```moonbit
pub(all) struct InventoryViewModel {
  title : String
  capacity_label : String
  can_add : Bool
  items : Array[InventoryItemViewModel]
}

pub fn compute_view_model(model : InventoryModel) -> InventoryViewModel {
  {
    title: model.title,
    capacity_label: "\{model.items.length()} / \{model.capacity}",
    can_add: model.items.length() < model.capacity,
    items: model.items.map(compute_item_view_model),
  }
}
```

```xml
<Text Text="{ui:Binding Path=capacityLabel}" />
<Button IsEnabled="{ui:Binding Path=canAdd}" />
```

自定义 ViewModel type 和计算函数位于用户拥有的 business package
source；`.mbti` 把公开 type/function contract 传给 generator。Generator 不覆盖
business source。

用户计算必须是确定性的 typed computation。它可以调用同一 business package 中的普通 MoonBit
function，但不操作 Entity、不提交 UI mutation，也不持有 durable business state。

## Reconcile

每个 mounted View 保存一个 committed ViewModel，它同时承担 presentation cache。

```text
next Model
    │ compute_view_model
    ▼
candidate ViewModel
    │ diff with committed ViewModel
    ▼
UI mutation batch
    │ accepted
    ▼
commit candidate ViewModel
```

Generator 从 XAML 建立 `ViewModel field → node/property targets` 映射。运行时按 value equality
比较 scalar、String 和 enum；nested ViewModel 按生成的 typed diff 比较；collection item 按
稳定 key 调和。字段没有变化时不生成 UI mutation。

Reconcile 另行保存 Entity、active branch 和 keyed item identity。这些数据描述具体 mounted
View，不属于 ViewModel。

Selene UI Host 拒绝 mutation batch 时，committed ViewModel 和 reconciliation state 均保持不变。

## LocalState 与 replacement

当前 contract 固定为 `compute_view_model(Model) -> ViewModel`。需要可靠跨更新
保留的输入草稿、展开状态等值进入 Model。ViewIR 保留 `LocalState` scope
kind 供未来显式 contract 使用，当前 generator 不推断或注入第二个计算参数。

Component artifact replacement 由业务侧保留 Model，先卸载旧 Guest，再用新代码重新计算
ViewModel 和 mount UI。Guest-local state 不跨 instance 保留。

## 相关决策

- Model 的定义、所有权和输入流程：[Model as Input](model-as-input.md)
- ViewModel diff、keyed identity 与 mutation planning：[Generated Reconciliation](generated-reconciliation.md)
- View 的私有调和状态：[View State System](view-state-system.md)
