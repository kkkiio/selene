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
    #|     <ui:Image x:Name="tabIcon" Source="{ui:Binding Path=icon}"
    #|      Tint="{ui:Binding Path=iconTint}" />
    #|     <ui:Image x:Name="sheetIcon" Source="sheet.png"
    #|      SourceRegion="{ui:Binding Path=iconRegion}" />
    #|     <ui:Text x:Name="tabLabel" Text="{ui:Binding Path=label}" />
    #|     <ui:Button.VisualStates>
    #|      <ui:VisualStateGroup Name="SelectionStates" Current="{ui:Binding Path=selected}">
    #|       <ui:VisualState Name="Normal">
    #|        <ui:Setter TargetName="tabIcon" Property="Source" Value="{ui:Binding Path=icon}" />
    #|        <ui:Setter TargetName="tabIcon" Property="Tint" Value="{ui:Binding Path=iconTint}" />
    #|        <ui:Setter TargetName="sheetIcon" Property="SourceRegion" Value="{ui:Binding Path=iconRegion}" />
    #|       </ui:VisualState>
    #|       <ui:VisualState Name="Selected">
    #|        <ui:Setter Property="Background" Value="#6b3d26" />
    #|        <ui:Setter TargetName="tabIcon" Property="Source" Value="{ui:Binding Path=selectedIcon}" />
    #|        <ui:Setter TargetName="tabIcon" Property="Tint" Value="#ffd080" />
    #|        <ui:Setter TargetName="sheetIcon" Property="SourceRegion" Value="32 0 24 24" />
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
    #|  icon_region : String
    #|  icon_tint : String
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
        IRValue::Constant(IRConstant::ImageRegionValue(x, y, width, height), _) =>
          "region:\{x},\{y},\{width},\{height}"
        IRValue::Constant(IRConstant::NoImageRegion, _) => "region:none"
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
      #|  "binding-4",
      #|  [
      #|    (
      #|      "Normal",
      #|      "node-root-view/tabs:__SELENE_KEY__/tab-icon",
      #|      "Source",
      #|      "binding:binding-1",
      #|    ),
      #|    (
      #|      "Normal",
      #|      "node-root-view/tabs:__SELENE_KEY__/tab-icon",
      #|      "Tint",
      #|      "binding:binding-3",
      #|    ),
      #|    (
      #|      "Normal",
      #|      "node-root-view/tabs:__SELENE_KEY__/sheet-icon",
      #|      "SourceRegion",
      #|      "binding:binding-5",
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
      #|      "binding:binding-6",
      #|    ),
      #|    (
      #|      "Selected",
      #|      "node-root-view/tabs:__SELENE_KEY__/tab-icon",
      #|      "Tint",
      #|      "string:#ffd080",
      #|    ),
      #|    (
      #|      "Selected",
      #|      "node-root-view/tabs:__SELENE_KEY__/sheet-icon",
      #|      "SourceRegion",
      #|      "region:32,0,24,24",
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

///|
test "VI-IR-05 seals Grid tracks, flow, placement, and spans as typed constants" {
  let xaml =
    #|<ui:Grid xmlns:ui="urn:selene:xaml:ui"
    #| xmlns:model="moonbit:example/grid/model"
    #| ui:DataType="model:GridState"
    #| Rows="Auto minmax(80, 1fr)"
    #| Columns="repeat(2, 25% 1fr) repeat(auto-fit, minmax(40, 1fr)) fit-content(120)"
    #| AutoFlow="ColumnDense">
    #| <ui:Text ui:Grid.Row="1" ui:Grid.Column="2"
    #|   ui:Grid.RowSpan="2" ui:Grid.ColumnSpan="3" Text="Cell" />
    #|</ui:Grid>
  let contract =
    #|package "example/grid/model"
    #|pub(all) struct GridState {}
  let ir = @viewir.compile("fixtures/grid.xaml", xaml, contract)
  guard ir.root
    is IRNode::Element(
      "Grid",
      _,
      _,
      grid_properties,
      [IRNode::Element("Text", _, _, cell_properties, _, _)],
      _
    ) else {
    fail("expected a typed Grid with one Text child")
  }
  debug_inspect(
    (
      grid_properties.map(property => (property.name, property.value)),
      cell_properties.map(property => (property.name, property.value)),
    ),
    content=(
      #|(
      #|  [
      #|    (
      #|      "Rows",
      #|      Constant(
      #|        GridTracks([Auto, MinMax(Px(80), Fr(1))]),
      #|        {
      #|          source_uri: "fixtures/grid.xaml",
      #|          start: { offset: 113, line: 4, column: 2 },
      #|          end: { offset: 140, line: 4, column: 29 },
      #|        },
      #|      ),
      #|    ),
      #|    (
      #|      "Columns",
      #|      Constant(
      #|        GridTracks(
      #|          [
      #|            Repeat(Count(2), [Percent(0.25), Fr(1)]),
      #|            Repeat(AutoFit, [MinMax(Px(40), Fr(1))]),
      #|            FitContent(Px(120)),
      #|          ],
      #|        ),
      #|        {
      #|          source_uri: "fixtures/grid.xaml",
      #|          start: { offset: 142, line: 5, column: 2 },
      #|          end: { offset: 221, line: 5, column: 81 },
      #|        },
      #|      ),
      #|    ),
      #|    (
      #|      "AutoFlow",
      #|      Constant(
      #|        EnumValue("ColumnDense"),
      #|        {
      #|          source_uri: "fixtures/grid.xaml",
      #|          start: { offset: 223, line: 6, column: 2 },
      #|          end: { offset: 245, line: 6, column: 24 },
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|  [
      #|    (
      #|      "Grid.Row",
      #|      Constant(
      #|        IntValue(1),
      #|        {
      #|          source_uri: "fixtures/grid.xaml",
      #|          start: { offset: 257, line: 7, column: 11 },
      #|          end: { offset: 272, line: 7, column: 26 },
      #|        },
      #|      ),
      #|    ),
      #|    (
      #|      "Grid.Column",
      #|      Constant(
      #|        IntValue(2),
      #|        {
      #|          source_uri: "fixtures/grid.xaml",
      #|          start: { offset: 273, line: 7, column: 27 },
      #|          end: { offset: 291, line: 7, column: 45 },
      #|        },
      #|      ),
      #|    ),
      #|    (
      #|      "Grid.RowSpan",
      #|      Constant(
      #|        IntValue(2),
      #|        {
      #|          source_uri: "fixtures/grid.xaml",
      #|          start: { offset: 295, line: 8, column: 4 },
      #|          end: { offset: 314, line: 8, column: 23 },
      #|        },
      #|      ),
      #|    ),
      #|    (
      #|      "Grid.ColumnSpan",
      #|      Constant(
      #|        IntValue(3),
      #|        {
      #|          source_uri: "fixtures/grid.xaml",
      #|          start: { offset: 315, line: 8, column: 24 },
      #|          end: { offset: 337, line: 8, column: 46 },
      #|        },
      #|      ),
      #|    ),
      #|    (
      #|      "Text",
      #|      Constant(
      #|        StringValue("Cell"),
      #|        {
      #|          source_uri: "fixtures/grid.xaml",
      #|          start: { offset: 338, line: 8, column: 47 },
      #|          end: { offset: 349, line: 8, column: 58 },
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|)
    ),
  )
  let messages : Array[String] = []
  for
    invalid in [
      ("Rows=\"Auto minmax(80, 1fr)\"", "Rows=\"repeat(0, 1fr)\""),
      ("ui:Grid.Row=\"1\"", "ui:Grid.Row=\"-1\""),
      ("ui:Grid.RowSpan=\"2\"", "ui:Grid.RowSpan=\"0\""),
    ] {
    try
      ignore(
        @viewir.compile(
          "fixtures/grid.xaml",
          xaml.replace(old=invalid.0, new=invalid.1),
          contract,
        ),
      )
    catch {
      ViewIRError::Unsupported(message, _) => messages.push(message)
      error => raise error
    } noraise {
      _ => fail("invalid Grid literal must fail during ViewIR sealing")
    }
  }
  debug_inspect(
    messages,
    content=(
      #|[
      #|  "repeat() count must be positive",
      #|  "grid index must be zero or greater",
      #|  "grid span must be a positive integer",
      #|]
    ),
  )
}

///|
test "VI-RESOURCE-01 resolves external and local static resources before sealing" {
  let xaml =
    #|<View xmlns="urn:selene:xaml:ui"
    #|      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #|      xmlns:model="moonbit:example/theme/model"
    #|      x:Class="ThemeView" DataType="model:ThemeState">
    #|  <View.Resources>
    #|    <ResourceDictionary Source="../theme.xaml">
    #|      <x:Double x:Key="Radius.Panel">12</x:Double>
    #|    </ResourceDictionary>
    #|  </View.Resources>
    #|  <Flex Background="{StaticResource Color.Surface}"
    #|        Padding="{StaticResource Spacing.Small}"
    #|        Radius="{StaticResource Radius.Panel}" />
    #|</View>
  let theme =
    #|<ResourceDictionary xmlns="urn:selene:xaml:ui"
    #|                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    #|  <Color x:Key="Color.Surface">#fff4dc</Color>
    #|  <x:Double x:Key="Spacing.Small">8</x:Double>
    #|</ResourceDictionary>
  let contract =
    #|package "example/theme/model"
    #|pub(all) struct ThemeState {}
  let references = @viewir.referenced_resource_documents(
    "ui/views/theme-view.xaml", xaml,
  )
  debug_inspect(
    references,
    content=(
      #|["ui/theme.xaml"]
    ),
  )
  let ir = @viewir.compile_with_resources(
    "ui/views/theme-view.xaml",
    xaml,
    contract,
    [{ source_uri: "ui/./theme.xaml", source: theme }],
  )
  guard ir.root is IRNode::Element(_, _, _, _, [child], _) &&
    child is IRNode::Element(_, _, _, properties, _, _) else {
    fail("expected themed Flex")
  }
  debug_inspect(
    properties,
    content=(
      #|[
      #|  {
      #|    name: "Background",
      #|    value: Constant(
      #|      StringValue("#fff4dc"),
      #|      {
      #|        source_uri: "ui/views/theme-view.xaml",
      #|        start: { offset: 369, line: 10, column: 9 },
      #|        end: { offset: 412, line: 10, column: 52 },
      #|      },
      #|    ),
      #|  },
      #|  {
      #|    name: "Padding",
      #|    value: Constant(
      #|      RectValue(8, 8, 8, 8),
      #|      {
      #|        source_uri: "ui/views/theme-view.xaml",
      #|        start: { offset: 421, line: 11, column: 9 },
      #|        end: { offset: 461, line: 11, column: 49 },
      #|      },
      #|    ),
      #|  },
      #|  {
      #|    name: "Radius",
      #|    value: Constant(
      #|      DoubleValue(12),
      #|      {
      #|        source_uri: "ui/views/theme-view.xaml",
      #|        start: { offset: 470, line: 12, column: 9 },
      #|        end: { offset: 508, line: 12, column: 47 },
      #|      },
      #|    ),
      #|  },
      #|]
    ),
  )
}

///|
test "VI-RESOURCE-02 rejects missing, duplicate, and cyclic resources" {
  let contract =
    #|package "example/theme/model"
    #|pub(all) struct ThemeState {}
  let documents : Array[(String, String, Array[@viewir.ResourceDocument])] = [
    (
      "ui/missing.xaml",
      (
        #|<View xmlns="urn:selene:xaml:ui"
        #|      xmlns:model="moonbit:example/theme/model"
        #|      DataType="model:ThemeState">
        #|  <Text Color="{StaticResource Color.Missing}" />
        #|</View>
      ),
      [],
    ),
    (
      "ui/duplicate.xaml",
      (
        #|<View xmlns="urn:selene:xaml:ui"
        #|      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        #|      xmlns:model="moonbit:example/theme/model"
        #|      DataType="model:ThemeState">
        #|  <View.Resources>
        #|    <ResourceDictionary>
        #|      <Color x:Key="Color.Text">#111111</Color>
        #|      <Color x:Key="Color.Text">#222222</Color>
        #|    </ResourceDictionary>
        #|  </View.Resources>
        #|</View>
      ),
      [],
    ),
    (
      "ui/view.xaml",
      (
        #|<View xmlns="urn:selene:xaml:ui"
        #|      xmlns:model="moonbit:example/theme/model"
        #|      DataType="model:ThemeState">
        #|  <View.Resources>
        #|    <ResourceDictionary Source="a.xaml" />
        #|  </View.Resources>
        #|</View>
      ),
      [
        {
          source_uri: "ui/a.xaml",
          source: (
            #|<ResourceDictionary xmlns="urn:selene:xaml:ui"
            #|                    Source="b.xaml" />
          ),
        },
        {
          source_uri: "ui/b.xaml",
          source: (
            #|<ResourceDictionary xmlns="urn:selene:xaml:ui"
            #|                    Source="a.xaml" />
          ),
        },
      ],
    ),
  ]
  let messages : Array[String] = []
  for resource_case in documents {
    let (source_uri, source, resources) = resource_case
    try
      ignore(
        @viewir.compile_with_resources(source_uri, source, contract, resources),
      )
    catch {
      @viewir.ViewIRError::Unsupported(message, _) => messages.push(message)
      error => raise error
    } noraise {
      _ => fail("invalid resource graph must fail before ViewIR sealing")
    }
  }
  debug_inspect(
    messages,
    content=(
      #|[
      #|  "StaticResource key does not exist: Color.Missing",
      #|  "duplicate ResourceDictionary key: Color.Text",
      #|  "ResourceDictionary.Source cycle includes ui/a.xaml",
      #|]
    ),
  )
}
