///|
fn resolve_model_type(
  text : String,
  namespaces : Map[String, String],
  span : @infoset.XamlSourceSpan,
) -> IRTypeRef raise ViewIRError {
  let (prefix, type_name) = match text.split_once(":") {
    Some((prefix, name)) if prefix != "" && name != "" =>
      (prefix.to_owned(), name.to_owned())
    _ =>
      raise Unsupported(
        "ui:DataType must be a namespace-qualified MoonBit type", span,
      )
  }
  let namespace_uri = match namespaces.get(prefix) {
    Some(value) => value
    None =>
      raise Unsupported(
        "ui:DataType uses an unknown namespace prefix: " + prefix,
        span,
      )
  }
  if !namespace_uri.has_prefix("moonbit:") || namespace_uri.length() == 8 {
    raise Unsupported(
      "ui:DataType namespace must use moonbit:<package-path>", span,
    )
  }
  {
    package_alias: prefix,
    package_path: namespace_uri[8:].to_owned(),
    type_name,
    span,
  }
}

///|
priv struct RawVisualStateSetter {
  target_name : String?
  property : String
  value : SyntaxValue
  span : @infoset.XamlSourceSpan
}

///|
priv struct RawVisualState {
  name : String
  setters : Array[RawVisualStateSetter]
  span : @infoset.XamlSourceSpan
}

///|
priv struct RawVisualStateGroup {
  owner_node : String
  namescope : String
  name : String
  current : SyntaxValue?
  states : Array[RawVisualState]
  transitions : Array[SyntaxVisualTransition]
  span : @infoset.XamlSourceSpan
}

///|
fn syntax_member_value(definition : @infoset.XamlMemberNode) -> SyntaxValue? {
  match definition.binding() {
    Some((binding, _)) => Some(Binding(binding, definition.span))
    None => definition.literal().map(value => Literal(value, definition.span))
  }
}

///|
fn object_literal_member(
  object : @infoset.XamlObjectNode,
  name : String,
) -> String? {
  match object.find_member(name) {
    Some(definition) => definition.literal()
    None => None
  }
}

///|
fn collect_visual_state_groups(
  object : @infoset.XamlObjectNode,
  owner_node : String,
  namescope : String,
  groups : Array[RawVisualStateGroup],
) -> Unit {
  guard object.find_member("VisualStates") is Some(groups_member) else {
    return
  }
  for group_value in groups_member.values {
    guard group_value is Object(group_object) else { continue }
    let group_name = object_literal_member(group_object, "Name").unwrap_or("")
    let current = match group_object.find_member("Current") {
      Some(definition) => syntax_member_value(definition)
      None => None
    }
    let states : Array[RawVisualState] = []
    match group_object.find_member("States") {
      Some(states_member) =>
        for state_value in states_member.values {
          guard state_value is Object(state_object) else { continue }
          let state_name = object_literal_member(state_object, "Name").unwrap_or(
            "",
          )
          let setters : Array[RawVisualStateSetter] = []
          match state_object.find_member("Setters") {
            Some(setters_member) =>
              for setter_value in setters_member.values {
                guard setter_value is Object(setter_object) else { continue }
                guard setter_object.find_member("Property") is Some(property) &&
                  setter_object.find_member("Value") is Some(value_member) &&
                  syntax_member_value(value_member) is Some(value) else {
                  continue
                }
                setters.push({
                  target_name: object_literal_member(
                    setter_object, "TargetName",
                  ),
                  property: property.literal().unwrap_or(""),
                  value,
                  span: setter_object.span,
                })
              }
            None => ()
          }
          states.push({ name: state_name, setters, span: state_object.span })
        }
      None => ()
    }
    let transitions : Array[SyntaxVisualTransition] = []
    match group_object.find_member("Transitions") {
      Some(transitions_member) =>
        for transition_value in transitions_member.values {
          guard transition_value is Object(transition) else { continue }
          transitions.push({
            from: object_literal_member(transition, "From"),
            to: object_literal_member(transition, "To"),
            duration: object_literal_member(transition, "Duration").unwrap_or(
              "0",
            ),
            delay: object_literal_member(transition, "Delay").unwrap_or("0"),
            easing: object_literal_member(transition, "Easing").unwrap_or(
              "Linear",
            ),
            span: transition.span,
          })
        }
      None => ()
    }
    groups.push({
      owner_node,
      namescope,
      name: group_name,
      current,
      states,
      transitions,
      span: group_object.span,
    })
  }
}

///|
fn lower_syntax(
  source_uri : String,
  source : String,
) -> SyntaxViewIR raise ViewIRError {
  let document = @parser.parse_xaml(
    source_uri,
    source,
    @infoset.selene_xaml_schemas(),
  ) catch {
    error => raise Xaml(error)
  }
  let namespaces : Map[String, String] = Map([])
  for namespace_binding in document.namespaces {
    namespaces[namespace_binding.prefix.unwrap_or("")] = namespace_binding.namespace_uri
  }
  let data_type_member = match document.root.find_member("DataType") {
    Some(value) => value
    None =>
      raise Unsupported("root View requires ui:DataType", document.root.span)
  }
  let model_type = resolve_model_type(
    data_type_member.literal().unwrap_or(""),
    namespaces,
    data_type_member.span,
  )
  let view_name = match document.root.find_member("Class") {
    Some(class_definition) =>
      class_definition.literal().unwrap_or("").trim().to_owned()
    None => {
      let filename = source_uri
        .split("/")
        .last()
        .map_or(source_uri, value => value.to_owned())
      let stem = filename
        .split_once(".")
        .map_or(filename, value => value.0.to_owned())
      pascal_case(stem) + "View"
    }
  }
  if view_name == "" {
    raise Unsupported("x:Class cannot be empty", document.root.span)
  }
  let pending : Array[
    (@infoset.XamlObjectNode, String, Bool, String?, String?, String),
  ] = [(document.root, "root", false, None, None, "root")]
  let lowered : Map[String, SyntaxNode] = Map([])
  let child_links : Map[String, Array[String]] = Map([])
  let stable_key_origins : Map[
    String,
    (String?, String, @infoset.XamlSourceSpan),
  ] = Map([])
  let named_nodes : Map[String, String] = Map([])
  let raw_visual_state_groups : Array[RawVisualStateGroup] = []
  while pending.length() > 0 {
    let (
      object,
      path,
      template,
      parent_template,
      item_prefix_template,
      namescope,
    ) = pending.pop().unwrap()
    let type_name = object.type_name.local_name
    if type_name == "If" {
      let condition_member = object.find_member("Condition").unwrap()
      let condition = match condition_member.binding() {
        Some((binding, _)) => binding
        None =>
          raise Unsupported(
            "If.Condition must be a Binding",
            condition_member.span,
          )
      }
      let then_keys : Array[String] = []
      let else_keys : Array[String] = []
      for entry in [("Then", then_keys), ("Else", else_keys)] {
        let (branch_name, target) = entry
        match object.find_member(branch_name) {
          Some(definition) =>
            for index, value in definition.values {
              match value {
                Object(child) => {
                  let child_path = path +
                    "/" +
                    kebab_case(branch_name) +
                    "/" +
                    index.to_string()
                  target.push(child_path)
                  pending.push(
                    (
                      child, child_path, template, parent_template, item_prefix_template,
                      namescope,
                    ),
                  )
                }
                _ => ()
              }
            }
          None => ()
        }
      }
      lowered[path] = Conditional(condition, condition_member.span, [], [])
      child_links[path + ":then"] = then_keys
      child_links[path + ":else"] = else_keys
      continue
    }
    if type_name == "ItemsControl" {
      let source_member = object.find_member("ItemsSource").unwrap()
      let source_path = match source_member.binding() {
        Some((binding, _)) => binding
        None =>
          raise Unsupported(
            "ItemsControl.ItemsSource must be a Binding",
            source_member.span,
          )
      }
      let key_member = object.find_member("KeyPath")
      let key_path = match key_member {
        Some(key_definition) => key_definition.literal().unwrap_or("key")
        None => "key"
      }
      let key_span = key_member.map_or(object.span, key_definition => {
        key_definition.span
      })
      let template_keys : Array[String] = []
      let mut template_type : IRTypeRef? = None
      let generated_item_prefix = parent_template.unwrap_or("") +
        "/" +
        kebab_case(source_path) +
        ":__SELENE_KEY__"
      let template_member = object.find_member("ItemTemplate").unwrap()
      for value in template_member.values {
        match value {
          Object(data_template) => {
            match data_template.find_member("DataType") {
              Some(data_type_definition) =>
                template_type = Some(
                  resolve_model_type(
                    data_type_definition.literal().unwrap_or(""),
                    namespaces,
                    data_type_definition.span,
                  ),
                )
              None => ()
            }
            match data_template.find_member("Content") {
              Some(content) =>
                for index, template_value in content.values {
                  match template_value {
                    Object(child) => {
                      let child_path = path + "/item/" + index.to_string()
                      template_keys.push(child_path)
                      pending.push(
                        (
                          child,
                          child_path,
                          true,
                          parent_template,
                          Some(generated_item_prefix),
                          path,
                        ),
                      )
                    }
                    _ => ()
                  }
                }
              None => ()
            }
          }
          _ => ()
        }
      }
      lowered[path] = KeyedItems(
        source_path,
        source_member.span,
        key_path,
        key_span,
        template_type,
        [],
      )
      child_links[path] = template_keys
      continue
    }
    if !["View", "Flex", "ScrollView", "Text", "Image", "Button"].contains(
        type_name,
      ) {
      raise Unsupported(
        "unsupported generated UI element: " + type_name,
        object.span,
      )
    }
    let mut explicit_name : String? = None
    let mut explicit_name_span = object.span
    let properties : Array[SyntaxProperty] = []
    for definition in object.members {
      if definition.is_directive && definition.name.local_name == "Name" {
        explicit_name = definition.literal()
        explicit_name_span = definition.span
      } else if definition.name.local_name != "Children" &&
        definition.name.local_name != "Spans" &&
        definition.name.local_name != "VisualStates" &&
        definition.name.local_name != "DataType" &&
        definition.name.local_name != "Class" {
        match definition.binding() {
          Some((binding, _)) =>
            properties.push({
              name: definition.name.local_name,
              value: Binding(binding, definition.span),
            })
          None =>
            match definition.literal() {
              Some(value) =>
                properties.push({
                  name: definition.name.local_name,
                  value: Literal(value, definition.span),
                })
              None => ()
            }
        }
      }
    }
    let key = match explicit_name {
      Some(name) => kebab_case(name)
      None => {
        let prefix = if template { "item" } else { "node" }
        prefix +
        "-" +
        path.replace(old="/", new="-") +
        "-" +
        kebab_case(type_name)
      }
    }
    let node_template = match item_prefix_template {
      Some(prefix) => prefix + "/" + key
      None => key
    }
    let origin_span = match explicit_name {
      Some(_) => explicit_name_span
      None => object.span
    }
    match stable_key_origins.get(node_template) {
      Some((previous_name, previous_path, previous_span)) =>
        match (previous_name, explicit_name) {
          (Some(previous), Some(current)) => {
            let (first_name, second_name, collision_span) = if previous_span.start.offset <=
              origin_span.start.offset {
              (previous, current, origin_span)
            } else {
              (current, previous, previous_span)
            }
            raise Unsupported(
              "x:Name stable key collision: " +
              first_name +
              " and " +
              second_name +
              " both normalize to " +
              node_template,
              collision_span,
            )
          }
          _ => {
            let previous_label = match previous_name {
              Some(name) => "x:Name " + name
              None => "generated node " + previous_path
            }
            let current_label = match explicit_name {
              Some(name) => "x:Name " + name
              None => "generated node " + path
            }
            let (first_label, second_label, collision_span) = if previous_span.start.offset <=
              origin_span.start.offset {
              (previous_label, current_label, origin_span)
            } else {
              (current_label, previous_label, previous_span)
            }
            raise Unsupported(
              "stable key collision: " +
              first_label +
              " and " +
              second_label +
              " both map to " +
              node_template,
              collision_span,
            )
          }
        }
      None =>
        stable_key_origins[node_template] = (explicit_name, path, origin_span)
    }
    match explicit_name {
      Some(name) => named_nodes[namescope + "\u{1f}" + name] = node_template
      None => ()
    }
    collect_visual_state_groups(
      object, node_template, namescope, raw_visual_state_groups,
    )
    let children : Array[String] = []
    let child_member = match object.find_member("Children") {
      Some(value) => Some(value)
      None => object.find_member("Spans")
    }
    match child_member {
      Some(definition) =>
        for index, value in definition.values {
          match value {
            Object(child) => {
              let child_path = path + "/" + index.to_string()
              children.push(child_path)
              pending.push(
                (
                  child,
                  child_path,
                  template,
                  Some(node_template),
                  item_prefix_template,
                  namescope,
                ),
              )
            }
            _ => ()
          }
        }
      None => ()
    }
    lowered[path] = Element(
      type_name,
      key,
      explicit_name,
      properties,
      [],
      object.span,
    )
    child_links[path] = children
  }
  let ordered_paths = lowered.keys().collect()
  ordered_paths.sort()
  for path in ordered_paths.rev() {
    match lowered[path] {
      Element(kind, key, name, properties, _, span) => {
        let children = child_links
          .get(path)
          .unwrap_or([])
          .map(child_path => lowered[child_path])
        lowered[path] = Element(kind, key, name, properties, children, span)
      }
      Conditional(condition, span, _, _) => {
        let then_nodes = child_links
          .get(path + ":then")
          .unwrap_or([])
          .map(child_path => lowered[child_path])
        let else_nodes = child_links
          .get(path + ":else")
          .unwrap_or([])
          .map(child_path => lowered[child_path])
        lowered[path] = Conditional(condition, span, then_nodes, else_nodes)
      }
      KeyedItems(source_path, source_span, key_path, key_span, data_type, _) => {
        let children = child_links
          .get(path)
          .unwrap_or([])
          .map(child_path => lowered[child_path])
        lowered[path] = KeyedItems(
          source_path, source_span, key_path, key_span, data_type, children,
        )
      }
    }
  }
  let visual_state_groups : Array[SyntaxVisualStateGroup] = []
  for group in raw_visual_state_groups {
    visual_state_groups.push({
      owner_node: group.owner_node,
      name: group.name,
      current: group.current,
      states: group.states.map(state => {
        name: state.name,
        setters: state.setters.map(setter => {
          let target_node = match setter.target_name {
            Some(name) =>
              named_nodes
              .get(group.namescope + "\u{1f}" + name)
              .unwrap_or("\u{0}" + name)
            None => group.owner_node
          }
          {
            target_node,
            property: setter.property,
            value: setter.value,
            span: setter.span,
          }
        }),
        span: state.span,
      }),
      transitions: group.transitions,
      span: group.span,
    })
  }
  {
    identity: { view_name, source_uri, span: document.root.span },
    data_type: model_type,
    root: lowered["root"],
    visual_state_groups,
  }
}

///|
fn kebab_case(value : String) -> String {
  let output = StringBuilder::new()
  for index, ch in value {
    if ch >= 'A' && ch <= 'Z' {
      if index > 0 {
        output.write_char('-')
      }
      output.write_char((ch.to_int() + 32).unsafe_to_char())
    } else if ch == '_' || ch == ' ' {
      output.write_char('-')
    } else {
      output.write_char(ch)
    }
  }
  output.to_string()
}

///|
fn pascal_case(value : String) -> String {
  let output = StringBuilder::new()
  let mut uppercase = true
  for ch in value {
    if ch == '_' || ch == '-' || ch == ' ' {
      uppercase = true
    } else if uppercase && ch >= 'a' && ch <= 'z' {
      output.write_char((ch.to_int() - 32).unsafe_to_char())
      uppercase = false
    } else {
      output.write_char(ch)
      uppercase = false
    }
  }
  output.to_string()
}

///|
fn snake_case(value : String) -> String {
  let output = StringBuilder::new()
  let mut previous_underscore = false
  for index, ch in value {
    if ch >= 'A' && ch <= 'Z' {
      if index > 0 && !previous_underscore {
        output.write_char('_')
      }
      output.write_char((ch.to_int() + 32).unsafe_to_char())
      previous_underscore = false
    } else if ch == '-' || ch == ' ' {
      if !previous_underscore {
        output.write_char('_')
      }
      previous_underscore = true
    } else {
      output.write_char(ch)
      previous_underscore = ch == '_'
    }
  }
  output.to_string()
}
