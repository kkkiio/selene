# ViewIR

状态：**Accepted**

本文定义 Selene XAML compiler 的 `ViewIR`。`ViewIR` 是 Infoset 与 generated source 之间的
typed semantic representation，由 Embedded emitter 和 Component emitter 读取。

```text
XAML + business contract
           │
           ▼
         Infoset
           │ vocabulary/type lowering
           ▼
         ViewIR
        ┌────┴────┐
        │         │
Embedded emitter  Component emitter
        │         │
Embedded View     Component Guest
package           package
```

Embedded 和 Component 可以在两次独立 generator invocation 中分别构造等价的 `ViewIR`。共享的是
IR schema、lowering 规则和行为测试，不要求共享同一个内存对象、生成目录或 runtime source。

## Purpose

Infoset 保留 XAML language 的对象、成员、文本、namespace、directive 和 source span。`ViewIR`
进一步完成 Selene vocabulary 与业务 contract 的语义解析：

- UI type 和 property 已解析为确定的 vocabulary symbol；
- literal 已转换成 typed constant；
- binding path 已解析到确定的 data scope、field 和 result type；
- `If`、keyed collection 和 template identity 已显式建模；
- raw UI event 已连接到 typed Action route；
- emitter 所需的 Host capability 已完整收集；
- 所有 generated expression 都能追溯到 XAML source span。

Emitter 只决定这些语义如何投影到具体 runtime API。它不重新解析 XAML member、binding path、
collection key 或 Action 名称。

## Invariants

一个有效的 `ViewIR` 满足以下 invariant：

1. 所有 XAML type、member、directive 和 markup extension 都已经解析；
2. 所有 node、data scope、binding 和 action route 都有稳定且唯一的 ID；
3. 每个 binding source path 和 target property 都有确定类型；
4. 每个 structural node 的 identity policy 已确定；
5. 每个 dynamic collection 的 key path 存在、类型稳定且可比较；
6. 每个 Action variant 与 payload expression 已通过业务 contract 检查；
7. namescope、template scope 和 item data scope 没有悬空引用；
8. required capabilities 可以被所选 emitter 和对应 Host contract 完整实现；
9. 所有 diagnostic-bearing symbol 都保留原始 source span；
10. validation 完成后 `ViewIR` 只读，emitter 不修改它。

Lowering 收集多个 diagnostic 后统一失败，不向 emitter 传递 partially valid IR。

## Top-level shape

下面的 MoonBit 类型用于说明结构，最终字段名称可以随实现调整，但边界和所有权保持稳定：

```moonbit
pub(all) struct ViewIR {
  identity : IRViewIdentity
  contract : IRBusinessContract
  root : IRNode
  data_scopes : Array[IRDataScope]
  bindings : Array[IRBinding]
  action_routes : Array[IRActionRoute]
  required_capabilities : Array[IRCapability]
}
```

ID 使用 compiler 内部的 deterministic value。Array 与 map 在 seal 前按稳定 ID 排序，保证相同输入
产生逐 byte 一致的 generated source、source map 和 inspect snapshot。

## View identity

```moonbit
pub(all) struct IRViewIdentity {
  view_name : String
  source_uri : String
  span : @infoset.XamlSourceSpan
}
```

`view_name` 来自 `x:Class` 或 deterministic filename convention。Output directory、package alias、
ownership lock 和 artifact filename 属于 generate request，不进入 `ViewIR`。

## Business contract

`.mbti` 和 WIT 先分别解析成 compiler 内部的 resolved business contract。`ViewIR` 只保存当前 View
实际使用的 semantic type 和 symbol reference：

```text
IRBusinessContract
├── Model type
├── computed ViewModel type
├── Patch type and supported operations
├── Action type and variants
└── referenced item/value types
```

`IRTypeRef` 表达 Bool、Int、Double、String、Option、Array、record、variant 和 named business type
等语义 shape。MoonBit package alias、wit-bindgen binding path 和 generated FFI name 属于 emitter 的
contract projection，不参与 binding 或 reconciliation 语义判断。

Embedded generation 通常从 `.mbti` 构造 resolved contract；Component generation 从 selected WIT
world/business interface 构造 resolved contract。等价 contract 应产生等价的 ViewModel field、Patch operation
和 Action variant 语义。

## Data scopes

每个 binding 都属于明确的 data scope：

```moonbit
pub(all) struct IRDataScope {
  id : IRDataScopeId
  parent : IRDataScopeId?
  value_type : IRTypeRef
  kind : IRDataScopeKind
  span : @infoset.XamlSourceSpan
}

pub(all) enum IRDataScopeKind {
  RootViewModel
  TemplateItem
  LocalState
}
```

根 scope 的 value type 是 computed ViewModel。每个 keyed item template 创建独立 item scope；以后引入
DataTemplate 或显式 LocalState 时使用相同的 scope 机制。Binding path 不能隐式穿过 template 或
namescope boundary。

Data scope 参考 WinUI compiled binding 中的 `BindUniverse` 思路，但 Selene 不记录 INPC listener、
TwoWay setter 或 binding phase。Selene 使用 immutable Model、computed ViewModel 和显式
`replace/apply` transaction。

## Typed node tree

```moonbit
pub(all) enum IRNode {
  Element(IRElement)
  Conditional(IRConditional)
  KeyedItems(IRKeyedItems)
}
```

### Element

```moonbit
pub(all) struct IRElement {
  id : IRNodeId
  kind : IRNodeKind
  data_scope : IRDataScopeId
  properties : Array[IRProperty]
  children : Array[IRNode]
  span : @infoset.XamlSourceSpan
}
```

`IRNodeId` 由显式 `x:Name` 或 deterministic authored path 产生。它在同一 ViewIR 中唯一，并作为
generated reconciliation、event connection、source map 和 Host node key 的共同 identity。动态
item 内的实际 runtime identity 由 template node ID 与 item key 组合。

`IRNodeKind` 与 `IRPropertyKind` 引用 Selene XAML vocabulary symbol。它们不保存 Selene Entity、
UI store address、WIT enum encoding 或 MoonBit source spelling。

```moonbit
pub(all) struct IRProperty {
  kind : IRPropertyKind
  target_type : IRTypeRef
  value : IRValue
  span : @infoset.XamlSourceSpan
}

pub(all) enum IRValue {
  Constant(IRConstant)
  Binding(IRBindingId)
}
```

Literal conversion 在 lowering 阶段完成。Emitter 不解析 color、length、enum 或其他 XAML text
syntax。

### Conditional

```moonbit
pub(all) struct IRConditional {
  id : IRNodeId
  condition : IRBindingId
  then_branch : Array[IRNode]
  else_branch : Array[IRNode]
  span : @infoset.XamlSourceSpan
}
```

Condition binding 的 result type 必须是 Bool。IR 保留两个 branch 和稳定 identity boundary；active
branch、branch-local runtime state 和 teardown mutation 属于 mounted View runtime。

### Keyed items

```moonbit
pub(all) struct IRKeyedItems {
  id : IRNodeId
  items : IRBindingId
  item_scope : IRDataScopeId
  key_path : IRBindingPath
  template : Array[IRNode]
  span : @infoset.XamlSourceSpan
}
```

Lowering 验证 collection item type、key field 和 key type。IR 表达稳定 identity policy，不保存某次
运行时 collection 的 key order、epoch、LIS 或 item record。

## Bindings

Binding 与 tree 分开保存，避免一个 source path 绑定多个 target 时重复解析：

```moonbit
pub(all) struct IRBinding {
  id : IRBindingId
  scope : IRDataScopeId
  path : IRBindingPath
  result_type : IRTypeRef
  dependencies : Array[IRFieldRef]
  targets : Array[IRBindingTarget]
  span : @infoset.XamlSourceSpan
}

pub(all) struct IRBindingTarget {
  node : IRNodeId
  property : IRPropertyKind
  target_type : IRTypeRef
  conversion : IRConversion?
  span : @infoset.XamlSourceSpan
}
```

`IRBindingPath` 是 resolved typed step sequence，不保存原始字符串：

```text
RootViewModel
  → field inventory
  → field selected_item
  → field display_name : String
```

每个 step 保存 declaring type、result type、nullable/optional navigation 和原始 token span。
`dependencies` 是 computation 后可以观察的 ViewModel field dependency；generated diff 用它建立
`field → target` equality gate。

User-defined `compute_view_model` 对 compiler opaque。ViewIR 不表达用户函数内部 dependency graph；
每次 Model replacement 先计算完整 candidate ViewModel，再从 IR binding dependencies 开始 typed
diff。

## Action routes

Event member lower 为独立 route：

```moonbit
pub(all) struct IRActionRoute {
  id : IRActionRouteId
  source_node : IRNodeId
  source_scope : IRDataScopeId
  event_kind : IRUiEventKind
  action_variant : IRVariantRef
  payload : IRActionPayload?
  span : @infoset.XamlSourceSpan
}
```

`payload` 可以引用当前 item scope 的 stable key 或经过类型检查的 ViewModel field。Lowering 确保
payload type 与 Action variant payload 一致。

Embedded emitter 将 route 生成成 Selene raw UI event 到 typed action EventBus 的映射。Component
emitter 将 route 生成成 WIT `handle-event` 的 match 和 `option<Action>` 返回值。两边不能重新解释
authored Action string。

## Required capabilities

Lowering 从 node、property、binding target 和 event route 收集 deterministic capability set：

```text
node kinds
property mutations
raw UI event kinds
focus/scroll requirements
asset/value conversions
```

Embedded emitter 检查所需能力都有 concrete Selene API。Component emitter 检查 selected Host WIT
package 可以表达这些能力，并把 capability set 纳入 ABI fingerprint。缺失能力是 generation error，
不能静默跳过 property 或 event。

## Lowering passes

`ViewIR` 通过有序 pass 构建。每个 pass 只接收满足前一阶段 invariant 的输入：

1. **Vocabulary resolution**：把 Infoset type/member 映射到 Selene vocabulary symbol；
2. **Contract resolution**：解析 Model、ViewModel、Patch、Action 和 item types；
3. **Scope construction**：建立 root、template item、namescope 和 local-state boundary；
4. **Node identity**：分配并验证 deterministic node ID；
5. **Value lowering**：把 literal 和 markup extension 转换为 typed `IRValue`；
6. **Binding lowering**：解析 typed path、dependency 和 target assignment；
7. **Structural lowering**：建立 `Conditional`、`KeyedItems` 和 template identity；
8. **Action lowering**：解析 event kind、Action variant 和 payload；
9. **Capability collection**：计算两个 emitter 需要实现的 vocabulary capability；
10. **Validation and seal**：检查引用完整性、类型、identity、排序和 source span。

Pass 可以使用 private mutable builder。最终 `ViewIR` 不公开 mutation API。

## Emitter contract

两个 emitter 可以独立决定：

- package/module layout；
- generated MoonBit type spelling 和 import alias；
- runtime record layout；
- Selene Entity object 或 WIT Entity UInt 的具体调用；
- EventBus 或 WIT Action return 的投影；
- source formatting 和 target-specific optimization。

两个 emitter 必须直接采用 ViewIR 已确定的 node identity、typed binding、structural scope、Action route
和 capability。Emitter 中不出现 XAML member lookup、binding string parsing、Action name parsing 或
collection key type inference。

## Compile-time ViewIR and runtime MutationPlan

`ViewIR` 与 `MutationPlan` 生命周期不同：

| structure | produced by | lifetime | content |
| --- | --- | --- | --- |
| `ViewIR` | generator lowering | compile time | static typed View semantics |
| `MutationPlan` | generated reconciliation | one `mount/replace/apply` transaction | concrete runtime tree changes |

`ViewIR` 不保存 committed Model、candidate ViewModel、active branch、item order、Host Entity 或 Guest
record。Generated source 使用 ViewIR 固化的控制流，在每次更新时创建和验证 `MutationPlan`。

## Diagnostics and testing

ViewIR 节点保存精确 source span。Lowering diagnostic 直接定位 XAML；emitter diagnostic 通过
`IRNodeId`、`IRBindingId` 或 `IRActionRouteId` 找回 source span；Moon compiler diagnostic 继续通过
generated `.mbt.map.json` 映射。

Compiler tests 使用稳定的 semantic `inspect` snapshot 覆盖：

- typed node tree；
- data scope 和 resolved binding path；
- `If` 与 keyed template identity；
- Action route 和 payload；
- required capability；
- diagnostic 与 source span。

ViewIR inspect 只用于 compiler test 和诊断，不作为 checked-in runtime artifact、plugin ABI 或公开
serialization format。

## Excluded data

以下内容不进入 `ViewIR`：

- Selene Entity、World、UI store 或 EventBus；
- WIT Entity value、Canonical ABI handle 或 Wasm instance；
- `ComponentHost` trait、trait object 或 Host registry；
- generated MoonBit source、output path、ownership lock 或 artifact filename；
- committed Model/ViewModel、branch/item runtime state 或 `MutationPlan`；
- Wasmtime、JCO、browser bridge 或 packaging configuration；
- runtime XAML descriptor、interpreter instruction 或 serialized BAML/XBF equivalent。

## GenerationPlan migration

`GenerationPlan`、`PlanNode`、`PlanProperty` 和 `PlanValue` 已由 typed ViewIR 替换。
Business contract normalization、collection/binding/Action analysis 和 capability collection 都在
emitter 之前完成。Embedded emitter 和 Component emitter 分属独立 package，并对同一
ViewIR behavior fixture 运行 semantic snapshot/compile test。

这是 `0.x` compiler internal breaking change，没有 `GenerationPlan` alias 或双 IR adapter。

## Ecosystem references

### WPF and System.Xaml

- [`XamlNodeType`](https://learn.microsoft.com/en-us/dotnet/api/system.xaml.xamlnodetype?view=windowsdesktop-10.0)
  定义 `StartObject`、`StartMember`、`Value`、`EndMember`、`EndObject` 和 namespace node stream。
- [`XamlNodeList`](https://github.com/dotnet/wpf/blob/main/src/Microsoft.DotNet.Wpf/src/System.Xaml/System/Xaml/XamlNodeList.cs)
  缓存并重放通用 XAML node stream；Selene Infoset 承担对应层次的职责。
- [`BamlRecords.cs`](https://github.com/dotnet/wpf/blob/main/src/Microsoft.DotNet.Wpf/src/PresentationFramework/System/Windows/Markup/BamlRecords.cs)
  展示 element/property、collection、event、connection ID、deferred content、resource 和 source line
  的 compiled record vocabulary。
- [WPF globalization and BAML workflow](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/wpf-globalization-and-localization-overview)
  说明 BAML 是 WPF 的 compiled XAML form 和发布资源。

Selene 借鉴 source location、stable connection identity 和 deferred structural boundary。BAML 的
serialized object-writer record stream 不作为 ViewIR 形态。

### WinUI

- [`XamlDomNode`](https://github.com/microsoft/microsoft-ui-xaml/blob/main/src/XamlCompiler/BuildTasks/Microsoft/Xaml/XamlDom/XamlDomNode.cs)、
  [`XamlDomObject`](https://github.com/microsoft/microsoft-ui-xaml/blob/main/src/XamlCompiler/BuildTasks/Microsoft/Xaml/XamlDom/XamlDomObject.cs) 和
  [`XamlDomMember`](https://github.com/microsoft/microsoft-ui-xaml/blob/main/src/XamlCompiler/BuildTasks/Microsoft/Xaml/XamlDom/XamlDomMember.cs)
  展示 resolved type/member、source range 与 validation 后 seal 的 typed DOM。
- [`ConnectionIdElement`](https://github.com/microsoft/microsoft-ui-xaml/blob/main/src/XamlCompiler/BuildTasks/Microsoft/Xaml/XamlCompiler/ConnectionIdElement.cs)
  将 node identity、field、event、binding、template/namescope 和 deferred-load 信息组织为 codegen
  side model。
- [`BindPathStep`](https://github.com/microsoft/microsoft-ui-xaml/blob/main/src/XamlCompiler/Microsoft.UI.Xaml.Markup.Compiler.Parsing/BindPathStep.cs)
  将 compiled binding 表达为 typed path、assignment 和 dependency/dependent graph。
- [`ObjectWriterNodeType`](https://github.com/microsoft/microsoft-ui-xaml/blob/main/dxaml/xcp/core/inc/ObjectWriterNodeType.h)
  定义 create type、set value、collection/dictionary、resource、connection 和 conditional scope 等
  XBF object-writer instruction。
- [WinUI XAML compiler design note](https://github.com/microsoft/microsoft-ui-xaml/blob/main/docs/design-notes/xamlcompiler.md)
  记录 XamlDom、type universe、binding parser、connection ID 和 two-pass code generation。

Selene 主要借鉴 sealed semantic model、binding side graph、data scope 和 event connection。XBF
instruction stream 面向 object construction，不能承载 Selene 的 runtime reconciliation contract。

### Avalonia XamlX

- [`XamlCompiler`](https://github.com/AvaloniaUI/XamlX/blob/master/src/XamlX/Compiler/XamlCompiler.cs)
  依次运行 directive、type reference、property reference、content、assignment、constructable object
  和 simplification transformer，再交给 backend emitter。
- [AST interfaces](https://github.com/AvaloniaUI/XamlX/blob/master/src/XamlX/Ast/Common.cs)、
  [XAML AST nodes](https://github.com/AvaloniaUI/XamlX/blob/master/src/XamlX/Ast/Xaml.cs) 和
  [CLR-resolved nodes](https://github.com/AvaloniaUI/XamlX/blob/master/src/XamlX/Ast/Clr.cs)
  区分 value、manipulation、type reference、property reference 和 resolved assignment/new-object node。

Selene 借鉴 ordered transform、pass invariant、typed resolution 和 backend separation。ViewIR node
保持 pure data，不实现 Embedded 或 Component emit method。

### .NET MAUI XamlC

- [`XamlNode.cs`](https://github.com/dotnet/maui/blob/main/src/Controls/src/Xaml/XamlNode.cs)
  使用 `ElementNode`、`ValueNode`、`MarkupNode` 和 `ListNode` 构造简洁 AST。
- [`XamlCTask.cs`](https://github.com/dotnet/maui/blob/main/src/Controls/src/Build.Tasks/XamlCTask.cs)
  依次运行 markup expansion、platform simplification、object creation、namescope、field、resource 和
  property visitor。
- [.NET MAUI XAML processing](https://learn.microsoft.com/en-us/dotnet/maui/xaml/xamlc)
  记录 runtime inflation、XamlC IL 和 C# source generation 三种交付方式。

Selene 借鉴显式 pass ordering 和 generated source workflow。Type/binding/action analysis 必须在
ViewIR lowering 中完成，避免分散到两个 backend visitor。

## Related decisions

- [Embedded View Package](embedded-view-package.md)
- [WebAssembly Component Guest Package](wasm-component-guest-package.md)
- [WebAssembly Component Host](wasm-component-host.md)
- [Model as Input](model-as-input.md)
- [Computed ViewModel](computed-view-model.md)
- [Generated Reconciliation](generated-reconciliation.md)
