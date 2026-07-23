///|
pub(all) enum XamlScalarType {
  Any
  String
  Bool
  Int
  Double
  Val
  Color
  Rect
  Radius
  EntityReference
  Data
} derive(Eq, Debug)

///|
pub(all) struct XamlMemberDefinition {
  name : String
  value_type : XamlScalarType
  is_attached : Bool
  is_collection : Bool
  is_required : Bool
} derive(Eq, Debug)

///|
pub fn XamlMemberDefinition::XamlMemberDefinition(
  name : String,
  value_type : XamlScalarType,
  is_attached? : Bool = false,
  is_collection? : Bool = false,
  is_required? : Bool = false,
) -> XamlMemberDefinition {
  { name, value_type, is_attached, is_collection, is_required }
}

///|
pub(all) struct XamlTypeDefinition {
  name : String
  content_member : String?
  members : Map[String, XamlMemberDefinition]
  is_collection : Bool
  is_markup_extension : Bool
} derive(Eq, Debug)

///|
pub fn XamlTypeDefinition::XamlTypeDefinition(
  name : String,
  content_member? : String? = None,
  members? : Array[XamlMemberDefinition] = [],
  is_collection? : Bool = false,
  is_markup_extension? : Bool = false,
) -> XamlTypeDefinition raise XamlError {
  let member_map : Map[String, XamlMemberDefinition] = Map([])
  for definition in members {
    if definition.name == "" || member_map.contains(definition.name) {
      raise xaml_failure(
        "SX1002",
        "invalid or duplicate XAML member definition: " + definition.name,
        XamlSourceSpan::unknown(name),
      )
    }
    member_map[definition.name] = definition
  }
  match content_member {
    Some(content_name) if !member_map.contains(content_name) =>
      raise xaml_failure(
        "SX1003",
        "content member is not defined on XAML type " +
        name +
        ": " +
        content_name,
        XamlSourceSpan::unknown(name),
      )
    _ => ()
  }
  {
    name,
    content_member,
    members: member_map,
    is_collection,
    is_markup_extension,
  }
}

///|
pub(all) struct XamlSchema {
  namespace_uri : String
  types : Map[String, XamlTypeDefinition]
} derive(Eq, Debug)

///|
pub(all) struct XamlSchemaBuilder {
  namespace_uri : String
  types : Array[XamlTypeDefinition]
}

///|
pub fn XamlSchemaBuilder::XamlSchemaBuilder(
  namespace_uri : String,
) -> XamlSchemaBuilder {
  { namespace_uri, types: [] }
}

///|
pub fn XamlSchemaBuilder::add_type(
  self : XamlSchemaBuilder,
  definition : XamlTypeDefinition,
) -> Unit raise XamlError {
  for existing in self.types {
    if existing.name == definition.name {
      let span = XamlSourceSpan::unknown(self.namespace_uri)
      raise XamlError::Diagnostic({
        code: "SX1001",
        message: "duplicate XAML type definition: " + definition.name,
        severity: Error,
        span,
      })
    }
  }
  self.types.push(definition)
}

///|
pub fn XamlSchemaBuilder::build(self : XamlSchemaBuilder) -> XamlSchema {
  let types : Map[String, XamlTypeDefinition] = Map([])
  for definition in self.types {
    types[definition.name] = definition
  }
  { namespace_uri: self.namespace_uri, types }
}

///|
pub(all) struct XamlSchemaRegistry {
  schemas : Map[String, XamlSchema]
}

///|
pub fn XamlSchemaRegistry::XamlSchemaRegistry() -> XamlSchemaRegistry {
  { schemas: Map([]) }
}

///|
pub fn XamlSchemaRegistry::register(
  self : XamlSchemaRegistry,
  schema : XamlSchema,
) -> XamlSchemaRegistry {
  self.schemas[schema.namespace_uri] = schema
  self
}

///|
pub fn XamlSchemaRegistry::schema(
  self : XamlSchemaRegistry,
  namespace_uri : String,
) -> XamlSchema? {
  self.schemas.get(namespace_uri)
}

///|
pub fn XamlSchemaRegistry::type_definition(
  self : XamlSchemaRegistry,
  name : XamlQualifiedName,
) -> XamlTypeDefinition? {
  match self.schemas.get(name.namespace_uri) {
    Some(schema) => schema.types.get(name.local_name)
    None => None
  }
}

///|
pub fn selene_xaml_schemas() -> XamlSchemaRegistry raise XamlError {
  let common = [
    XamlMemberDefinition("Id", String),
    XamlMemberDefinition("DataType", String),
    XamlMemberDefinition("Slot", String, is_attached=true),
    XamlMemberDefinition("Width", Val),
    XamlMemberDefinition("Height", Val),
    XamlMemberDefinition("MinWidth", Val),
    XamlMemberDefinition("MinHeight", Val),
    XamlMemberDefinition("MaxWidth", Val),
    XamlMemberDefinition("MaxHeight", Val),
    XamlMemberDefinition("Grow", Double),
    XamlMemberDefinition("Shrink", Double),
    XamlMemberDefinition("Basis", Val),
    XamlMemberDefinition("Margin", Rect),
    XamlMemberDefinition("Padding", Rect),
    XamlMemberDefinition("Background", Color),
    XamlMemberDefinition("BorderColor", Color),
    XamlMemberDefinition("Border", Rect),
    XamlMemberDefinition("Radius", Radius),
    XamlMemberDefinition("OutlineColor", Color),
    XamlMemberDefinition("OutlineWidth", Double),
    XamlMemberDefinition("OutlineOffset", Double),
    XamlMemberDefinition("Shadow", String),
    XamlMemberDefinition("Display", String),
    XamlMemberDefinition("Position", String),
    XamlMemberDefinition("Left", Val),
    XamlMemberDefinition("Top", Val),
    XamlMemberDefinition("Right", Val),
    XamlMemberDefinition("Bottom", Val),
    XamlMemberDefinition("ZIndex", Int),
    XamlMemberDefinition("Target", EntityReference),
    XamlMemberDefinition("Watch", EntityReference),
    XamlMemberDefinition("TabIndex", Int),
    XamlMemberDefinition("Focusable", Bool),
    XamlMemberDefinition("FocusScope", Bool),
    XamlMemberDefinition("AutoFocus", Bool),
    XamlMemberDefinition("Enabled", Bool),
    XamlMemberDefinition("OnClick", String),
    XamlMemberDefinition("OnPointerDown", String),
    XamlMemberDefinition("OnEnter", String),
    XamlMemberDefinition("OnExit", String),
    XamlMemberDefinition("OnFocus", String),
    XamlMemberDefinition("OnBlur", String),
    XamlMemberDefinition("OnSpawn", String),
    XamlMemberDefinition("OnChange", String),
    XamlMemberDefinition("VisualStates", Any, is_collection=true),
  ]
  let content = XamlMemberDefinition("Children", Any, is_collection=true)
  let visual_types = ["View", "Flex", "Grid", "ScrollView", "Button"]
  let builder = XamlSchemaBuilder(selene_ui_namespace)
  for name in visual_types {
    let members = common.copy()
    members.push(content)
    if name == "Flex" {
      members.push(XamlMemberDefinition("Direction", String))
      members.push(XamlMemberDefinition("Wrap", String))
      members.push(XamlMemberDefinition("Gap", Double))
      members.push(XamlMemberDefinition("RowGap", Double))
      members.push(XamlMemberDefinition("ColumnGap", Double))
      members.push(XamlMemberDefinition("Justify", String))
      members.push(XamlMemberDefinition("Align", String))
    } else if name == "Grid" {
      members.push(XamlMemberDefinition("Gap", Double))
      members.push(XamlMemberDefinition("RowGap", Double))
      members.push(XamlMemberDefinition("ColumnGap", Double))
      members.push(XamlMemberDefinition("Rows", String))
      members.push(XamlMemberDefinition("Columns", String))
      members.push(XamlMemberDefinition("AutoFlow", String))
      members.push(XamlMemberDefinition("Row", Int, is_attached=true))
      members.push(XamlMemberDefinition("Column", Int, is_attached=true))
      members.push(XamlMemberDefinition("RowSpan", Int, is_attached=true))
      members.push(XamlMemberDefinition("ColumnSpan", Int, is_attached=true))
    } else if name == "ScrollView" {
      members.push(XamlMemberDefinition("HorizontalScroll", Bool))
      members.push(XamlMemberDefinition("VerticalScroll", Bool))
      members.push(XamlMemberDefinition("ScrollbarWidth", Double))
    }
    builder.add_type(
      XamlTypeDefinition(name, content_member=Some("Children"), members~),
    )
  }
  builder.add_type(
    XamlTypeDefinition("Navigation", members=[
      XamlMemberDefinition("Up", String, is_attached=true),
      XamlMemberDefinition("Down", String, is_attached=true),
      XamlMemberDefinition("Left", String, is_attached=true),
      XamlMemberDefinition("Right", String, is_attached=true),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition(
      "Text",
      content_member=Some("Spans"),
      members=common +
        [
          XamlMemberDefinition("Text", String),
          XamlMemberDefinition("Spans", Any, is_collection=true),
          XamlMemberDefinition("Color", Color),
          XamlMemberDefinition("FontFamily", String),
          XamlMemberDefinition("FontSize", Double),
          XamlMemberDefinition("Bold", Bool),
          XamlMemberDefinition("Align", String),
          XamlMemberDefinition("Wrap", String),
          XamlMemberDefinition("Overflow", String),
          XamlMemberDefinition("LineHeight", Double),
        ],
    ),
  )
  builder.add_type(
    XamlTypeDefinition("Span", content_member=Some("Text"), members=[
      XamlMemberDefinition("Text", String),
      XamlMemberDefinition("Color", Color),
      XamlMemberDefinition("FontFamily", String),
      XamlMemberDefinition("FontSize", Double),
      XamlMemberDefinition("Bold", Bool),
      XamlMemberDefinition("Underline", Bool),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition(
      "Image",
      members=common +
        [
          XamlMemberDefinition("Source", String, is_required=true),
          XamlMemberDefinition("Fit", String),
          XamlMemberDefinition("Tint", Color),
          XamlMemberDefinition("SourceRegion", Rect),
        ],
    ),
  )
  builder.add_type(
    XamlTypeDefinition(
      "ItemsControl",
      members=common +
        [
          XamlMemberDefinition("ItemsSource", Data, is_required=true),
          XamlMemberDefinition("ItemTemplate", Any, is_required=true),
          XamlMemberDefinition("KeyPath", String),
        ],
    ),
  )
  builder.add_type(
    XamlTypeDefinition("If", members=[
      XamlMemberDefinition("Condition", Data, is_required=true),
      XamlMemberDefinition("Then", Any, is_collection=true),
      XamlMemberDefinition("Else", Any, is_collection=true),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition("DataTemplate", content_member=Some("Content"), members=[
      XamlMemberDefinition("DataType", String),
      XamlMemberDefinition("Content", Any, is_collection=true),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition("Component", content_member=Some("Content"), members=[
      XamlMemberDefinition("Name", String, is_required=true),
      XamlMemberDefinition("Namespace", String),
      XamlMemberDefinition("Parameters", Any, is_collection=true),
      XamlMemberDefinition("Content", Any, is_collection=true),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition("Parameter", members=[
      XamlMemberDefinition("Name", String, is_required=true),
      XamlMemberDefinition("Type", String, is_required=true),
      XamlMemberDefinition("Default", Any),
      XamlMemberDefinition("Required", Bool),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition("Slot", content_member=Some("Fallback"), members=[
      XamlMemberDefinition("Name", String),
      XamlMemberDefinition("Fallback", Any, is_collection=true),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition("VisualStateGroup", content_member=Some("States"), members=[
      XamlMemberDefinition("Name", String, is_required=true),
      XamlMemberDefinition("Current", Data),
      XamlMemberDefinition("States", Any, is_collection=true),
      XamlMemberDefinition("Transitions", Any, is_collection=true),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition("VisualState", content_member=Some("Setters"), members=[
      XamlMemberDefinition("Name", String, is_required=true),
      XamlMemberDefinition("Setters", Any, is_collection=true),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition("Setter", members=[
      XamlMemberDefinition("TargetName", String),
      XamlMemberDefinition("Property", String, is_required=true),
      XamlMemberDefinition("Value", Any, is_required=true),
    ]),
  )
  builder.add_type(
    XamlTypeDefinition("Transition", members=[
      XamlMemberDefinition("From", String),
      XamlMemberDefinition("To", String),
      XamlMemberDefinition("Duration", Double),
      XamlMemberDefinition("Delay", Double),
      XamlMemberDefinition("Easing", String),
    ]),
  )
  let ui_schema = builder.build()
  ui_schema.types["Binding"] = XamlTypeDefinition(
    "Binding",
    is_markup_extension=true,
  )
  ui_schema.types["TemplateBinding"] = XamlTypeDefinition(
    "TemplateBinding",
    is_markup_extension=true,
  )
  let x_builder = XamlSchemaBuilder(xaml_2006_namespace)
  x_builder.add_type(XamlTypeDefinition("Null", is_markup_extension=true))
  x_builder.add_type(XamlTypeDefinition("Reference", is_markup_extension=true))
  x_builder.add_type(XamlTypeDefinition("Type", is_markup_extension=true))
  XamlSchemaRegistry().register(x_builder.build()).register(ui_schema)
}
