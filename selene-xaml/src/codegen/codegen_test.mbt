///|
test "CG-VIEW-01 emits typed Embedded view source and mappings" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState" x:Name="root">
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=items}" KeyPath="id"><ui:ItemsControl.ItemTemplate>
    #|  <ui:DataTemplate ui:DataType="model:DemoItem"><ui:Button x:Name="row" OnClick="select_item">
    #|   <ui:Text Text="{ui:Binding Path=displayLabel}" />
    #|  </ui:Button></ui:DataTemplate>
    #| </ui:ItemsControl.ItemTemplate></ui:ItemsControl>
    #|</ui:View>
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoItem {
    #|  id : String
    #|  label : String
    #|}
    #|pub(all) struct DemoState {
    #|  items : Array[DemoItem]
    #|}
    #|pub fn DemoItem::display_label(Self) -> String
    #|pub(all) enum DemoPatch {
    #|  ItemsReplace(Array[DemoItem])
    #|  ItemUpsert(DemoItem)
    #|  ItemRemove(String)
    #|  ItemMove((String, UInt))
    #|}
  let generated = @codegen.generate_embedded_view_package(
    "fixtures/demo.xaml", xaml, "fixtures/model.mbti", mbti,
  )
  let mut view = ""
  let mut source_map = ""
  for file in generated.files {
    if file.path == "view.generated.mbt" {
      view = file.content
    }
    if file.path == "view.generated.mbt.map.json" {
      source_map = file.content
    }
  }
  debug_inspect(
    (
      view.contains("entity : @entity.Entity"),
      view.contains("state.items"),
      view.contains("generated_item_1.display_label()"),
      view.contains("DemoViewAction::SelectItem(generated_action_key)"),
      view.contains("@ui_host.TreeMutation::Move"),
      view.contains("parent: Some(\"root\")"),
      view.contains("host.mount(entity, desired)"),
      !view.contains("_worlds"),
      source_map.contains("\"original_offset\""),
      source_map.contains("\"generated_offset\""),
      source_map.split("\"source\":").length() - 1,
    ),
    content="(true, true, true, true, true, true, true, true, true, true, 3)",
  )
}

///|
test "CG-RUNTIME-01 fixes Embedded Views to the KKKIIO Selene module" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState" />
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoState { title : String }
  let generated = @codegen.generate_embedded_view_package(
    "ui/demo.xaml", xaml, "model/demo.mbti", mbti,
  )
  let manifest = generated.files[0].content
  let lock = generated.files.last().unwrap().content
  assert_eq(manifest.contains("\"KKKIIO/selene/app\""), true)
  assert_eq(manifest.contains("\"KKKIIO/selene/entity\""), true)
  assert_eq(
    manifest.contains("\"KKKIIO/selene_xaml_runtime/component_host\""),
    true,
  )
  assert_eq(lock.contains("\"runtime\": \"KKKIIO/selene\""), true)
}

///|
test "CG-RECT-01 rect values follow CSS order and reject three components" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState"
    #| x:Name="root" Margin="1 2" Padding="10 20 30 40" />
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoState {
    #|  title : String
    #|}
  let generated = @codegen.generate_embedded_view_package(
    "fixtures/rect.xaml", xaml, "fixtures/model.mbti", mbti,
  )
  let view = generated.files[2].content
  debug_inspect(
    (
      view.contains("margin_left: 2,\n      margin_top: 1,"),
      view.contains("margin_right: 2,\n      margin_bottom: 1,"),
      view.contains(
        "padding_left: 40,\n      padding_top: 10,\n      padding_right: 20,\n      padding_bottom: 30,",
      ),
      view.contains("    2 => if index == 0 || index == 2"),
      view.contains("    4 =>\n      match index {"),
      !view.contains("    3 => if index == 0 || index == 2"),
    ),
    content="(true, true, true, true, true, true)",
  )
  let invalid = xaml.replace(old="10 20 30 40", new="10 20 30")
  try
    @codegen.generate_embedded_view_package(
      "fixtures/rect.xaml", invalid, "fixtures/model.mbti", mbti,
    )
  catch {
    @viewir.ViewIRError::Unsupported(message, _) =>
      debug_inspect(
        message,
        content="\"rect literal requires one, two, or four numbers\"",
      )
    error => raise error
  } noraise {
    _ => fail("three-component rect literals must be rejected")
  }
}

///|
test "CG-PATCH-01 patch families are field-prefixed and shape-exact" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState" x:Name="root">
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=primaryItems}" KeyPath="id"><ui:ItemsControl.ItemTemplate>
    #|  <ui:DataTemplate ui:DataType="model:DemoItem"><ui:Text Text="{ui:Binding Path=label}" /></ui:DataTemplate>
    #| </ui:ItemsControl.ItemTemplate></ui:ItemsControl>
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=secondaryItems}" KeyPath="id"><ui:ItemsControl.ItemTemplate>
    #|  <ui:DataTemplate ui:DataType="model:DemoItem"><ui:Text Text="{ui:Binding Path=label}" /></ui:DataTemplate>
    #| </ui:ItemsControl.ItemTemplate></ui:ItemsControl>
    #|</ui:View>
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoItem {
    #|  id : String
    #|  label : String
    #|}
    #|pub(all) struct DemoState {
    #|  primary_items : Array[DemoItem]
    #|  secondary_items : Array[DemoItem]
    #|}
    #|pub(all) enum DemoPatch {
    #|  PrimaryItemsReplace(Array[DemoItem])
    #|  PrimaryItemUpsert(DemoItem)
    #|  PrimaryItemRemove(String)
    #|  PrimaryItemMove((String, UInt))
    #|  SecondaryItemsReplace(Array[DemoItem])
    #|  SecondaryItemUpsert(DemoItem)
    #|  SecondaryItemRemove(String)
    #|  SecondaryItemMove((String, UInt))
    #|}
  let generated = @codegen.generate_embedded_view_package(
    "fixtures/patch.xaml", xaml, "fixtures/model.mbti", mbti,
  )
  let view = generated.files[2].content
  debug_inspect(
    (
      view.contains("PrimaryItemsReplace(values)"),
      view.contains("SecondaryItemsReplace(values)"),
      view.split("PrimaryItemUpsert(value) =>").collect().length(),
      view.split("SecondaryItemUpsert(value) =>").collect().length(),
    ),
    content="(true, true, 2, 2)",
  )
  let invalid_shapes = [
    (
      "PrimaryItemsReplace(Array[DemoItem])", "PrimaryItemsReplace(Array[String])",
    ),
    ("PrimaryItemUpsert(DemoItem)", "PrimaryItemUpsert(String)"),
    ("PrimaryItemRemove(String)", "PrimaryItemRemove(Int)"),
    ("PrimaryItemMove((String, UInt))", "PrimaryItemMove((Int, UInt))"),
  ]
  let messages : Array[String] = []
  for shape in invalid_shapes {
    let (valid, invalid) = shape
    try
      @codegen.generate_embedded_view_package(
        "fixtures/patch.xaml",
        xaml,
        "fixtures/model.mbti",
        mbti.replace(old=valid, new=invalid),
      )
    catch {
      @viewir.ViewIRError::InvalidContract(message) => messages.push(message)
      error => raise error
    } noraise {
      _ => fail("invalid patch payload must be rejected")
    }
  }
  debug_inspect(
    messages,
    content=(
      #|[
      #|  "patch variant payload must be Array[DemoItem]: PrimaryItemsReplace",
      #|  "patch variant payload must be DemoItem: PrimaryItemUpsert",
      #|  "patch variant payload must be String: PrimaryItemRemove",
      #|  "patch variant payload must be (String, UInt): PrimaryItemMove",
      #|]
    ),
  )
}

///|
test "CG-PATCH-02 one patch variant cannot serve two collections" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState">
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=item}" KeyPath="id"><ui:ItemsControl.ItemTemplate>
    #|  <ui:DataTemplate ui:DataType="model:DemoItem"><ui:Text Text="{ui:Binding Path=label}" /></ui:DataTemplate>
    #| </ui:ItemsControl.ItemTemplate></ui:ItemsControl>
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=items}" KeyPath="id"><ui:ItemsControl.ItemTemplate>
    #|  <ui:DataTemplate ui:DataType="model:DemoItem"><ui:Text Text="{ui:Binding Path=label}" /></ui:DataTemplate>
    #| </ui:ItemsControl.ItemTemplate></ui:ItemsControl>
    #|</ui:View>
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoItem {
    #|  id : String
    #|  label : String
    #|}
    #|pub(all) struct DemoState {
    #|  item : Array[DemoItem]
    #|  items : Array[DemoItem]
    #|}
    #|pub(all) enum DemoPatch {
    #|  ItemReplace(Array[DemoItem])
    #|  ItemsReplace(Array[DemoItem])
    #|  ItemUpsert(DemoItem)
    #|  ItemRemove(String)
    #|  ItemMove((String, UInt))
    #|}
  try
    @codegen.generate_embedded_view_package(
      "fixtures/patch-conflict.xaml", xaml, "fixtures/model.mbti", mbti,
    )
  catch {
    @viewir.ViewIRError::InvalidContract(message) =>
      debug_inspect(
        message,
        content="\"patch variant is claimed by multiple collections: ItemUpsert\"",
      )
    error => raise error
  } noraise {
    _ => fail("patch families must belong to one collection")
  }
}

///|
test "CG-PROPERTY-01 generated properties reject silent degradation" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState" x:Name="root">
    #| <ui:Flex Direction="RowReverse">
    #|  <ui:Text Text="{ui:Binding Path=title}" Align="Center" Wrap="WordWrap" />
    #|  <ui:Image Source="icon.png" Fit="Stretch" />
    #| </ui:Flex>
    #|</ui:View>
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoState {
    #|  title : String
    #|}
  let generated = @codegen.generate_embedded_view_package(
    "fixtures/properties.xaml", xaml, "fixtures/model.mbti", mbti,
  )
  let view = generated.files[2].content
  debug_inspect(
    (
      view.contains("align: @ui_host.TextAlign::Center"),
      view.contains("wrap: true"),
      view.contains("fit: @ui_host.ImageFit::Fill"),
      view.contains("direction: @ui_host.FlexDirection::RowReverse"),
    ),
    content="(true, true, true, true)",
  )
  let invalid_literals = [
    (
      "Align=\"Center\"", "Align=\"Diagonal\"", "invalid generated Align literal: Diagonal",
    ),
    ("Fit=\"Stretch\"", "Fit=\"Tile\"", "invalid generated Fit literal: Tile"),
    (
      "Direction=\"RowReverse\"", "Direction=\"Circular\"", "invalid generated Direction literal: Circular",
    ),
    (
      "Wrap=\"WordWrap\"", "Wrap=\"Balanced\"", "invalid generated Wrap literal: Balanced",
    ),
  ]
  let literal_messages : Array[String] = []
  for literal_case in invalid_literals {
    let (valid, invalid, expected) = literal_case
    try
      @codegen.generate_embedded_view_package(
        "fixtures/properties.xaml",
        xaml.replace(old=valid, new=invalid),
        "fixtures/model.mbti",
        mbti,
      )
    catch {
      @viewir.ViewIRError::Unsupported(message, _) => {
        literal_messages.push(message)
        inspect(message == expected, content="true")
      }
      error => raise error
    } noraise {
      _ => fail("invalid property literal must be rejected")
    }
  }
  debug_inspect(
    literal_messages,
    content=(
      #|[
      #|  "invalid generated Align literal: Diagonal",
      #|  "invalid generated Fit literal: Tile",
      #|  "invalid generated Direction literal: Circular",
      #|  "invalid generated Wrap literal: Balanced",
      #|]
    ),
  )
  let binding_properties = [
    ("Align=\"Center\"", "Align=\"{ui:Binding Path=title}\"", "Align"),
    ("Fit=\"Stretch\"", "Fit=\"{ui:Binding Path=title}\"", "Fit"),
    (
      "Direction=\"RowReverse\"", "Direction=\"{ui:Binding Path=title}\"", "Direction",
    ),
    ("Wrap=\"WordWrap\"", "Wrap=\"{ui:Binding Path=title}\"", "Wrap"),
  ]
  let binding_messages : Array[String] = []
  for binding_case in binding_properties {
    let (literal, binding, property) = binding_case
    try
      @codegen.generate_embedded_view_package(
        "fixtures/properties.xaml",
        xaml.replace(old=literal, new=binding),
        "fixtures/model.mbti",
        mbti,
      )
    catch {
      @viewir.ViewIRError::Unsupported(message, _) => {
        binding_messages.push(message)
        inspect(
          message == "generated property does not support Binding: " + property,
          content="true",
        )
      }
      error => raise error
    } noraise {
      _ => fail("enum-like property binding must be rejected")
    }
  }
  debug_inspect(
    binding_messages,
    content=(
      #|[
      #|  "generated property does not support Binding: Align",
      #|  "generated property does not support Binding: Fit",
      #|  "generated property does not support Binding: Direction",
      #|  "generated property does not support Binding: Wrap",
      #|]
    ),
  )
  let unsupported = xaml.replace(
    old="x:Name=\"root\"",
    new="x:Name=\"root\" MinWidth=\"320\"",
  )
  try
    @codegen.generate_embedded_view_package(
      "fixtures/properties.xaml", unsupported, "fixtures/model.mbti", mbti,
    )
  catch {
    @viewir.ViewIRError::Unsupported(message, _) =>
      debug_inspect(
        message,
        content="\"unsupported generated property: MinWidth\"",
      )
    error => raise error
  } noraise {
    _ => fail("unimplemented generated property must be rejected")
  }
}

///|
test "CG-PROPERTY-02 Position is literal-only and Button defaults remain overridable" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState"
    #| x:Name="root" Position="Absolute">
    #| <ui:Button x:Name="explicit" Focusable="false" />
    #| <ui:Button x:Name="default" />
    #| <ui:Button x:Name="bound" Focusable="{ui:Binding Path=flag}" />
    #|</ui:View>
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoState {
    #|  flag : Bool
    #|}
  let generated = @codegen.generate_embedded_view_package(
    "fixtures/position.xaml", xaml, "fixtures/model.mbti", mbti,
  )
  let view = generated.files[2].content
  let explicit_start = view.find("key: \"explicit\"").unwrap()
  let default_start = view.find("key: \"default\"").unwrap()
  let bound_start = view.find("key: \"bound\"").unwrap()
  debug_inspect(
    (
      view.contains("absolute: true"),
      view[explicit_start:default_start].contains("focusable: false"),
      view[default_start:bound_start].contains("focusable: true"),
      view[bound_start:].contains("focusable: state.flag"),
    ),
    content="(true, true, true, true)",
  )
  let invalid_positions = [
    (
      "Position=\"Absolute\"", "Position=\"Fixed\"", "invalid generated Position literal: Fixed",
    ),
    (
      "Position=\"Absolute\"", "Position=\"{ui:Binding Path=flag}\"", "generated property does not support Binding: Position",
    ),
  ]
  let messages : Array[String] = []
  for position_case in invalid_positions {
    let (valid, invalid, expected) = position_case
    try
      @codegen.generate_embedded_view_package(
        "fixtures/position.xaml",
        xaml.replace(old=valid, new=invalid),
        "fixtures/model.mbti",
        mbti,
      )
    catch {
      @viewir.ViewIRError::Unsupported(message, _) => {
        messages.push(message)
        inspect(message == expected, content="true")
      }
      error => raise error
    } noraise {
      _ => fail("invalid generated Position must be rejected")
    }
  }
  debug_inspect(
    messages,
    content=(
      #|[
      #|  "invalid generated Position literal: Fixed",
      #|  "generated property does not support Binding: Position",
      #|]
    ),
  )
}

///|
test "CG-LAYOUT-01 emits auto, pixel, percent, and flex sizing semantics" {
  let xaml =
    #|<ui:Flex xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/layout/model" x:Class="LayoutView" ui:DataType="model:LayoutState"
    #| x:Name="root" Width="100%" Height="Auto" Grow="1" Shrink="0" Basis="25%">
    #| <ui:Text x:Name="label" Width="{ui:Binding Path=labelWidth}" Height="24" Text="Layout" />
    #|</ui:Flex>
  let mbti =
    #|package "example/layout/model"
    #|pub(all) struct LayoutState {
    #|  label_width : Double
    #|}
  let generated = @codegen.generate_embedded_view_package(
    "fixtures/layout.xaml", xaml, "fixtures/layout.mbti", mbti,
  )
  let view = generated.files[2].content
  debug_inspect(
    (
      view.contains("width: @ui_host.LayoutValue::Percent(1)"),
      view.contains("height: @ui_host.LayoutValue::Auto"),
      view.contains("flex_basis: @ui_host.LayoutValue::Percent(0.25)"),
      view.contains("flex_grow: 1"),
      view.contains("flex_shrink: 0"),
      view.contains("width: @ui_host.LayoutValue::Px(state.label_width)"),
      view.contains("height: @ui_host.LayoutValue::Px(24)"),
    ),
    content="(true, true, true, true, true, true, true)",
  )
  let messages : Array[String] = []
  for invalid in ["Wide", "10%%"] {
    try
      @codegen.generate_embedded_view_package(
        "fixtures/layout.xaml",
        xaml.replace(old="Height=\"Auto\"", new="Height=\"" + invalid + "\""),
        "fixtures/layout.mbti",
        mbti,
      )
    catch {
      @viewir.ViewIRError::Unsupported(message, _) => messages.push(message)
      error => raise error
    } noraise {
      _ => fail("invalid layout literal must be rejected")
    }
  }
  debug_inspect(
    messages,
    content=(
      #|["invalid layout literal: Wide", "invalid percentage literal: 10%%"]
    ),
  )
}

///|
test "CG-MBTI-01 emits the reachable alias and model surface only" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState"
    #| x:Name="root" Width="{ui:Binding Path=ratio}">
    #| <ui:If Condition="{ui:Binding Path=visible}">
    #|  <ui:If.Then><ui:Text Text="{ui:Binding Path=score}" /></ui:If.Then>
    #| </ui:If>
    #| <ui:ItemsControl ItemsSource="{ui:Binding Path=items}" KeyPath="id"><ui:ItemsControl.ItemTemplate>
    #|  <ui:DataTemplate ui:DataType="model:DemoItem"><ui:Button OnClick="select_item">
    #|   <ui:Text Text="{ui:Binding Path=label}" />
    #|  </ui:Button></ui:DataTemplate>
    #| </ui:ItemsControl.ItemTemplate></ui:ItemsControl>
    #|</ui:View>
  let mbti =
    #|package "example/demo/model"
    #|pub type Caption = String
    #|pub type ItemId = String
    #|pub type PatchReason = String
    #|pub type Ratio = Double
    #|pub type Score = Int
    #|pub type Visible = Bool
    #|pub type UnusedAlias = String
    #|pub(all) enum DisplayMode {
    #|  Compact
    #|  Expanded
    #|}
    #|pub(all) struct NestedModel {
    #|  caption : Caption
    #|  mode : DisplayMode
    #|}
    #|pub(all) struct DemoItem {
    #|  id : ItemId
    #|  label : Caption
    #|  nested : NestedModel
    #|}
    #|pub(all) struct PatchEnvelope {
    #|  reason : PatchReason
    #|}
    #|pub(all) struct DemoState {
    #|  items : Array[DemoItem]
    #|  nested : NestedModel
    #|  ratio : Ratio
    #|  score : Score
    #|  visible : Visible
    #|}
    #|pub(all) enum DemoPatch {
    #|  ItemsReplace(Array[DemoItem])
    #|  ItemUpsert(DemoItem)
    #|  ItemRemove(ItemId)
    #|  ItemMove((ItemId, UInt))
    #|  Reset(PatchEnvelope)
    #|}
    #|pub(all) enum DemoViewAction {
    #|  Existing
    #|  SelectItem(String)
    #|}
    #|pub(all) enum UnusedEnum {
    #|  Unused
    #|}
    #|pub(all) struct UnusedStruct {
    #|  value : UnusedAlias
    #|}
  let generated = @codegen.generate_embedded_view_package(
    "fixtures/aliases.xaml", xaml, "fixtures/model.mbti", mbti,
  )
  let state = generated.files[1].content
  let view = generated.files[2].content
  debug_inspect(
    (
      state.contains("pub type ItemId = @model.ItemId"),
      state.contains("pub type Score = @model.Score"),
      state.contains("pub type DemoItem = @model.DemoItem"),
      state.contains("pub type NestedModel = @model.NestedModel"),
      state.contains("pub type DisplayMode = @model.DisplayMode"),
      state.contains("pub type PatchEnvelope = @model.PatchEnvelope"),
      state.contains("pub type DemoPatch = @model.DemoPatch"),
      !state.contains("DemoViewAction"),
      !state.contains("UnusedEnum"),
      !state.contains("UnusedStruct"),
      !state.contains("UnusedAlias"),
      view.contains("state.score.to_string()"),
      view.contains("width: @ui_host.LayoutValue::Px(state.ratio)"),
      view.contains("DemoViewAction::SelectItem(generated_action_key)"),
      (state + view).split("pub(all) enum DemoViewAction {").collect().length(),
    ),
    content=(
      #|(
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  2,
      #|)
    ),
  )
}

///|
test "CG-GENERATE-01 output set, source map, and lock are deterministic" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState" x:Name="root">
    #| <ui:Text Text="{ui:Binding Path=title}" />
    #|</ui:View>
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoState {
    #|  title : String
    #|}
  let first = @codegen.generate_embedded_view_package(
    "ui/demo.xaml", xaml, "model/demo.mbti", mbti,
  )
  let second = @codegen.generate_embedded_view_package(
    "ui/demo.xaml", xaml, "model/demo.mbti", mbti,
  )
  let paths = first.files.map(file => file.path)
  let state = first.files[1].content
  let view = first.files[2].content
  let lock = first.files.last().unwrap().content
  let source_map = first.files[3].content
  let state_hash = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding.encode(@encoding.Encoding::UTF8, state)),
  )
  let view_hash = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding.encode(@encoding.Encoding::UTF8, view)),
  )
  debug_inspect(
    (
      paths,
      first == second,
      source_map.has_prefix("{\n  \"mappings\": ["),
      source_map.contains("\"length\":"),
      lock.contains("\"format_version\": 1"),
      state.has_prefix(
        "// Generated by selene-xaml@0.1.0. DO NOT EDIT.\n// lock-format: 1\n// input user ui/demo.xaml sha256=",
      ),
      view.has_prefix(
        "// Generated by selene-xaml@0.1.0. DO NOT EDIT.\n// lock-format: 1\n// input user ui/demo.xaml sha256=",
      ),
      lock.contains("\"resolved_contract\": { \"kind\": \"mbti\""),
      lock.contains("\"requested_outputs\":"),
      lock.contains("\"output_naming\":"),
      lock.contains(
        "\"package_alias\": { \"alias\": \"model\", \"package\": \"example/demo/model\" }",
      ),
      lock.contains("\"imported_sidecars\": []"),
      lock.contains("\"host_capability\":"),
      lock.contains("\"abi_fingerprint\": \"sha256:"),
      lock.contains("\"sha256\": \""),
      lock.contains(
        "{ \"owner\": \"selene-xaml\", \"path\": \"state.generated.mbt\", \"sha256\": \"" +
        state_hash +
        "\" }",
      ),
      lock.contains(
        "{ \"owner\": \"selene-xaml\", \"path\": \"view.generated.mbt\", \"sha256\": \"" +
        view_hash +
        "\" }",
      ),
      !lock.contains("/Users/"),
      !lock.contains("generated_at"),
    ),
    content=(
      #|(
      #|  [
      #|    "moon.pkg",
      #|    "state.generated.mbt",
      #|    "view.generated.mbt",
      #|    "view.generated.mbt.map.json",
      #|    "selene-xaml.lock.json",
      #|  ],
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|)
    ),
  )
}

///|
test "CG-ABI-01 action ABI changes participate in the lock fingerprint" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState" x:Name="root">
    #| <ui:Button x:Name="primaryAction" OnClick="save"><ui:Text Text="Save" /></ui:Button>
    #|</ui:View>
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoState {
    #|  title : String
    #|}
  let renamed_action = xaml.replace(
    old="OnClick=\"save\"",
    new="OnClick=\"archive\"",
  )
  let changed_literal = xaml.replace(old="Text=\"Save\"", new="Text=\"Store\"")
  let base = @codegen.generate_embedded_view_package(
    "ui/demo.xaml", xaml, "model/demo.mbti", mbti,
  )
  let renamed = @codegen.generate_embedded_view_package(
    "ui/demo.xaml", renamed_action, "model/demo.mbti", mbti,
  )
  let literal = @codegen.generate_embedded_view_package(
    "ui/demo.xaml", changed_literal, "model/demo.mbti", mbti,
  )
  let marker = "\"abi_fingerprint\": \"sha256:"
  let base_lock = base.files.last().unwrap().content
  let renamed_lock = renamed.files.last().unwrap().content
  let literal_lock = literal.files.last().unwrap().content
  let base_start = base_lock.find(marker).unwrap() + marker.length()
  let renamed_start = renamed_lock.find(marker).unwrap() + marker.length()
  let literal_start = literal_lock.find(marker).unwrap() + marker.length()
  let base_fingerprint = base_lock[base_start:base_start + 64]
  let renamed_fingerprint = renamed_lock[renamed_start:renamed_start + 64]
  let literal_fingerprint = literal_lock[literal_start:literal_start + 64]
  debug_inspect(
    (
      base_fingerprint.length(),
      base_fingerprint != renamed_fingerprint,
      base_fingerprint == literal_fingerprint,
      base.files[2].content.contains("DemoViewAction::Save"),
      renamed.files[2].content.contains("DemoViewAction::Archive"),
    ),
    content="(64, true, true, true, true)",
  )
}

///|
test "CG-PATH-01 generator paths are canonical repository artifacts" {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model" x:Class="DemoView" ui:DataType="model:DemoState" />
  let mbti =
    #|package "example/demo/model"
    #|pub(all) struct DemoState {
    #|  title : String
    #|}
  let generated = @codegen.generate_embedded_view_package(
    "./ui/sections/../demo.xaml", xaml, "contracts/../model/./demo.mbti", mbti,
  )
  let state = generated.files[1].content
  let lock = generated.files.last().unwrap().content
  debug_inspect(
    (
      state.contains("// input user ui/demo.xaml sha256="),
      state.contains("// input moon-info model/demo.mbti sha256="),
      lock.contains("\"path\": \"ui/demo.xaml\""),
      lock.contains("\"path\": \"model/demo.mbti\""),
      !lock.contains("../"),
      !lock.contains("./"),
    ),
    content="(true, true, true, true, true, true)",
  )
  let invalid_paths = [
    "../ui/demo.xaml", "ui/../../demo.xaml", "/workspace/ui/demo.xaml", "C:\\workspace\\ui\\demo.xaml",
    "ui/..",
  ]
  let messages : Array[String] = []
  for path in invalid_paths {
    try
      @codegen.generate_embedded_view_package(
        path, xaml, "model/demo.mbti", mbti,
      )
    catch {
      @embedded_emitter.EmbeddedEmitterError::InvalidArtifactPath(message) =>
        messages.push(message)
      error => raise error
    } noraise {
      _ => fail("unsafe generator path must be rejected")
    }
  }
  debug_inspect(
    messages,
    content=(
      #|[
      #|  "generator input path escapes the repository: ../ui/demo.xaml",
      #|  "generator input path escapes the repository: ui/../../demo.xaml",
      #|  "generator input paths must be repository-relative: /workspace/ui/demo.xaml",
      #|  "generator input paths must be repository-relative: C:\\workspace\\ui\\demo.xaml",
      #|  "generator input paths must name a repository artifact: ui/..",
      #|]
    ),
  )
}

///|
async test "CG-FORMAT-01 snapshots canonical moonfmt output" (t : @test.Test) {
  // This fixture covers the currently emitted Inventory shapes, including long
  // keys, interpolated item paths, records, patch methods, and action routes.
  // It does not claim moonfmt equivalence for unbounded .mbti identifiers,
  // deeply nested authored type expressions, or arbitrarily long rect bindings.
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/canonical/model" x:Class="CanonicalFormattingView"
    #| ui:DataType="model:CanonicalFormattingState" x:Name="extraordinarilyLongFormattingAcceptanceRoot">
    #| <ui:ItemsControl x:Name="extraordinarilyLongFormattingAcceptanceItems"
    #|  ItemsSource="{ui:Binding Path=items}" KeyPath="id"><ui:ItemsControl.ItemTemplate>
    #|  <ui:DataTemplate ui:DataType="model:CanonicalFormattingItem">
    #|   <ui:Button x:Name="extraordinarilyLongFormattingAcceptanceButton" OnClick="select_item" Margin="1 2 3 4">
    #|    <ui:Text x:Name="extraordinarilyLongFormattingAcceptanceLabel" Text="{ui:Binding Path=label}" />
    #|   </ui:Button>
    #|  </ui:DataTemplate>
    #| </ui:ItemsControl.ItemTemplate></ui:ItemsControl>
    #|</ui:View>
  let mbti =
    #|package "example/canonical/model"
    #|pub(all) struct CanonicalFormattingItem {
    #|  id : String
    #|  label : String
    #|}
    #|pub(all) struct CanonicalFormattingState {
    #|  items : Array[CanonicalFormattingItem]
    #|}
    #|pub(all) enum CanonicalFormattingPatch {
    #|  ItemsReplace(Array[CanonicalFormattingItem])
    #|  ItemUpsert(CanonicalFormattingItem)
    #|  ItemRemove(String)
    #|  ItemMove((String, UInt))
    #|}
  let generated = @generator_io.format_generated_package(
    @codegen.generate_embedded_view_package(
      "fixtures/formatting/acceptance-view.xaml", xaml, "fixtures/formatting/canonical-model.mbti",
      mbti,
    ),
  )
  let state = generated.files[1].content
  let view = generated.files[2].content
  assert_eq(state.has_suffix("\n\n"), false)
  assert_eq(
    view.contains(
      "key: \"extraordinarily-long-formatting-acceptance-root/items:\\{generated_item_key_1}/extraordinarily-long-formatting-acceptance-button\"",
    ),
    true,
  )
  assert_eq(
    view.contains(
      "parent: Some(\n        \"extraordinarily-long-formatting-acceptance-root/items:\\{generated_item_key_1}/extraordinarily-long-formatting-acceptance-button\",\n      ),",
    ),
    true,
  )
  assert_eq(
    view.contains(
      "for spec in previous {\n    previous_by_key[spec.key] = spec\n  }",
    ),
    true,
  )
  assert_eq(view.contains("host.apply(entity, mutations)"), true)
  assert_eq(
    view.contains(
      "CanonicalFormattingView::replace(entity, { ..record.model, items, })",
    ),
    true,
  )
  assert_eq(view.contains(" + \"/items:"), false)
  assert_eq(view.contains("{ raise Released }"), false)
  for file in generated.files {
    let header =
      $|===== \{file.path} =====
    t.writeln(header)
    t.write(file.content)
    if !file.content.has_suffix("\n") {
      t.writeln("")
    }
    t.writeln("")
  }
  t.snapshot(filename="canonical_embedded_package.txt")
}
