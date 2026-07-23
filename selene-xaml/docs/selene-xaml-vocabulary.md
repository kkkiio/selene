# Selene XAML Vocabulary 指南

Selene XAML 由两部分组成：MS-XAML-2017 Profile 1 对象映射，以及命名空间
`urn:selene:xaml:ui` 中的 Selene UI vocabulary。本文定义后者，并说明这些名称与
WPF、WinUI、Avalonia、NoesisGUI 和 Web UI 概念之间的关系。

本文中的“组件”泛指可以出现在 XAML 中的 `ui:` 类型。只有
`ui:Component` 专指可注册、可复用的 Selene 组件。

## 先区分三个层次

| 层次 | 负责什么 | 典型名称 | Selene 中的位置 |
| --- | --- | --- | --- |
| MS-XAML-2017 对象映射规范 | 定义 XML 如何映射到 Xaml schema、object、member、text 和 markup extension infoset | namespace、object element、property element、attached member、`x:Name` | Profile 1 parser 和 infoset |
| UI 框架 vocabulary | 定义可实例化的 UI 类型、属性和运行时语义 | WPF 的 `ItemsControl`、`Grid`、`DataTemplate` | 不由 MS-XAML-2017 强制规定 |
| Selene UI vocabulary | 将选定的 UI 类型 lower 为 typed tree、binding 和 reconciliation control flow | `ui:Flex`、`ui:If`、`ui:Component` | `urn:selene:xaml:ui`、View package 与 Host adapter |

因此，`ItemsControl`、`Button` 和 `Grid` 是 WPF 等 UI 框架里的 vocabulary
名称。它们不是每个 XAML 实现都必须提供的标准类型。`x:Name`、`x:Null` 等
`x:` 项属于跨 vocabulary 的 XAML 语言设施；Selene Profile 1 只实现其中明确
列出的子集。精确的规范覆盖和偏差以
[Profile 1 conformance matrix](ms-xaml-conformance.md) 为准。

本文用以下等级描述 Selene 类型和参考物之间的一致程度：

| 等级 | 含义 |
| --- | --- |
| 高 | 用途和核心标记模型都接近，已有经验可以直接迁移 |
| 中 | 解决相同问题，但属性系统、生命周期或运行时语义有明显差异 |
| 低 | 只有局部概念可用于理解，不应期待 API 或行为兼容 |
| 无直接对应 | Selene 组合了多个生态概念，或提供了自己的结构能力 |

这些等级不表示 MS-XAML conformance。

## 生态参考物速查

`~` 表示近似概念，`—` 表示该生态没有直接的同层类型。

| Selene | WPF | WinUI 3 | Avalonia | NoesisGUI | Web / React |
| --- | --- | --- | --- | --- | --- |
| `View` | `Panel` / `Border` ~ | `Panel` / `Border` ~ | `Panel` / `Border` ~ | `Panel` / `Border` ~ | `<div>` |
| `Flex` | `StackPanel` / `WrapPanel` ~ | `StackPanel` / `ItemsWrapGrid` ~ | `StackPanel` / `WrapPanel` ~ | `StackPanel` / `WrapPanel` ~ | CSS Flexbox |
| `Grid` | `Grid` | `Grid` | `Grid` | `Grid` | CSS Grid |
| `ScrollView` | `ScrollViewer` | `ScrollViewer` | `ScrollViewer` | `ScrollViewer` | overflow container |
| `Text` | `TextBlock` | `TextBlock` | `TextBlock` | `TextBlock` | text element |
| `Span` | `Span` / `Run` | `Span` / `Run` | `Span` / `Run` | `Span` / `Run` | `<span>` |
| `Image` | `Image` | `Image` | `Image` | `Image` | `<img>` |
| `Button` | `Button` | `Button` | `Button` | `Button` | `<button>` |
| `ItemsControl` | `ItemsControl` | `ItemsControl` | `ItemsControl` | `ItemsControl` | list rendering ~ |
| `If` | trigger / `Visibility` ~ | `x:Load` / `Visibility` ~ | conditional class / binding ~ | trigger / `Visibility` ~ | conditional rendering |
| `DataTemplate` | `DataTemplate` | `DataTemplate` | `DataTemplate` | `DataTemplate` | template / JSX fragment ~ |
| `Component` | `UserControl` / custom control | `UserControl` / custom control | `UserControl` / `TemplatedControl` | `UserControl` / custom control | component / custom element |
| `Parameter` | dependency property ~ | dependency property ~ | styled property ~ | dependency property ~ | props / attributes |
| `Slot` | `ContentPresenter` ~ | `ContentPresenter` ~ | `ContentPresenter` ~ | `ContentPresenter` ~ | `<slot>` / `children` |
| `VisualStateGroup` | `VisualStateGroup` | `VisualStateGroup` | style/pseudo-class group ~ | `VisualStateGroup` | state model ~ |
| `VisualState` | `VisualState` | `VisualState` | style/pseudo-class ~ | `VisualState` | state/class ~ |
| `Setter` | style setter / storyboard ~ | visual-state `Setter` | style `Setter` | style setter / storyboard ~ | style assignment ~ |
| `Transition` | `VisualTransition` | `VisualTransition` | property transition | `VisualTransition` | CSS transition |
| `Binding` | `{Binding}` | `{Binding}` / `{x:Bind}` | `{Binding}` | `{Binding}` | reactive projection ~ |
| `TemplateBinding` | `{TemplateBinding}` | `{TemplateBinding}` | `{TemplateBinding}` | `{TemplateBinding}` | component parameter read ~ |

## 可视类型

布局容器（`View`、`Flex`、`Grid`、`ScrollView`）及通用 box/alignment/positioning/overflow
模型详见 [Selene CSS Layout](selene-css-layout.md)。本节只列出非布局的可视类型。

| 类型 | Selene 定义 | 最接近参考物 | 一致程度 | 关键差异与取舍 |
| --- | --- | --- | --- | --- |
| `Text` | 文本 Entity；支持纯文本属性、排版属性及由 `Span` 组成的富文本 | XAML `TextBlock`；HTML text element | 高 | 提供常用字体、颜色、对齐、换行和溢出选项；没有完整 typography、inline 类型层级和文本编辑模型。固有尺寸由 layout engine 按约束宽度和换行规则 measure。 |
| `Span` | `Text` 内的富文本片段，也保留 Entity 以支持动态 binding | XAML `Span`/`Run`；HTML `<span>` | 高 | runtime 会把片段汇总成父 `Text` 的稳定 span 列表；格式限定为文本、字体、颜色、粗体和下划线。 |
| `Image` | 由 `Source` 加载图像，支持 `Fit`、`Tint`、`SourceRegion` 和 `atlas.json#region` | XAML `Image`；HTML `<img>` | 高 | `Fit` 使用 `Stretch`、`Contain`、`Cover`、`None`（对标 CSS `object-fit`）；Selene `atlas` 可导入 canonical Selene、Aseprite 和 TexturePacker JSON，并把命名 region 解析成同一 ImageHandle 的 `ImageRegion2D`。固有尺寸来自 region 或普通图片资源。 |
| `Button` | 可交互、可聚焦的多子节点容器；事件名映射到 runtime 注册的 action | 各 XAML 框架的 `Button`；HTML `<button>` | 中 | 交互和焦点由 ECS stores 与 systems 驱动，action 接收 `XamlActionContext`；没有 routed event、command、control template 和框架级样式系统。 |

## 数据与结构类型

| 类型 | Selene 定义 | 最接近参考物 | 一致程度 | 关键差异与取舍 |
| --- | --- | --- | --- | --- |
| `ItemsControl` | 用 `ItemsSource` 数组和 `ItemTemplate` 重复生成内容；`KeyPath` 可读取稳定 String/Int key | WPF、WinUI、Avalonia、NoesisGUI `ItemsControl` | 高 | 保留熟悉的 `ItemsSource` + `ItemTemplate` 模型。ViewModel replacement 或 typed patch 按 key 局部调和并保留 item host Entity，重复 key 在 mutation 前失败；没有直接 `Items`、ItemsPanel、collection view、选择、虚拟化或隐式 observable collection。省略 `KeyPath` 时使用数组索引。 |
| `If` | 根据 `Condition` 的 truthy 值实例化 `Then` 或 `Else` 子树 | React 条件渲染；XAML trigger/visibility | 中 | 条件控制 instance tree 结构，ViewModel replacement 只替换发生变化的分支。XAML 框架常通过 `Visibility`、trigger 或 converter 保留节点；Selene 选择显式结构节点以适配 ECS 生命周期。 |
| `DataTemplate` | 保存一组可按 item data 实例化的 `Content`，当前由 `ItemsControl.ItemTemplate` 使用 | XAML `DataTemplate` | 高 | item 成为模板内容的 data scope；没有 `DataType`、resources、template selector、hierarchical template 或任意框架对象的隐式模板查找。 |

## 组件化类型

| 类型 | Selene 定义 | 最接近参考物 | 一致程度 | 关键差异与取舍 |
| --- | --- | --- | --- | --- |
| `Component` | 可注册模板的根类型，声明 QName、parameters 和 content；实例拥有隔离的内部 namescope | XAML `UserControl`/custom control；Web Component | 中 | runtime 以精确 namespace URI + type name 注册，支持可选 spawn callback，并拒绝递归组件引用；没有 CLR 类继承、code-behind、resources、style 或 control-template 查找。 |
| `Parameter` | 声明组件输入的名称、类型、默认值和 required 约束 | XAML dependency/styled property；React props | 中 | 支持 String、Bool、Int、Double、Val、Color 和通用 Data 的紧凑类型集合；在组件边界做转换和校验，未提供 dependency property metadata、继承、优先级或双向写回。 |
| `Slot` | 在组件模板中声明默认或命名投影点，并可包含 fallback 子树 | Web Components `<slot>`；XAML `ContentPresenter` | 高（Web）/中（XAML） | 调用方以 attached `ui:Slot` 选择投影点；投影内容保持调用方 data 和 namescope，模板内部保持组件 namescope。没有 Shadow DOM API 或 WPF content property/template selector 体系。 |

## 状态类型

| 类型 | Selene 定义 | 最接近参考物 | 一致程度 | 关键差异与取舍 |
| --- | --- | --- | --- | --- |
| `VisualStateGroup` | 一组互斥状态，包含 `States`、`Transitions` 和可 binding 的 `Current` | WPF、WinUI、NoesisGUI `VisualStateGroup` | 高 | 没有 `Current` 的 group 由 Host 的 Normal、Hovered、Focused、Pressed、Disabled 状态驱动，业务 group 由 typed `Current` binding 驱动；没有可替换的 VisualStateManager。Avalonia 更接近以 pseudo-class/style 表达状态。 |
| `VisualState` | 命名状态及其有序 setter 列表 | WinUI `VisualState`；WPF/Noesis `VisualState` | 高 | Selene 直接叠加 property values；没有 Storyboard、StateTrigger 或任意 animation object tree。多个 group 按声明顺序形成确定的覆盖层。 |
| `Setter` | 将 `Value` 写到 owner 或 `TargetName` 指向的节点属性 | WinUI visual-state `Setter`；XAML style setter | 高（WinUI）/中（WPF、Noesis） | 目标必须位于正确 namescope，属性必须属于 runtime 支持的 ECS 投影；没有样式 selector、资源引用和完整 dependency property precedence。 |
| `Transition` | 用 `From`、`To`、`Duration`、`Delay`、`Easing` 描述状态切换 | XAML `VisualTransition`；CSS transition | 中 | Color、Double 和同单位 layout value 可插值，其他值离散切换；支持 Linear、EaseIn、EaseOut、EaseInOut，并可从中断时当前值继续。省去 Storyboard、keyframe 和自定义 easing 对象。 |

## 标记扩展

| 类型 | Selene 定义 | 最接近参考物 | 一致程度 | 关键差异与取舍 |
| --- | --- | --- | --- | --- |
| `Binding` | `{ui:Binding Path=...}` 从当前 typed ViewModel scope 读取字段并写入属性 | XAML `{Binding}` | 中 | 只有 source-to-target；Model replacement 或 typed patch 先计算 candidate ViewModel，再更新发生变化的字段。没有 runtime `DataContext` 继承对象、TwoWay/OneTime mode、converter、fallback、validation、ElementName 或自动属性通知。typed scope 让数据变化边界与 ECS mutation 明确。 |
| `TemplateBinding` | `{ui:TemplateBinding ...}` 从当前组件 parameter map 读取值 | XAML `{TemplateBinding}` | 中 | 指向 `ui:Parameter`，并非 templated parent 的 dependency property；只承担组件模板内的轻量 parameter 投影。 |

两种扩展都接受位置参数或 `Path=...`。`.` 和空路径表示当前 data 值；路径可
穿过 object 字段和 array 索引。

## XAML 语言层 vocabulary

以下项目属于解析和对象映射层。infoset 中存在某个 directive，不等于 runtime
具备完整 CLR/WPF 构造语义。

| 语法或名称 | 来源 | Profile 1 行为 | Runtime 边界 |
| --- | --- | --- | --- |
| object element 与 property element | MS-XAML 对象映射 | `<ui:Text>` 创建 object node；`<ui:ItemsControl.ItemTemplate>` 设置已注册 member | 只能使用 schema registry 中的精确类型和 member；未知 non-ignorable 名称报错 |
| attached member | MS-XAML 对象映射 | `ui:Grid.Row`、`ui:Grid.Column`、`ui:Slot` 必须由 owner schema 声明为 attached | 按各 vocabulary 的 Implemented/Planned 状态投影，没有通用 getter/setter metadata |
| `x:Name` | 标准 `x:` directive | 进入 namescope；和 Selene `Id` 共享唯一性约束 | runtime 可用它解析 target、watch、导航、state target 和 name-restored reload state |
| `x:Class` | 标准 `x:` directive | 只允许在 document root，决定公开 generated View type 名称 | 保留 MoonBit generated type 命名，不提供 CLR class construction/inheritance |
| `x:Items` | 标准 `x:` directive | parser 接受并保存在 infoset | 没有通用 list/dictionary 构造；重复数据 UI 使用 `ui:ItemsControl` |
| `x:Initialization` | 标准 `x:` directive | parser 接受 text/object values 并保存在 infoset | 没有 CLR 初始化或任意对象构造协议 |
| `x:PositionalParameters` | 标准 `x:` directive | parser 接受并保存在 infoset | 没有通用 constructor invocation；markup extension 自己解释位置参数 |
| `{x:Null}` | 标准 `x:` markup extension | 求值为 `XamlData::Null` | 可用于 Profile 1 支持的 value/member；没有完整 nullable type metadata |
| `{x:Reference name}` | 标准 `x:` markup extension | 名称在正确的组件或调用方 namescope 中解析 | EntityReference 成员在构造后连接；不会向任意 member 暴露通用对象引用 |
| `{x:Type prefix:Name}` | 标准 `x:` markup extension | 使用 namespace map 和 schema registry 校验类型 | 结果是 symbolic type name，不创建通用 runtime `XamlType` 对象 |
| `xml:space` | XML namespace | 支持 `default` 和 `preserve`，控制 text normalization | 只影响 parser 生成的 text nodes |
| `mc:Ignorable` | XAML Markup Compatibility | 忽略列出的设计时 namespace 中的 attribute/element | 未实现 `ProcessContent`、`AlternateContent`、preservation 等完整 MC vocabulary |

Selene 使用标准 `x:` namespace：
`http://schemas.microsoft.com/winfx/2006/xaml`。`ui:` namespace 是
`urn:selene:xaml:ui`。前缀名称可以变化，namespace URI 决定身份。

## Selene 的总体取舍

- **ECS-native runtime**：generated View 通过 Selene UI Host 创建 Entity 并写入 Selene UI stores，公开 View 身份始终是根 Entity。
- **CSS-first 布局**：尺寸、box、alignment、Flex、Grid、positioning 和 overflow 优先对标 CSS 与 Taffy 引擎；布局模型详见 [Selene CSS Layout](selene-css-layout.md)。
- **显式数据通知**：Model replacement 与 typed patch 是 binding 和结构更新边界；idle frame 不轮询或重写未变化的 stores。
- **局部结构调和**：`If` 只替换变化分支，keyed `ItemsControl` 只替换受影响 item；文件 reload 采用验证后整体替换，并恢复 host 与按名称保存的状态。
- **轻量组件与状态系统**：typed parameters、slots、namescope、setter overlays 和有限 transition 覆盖声明式游戏 UI 的核心需求，避免引入 CLR reflection、完整 dependency property、resource/style 和 Storyboard 子系统。

## Vocabulary automated coverage

Parser acceptance 只表示名称和 object/member mapping 可以进入 infoset。Generated View / Host
一列才表示当前生成和 ECS 投影路径已经具备自动化覆盖。

| 类型 | Parser / infoset | Generated View / Host |
| --- | --- | --- |
| `View` | Accepted | `CG-VIEW-01`, `INVENTORY-01` |
| `Flex` | Accepted | `CG-VIEW-01`, `CG-LAYOUT-01`, `INVENTORY-01`, `INVENTORY-LAYOUT-01` |
| `ScrollView` | Accepted | `CG-VIEW-01`, `CG-LAYOUT-01`, `INVENTORY-01`, `INVENTORY-LAYOUT-01` |
| `Text` | Accepted | `CG-VIEW-01`, `INVENTORY-01`, `CH-INCREMENTAL-01` |
| `Span` | Accepted | — |
| `Image` | Accepted | `CG-VIEW-01`, `INVENTORY-01`, `CH-VISUAL-STATE-01` |
| `Button` | Accepted | `CG-VIEW-01`, `INVENTORY-01`, `CH-EVENT-01`, `CH-VISUAL-STATE-01` |
| `Grid` | `PC-INFOSET-01` | Planned |
| `ItemsControl` | Accepted | `CG-VIEW-01`, `INVENTORY-01` |
| `If` | Accepted | `CG-VIEW-01`, `INVENTORY-01` |
| `DataTemplate` | Accepted | `CG-VIEW-01`, `INVENTORY-01` |
| `Binding` | Accepted | `VI-IR-01`, `VI-IR-03`, `CG-VIEW-01`, `INVENTORY-01` |
| `TemplateBinding` | Accepted | — |
| `Component` / `Parameter` / `Slot` | Accepted | — |
| visual states 与 transitions | Accepted | `VI-IR-04`, `CH-VISUAL-STATE-01`, `INVENTORY-01` |
| `x:Reference` | Accepted | — |
| 热重载 | N/A | `CH-RELOAD-01` |
| UI mutation 增量提交 | N/A | `CH-INCREMENTAL-01` |
| World 隔离 | N/A | `CH-BROWSER-01` |

## 官方参考资料

- [MS-XAML-2017 Xaml Schema Information Set](https://learn.microsoft.com/en-us/openspecs/microsoft_domain_specific_languages/ms-xaml-2017/b9b26f10-5e6c-4e93-b82a-198f1d11d3ab)
- [MS-XAML `x:` Schema](https://learn.microsoft.com/en-us/openspecs/microsoft_domain_specific_languages/ms-xaml/8b8949ad-2d26-4ec5-913e-1df1ebd5e78c)
- [Selene CSS Layout](selene-css-layout.md)
- [WPF Data Templating Overview](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/data/data-templating-overview)
- [WinUI Data Binding in Depth](https://learn.microsoft.com/en-us/windows/apps/develop/data-binding/data-binding-in-depth)
- [WinUI `VisualState.Setters`](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.visualstate.setters?view=windows-app-sdk-1.8)
- [Avalonia `ItemsControl`](https://docs.avaloniaui.net/controls/data-display/collections/itemscontrol)
- [Avalonia Style Classes and Pseudoclasses](https://docs.avaloniaui.net/docs/styling/style-classes)
- [NoesisGUI Architecture](https://www.noesisengine.com/docs/Gui.Core.Architecture.html)
- [NoesisGUI Binding](https://www.noesisengine.com/docs/Gui.Core.Binding.html)
- [CSS Flexbox](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Flexible_box_layout/Basic_concepts)
- [Web Components Templates and Slots](https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_templates_and_slots)
- [React Conditional Rendering](https://react.dev/learn/conditional-rendering)
