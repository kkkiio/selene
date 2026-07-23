# Embedded View Package

状态：**Accepted**

本文定义 Embedded emitter 生成的 MoonBit package。游戏直接 import 这个 package，并在同一个
Selene 进程和 World 中使用它。它可以直接依赖 Selene 引擎公开 API，包括 Entity、App、Plugin、
Events、UI components 和 UI stores。

Embedded View 与游戏在同一个进程和 World 中，generated code 直接把 UI mutation 提交给
`selene/ui_view`。

## 边界

```text
game Model + XAML
        │
        ▼
      ViewIR
        │ Embedded emitter
        ▼
Embedded View package ────── import ────── game package
        │                                      │
        ├── selene/ui_view ViewHost              ├── mount / replace / apply
        ├── private View records                └── read typed action EventBus
        └── generated Plugin and EventBus
```

根 Entity 是 mounted View 的唯一公开身份。公开 API 不创建 View instance，也不返回 opaque View
handle。游戏已经拥有 Entity，View 的私有状态和 Selene UI tree 都附着于该身份。

## Package dependencies

Embedded View package 可以静态 import：

- 业务 Model 与用户拥有的 `compute_view_model`；
- `KKKIIO/selene/entity`；
- `KKKIIO/selene/event`；
- `KKKIIO/selene/app`、`ecs` 和 `system`；
- `KKKIIO/selene/ui_view`；
- Selene 的稳定 UI component、store 和 hierarchy API；
- generator 生成的 typed node、mutation 和 reconciliation code。

所有依赖在 MoonBit 编译期确定。`ViewHost` 以 concrete MoonBit API 提供 UI mutation 提交能力，
generated code 静态调用 `mount` 和 `apply`。

## Generated package

一个 package 可以由一个或一组具有同一业务 contract 的 XAML document 生成：

```text
views/inventory/
├── moon.pkg
├── state.generated.mbt
├── view.generated.mbt
├── view.generated.mbt.map.json
├── selene-xaml.lock.json
└── view_helpers.mbt               # user-owned, optional
```

Generator 只覆盖 lock 中声明为 generator-owned 的文件。业务 Model 和
`compute_view_model` 属于 `.mbti` 所描述的 business package，generated package 静态
import 它们并为使用到的 public business type 生成 type alias。

## Public API

以下以 Inventory 为例。具体 Model、Patch 和 Action 类型由业务 contract 与 XAML 决定。

```moonbit
pub fn InventoryView::mount(
  entity : @entity.Entity,
  model : @model.InventoryModel,
) -> Unit raise InventoryViewError

pub fn InventoryView::replace(
  entity : @entity.Entity,
  model : @model.InventoryModel,
) -> Unit raise InventoryViewError

pub fn InventoryView::apply(
  entity : @entity.Entity,
  patches : Array[InventoryPatch],
) -> Unit raise InventoryViewError

pub fn plugin(app : @app.App) -> @app.App

pub let action_event_bus : @event.Events[InventoryActionEvent]
```

`InventoryView` 是静态 API namespace。`mount` 成功时返回 `Unit`，调用方继续使用传入的 Entity。
`replace` 和 `apply` 同样以 Entity 定位 mounted View。

### mount

`mount(entity, model)` 执行一个原子 transaction：

1. 验证 Entity 属于当前 World、处于 alive 状态，并且尚未挂载该 View；
2. 计算完整 candidate ViewModel；
3. 生成并验证初始 UI mutation plan；
4. 通过 `ViewHost` 创建 Entity hierarchy 并写入 UI stores；
5. 以根 Entity 为 key 提交私有 View record；
6. 成功返回 `Unit`。

任一步骤失败都会撤销本次创建的 UI entities 和 stores，不留下 View record 或半棵 tree。

### replace

`replace(entity, model)` 接收新的 immutable Model snapshot。Generated code 计算 candidate
ViewModel，与 committed ViewModel 调和，验证完整 mutation plan，然后交给 `ViewHost` 原子
提交。`ViewHost` 只写 mutation 指定的组件和受影响层级；提交成功后才替换私有 record 中的
committed Model、ViewModel 和 reconciliation state。

### apply

`apply(entity, patches)` 按顺序解释 typed patch batch。Patch 首先作用于 candidate Model，随后
进入与 `replace` 相同的 computation、reconciliation 和 commit 流程。Invalid patch、duplicate
key 或 mutation validation error 都不会改变 committed state。

## Typed action EventBus

Embedded View package 生成自己的 Selene EventBus。这个全局值可以被游戏直接 import，因为 View
和游戏运行在同一个 MoonBit 进程中。

```moonbit
pub(all) enum InventoryAction {
  SelectItem(String)
  OpenHelp
  CloseHelp
}

pub(all) struct InventoryActionEvent {
  entity : @entity.Entity
  action : InventoryAction
}

pub let action_event_bus : @event.Events[InventoryActionEvent] =
  @event.Events()
```

Event 包含根 Entity，因此同一种 View 挂载多次时，游戏仍能确定 Action 来自哪个实例。

Generated plugin 负责：

- 通过 `App::add_message` 注册 `action_event_bus`；
- 注册读取 Selene UI input/event buses 的 routing system；
- 将 child Entity 或 node identity 映射回根 Entity 和当前 action route；
- 把 raw UI event 转换为 typed Action；
- 将 `InventoryActionEvent` 写入 `action_event_bus`；
- 推进 visual state transition，并清理已经销毁的 View record。

游戏不实现 generated event router，也不调用公开的 `handle_event`。游戏只读取 typed bus、更新
自己的 Model，再调用 `replace` 或 `apply`：

```moonbit
let inventory_action_reader : @event.EventReader[InventoryActionEvent] =
  @event.EventReader()

fn handle_inventory_actions(_world : @ecs.World) -> Unit {
  for event in inventory_action_reader.read(@inventory_view.action_event_bus) {
    match event.action {
      SelectItem(key) => update_selected_item(event.entity, key)
      OpenHelp => set_help_visible(event.entity, true)
      CloseHelp => set_help_visible(event.entity, false)
    }
  }
}

fn main {
  @app.App()
  .add_plugin(@plugins.default_plugin)
  .add_plugin(@inventory_view.plugin)
  .add_system(@system.PostUpdate, handle_inventory_actions)
  .run()
}
```

Event routing 与业务处理通过 EventBus 解耦。View 只发布用户意图，游戏继续拥有 Model 和业务
规则。

## Private state and lifecycle

Generated package 为每个 World 保存私有 `Map[Entity, ViewRecord]`：

```text
Embedded View record
├── committed Model snapshot
├── committed computed ViewModel
├── committed node/tree snapshot
├── active branch and keyed item state
├── node Entity and action routes
├── XAML focus-scope declarations and resolved navigation keys
└── visual transition state
```

这些 record 不通过公开 API 暴露。一个根 Entity 在同一 package 中最多挂载一次，同一 package
可以在不同 Entity 上挂载任意多个实例。

销毁根 Entity 就是销毁该 View。Selene 的 Entity lifecycle 负责级联销毁 UI 子 Entity 和清理
对应 stores；generated cleanup system 删除已经死亡根 Entity 对应的私有 record。公开 API 不提供
第二个 `release` 或 View handle lifecycle。

## Selene UI access

Embedded emitter 可以为确定的 XAML node 和 property 直接生成 typed Selene 操作。Generated code
可以使用 Entity hierarchy、UI component constructor 和 typed stores，也可以调用 Selene 提供的
concrete batch mutation function。选择依据是 atomic validation、错误语义和生成代码大小，不引入
运行时多态。

ViewIR 已经解析 node kind、property、binding 和 action route。运行时不加载 XAML schema，不执行
descriptor walker，也不通过字符串 registry 查找 component 或 property。

`FocusScope`、`AutoFocus`、`TabIndex` 和 attached `Navigation` members 进入 generated
`NodeSpec`。View Host 在完整 batch 验证后解析 stable-key navigation target，并将 active
scope root 与初始焦点投影到 Selene UI runtime。XAML key 和声明 record 留在 View Host
边界内，`selene/ui` 只观察 Entity 组成的 focus scope stack。

`Image.Tint` 以 CSS color 字符串进入 generated `NodeStyle`，支持 literal、typed Binding
和 VisualState Setter。View Host 在挂载、普通更新及可视状态过渡时把它解析成
`UiImage.tint`；`Source="atlas.json#region"` 解析出的 image region 在 tint 更新期间保持不变。

`Image.SourceRegion` 使用 `x y width height` 像素语法并进入现有的
`ImageRegion2D`，支持 literal、String Binding 和 VisualState Setter；空字符串表示不裁剪。
这个次序直接对应 spritesheet metadata 的左上角坐标与区域尺寸；它是现有
`SourceRegion` 的几何值语法，不采用 `Margin` / `Padding` 的 CSS box shorthand。
一个 Image node 的 base properties 与全部 VisualState Setter 必须统一选择 named
`atlas.json#region` 或显式 `SourceRegion`，Host 在 mutation commit 前拒绝混用。

## Error contract

公开错误至少区分：

- root Entity 已死亡或属于错误 World；
- 同一 Entity 重复 mount；
- Entity 尚未 mount 就调用 `replace` 或 `apply`；
- invalid Patch 或 duplicate item key；
- generated reconciliation validation failure；
- Selene UI mutation transaction rejection。

错误不会改变上一次成功提交的 Model、ViewModel、tree identity、action routes 或 EventBus 内容。
