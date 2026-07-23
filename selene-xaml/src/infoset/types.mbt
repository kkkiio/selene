///|
pub let xaml_2006_namespace : String = "http://schemas.microsoft.com/winfx/2006/xaml"

///|
pub let selene_ui_namespace : String = "urn:selene:xaml:ui"

///|
pub let markup_compatibility_namespace : String = "http://schemas.openxmlformats.org/markup-compatibility/2006"

///|
pub let xml_namespace : String = "http://www.w3.org/XML/1998/namespace"

///|
pub(all) struct XamlQualifiedName {
  namespace_uri : String
  local_name : String
  prefix : String?
} derive(Eq, Debug)

///|
pub fn XamlQualifiedName::XamlQualifiedName(
  namespace_uri : String,
  local_name : String,
  prefix? : String? = None,
) -> XamlQualifiedName {
  { namespace_uri, local_name, prefix }
}

///|
pub(all) struct XamlSourcePosition {
  offset : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
pub(all) struct XamlSourceSpan {
  source_uri : String
  start : XamlSourcePosition
  end : XamlSourcePosition
} derive(Eq, Debug)

///|
pub fn XamlSourceSpan::unknown(source_uri : String) -> XamlSourceSpan {
  {
    source_uri,
    start: { offset: 0, line: 1, column: 1 },
    end: { offset: 0, line: 1, column: 1 },
  }
}

///|
pub(all) enum XamlDiagnosticSeverity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub(all) struct XamlDiagnostic {
  code : String
  message : String
  severity : XamlDiagnosticSeverity
  span : XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) suberror XamlError {
  Diagnostic(XamlDiagnostic)
  FileNotFound(String)
  InvalidUtf8(String)
} derive(Eq, Debug)

///|
pub impl Show for XamlError with fn output(self, logger) {
  match self {
    Diagnostic(value) =>
      logger.write_string(
        value.span.source_uri +
        ":" +
        value.span.start.line.to_string() +
        ":" +
        value.span.start.column.to_string() +
        " " +
        value.code +
        ": " +
        value.message,
      )
    FileNotFound(path) => logger.write_string("XAML file not found: " + path)
    InvalidUtf8(path) =>
      logger.write_string("XAML file is not valid UTF-8: " + path)
  }
}

///|
pub(all) struct XamlNamespaceNode {
  prefix : String?
  namespace_uri : String
  span : XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) enum XamlMarkupValue {
  Literal(String)
  Extension(XamlMarkupExtension)
} derive(Eq, Debug)

///|
pub(all) struct XamlMarkupArgument {
  name : String?
  value : XamlMarkupValue
} derive(Eq, Debug)

///|
pub(all) struct XamlMarkupExtension {
  type_name : XamlQualifiedName
  arguments : Array[XamlMarkupArgument]
  span : XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct XamlTextNode {
  text : String
  span : XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) enum XamlValueNode {
  Object(XamlObjectNode)
  Text(XamlTextNode)
  Markup(XamlMarkupExtension)
} derive(Eq, Debug)

///|
pub(all) struct XamlMemberNode {
  name : XamlQualifiedName
  values : Array[XamlValueNode]
  is_attached : Bool
  is_directive : Bool
  span : XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct XamlObjectNode {
  type_name : XamlQualifiedName
  members : Array[XamlMemberNode]
  namespaces : Array[XamlNamespaceNode]
  span : XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct XamlDocument {
  source_uri : String
  root : XamlObjectNode
  namespaces : Array[XamlNamespaceNode]
  diagnostics : Array[XamlDiagnostic]
} derive(Eq, Debug)

///|
pub(all) enum XamlData {
  Null
  Bool(Bool)
  Int(Int)
  Double(Double)
  String(String)
  Array(Array[XamlData])
  Object(Map[String, XamlData])
} derive(Eq, Debug)

///|
pub fn XamlData::object(entries : Array[(String, XamlData)]) -> XamlData {
  let result : Map[String, XamlData] = Map([])
  for entry in entries {
    result[entry.0] = entry.1
  }
  Object(result)
}

///|
pub fn XamlData::get_path(self : XamlData, path : String) -> XamlData? {
  if path == "" || path == "." {
    return Some(self)
  }
  let mut current = self
  for part in path.split(".") {
    match current {
      Object(values) =>
        match values.get(part.to_owned()) {
          Some(value) => current = value
          None => return None
        }
      Array(values) => {
        let index = @string.parse_int(part) catch { _ => return None }
        if index < 0 || index >= values.length() {
          return None
        }
        current = values[index]
      }
      _ => return None
    }
  }
  Some(current)
}

///|
pub fn XamlData::as_string(self : XamlData) -> String {
  match self {
    Null => ""
    Bool(value) => value.to_string()
    Int(value) => value.to_string()
    Double(value) => value.to_string()
    String(value) => value
    Array(_) => "[Array]"
    Object(_) => "[Object]"
  }
}

///|
pub fn xaml_failure(
  code : String,
  message : String,
  span : XamlSourceSpan,
) -> XamlError {
  XamlError::Diagnostic({ code, message, severity: Error, span })
}

///|
pub fn XamlObjectNode::find_member(
  self : XamlObjectNode,
  name : String,
) -> XamlMemberNode? {
  for definition in self.members {
    if definition.name.local_name == name {
      return Some(definition)
    }
  }
  None
}

///|
pub fn XamlMemberNode::literal(self : XamlMemberNode) -> String? {
  guard self.values.length() > 0 else { return None }
  match self.values[0] {
    Text(value) => Some(value.text)
    Markup(extension) =>
      if extension.arguments.length() > 0 {
        match extension.arguments[0].value {
          Literal(value) => Some(value)
          _ => None
        }
      } else {
        None
      }
    Object(_) => None
  }
}

///|
pub fn XamlMemberNode::binding(self : XamlMemberNode) -> (String, Bool)? {
  guard self.values.length() > 0 else { return None }
  guard self.values[0] is Markup(extension) else { return None }
  if extension.type_name.namespace_uri != selene_ui_namespace ||
    (
      extension.type_name.local_name != "Binding" &&
      extension.type_name.local_name != "TemplateBinding"
    ) {
    return None
  }
  let mut path = "."
  for argument in extension.arguments {
    match argument.value {
      Literal(value) =>
        match argument.name {
          Some("Path") => path = value
          None => path = value
          _ => ()
        }
      _ => ()
    }
  }
  Some((path, extension.type_name.local_name == "TemplateBinding"))
}
