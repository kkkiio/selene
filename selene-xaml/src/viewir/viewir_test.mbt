///|
test "VI-IR-01 seals Model, ViewModel, scopes, bindings, actions, and capabilities" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"
    #| xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:contract="moonbit:example/inventory/view"
    #| x:Class="InventoryView" ui:DataType="contract:InventoryViewModel" x:Name="root">
    #| <ui:Text Text="{ui:Binding Path=title}" />
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=items}" KeyPath="id">
    #|  <ui:ItemsControl.ItemTemplate>
    #|   <ui:DataTemplate ui:DataType="contract:InventoryItemViewModel">
    #|    <ui:Button x:Name="row" OnClick="select_item">
    #|     <ui:Text Text="{ui:Binding Path=label}" />
    #|    </ui:Button>
    #|   </ui:DataTemplate>
    #|  </ui:ItemsControl.ItemTemplate>
    #| </ui:ItemsControl>
    #|</ui:View>
  let contract =
    #|package "example/inventory/view"
    #|pub(all) struct InventoryModel { revision : UInt }
    #|pub(all) struct InventoryItemViewModel { id : String; label : String }
    #|pub(all) struct InventoryViewModel {
    #|  title : String
    #|  items : Array[InventoryItemViewModel]
    #|}
    #|pub fn compute_view_model(InventoryModel) -> InventoryViewModel
    #|pub(all) enum InventoryViewAction { SelectItem(String) }
  let ir = @viewir.compile("fixtures/inventory.xaml", xaml, contract)
  let routes = ir.action_routes.map(route => {
    (
      route.id,
      route.source_scope,
      route.event_kind,
      route.variant_name,
      route.collection_path,
      route.node_template,
    )
  })
  let binding_summary = ir.bindings.map(binding => {
    (
      binding.id,
      binding.scope_id,
      binding.path,
      binding.result_type,
      binding.targets.map(target => (target.node, target.property)),
    )
  })
  debug_inspect(
    (
      ir.identity.view_name,
      ir.contract.model_type.type_name,
      ir.contract.view_model_type.type_name,
      ir.contract.view_model_projection,
      ir.data_scopes.map(scope => (scope.id, scope.value_type.type_name)),
      binding_summary,
      routes,
      ir.required_capabilities,
    ),
    content=(
      #|(
      #|  "InventoryView",
      #|  "InventoryModel",
      #|  "InventoryViewModel",
      #|  Compute("compute_view_model"),
      #|  [
      #|    ("root", "InventoryViewModel"),
      #|    ("item:root:items", "InventoryItemViewModel"),
      #|  ],
      #|  [
      #|    (
      #|      "binding-0",
      #|      "root",
      #|      "items",
      #|      "Array[InventoryItemViewModel]",
      #|      [("root", "$items")],
      #|    ),
      #|    (
      #|      "binding-1",
      #|      "root",
      #|      "title",
      #|      "String",
      #|      [("node-root-0-text", "Text")],
      #|    ),
      #|    (
      #|      "binding-2",
      #|      "item:root:items",
      #|      "label",
      #|      "String",
      #|      [("root/items:__SELENE_KEY__/item-root-1/item/0/0-text", "Text")],
      #|    ),
      #|  ],
      #|  [
      #|    (
      #|      "action:root/items:__SELENE_KEY__/row:Click",
      #|      "item:root:items",
      #|      "Click",
      #|      "SelectItem",
      #|      Some("items"),
      #|      "root/items:__SELENE_KEY__/row",
      #|    ),
      #|  ],
      #|  [TreeMutation, KeyedCollection, ActionRouting],
      #|)
    ),
  )
}

///|
test "VI-IR-02 identity projection remains a complete resolved contract" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"
    #| xmlns:model="moonbit:example/demo/model"
    #| ui:DataType="model:DemoModel">
    #| <ui:Text Text="{ui:Binding Path=title}" />
    #|</ui:View>
  let contract =
    #|package "example/demo/model"
    #|pub(all) struct DemoModel { title : String }
  let ir = @viewir.compile("fixtures/demo.xaml", xaml, contract)
  debug_inspect(
    (
      ir.contract.model_type.type_name,
      ir.contract.view_model_type.type_name,
      ir.contract.view_model_projection,
      ir.bindings[0].steps,
    ),
    content=(
      #|(
      #|  "DemoModel",
      #|  "DemoModel",
      #|  Identity,
      #|  [
      #|    {
      #|      declaring_type: "DemoModel",
      #|      step: "title",
      #|      result_type: "String",
      #|      span: {
      #|        source_uri: "fixtures/demo.xaml",
      #|        start: { offset: 123, line: 4, column: 11 },
      #|        end: { offset: 153, line: 4, column: 41 },
      #|      },
      #|    },
      #|  ],
      #|)
    ),
  )
}

///|
test "VI-IR-03 WIT resolves a distinct Model, computed ViewModel, Patch, Action, and resource" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"
    #| xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:demo/component/gen/api"
    #| x:Class="DemoView" ui:DataType="model:DemoViewModel" x:Name="root">
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=items}" KeyPath="id">
    #|  <ui:ItemsControl.ItemTemplate>
    #|   <ui:DataTemplate ui:DataType="model:DemoItem">
    #|    <ui:Button x:Name="row" OnClick="select_item">
    #|     <ui:Text Text="{ui:Binding Path=label}" />
    #|    </ui:Button>
    #|   </ui:DataTemplate>
    #|  </ui:ItemsControl.ItemTemplate>
    #| </ui:ItemsControl>
    #|</ui:View>
  let wit =
    #|package demo:ui@0.1.0;
    #|interface demo-ui-api {
    #|  record demo-item { id: string, label: string }
    #|  record demo-model { revision: u32, items: list<demo-item> }
    #|  record demo-view-model { items: list<demo-item> }
    #|  variant demo-patch {
    #|    items-replace(list<demo-item>),
    #|    item-upsert(demo-item),
    #|    item-remove(string),
    #|    item-move(tuple<string, u32>),
    #|  }
    #|  variant ui-event { click(string) }
    #|  variant demo-action { select-item(string) }
    #|  mount: func(entity: u32, model: demo-model);
    #|  replace: func(entity: u32, model: demo-model);
    #|  apply: func(entity: u32, patches: list<demo-patch>);
    #|  handle-event: func(entity: u32, event: ui-event) -> option<demo-action>;
    #|  update: func();
    #|  unmount: func(entity: u32);
    #|}
    #|world demo-ui {
    #|  import selene:ui-host/tree@0.1.0;
    #|  export demo-ui-api;
    #|}
  let (ir, target) = @viewir.compile_wit(
    "fixtures/demo.xaml", xaml, "fixtures/wit", wit,
  )
  debug_inspect(
    (
      ir.contract.model_type.type_name,
      ir.contract.view_model_type.type_name,
      ir.contract.view_model_projection,
      ir.contract.patch.map(patch => patch.name),
      ir.contract.action.variants,
      target,
    ),
    content=(
      #|(
      #|  "DemoModel",
      #|  "DemoViewModel",
      #|  Compute("compute_view_model"),
      #|  Some("DemoPatch"),
      #|  [{ name: "SelectItem", payload: Some("String") }],
      #|  {
      #|    event_type: "UiEvent",
      #|    action_type: "DemoAction",
      #|    tree_package: "selene:ui-host/tree@0.1.0",
      #|  },
      #|)
    ),
  )
}

///|
test "VI-IR-04 seals template VisualState bindings, targets, overlays, and transitions" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"
    #| xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/inventory/model"
    #| x:Class="InventoryView" ui:DataType="model:InventoryState">
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=tabs}" KeyPath="id">
    #|  <ui:ItemsControl.ItemTemplate>
    #|   <ui:DataTemplate ui:DataType="model:InventoryTab">
    #|    <ui:Button x:Name="tabButton">
    #|     <ui:Image x:Name="tabIcon" Source="{ui:Binding Path=icon}" />
    #|     <ui:Text x:Name="tabLabel" Text="{ui:Binding Path=label}" />
    #|     <ui:Button.VisualStates>
    #|      <ui:VisualStateGroup Name="SelectionStates" Current="{ui:Binding Path=selected}">
    #|       <ui:VisualState Name="Normal">
    #|        <ui:Setter TargetName="tabIcon" Property="Source" Value="{ui:Binding Path=icon}" />
    #|       </ui:VisualState>
    #|       <ui:VisualState Name="Selected">
    #|        <ui:Setter Property="Background" Value="#6b3d26" />
    #|        <ui:Setter TargetName="tabIcon" Property="Source" Value="{ui:Binding Path=selectedIcon}" />
    #|        <ui:Setter TargetName="tabLabel" Property="Bold" Value="true" />
    #|       </ui:VisualState>
    #|       <ui:VisualStateGroup.Transitions>
    #|        <ui:Transition From="Normal" To="Selected" Duration="0.12" Easing="EaseOut" />
    #|       </ui:VisualStateGroup.Transitions>
    #|      </ui:VisualStateGroup>
    #|     </ui:Button.VisualStates>
    #|    </ui:Button>
    #|   </ui:DataTemplate>
    #|  </ui:ItemsControl.ItemTemplate>
    #| </ui:ItemsControl>
    #|</ui:View>
  let contract =
    #|package "example/inventory/model"
    #|pub(all) struct InventoryTab {
    #|  id : String
    #|  label : String
    #|  icon : String
    #|  selected_icon : String
    #|  selected : Bool
    #|}
    #|pub(all) struct InventoryState { tabs : Array[InventoryTab] }
  let ir = @viewir.compile("fixtures/inventory-states.xaml", xaml, contract)
  let group = ir.visual_state_groups[0]
  let current_binding = match group.current {
    Some(IRValue::Binding(id, _)) => id
    _ => fail("SelectionStates.Current must seal as a typed binding")
  }
  let setters : Array[(String, String, String, String)] = []
  for state in group.states {
    for setter in state.setters {
      let value = match setter.value {
        IRValue::Binding(id, _) => "binding:" + id
        IRValue::Constant(IRConstant::StringValue(value), _) =>
          "string:" + value
        IRValue::Constant(IRConstant::BoolValue(value), _) =>
          "bool:" + value.to_string()
        _ => "other"
      }
      setters.push((state.name, setter.target_node, setter.property, value))
    }
  }
  debug_inspect(
    (
      group.owner_node,
      group.name,
      current_binding,
      setters,
      group.transitions.map(transition => {
        (
          transition.from,
          transition.to,
          transition.duration,
          transition.delay,
          transition.easing,
        )
      }),
      ir.required_capabilities.contains(IRCapability::VisualState),
    ),
    content=(
      #|(
      #|  "node-root-view/tabs:__SELENE_KEY__/tab-button",
      #|  "SelectionStates",
      #|  "binding-3",
      #|  [
      #|    (
      #|      "Normal",
      #|      "node-root-view/tabs:__SELENE_KEY__/tab-icon",
      #|      "Source",
      #|      "binding:binding-1",
      #|    ),
      #|    (
      #|      "Selected",
      #|      "node-root-view/tabs:__SELENE_KEY__/tab-button",
      #|      "Background",
      #|      "string:#6b3d26",
      #|    ),
      #|    (
      #|      "Selected",
      #|      "node-root-view/tabs:__SELENE_KEY__/tab-icon",
      #|      "Source",
      #|      "binding:binding-4",
      #|    ),
      #|    (
      #|      "Selected",
      #|      "node-root-view/tabs:__SELENE_KEY__/tab-label",
      #|      "Bold",
      #|      "bool:true",
      #|    ),
      #|  ],
      #|  [(Some("Normal"), Some("Selected"), 0.12, 0, "EaseOut")],
      #|  true,
      #|)
    ),
  )
}
