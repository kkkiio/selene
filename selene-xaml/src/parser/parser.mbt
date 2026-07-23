///|
fn XamlSourceSpan::from_xml(
  source_uri : String,
  span : @xml.SourceSpan,
) -> XamlSourceSpan {
  {
    source_uri,
    start: {
      offset: span.start.offset,
      line: span.start.line,
      column: span.start.column,
    },
    end: {
      offset: span.end.offset,
      line: span.end.line,
      column: span.end.column,
    },
  }
}

///|
fn normalize_xaml_text(text : String, preserve : Bool) -> String {
  if preserve {
    return text
  }
  let output = StringBuilder::new()
  let mut pending_space = false
  let mut wrote_content = false
  for ch in text {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if wrote_content {
        pending_space = true
      }
    } else {
      if pending_space {
        output.write_char(' ')
      }
      output.write_char(ch)
      pending_space = false
      wrote_content = true
    }
  }
  output.to_string()
}

///|
fn xaml_qname(name : @xml.XmlName) -> XamlQualifiedName {
  XamlQualifiedName(
    name.namespace_uri.unwrap_or(""),
    name.local_name,
    prefix=name.prefix,
  )
}

///|
fn parse_xaml_member_value(
  source_uri : String,
  value : String,
  namespaces : Map[String, String],
  schemas : XamlSchemaRegistry,
  span : XamlSourceSpan,
) -> XamlValueNode raise XamlError {
  let trimmed = value.trim()
  if trimmed.has_prefix("{}") {
    XamlValueNode::Text({ text: trimmed[2:].to_owned(), span })
  } else if trimmed.has_prefix("{") {
    let extension = parse_markup_extension(source_uri, value, namespaces, span~)
    let pending = [extension]
    while pending.length() > 0 {
      let candidate = pending.pop().unwrap()
      guard schemas.type_definition(candidate.type_name)
        is Some(type_definition) &&
        type_definition.is_markup_extension else {
        raise xaml_failure(
          "SX1205",
          "unknown XAML markup extension {" +
          candidate.type_name.namespace_uri +
          "}" +
          candidate.type_name.local_name,
          candidate.span,
        )
      }
      if candidate.type_name.namespace_uri == xaml_2006_namespace &&
        candidate.type_name.local_name == "Type" {
        guard candidate.arguments.length() == 1 &&
          candidate.arguments[0].value is XamlMarkupValue::Literal(lexical_type) else {
          raise xaml_failure(
            "SX1206",
            "x:Type requires one literal qualified type name",
            candidate.span,
          )
        }
        let parts = lexical_type.split(":").to_array()
        let referenced_type = match parts {
          [local_name] =>
            XamlQualifiedName(
              namespaces.get("").unwrap_or(""),
              local_name.to_owned(),
            )
          [prefix, local_name] =>
            match namespaces.get(prefix.to_owned()) {
              Some(namespace_uri) =>
                XamlQualifiedName(namespace_uri, local_name.to_owned())
              None =>
                raise xaml_failure(
                  "SX1206",
                  "x:Type uses an unknown namespace prefix: " +
                  prefix.to_owned(),
                  candidate.span,
                )
            }
          _ =>
            raise xaml_failure(
              "SX1206",
              "x:Type requires a qualified type name",
              candidate.span,
            )
        }
        if schemas.type_definition(referenced_type) is None {
          raise xaml_failure(
            "SX1206",
            "x:Type references an unknown type: " + lexical_type,
            candidate.span,
          )
        }
      }
      if candidate.type_name.namespace_uri == xaml_2006_namespace &&
        candidate.type_name.local_name == "Null" &&
        candidate.arguments.length() != 0 {
        raise xaml_failure(
          "SX1206",
          "x:Null does not accept arguments",
          candidate.span,
        )
      }
      if candidate.type_name.namespace_uri == xaml_2006_namespace &&
        candidate.type_name.local_name == "Reference" &&
        !(candidate.arguments.length() == 1 &&
        candidate.arguments[0].value is XamlMarkupValue::Literal(reference_name) &&
        reference_name.trim() != "") {
        raise xaml_failure(
          "SX1206",
          "x:Reference requires one literal name",
          candidate.span,
        )
      }
      for argument in candidate.arguments {
        if argument.value is XamlMarkupValue::Extension(nested) {
          pending.push(nested)
        }
      }
    }
    XamlValueNode::Markup(extension)
  } else {
    XamlValueNode::Text({ text: value, span })
  }
}

///|
fn parse_object_event(
  events : Array[@xml.NamespaceEvent],
  start_index : Int,
  is_root : Bool,
  source_uri : String,
  schemas : XamlSchemaRegistry,
  inherited_namespaces : Map[String, String],
  inherited_ignorable : Map[String, Bool],
  inherited_preserve_space : Bool,
  names : Map[String, XamlSourceSpan],
) -> (XamlObjectNode, Int) raise XamlError {
  let start_event = events[start_index]
  let (element, empty) = match start_event.kind {
    Start(value) => (value, false)
    Empty(value) => (value, true)
    _ =>
      raise xaml_failure(
        "SX1101",
        "expected an object element",
        XamlSourceSpan::from_xml(source_uri, start_event.span),
      )
  }
  let object_span = XamlSourceSpan::from_xml(source_uri, start_event.span)
  let type_name = xaml_qname(element.name)
  let namespaces : Map[String, String] = Map([])
  for prefix, uri in inherited_namespaces {
    namespaces[prefix] = uri
  }
  let namespace_nodes : Array[XamlNamespaceNode] = []
  for declaration in element.namespace_declarations {
    let prefix = declaration.prefix.unwrap_or("")
    namespaces[prefix] = declaration.namespace_uri
    namespace_nodes.push({
      prefix: declaration.prefix,
      namespace_uri: declaration.namespace_uri,
      span: XamlSourceSpan::from_xml(source_uri, declaration.span),
    })
  }
  let ignorable : Map[String, Bool] = Map([])
  for uri, value in inherited_ignorable {
    ignorable[uri] = value
  }
  for attribute in element.attributes {
    if attribute.name.namespace_uri == Some(markup_compatibility_namespace) &&
      attribute.name.local_name == "Ignorable" {
      let prefixes = attribute.value
        .replace(old="\t", new=" ")
        .replace(old="\n", new=" ")
        .replace(old="\r", new=" ")
      for prefix in prefixes.split(" ") {
        if prefix != "" {
          match namespaces.get(prefix.to_owned()) {
            Some(uri) => ignorable[uri] = true
            None =>
              raise xaml_failure(
                "SX1102",
                "mc:Ignorable names an undeclared prefix: " + prefix.to_owned(),
                XamlSourceSpan::from_xml(source_uri, attribute.value_span),
              )
          }
        }
      }
    }
  }
  guard schemas.type_definition(type_name) is Some(type_definition) else {
    raise xaml_failure(
      "SX1103",
      "unknown XAML type {" +
      type_name.namespace_uri +
      "}" +
      type_name.local_name,
      object_span,
    )
  }
  let members : Array[XamlMemberNode] = []
  let seen_members : Map[String, Bool] = Map([])
  let mut preserve_space = inherited_preserve_space
  let mut local_name : String? = None
  let mut local_id : String? = None
  for attribute in element.attributes {
    let attribute_span = XamlSourceSpan::from_xml(source_uri, attribute.span)
    let attribute_uri = attribute.name.namespace_uri.unwrap_or("")
    if attribute_uri == markup_compatibility_namespace {
      continue
    }
    if ignorable.contains(attribute_uri) {
      continue
    }
    if attribute_uri == xml_namespace && attribute.name.local_name == "space" {
      if attribute.value == "preserve" {
        preserve_space = true
      } else if attribute.value == "default" {
        preserve_space = false
      } else {
        raise xaml_failure(
          "SX1104", "xml:space must be 'default' or 'preserve'", attribute_span,
        )
      }
      continue
    }
    let is_directive = attribute_uri == xaml_2006_namespace
    if is_directive {
      let directive = attribute.name.local_name
      if directive != "Name" &&
        directive != "Class" &&
        directive != "Key" &&
        directive != "Items" &&
        directive != "Initialization" &&
        directive != "PositionalParameters" {
        raise xaml_failure(
          "SX1105",
          "unsupported XAML directive x:" + directive,
          attribute_span,
        )
      }
      if directive == "Name" {
        if local_id is Some(_) {
          raise xaml_failure(
            "SX1106", "a node cannot declare both Id and x:Name", attribute_span,
          )
        }
        local_name = Some(attribute.value)
      }
      if directive == "Class" {
        if !is_root {
          raise xaml_failure(
            "SX1123", "x:Class is only valid on the document root", attribute_span,
          )
        }
        let class_name = attribute.value.trim()
        if class_name == "" || class_name.has_prefix("{") {
          raise xaml_failure(
            "SX1123", "x:Class requires a literal type name", attribute_span,
          )
        }
      }
      let key = xaml_2006_namespace + "|" + directive
      if seen_members.contains(key) {
        raise xaml_failure(
          "SX1107",
          "duplicate member x:" + directive,
          attribute_span,
        )
      }
      seen_members[key] = true
      members.push({
        name: xaml_qname(attribute.name),
        values: [
          parse_xaml_member_value(
            source_uri,
            attribute.value,
            namespaces,
            schemas,
            XamlSourceSpan::from_xml(source_uri, attribute.value_span),
          ),
        ],
        is_attached: false,
        is_directive: true,
        span: attribute_span,
      })
      continue
    }
    if attribute_uri != "" && attribute_uri != type_name.namespace_uri {
      if schemas.schema(attribute_uri) is None {
        raise xaml_failure(
          "SX1108",
          "unknown non-ignorable member namespace: " + attribute_uri,
          attribute_span,
        )
      }
    }
    let lexical_name = attribute.name.local_name
    let attached = lexical_name.contains(".")
    let mut member_definition : XamlMemberDefinition? = None
    if attached {
      let parts = lexical_name.split(".").to_array()
      if parts.length() != 2 {
        raise xaml_failure(
          "SX1109",
          "invalid attached member name: " + lexical_name,
          attribute_span,
        )
      }
      let owner_name = XamlQualifiedName(
        if attribute_uri == "" {
          type_name.namespace_uri
        } else {
          attribute_uri
        },
        parts[0].to_owned(),
      )
      match schemas.type_definition(owner_name) {
        Some(owner) =>
          match owner.members.get(parts[1].to_owned()) {
            Some(definition) =>
              if definition.is_attached {
                member_definition = Some(definition)
              }
            None => ()
          }
        None => ()
      }
    } else {
      member_definition = type_definition.members.get(lexical_name)
    }
    guard member_definition is Some(_) else {
      raise xaml_failure(
        "SX1110",
        if attached {
          "unknown or non-attachable member: " + lexical_name
        } else {
          "unknown member " + type_name.local_name + "." + lexical_name
        },
        attribute_span,
      )
    }
    let member_uri = if attribute_uri == "" {
      type_name.namespace_uri
    } else {
      attribute_uri
    }
    let key = member_uri + "|" + lexical_name
    if seen_members.contains(key) {
      raise xaml_failure(
        "SX1111",
        "duplicate member: " + lexical_name,
        attribute_span,
      )
    }
    if lexical_name == "Id" {
      if local_name is Some(_) {
        raise xaml_failure(
          "SX1106", "a node cannot declare both Id and x:Name", attribute_span,
        )
      }
      local_id = Some(attribute.value)
    }
    seen_members[key] = true
    members.push({
      name: XamlQualifiedName(
        member_uri,
        lexical_name,
        prefix=attribute.name.prefix,
      ),
      values: [
        parse_xaml_member_value(
          source_uri,
          attribute.value,
          namespaces,
          schemas,
          XamlSourceSpan::from_xml(source_uri, attribute.value_span),
        ),
      ],
      is_attached: attached,
      is_directive: false,
      span: attribute_span,
    })
  }
  let effective_name = match local_name {
    Some(name) => Some(name)
    None => local_id
  }
  match effective_name {
    Some(name) =>
      if names.contains(name) {
        raise xaml_failure(
          "SX1112",
          "duplicate name in namescope: " + name,
          object_span,
        )
      } else {
        names[name] = object_span
      }
    None => ()
  }
  let mut index = start_index + 1
  if !empty {
    while index < events.length() {
      let event = events[index]
      match event.kind {
        End(_) => {
          index += 1
          break
        }
        Comment(_) | PI(_) => index += 1
        DocType(_) =>
          raise xaml_failure(
            "SX1113",
            "DTD declarations are forbidden by Selene XAML Profile 1",
            XamlSourceSpan::from_xml(source_uri, event.span),
          )
        Text(text) | CData(text) => {
          let normalized = normalize_xaml_text(text, preserve_space)
          if normalized != "" {
            guard type_definition.content_member is Some(content_name) else {
              raise xaml_failure(
                "SX1114",
                "type " + type_name.local_name + " does not accept text content",
                XamlSourceSpan::from_xml(source_uri, event.span),
              )
            }
            let key = type_name.namespace_uri + "|" + content_name
            let text_value = XamlValueNode::Text({
              text: normalized,
              span: XamlSourceSpan::from_xml(source_uri, event.span),
            })
            let mut appended = false
            for existing in members {
              if existing.name.namespace_uri + "|" + existing.name.local_name ==
                key {
                existing.values.push(text_value)
                appended = true
                break
              }
            }
            if !appended {
              seen_members[key] = true
              members.push({
                name: XamlQualifiedName(type_name.namespace_uri, content_name),
                values: [text_value],
                is_attached: false,
                is_directive: false,
                span: XamlSourceSpan::from_xml(source_uri, event.span),
              })
            }
          }
          index += 1
        }
        Start(child_element) | Empty(child_element) => {
          let child_uri = child_element.name.namespace_uri.unwrap_or("")
          if ignorable.contains(child_uri) {
            if event.kind is Start(_) {
              let mut depth = 1
              index += 1
              while index < events.length() && depth > 0 {
                match events[index].kind {
                  Start(_) => depth += 1
                  End(_) => depth -= 1
                  _ => ()
                }
                index += 1
              }
            } else {
              index += 1
            }
            continue
          }
          let child_local_name = child_element.name.local_name
          if child_uri == xaml_2006_namespace &&
            (
              child_local_name == "Items" ||
              child_local_name == "Initialization" ||
              child_local_name == "PositionalParameters"
            ) {
            let key = xaml_2006_namespace + "|" + child_local_name
            if seen_members.contains(key) {
              raise xaml_failure(
                "SX1117",
                "duplicate directive member x:" + child_local_name,
                XamlSourceSpan::from_xml(source_uri, event.span),
              )
            }
            let directive_values : Array[XamlValueNode] = []
            let directive_span = XamlSourceSpan::from_xml(
              source_uri,
              event.span,
            )
            let directive_is_empty = event.kind is Empty(_)
            index += 1
            if !directive_is_empty {
              while index < events.length() {
                match events[index].kind {
                  End(_) => {
                    index += 1
                    break
                  }
                  Comment(_) | PI(_) => index += 1
                  Text(text) | CData(text) => {
                    let normalized = normalize_xaml_text(text, preserve_space)
                    if normalized != "" {
                      directive_values.push(
                        XamlValueNode::Text({
                          text: normalized,
                          span: XamlSourceSpan::from_xml(
                            source_uri,
                            events[index].span,
                          ),
                        }),
                      )
                    }
                    index += 1
                  }
                  Start(_) | Empty(_) => {
                    let (child, next_index) = parse_object_event(
                      events, index, false, source_uri, schemas, namespaces, ignorable,
                      preserve_space, names,
                    )
                    directive_values.push(XamlValueNode::Object(child))
                    index = next_index
                  }
                  _ => index += 1
                }
              }
            }
            if child_local_name == "Initialization" &&
              directive_values.length() > 1 {
              raise xaml_failure(
                "SX1118", "x:Initialization accepts one text value", directive_span,
              )
            }
            seen_members[key] = true
            members.push({
              name: XamlQualifiedName(
                xaml_2006_namespace,
                child_local_name,
                prefix=Some("x"),
              ),
              values: directive_values,
              is_attached: false,
              is_directive: true,
              span: directive_span,
            })
            continue
          }
          if child_local_name.contains(".") {
            let parts = child_local_name.split(".").to_array()
            if parts.length() != 2 || parts[0] != type_name.local_name {
              raise xaml_failure(
                "SX1115",
                "invalid property element " + child_local_name,
                XamlSourceSpan::from_xml(source_uri, event.span),
              )
            }
            let property_name = parts[1].to_owned()
            guard type_definition.members.get(property_name)
              is Some(property_definition) else {
              raise xaml_failure(
                "SX1116",
                "unknown property element " + child_local_name,
                XamlSourceSpan::from_xml(source_uri, event.span),
              )
            }
            let key = type_name.namespace_uri + "|" + property_name
            if seen_members.contains(key) {
              raise xaml_failure(
                "SX1117",
                "duplicate member: " + property_name,
                XamlSourceSpan::from_xml(source_uri, event.span),
              )
            }
            let property_values : Array[XamlValueNode] = []
            let property_span = XamlSourceSpan::from_xml(source_uri, event.span)
            let property_is_empty = event.kind is Empty(_)
            index += 1
            if !property_is_empty {
              while index < events.length() {
                match events[index].kind {
                  End(_) => {
                    index += 1
                    break
                  }
                  Comment(_) | PI(_) => index += 1
                  Text(text) | CData(text) => {
                    let normalized = normalize_xaml_text(text, preserve_space)
                    if normalized != "" {
                      property_values.push(
                        XamlValueNode::Text({
                          text: normalized,
                          span: XamlSourceSpan::from_xml(
                            source_uri,
                            events[index].span,
                          ),
                        }),
                      )
                    }
                    index += 1
                  }
                  Start(_) | Empty(_) => {
                    let (child, next_index) = parse_object_event(
                      events, index, false, source_uri, schemas, namespaces, ignorable,
                      preserve_space, names,
                    )
                    property_values.push(XamlValueNode::Object(child))
                    index = next_index
                  }
                  _ => index += 1
                }
              }
            }
            if !property_definition.is_collection &&
              property_values.length() > 1 {
              raise xaml_failure(
                "SX1118",
                "member " + property_name + " accepts one value",
                property_span,
              )
            }
            seen_members[key] = true
            members.push({
              name: XamlQualifiedName(type_name.namespace_uri, property_name),
              values: property_values,
              is_attached: false,
              is_directive: false,
              span: property_span,
            })
          } else {
            guard type_definition.content_member is Some(content_name) else {
              raise xaml_failure(
                "SX1119",
                "type " +
                type_name.local_name +
                " does not accept object content",
                XamlSourceSpan::from_xml(source_uri, event.span),
              )
            }
            let (child, next_index) = parse_object_event(
              events, index, false, source_uri, schemas, namespaces, ignorable, preserve_space,
              names,
            )
            let key = type_name.namespace_uri + "|" + content_name
            let mut appended = false
            for existing in members {
              if existing.name.namespace_uri + "|" + existing.name.local_name ==
                key {
                existing.values.push(XamlValueNode::Object(child))
                appended = true
                break
              }
            }
            if !appended {
              seen_members[key] = true
              members.push({
                name: XamlQualifiedName(type_name.namespace_uri, content_name),
                values: [XamlValueNode::Object(child)],
                is_attached: false,
                is_directive: false,
                span: XamlSourceSpan::from_xml(source_uri, event.span),
              })
            }
            index = next_index
          }
        }
        _ => index += 1
      }
    }
  }
  for member_name, definition in type_definition.members {
    if definition.is_required &&
      !seen_members.contains(type_name.namespace_uri + "|" + member_name) {
      raise xaml_failure(
        "SX1120",
        "missing required member " + type_name.local_name + "." + member_name,
        object_span,
      )
    }
  }
  (
    { type_name, members, namespaces: namespace_nodes, span: object_span },
    index,
  )
}

///|
pub fn parse_xaml(
  source_uri : String,
  source : String,
  schemas : XamlSchemaRegistry,
) -> XamlDocument raise XamlError {
  let reader = @xml.NamespaceReader::from_string(source)
  let events : Array[@xml.NamespaceEvent] = []
  while true {
    let event = reader.read_event() catch {
      error =>
        raise xaml_failure(
          "SX1100",
          "invalid XML: " + error.to_string(),
          XamlSourceSpan::unknown(source_uri),
        )
    }
    match event.kind {
      DocType(_) =>
        raise xaml_failure(
          "SX1113",
          "DTD declarations are forbidden by Selene XAML Profile 1",
          XamlSourceSpan::from_xml(source_uri, event.span),
        )
      Eof => break
      _ => events.push(event)
    }
  }
  let mut root_index = -1
  for index, event in events {
    match event.kind {
      Start(_) | Empty(_) => {
        root_index = index
        break
      }
      Text(text) =>
        if normalize_xaml_text(text, false) != "" {
          raise xaml_failure(
            "SX1121",
            "text is not allowed outside the root object",
            XamlSourceSpan::from_xml(source_uri, event.span),
          )
        }
      _ => ()
    }
  }
  if root_index < 0 {
    raise xaml_failure(
      "SX1122",
      "XAML document has no root object",
      XamlSourceSpan::unknown(source_uri),
    )
  }
  let root_namespaces : Map[String, String] = Map([])
  root_namespaces["xml"] = xml_namespace
  let (root, next_index) = parse_object_event(
    events,
    root_index,
    true,
    source_uri,
    schemas,
    root_namespaces,
    Map([]),
    false,
    Map([]),
  )
  for index = next_index; index < events.length(); index = index + 1 {
    match events[index].kind {
      Text(text) =>
        if normalize_xaml_text(text, false) != "" {
          raise xaml_failure(
            "SX1123",
            "content after the root object is not allowed",
            XamlSourceSpan::from_xml(source_uri, events[index].span),
          )
        }
      Comment(_) | PI(_) => ()
      _ =>
        raise xaml_failure(
          "SX1123",
          "multiple root objects are not allowed",
          XamlSourceSpan::from_xml(source_uri, events[index].span),
        )
    }
  }
  { source_uri, root, namespaces: root.namespaces, diagnostics: [] }
}
