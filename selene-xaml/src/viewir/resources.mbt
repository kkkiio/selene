///|
priv struct StaticResourceValue {
  text : String
}

///|
fn resolve_resource_uri(
  declaring_uri : String,
  source : String,
  span : @infoset.XamlSourceSpan,
) -> String raise ViewIRError {
  let normalized_source = source.trim().replace_all(old="\\", new="/")
  if normalized_source == "" ||
    normalized_source.has_prefix("/") ||
    (normalized_source.length() >= 2 && normalized_source[1] == ':') ||
    normalized_source.contains("://") {
    raise Unsupported(
      "ResourceDictionary.Source must be a repository-relative XAML path", span,
    )
  }
  let declaring = declaring_uri.replace_all(old="\\", new="/")
  let segments = declaring.split("/").to_array()
  if segments.length() > 0 {
    ignore(segments.pop())
  }
  for raw_segment in normalized_source.split("/") {
    let segment = raw_segment.to_owned()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if segments.length() == 0 {
        raise Unsupported(
          "ResourceDictionary.Source escapes the repository: " + source,
          span,
        )
      }
      ignore(segments.pop())
    } else {
      segments.push(segment)
    }
  }
  if segments.length() == 0 {
    raise Unsupported(
      "ResourceDictionary.Source must name a XAML document", span,
    )
  }
  segments.join("/")
}

///|
pub fn referenced_resource_documents(
  source_uri : String,
  source : String,
) -> Array[String] raise ViewIRError {
  let document = @parser.parse_xaml(
    source_uri,
    source,
    @infoset.selene_xaml_schemas(),
  ) catch {
    error => raise Xaml(error)
  }
  let references : Map[String, Bool] = Map([])
  let pending = [document.root]
  while pending.length() > 0 {
    let object = pending.pop().unwrap()
    if object.type_name.namespace_uri == @infoset.selene_ui_namespace &&
      object.type_name.local_name == "ResourceDictionary" {
      match object.find_member("Source") {
        Some(definition) =>
          match definition.literal() {
            Some(path) =>
              references[resolve_resource_uri(source_uri, path, definition.span)] = true
            None =>
              raise Unsupported(
                "ResourceDictionary.Source must be a literal XAML path",
                definition.span,
              )
          }
        None => ()
      }
    }
    for definition in object.members {
      for value in definition.values {
        if value is @infoset.XamlValueNode::Object(child) {
          pending.push(child)
        }
      }
    }
  }
  let paths = references.keys().collect()
  paths.sort()
  paths
}

///|
fn static_resource_key(extension : @infoset.XamlMarkupExtension) -> String? {
  if extension.type_name.namespace_uri != @infoset.selene_ui_namespace ||
    extension.type_name.local_name != "StaticResource" ||
    extension.arguments.length() != 1 {
    return None
  }
  match extension.arguments[0] {
    { name: None | Some("ResourceKey"), value: Literal(key) } =>
      Some(key.trim().to_owned())
    _ => None
  }
}

///|
fn resolve_static_resource_value(
  value : @infoset.XamlValueNode,
  resources : Map[String, StaticResourceValue],
) -> @infoset.XamlValueNode raise ViewIRError {
  guard value is @infoset.XamlValueNode::Markup(extension) &&
    extension.type_name.namespace_uri == @infoset.selene_ui_namespace &&
    extension.type_name.local_name == "StaticResource" else {
    return value
  }
  guard static_resource_key(extension) is Some(key) && key != "" else {
    raise Unsupported(
      "StaticResource requires one literal ResourceKey",
      extension.span,
    )
  }
  guard resources.get(key) is Some(resource) else {
    raise Unsupported(
      "StaticResource key does not exist: " + key,
      extension.span,
    )
  }
  @infoset.XamlValueNode::Text({ text: resource.text, span: extension.span })
}

///|
fn collect_resource_dictionary(
  dictionary : @infoset.XamlObjectNode,
  declaring_uri : String,
  inherited : Map[String, StaticResourceValue],
  documents : Map[String, String],
  cache : Map[String, Map[String, StaticResourceValue]],
  resolving : Map[String, Bool],
) -> Map[String, StaticResourceValue] raise ViewIRError {
  if dictionary.type_name.namespace_uri != @infoset.selene_ui_namespace ||
    dictionary.type_name.local_name != "ResourceDictionary" {
    raise Unsupported(
      "Resources accepts one ResourceDictionary object",
      dictionary.span,
    )
  }
  let resources : Map[String, StaticResourceValue] = Map([])
  for key, value in inherited {
    resources[key] = value
  }
  match dictionary.find_member("Source") {
    Some(definition) => {
      guard definition.literal() is Some(source) else {
        raise Unsupported(
          "ResourceDictionary.Source must be a literal XAML path",
          definition.span,
        )
      }
      let resolved_uri = resolve_resource_uri(
        declaring_uri,
        source,
        definition.span,
      )
      if resolving.contains(resolved_uri) {
        raise Unsupported(
          "ResourceDictionary.Source cycle includes " + resolved_uri,
          definition.span,
        )
      }
      let imported = match cache.get(resolved_uri) {
        Some(value) => value
        None => {
          guard documents.get(resolved_uri) is Some(imported_source) else {
            raise Unsupported(
              "ResourceDictionary.Source was not provided: " + resolved_uri,
              definition.span,
            )
          }
          resolving[resolved_uri] = true
          let imported_document = @parser.parse_xaml(
            resolved_uri,
            imported_source,
            @infoset.selene_xaml_schemas(),
          ) catch {
            error => raise Xaml(error)
          }
          let value = collect_resource_dictionary(
            imported_document.root,
            resolved_uri,
            Map([]),
            documents,
            cache,
            resolving,
          )
          resolving.remove(resolved_uri)
          cache[resolved_uri] = value
          value
        }
      }
      for key, value in imported {
        resources[key] = value
      }
    }
    None => ()
  }
  match dictionary.find_member("MergedDictionaries") {
    Some(definition) =>
      for value in definition.values {
        guard value is @infoset.XamlValueNode::Object(merged) else {
          raise Unsupported(
            "ResourceDictionary.MergedDictionaries accepts ResourceDictionary objects",
            definition.span,
          )
        }
        let imported = collect_resource_dictionary(
          merged, declaring_uri, resources, documents, cache, resolving,
        )
        for key, resource in imported {
          resources[key] = resource
        }
      }
    None => ()
  }
  let local_keys : Map[String, Bool] = Map([])
  match dictionary.find_member("Entries") {
    Some(definition) =>
      for value in definition.values {
        guard value is @infoset.XamlValueNode::Object(entry) &&
          entry.find_member("Key") is Some(key_member) &&
          key_member.literal() is Some(key) &&
          key.trim() != "" else {
          raise Unsupported(
            "ResourceDictionary entries require a non-empty x:Key",
            definition.span,
          )
        }
        let key = key.trim().to_owned()
        if local_keys.contains(key) {
          raise Unsupported(
            "duplicate ResourceDictionary key: " + key,
            key_member.span,
          )
        }
        guard entry.find_member("Value") is Some(value_member) &&
          value_member.values.length() == 1 else {
          raise Unsupported(
            "ResourceDictionary entries require one scalar value",
            entry.span,
          )
        }
        let resolved = resolve_static_resource_value(
          value_member.values[0],
          resources,
        )
        guard resolved is @infoset.XamlValueNode::Text(text) else {
          raise Unsupported(
            "ResourceDictionary entries must be scalar literals or StaticResource aliases",
            value_member.span,
          )
        }
        local_keys[key] = true
        resources[key] = { text: text.text }
      }
    None => ()
  }
  resources
}

///|
fn resolve_object_static_resources(
  object : @infoset.XamlObjectNode,
  inherited : Map[String, StaticResourceValue],
  documents : Map[String, String],
  cache : Map[String, Map[String, StaticResourceValue]],
  resolving : Map[String, Bool],
) -> @infoset.XamlObjectNode raise ViewIRError {
  let resources : Map[String, StaticResourceValue] = Map([])
  for key, value in inherited {
    resources[key] = value
  }
  match object.find_member("Resources") {
    Some(definition) => {
      guard definition.values.length() == 1 &&
        definition.values[0] is @infoset.XamlValueNode::Object(dictionary) else {
        raise Unsupported(
          "Resources accepts one ResourceDictionary object",
          definition.span,
        )
      }
      let collected = collect_resource_dictionary(
        dictionary,
        object.span.source_uri,
        resources,
        documents,
        cache,
        resolving,
      )
      resources.clear()
      for key, value in collected {
        resources[key] = value
      }
    }
    None => ()
  }
  let members : Array[@infoset.XamlMemberNode] = []
  for definition in object.members {
    if definition.name.local_name == "Resources" &&
      definition.name.namespace_uri == @infoset.selene_ui_namespace {
      continue
    }
    let values : Array[@infoset.XamlValueNode] = []
    for value in definition.values {
      match value {
        @infoset.XamlValueNode::Object(child) =>
          values.push(
            @infoset.XamlValueNode::Object(
              resolve_object_static_resources(
                child, resources, documents, cache, resolving,
              ),
            ),
          )
        _ => values.push(resolve_static_resource_value(value, resources))
      }
    }
    members.push({ ..definition, values, })
  }
  { ..object, members, }
}

///|
fn parse_and_resolve_view_document(
  source_uri : String,
  source : String,
  resource_documents : Array[ResourceDocument],
) -> @infoset.XamlDocument raise ViewIRError {
  let parsed = @parser.parse_xaml(
    source_uri,
    source,
    @infoset.selene_xaml_schemas(),
  ) catch {
    error => raise Xaml(error)
  }
  let documents : Map[String, String] = Map([])
  for document in resource_documents {
    let normalized_uri = resolve_resource_uri(
      "",
      document.source_uri,
      parsed.root.span,
    )
    if documents.contains(normalized_uri) {
      raise InvalidContract(
        "duplicate ResourceDictionary document: " + normalized_uri,
      )
    }
    documents[normalized_uri] = document.source
  }
  let cache : Map[String, Map[String, StaticResourceValue]] = Map([])
  let resolving : Map[String, Bool] = Map([])
  let root = resolve_object_static_resources(
    parsed.root,
    Map([]),
    documents,
    cache,
    resolving,
  )
  { ..parsed, root, }
}
