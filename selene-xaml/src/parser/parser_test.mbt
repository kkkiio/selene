///|
test "PC-INFOSET-01 namespace property attached content whitespace and spans" {
  let source =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"
    #|         xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #|         xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #|         xmlns:d="urn:fixture:designer" mc:Ignorable="d" d:Width="900">
    #|  <ui:View.Children>
    #|    <ui:Grid Columns="1fr 2fr">
    #|      <ui:Text x:Name="title" ui:Grid.Column="1">  Signal   Board  </ui:Text>
    #|      <d:Guide d:Mode="grid" />
    #|    </ui:Grid>
    #|  </ui:View.Children>
    #|</ui:View>
  let document = @parser.parse_xaml(
    "fixture.xaml",
    source,
    @infoset.selene_xaml_schemas(),
  )
  inspect(document.root.type_name.local_name, content="View")
  inspect(document.root.namespaces.length(), content="4")
  let children = document.root.find_member("Children").unwrap()
  inspect(children.values.length(), content="1")
  guard children.values[0] is @infoset.XamlValueNode::Object(grid) else {
    fail("expected Grid")
  }
  let grid_children = grid.find_member("Children").unwrap()
  inspect(grid_children.values.length(), content="1")
  guard grid_children.values[0] is @infoset.XamlValueNode::Object(text) else {
    fail("expected Text")
  }
  inspect(text.find_member("Grid.Column").unwrap().is_attached, content="true")
  debug_inspect(
    text.span,
    content=(
      #|{
      #|  source_uri: "fixture.xaml",
      #|  start: { offset: 314, line: 7, column: 7 },
      #|  end: { offset: 357, line: 7, column: 50 },
      #|}
    ),
  )
  debug_inspect(
    text.find_member("Spans").unwrap().literal(),
    content="Some(\"Signal Board\")",
  )
}

///|
test "PC-SPACE-01 xml space preserves authored text" {
  let source =
    #|<ui:Text xmlns:ui="urn:selene:xaml:ui"
    #|         xml:space="preserve"> A
    #|  B </ui:Text>
  let document = @parser.parse_xaml(
    "space.xaml",
    source,
    @infoset.selene_xaml_schemas(),
  )
  let value = document.root.find_member("Spans").unwrap().literal().unwrap()
  assert_true(value.contains("\n"))
  assert_true(value.has_prefix(" A"))
}

///|
test "PC-ME-01 parses nested named and positional markup arguments" {
  let namespaces : Map[String, String] = Map([
    ("ui", @infoset.selene_ui_namespace),
    ("x", @infoset.xaml_2006_namespace),
  ])
  let extension = @parser.parse_markup_extension(
    "markup.xaml", "{ui:Binding Path=selected.name, Fallback={x:Null}}", namespaces,
  )
  inspect(extension.type_name.local_name, content="Binding")
  inspect(extension.arguments.length(), content="2")
  debug_inspect(extension.arguments[0].name, content="Some(\"Path\")")
  guard extension.arguments[1].value
    is @infoset.XamlMarkupValue::Extension(nested) else {
    fail("expected nested markup extension")
  }
  inspect(nested.type_name.local_name, content="Null")
}

///|
test "PC-ME-02 escape and PC-ME-03 intrinsic values remain typed" {
  let source =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    #|  <ui:Text Text="{}{literal}" />
    #|  <ui:Text Text="{x:Type ui:Button}" />
    #|  <ui:Text Text="{x:Null}" />
    #|</ui:View>
  let document = @parser.parse_xaml(
    "intrinsics.xaml",
    source,
    @infoset.selene_xaml_schemas(),
  )
  let values = document.root.find_member("Children").unwrap().values
  guard values[0] is @infoset.XamlValueNode::Object(literal) else {
    fail("expected literal text")
  }
  debug_inspect(
    literal.find_member("Text").unwrap().literal(),
    content="Some(\"{literal}\")",
  )
  guard values[1] is @infoset.XamlValueNode::Object(type_value) else {
    fail("expected type extension")
  }
  guard type_value.find_member("Text").unwrap().values[0]
    is @infoset.XamlValueNode::Markup(type_extension) else {
    fail("expected typed extension")
  }
  inspect(type_extension.type_name.local_name, content="Type")
  guard values[2] is @infoset.XamlValueNode::Object(null_value) else {
    fail("expected null extension")
  }
  guard null_value.find_member("Text").unwrap().values[0]
    is @infoset.XamlValueNode::Markup(null_extension) else {
    fail("expected typed extension")
  }
  inspect(null_extension.type_name.local_name, content="Null")
  let unsupported =
    #|<ui:Text xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #|         Text="{x:Static Missing.Value}" />
  try {
    ignore(
      @parser.parse_xaml(
        "unsupported-extension.xaml",
        unsupported,
        @infoset.selene_xaml_schemas(),
      ),
    )
    fail("expected unknown markup extension")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1205")
    error => raise error
  }
  let unknown_type =
    #|<ui:Text xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #|         Text="{x:Type ui:Missing}" />
  try {
    ignore(
      @parser.parse_xaml(
        "unknown-type.xaml",
        unknown_type,
        @infoset.selene_xaml_schemas(),
      ),
    )
    fail("expected unknown x:Type")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1206")
    error => raise error
  }
}

///|
test "PC-DIRECTIVE-01 maps Items Initialization and PositionalParameters" {
  let source =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    #|  <x:Items><ui:Text Text="item" /></x:Items>
    #|  <x:PositionalParameters>left, right</x:PositionalParameters>
    #|  <x:Initialization>ready</x:Initialization>
    #|</ui:View>
  let root = @parser.parse_xaml(
      "directives.xaml",
      source,
      @infoset.selene_xaml_schemas(),
    ).root
  inspect(root.find_member("Items").unwrap().is_directive, content="true")
  inspect(root.find_member("Items").unwrap().values.length(), content="1")
  debug_inspect(
    root.find_member("PositionalParameters").unwrap().literal(),
    content="Some(\"left, right\")",
  )
  debug_inspect(
    root.find_member("Initialization").unwrap().literal(),
    content="Some(\"ready\")",
  )
}

///|
test "PC-DIRECTIVE-02 retains typed data scope and root x:Class" {
  let source =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"
    #|         xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #|         xmlns:model="moonbit:example/inventory/model"
    #|         x:Class="InventoryView"
    #|         ui:DataType="model:InventoryUiState">
    #|  <ui:ItemsControl ItemsSource="{ui:Binding Path=items}" KeyPath="id">
    #|    <ui:ItemsControl.ItemTemplate>
    #|      <ui:DataTemplate ui:DataType="model:InventoryItem">
    #|        <ui:Text Text="{ui:Binding Path=name}" />
    #|      </ui:DataTemplate>
    #|    </ui:ItemsControl.ItemTemplate>
    #|  </ui:ItemsControl>
    #|</ui:View>
  let root = @parser.parse_xaml(
      "typed-view.xaml",
      source,
      @infoset.selene_xaml_schemas(),
    ).root
  let model_namespaces = root.namespaces.filter_map(mapping => {
    if mapping.prefix == Some("model") {
      Some(mapping.namespace_uri)
    } else {
      None
    }
  })
  debug_inspect(
    (
      root.find_member("Class").unwrap().literal(),
      root.find_member("DataType").unwrap().literal(),
      model_namespaces,
    ),
    content=(
      #|(
      #|  Some("InventoryView"),
      #|  Some("model:InventoryUiState"),
      #|  ["moonbit:example/inventory/model"],
      #|)
    ),
  )
  let child = root.find_member("Children").unwrap().values[0]
  guard child is @infoset.XamlValueNode::Object(items) else {
    fail("expected ItemsControl")
  }
  let template = items.find_member("ItemTemplate").unwrap().values[0]
  guard template is @infoset.XamlValueNode::Object(data_template) else {
    fail("expected DataTemplate")
  }
  debug_inspect(
    data_template.find_member("DataType").unwrap().literal(),
    content="Some(\"model:InventoryItem\")",
  )
  try
    @parser.parse_xaml(
      "nested-class.xaml",
      (
        #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
        #|  <ui:Text x:Class="NestedView" />
        #|</ui:View>
      ),
      @infoset.selene_xaml_schemas(),
    )
  catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      debug_inspect(
        (diagnostic.code, diagnostic.message),
        content=(
          #|("SX1123", "x:Class is only valid on the document root")
        ),
      )
    error => raise error
  } noraise {
    _ => fail("expected nested x:Class to fail")
  }
}

///|
test "PC-SCHEMA-01 PC-SCHEMA-02 PC-SCHEMA-03 schema API rejects duplicate types" {
  try {
    ignore(
      @infoset.XamlTypeDefinition("Broken", members=[
        @infoset.XamlMemberDefinition("Value", String),
        @infoset.XamlMemberDefinition("Value", String),
      ]),
    )
    fail("expected duplicate schema member")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1002")
    error => raise error
  }
  let builder = @infoset.XamlSchemaBuilder("urn:test:schema")
  builder.add_type(
    @infoset.XamlTypeDefinition("Widget", content_member=Some("Children"), members=[
      @infoset.XamlMemberDefinition("Children", Any, is_collection=true),
    ]),
  )
  try {
    builder.add_type(@infoset.XamlTypeDefinition("Widget"))
    fail("expected duplicate schema type")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1001")
    error => raise error
  }
  let registry = @infoset.XamlSchemaRegistry().register(builder.build())
  assert_true(registry.schema("urn:test:schema") is Some(_))
}

///|
test "PC-DOC-01 PC-XML-01 ignores comments and rejects trailing roots" {
  let valid =
    #|<?preview yes?><ui:View xmlns:ui="urn:selene:xaml:ui"><!-- note --></ui:View>
  let document = @parser.parse_xaml(
    "document.xaml",
    valid,
    @infoset.selene_xaml_schemas(),
  )
  inspect(document.root.type_name.local_name, content="View")
  let invalid =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"/><ui:View xmlns:ui="urn:selene:xaml:ui"/>
  try {
    ignore(
      @parser.parse_xaml(
        "two-roots.xaml",
        invalid,
        @infoset.selene_xaml_schemas(),
      ),
    )
    fail("expected trailing root rejection")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1100")
    error => raise error
  }
}

///|
test "PC-DTD-01 rejects DTD before object mapping" {
  let source =
    #|<!DOCTYPE ui:View [<!ENTITY custom "unsafe">]>
    #|<ui:View xmlns:ui="urn:selene:xaml:ui">&custom;</ui:View>
  try {
    ignore(
      @parser.parse_xaml("dtd.xaml", source, @infoset.selene_xaml_schemas()),
    )
    fail("expected DTD rejection")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1113")
    error => raise error
  }
}

///|
test "PC-DUP-01 rejects duplicate names and duplicate members" {
  let duplicate_names =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    #|  <ui:Text x:Name="same" />
    #|  <ui:Button x:Name="same" />
    #|</ui:View>
  try {
    ignore(
      @parser.parse_xaml(
        "names.xaml",
        duplicate_names,
        @infoset.selene_xaml_schemas(),
      ),
    )
    fail("expected duplicate name")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1112")
    error => raise error
  }
  let duplicate_member =
    #|<ui:Text xmlns:ui="urn:selene:xaml:ui" Text="one">
    #|  <ui:Text.Text>two</ui:Text.Text>
    #|</ui:Text>
  try {
    ignore(
      @parser.parse_xaml(
        "members.xaml",
        duplicate_member,
        @infoset.selene_xaml_schemas(),
      ),
    )
    fail("expected duplicate member")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1117")
    error => raise error
  }
}

///|
test "PC-UNKNOWN-01 rejects unknown non-ignorable namespaces" {
  let source =
    #|<unknown:Thing xmlns:unknown="urn:not:registered" />
  try {
    ignore(
      @parser.parse_xaml("unknown.xaml", source, @infoset.selene_xaml_schemas()),
    )
    fail("expected unknown type")
  } catch {
    @infoset.XamlError::Diagnostic(diagnostic) =>
      inspect(diagnostic.code, content="SX1103")
    error => raise error
  }
}

///|
test "PC-NS-01 default namespace resolves unprefixed elements and attributes" {
  let source =
    #|<View xmlns="urn:selene:xaml:ui"
    #|      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    #|  <Flex>
    #|    <Text x:Name="label" Text="Hello" />
    #|    <Button OnClick="go">
    #|      <Image Source="icon.png" />
    #|    </Button>
    #|  </Flex>
    #|</View>
  let document = @parser.parse_xaml(
    "default-ns.xaml",
    source,
    @infoset.selene_xaml_schemas(),
  )
  inspect(document.root.type_name.local_name, content="View")
  inspect(document.root.type_name.namespace_uri, content="urn:selene:xaml:ui")
  let children = document.root.find_member("Children").unwrap()
  guard children.values[0] is @infoset.XamlValueNode::Object(flex) else {
    fail("expected Flex")
  }
  inspect(flex.type_name.local_name, content="Flex")
  let flex_children = flex.find_member("Children").unwrap()
  guard flex_children.values[0] is @infoset.XamlValueNode::Object(text) else {
    fail("expected Text")
  }
  inspect(text.type_name.local_name, content="Text")
  let name_member = text.find_member("Name")
  guard name_member is Some(_) else { fail("expected x:Name") }
  inspect(name_member.unwrap().is_directive, content="true")
  debug_inspect(
    text.find_member("Text").unwrap().literal(),
    content=(
      #|Some("Hello")
    ),
  )
}
