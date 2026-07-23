///|
pub fn compile_wit(
  source_uri : String,
  source : String,
  contract_uri : String,
  contract_source : String,
) -> (ViewIR, IRComponentTarget) raise ViewIRError {
  let syntax = lower_syntax(source_uri, source)
  let normalized = StringBuilder::new()
  for raw_line in contract_source.split("\n") {
    let line = raw_line.split_once("//").map_or(raw_line, pair => pair.0)
    normalized.write_string(line.to_owned())
    normalized.write_char(' ')
  }
  let wit = normalized.to_string()
  let records = parse_wit_records(wit)
  let variants = parse_wit_variants(wit)
  let (model_name, patch_name, event_name, action_name) = parse_wit_view_api(
    wit,
  )
  guard records.contains(model_name) else {
    raise InvalidContract(
      "WIT mount Model is not a public record: " + model_name,
    )
  }
  guard records.contains(syntax.data_type.type_name) else {
    raise InvalidContract(
      "root ui:DataType is not a public WIT record: " +
      syntax.data_type.type_name,
    )
  }
  guard variants.contains(action_name) else {
    raise InvalidContract(
      "WIT handle-event Action is not a public variant: " + action_name,
    )
  }
  if patch_name != "" && !variants.contains(patch_name) {
    raise InvalidContract(
      "WIT apply Patch is not a public variant: " + patch_name,
    )
  }
  guard event_name != "" else {
    raise InvalidContract(
      "WIT interface requires handle-event(entity, event) -> option<Action>",
    )
  }
  let mbti = StringBuilder::new()
  mbti.write_string("package \"" + syntax.data_type.package_path + "\"\n")
  let record_names = records.keys().collect()
  record_names.sort()
  for name in record_names {
    let record = records[name]
    mbti.write_string("pub(all) struct " + record.name + " {\n")
    for field in record.fields {
      mbti.write_string("  " + field.name + " : " + field.field_type + "\n")
    }
    mbti.write_string("}\n")
  }
  let variant_names = variants.keys().collect()
  variant_names.sort()
  for name in variant_names {
    let definition = variants[name]
    let emitted_name = if name == action_name {
      syntax.identity.view_name + "Action"
    } else {
      name
    }
    mbti.write_string("pub(all) enum " + emitted_name + " {\n")
    for variant in definition.variants {
      mbti.write_string("  " + variant.name)
      match variant.payload {
        Some(payload) => mbti.write_string("(" + payload + ")")
        None => ()
      }
      mbti.write_string("\n")
    }
    mbti.write_string("}\n")
  }
  if model_name != syntax.data_type.type_name {
    mbti.write_string(
      "pub fn compute_view_model(" +
      model_name +
      ") -> " +
      syntax.data_type.type_name +
      "\n",
    )
  }
  let tree_package = parse_tree_package(wit)
  let compiled = compile(source_uri, source, mbti.to_string())
  let ir = if patch_name != "" &&
    compiled.contract.patch.map_or(true, patch => patch.name != patch_name) {
    let selected = compiled.contract.enums[patch_name]
    let model = records[model_name]
    let mut generated_patch = true
    for _, collection in compiled.contract.collections {
      match model.field(collection.field_name) {
        Some(field) if field.field_type == "Array[" + collection.item_type + "]" =>
          ()
        _ => generated_patch = false
      }
    }
    let resolved_collections = if generated_patch {
      resolve_patch_families(
        parse_contract(mbti.to_string()),
        Some(selected),
        compiled.contract.collections,
      )
    } else {
      compiled.contract.collections
    }
    let capabilities = compiled.required_capabilities.copy()
    if !capabilities.contains(IRCapability::TypedPatch) {
      capabilities.push(IRCapability::TypedPatch)
    }
    {
      ..compiled,
      contract: {
        ..compiled.contract,
        patch: Some(selected),
        patch_projection: if generated_patch {
          IRPatchProjection::GeneratedCollections
        } else {
          IRPatchProjection::Apply("apply_patches")
        },
        collections: resolved_collections,
      },
      required_capabilities: capabilities,
    }
  } else {
    compiled
  }
  ignore(contract_uri)
  (ir, { event_type: event_name, action_type: action_name, tree_package })
}

///|
fn parse_wit_records(
  source : String,
) -> Map[String, IRStruct] raise ViewIRError {
  let records : Map[String, IRStruct] = Map([])
  for declaration in wit_declarations(source, "record") {
    let (raw_name, body) = declaration
    let name = pascal_case(raw_name)
    let fields : Array[IRField] = []
    for raw_field in split_wit_items(body) {
      guard raw_field.split_once(":") is Some((field_name, field_type)) else {
        raise InvalidContract("invalid WIT record field: " + raw_field)
      }
      fields.push({
        name: snake_case(field_name.trim().to_owned()),
        field_type: wit_type_to_moon(field_type.trim().to_owned()),
      })
    }
    fields.sort_by(fn(left, right) { left.name.compare(right.name) })
    records[name] = { name, fields }
  }
  records
}

///|
fn parse_wit_variants(source : String) -> Map[String, IREnum] raise ViewIRError {
  let variants : Map[String, IREnum] = Map([])
  for declaration in wit_declarations(source, "variant") {
    let (raw_name, body) = declaration
    let name = pascal_case(raw_name)
    let cases : Array[IRVariant] = []
    for raw_case in split_wit_items(body) {
      let item = raw_case.trim().to_owned()
      match item.find("(") {
        Some(open) => {
          guard item.has_suffix(")") else {
            raise InvalidContract("invalid WIT variant case: " + item)
          }
          cases.push({
            name: pascal_case(item[:open].trim().to_owned()),
            payload: Some(
              wit_type_to_moon(item[open + 1:item.length() - 1].to_owned()),
            ),
          })
        }
        None => cases.push({ name: pascal_case(item), payload: None })
      }
    }
    variants[name] = { name, variants: cases }
  }
  variants
}

///|
fn parse_wit_view_api(
  source : String,
) -> (String, String, String, String) raise ViewIRError {
  let interfaces = wit_declarations(source, "interface")
  if interfaces.length() != 1 {
    raise InvalidContract(
      "WIT contract must define exactly one exported business interface",
    )
  }
  let (_, body) = interfaces[0]
  let mut model_name = ""
  let mut patch_name = ""
  let mut event_name = ""
  let mut action_name = ""
  let mut replace_model_name = ""
  let mut has_replace = false
  let mut has_update = false
  let mut has_unmount = false
  for raw_member in body.split(";") {
    let item = raw_member.trim().to_owned()
    let entry = if item.has_prefix("unmount:") {
      item
    } else {
      match item.find("mount:") {
        Some(start) => item[start:].to_owned()
        None => item
      }
    }
    if entry.has_prefix("mount:") {
      let signature = entry[6:].trim().to_owned()
      guard signature.find("(") is Some(open) &&
        signature.find(")") is Some(close) else {
        raise InvalidContract("invalid WIT mount signature")
      }
      let parameters = split_wit_items(signature[open + 1:close].to_owned())
      guard parameters.length() == 2 &&
        parameters[0].split_once(":") is Some((_, entity_type)) &&
        entity_type.trim() == "u32" &&
        parameters[1].split_once(":") is Some((_, model_type)) else {
        raise InvalidContract("WIT mount requires (entity: u32, model: Model)")
      }
      model_name = pascal_case(model_type.trim().to_owned())
    } else if entry.has_prefix("replace:") {
      let signature = entry[8:].trim().to_owned()
      guard signature.find("(") is Some(open) &&
        signature.find(")") is Some(close) else {
        raise InvalidContract("invalid WIT replace signature")
      }
      let parameters = split_wit_items(signature[open + 1:close].to_owned())
      guard parameters.length() == 2 &&
        parameters[0].split_once(":") is Some((_, entity_type)) &&
        entity_type.trim() == "u32" &&
        parameters[1].split_once(":") is Some((_, replace_model)) else {
        raise InvalidContract(
          "WIT replace requires (entity: u32, model: Model)",
        )
      }
      replace_model_name = pascal_case(replace_model.trim().to_owned())
      has_replace = true
    } else if entry.has_prefix("apply:") {
      let signature = entry[6:].trim().to_owned()
      guard signature.find("(") is Some(open) &&
        signature.find(")") is Some(close) else {
        raise InvalidContract("invalid WIT apply signature")
      }
      let parameters = split_wit_items(signature[open + 1:close].to_owned())
      guard parameters.length() == 2 &&
        parameters[0].split_once(":") is Some((_, entity_type)) &&
        entity_type.trim() == "u32" else {
        raise InvalidContract("WIT apply requires entity: u32")
      }
      guard signature.find("list<") is Some(open) else {
        raise InvalidContract("WIT apply requires list<Patch>")
      }
      let rest = signature[open + 5:]
      guard rest.find(">") is Some(close) else {
        raise InvalidContract("WIT apply requires list<Patch>")
      }
      patch_name = pascal_case(rest[:close].trim().to_owned())
    } else if entry.has_prefix("handle-event:") {
      let signature = entry[13:].trim().to_owned()
      guard signature.find("(") is Some(open) &&
        signature.find(")") is Some(close) else {
        raise InvalidContract("invalid WIT handle-event signature")
      }
      let parameters = split_wit_items(signature[open + 1:close].to_owned())
      guard parameters.length() == 2 &&
        parameters[0].split_once(":") is Some((_, entity_type)) &&
        entity_type.trim() == "u32" &&
        parameters[1].split_once(":") is Some((_, event_type)) else {
        raise InvalidContract(
          "WIT handle-event requires (entity: u32, event: Event)",
        )
      }
      event_name = pascal_case(event_type.trim().to_owned())
      guard signature.find("option<") is Some(option_open) else {
        raise InvalidContract("WIT handle-event must return option<Action>")
      }
      let result = signature[option_open + 7:]
      guard result.find(">") is Some(option_close) else {
        raise InvalidContract("WIT handle-event must return option<Action>")
      }
      action_name = pascal_case(result[:option_close].trim().to_owned())
    } else if entry.has_prefix("update:") {
      if entry[7:].trim() != "func()" {
        raise InvalidContract("WIT update must be func()")
      }
      has_update = true
    } else if entry.has_prefix("unmount:") {
      let signature = entry[8:].trim().to_owned()
      guard signature.find("(") is Some(open) &&
        signature.find(")") is Some(close) else {
        raise InvalidContract("invalid WIT unmount signature")
      }
      let parameters = split_wit_items(signature[open + 1:close].to_owned())
      guard parameters.length() == 1 &&
        parameters[0].split_once(":") is Some((_, entity_type)) &&
        entity_type.trim() == "u32" else {
        raise InvalidContract("WIT unmount requires entity: u32")
      }
      has_unmount = true
    }
  }
  if model_name == "" {
    raise InvalidContract(
      "WIT business interface requires mount(entity, Model)",
    )
  }
  if has_replace && replace_model_name != model_name {
    raise InvalidContract("WIT mount and replace must use the same Model")
  }
  if !has_replace || !has_update || !has_unmount {
    raise InvalidContract(
      "WIT business interface requires replace, update, and unmount functions",
    )
  }
  (model_name, patch_name, event_name, action_name)
}

///|
fn wit_declarations(
  source : String,
  keyword : String,
) -> Array[(String, String)] raise ViewIRError {
  let declarations : Array[(String, String)] = []
  let marker = keyword + " "
  let mut cursor = 0
  while cursor < source.length() {
    guard source[cursor:].find(marker) is Some(relative) else { break }
    let start = cursor + relative + marker.length()
    guard source[start:].find("{") is Some(open_relative) else {
      raise InvalidContract("unterminated WIT " + keyword + " declaration")
    }
    let open = start + open_relative
    let name = source[start:open].trim().to_owned()
    let mut depth = 1
    let mut close = open + 1
    while close < source.length() && depth > 0 {
      if source[close] == '{' {
        depth += 1
      }
      if source[close] == '}' {
        depth -= 1
      }
      close += 1
    }
    if depth != 0 {
      raise InvalidContract("unterminated WIT " + keyword + ": " + name)
    }
    declarations.push((name, source[open + 1:close - 1].to_owned()))
    cursor = close
  }
  declarations
}

///|
fn split_wit_items(source : String) -> Array[String] {
  let items : Array[String] = []
  let mut depth = 0
  let mut start = 0
  for index = 0; index < source.length(); index = index + 1 {
    let char = source[index]
    if char == '<' || char == '(' {
      depth += 1
    }
    if char == '>' || char == ')' {
      depth -= 1
    }
    if char == ',' && depth == 0 {
      let item = source[start:index].trim().to_owned()
      if item != "" {
        items.push(item)
      }
      start = index + 1
    }
  }
  let final_item = source[start:].trim().to_owned()
  if final_item != "" {
    items.push(final_item)
  }
  items
}

///|
fn wit_type_to_moon(value : String) -> String raise ViewIRError {
  let source = value.trim().to_owned()
  if source.has_prefix("list<") && source.has_suffix(">") {
    return "Array[" +
      wit_type_to_moon(source[5:source.length() - 1].to_owned()) +
      "]"
  }
  if source.has_prefix("option<") && source.has_suffix(">") {
    return wit_type_to_moon(source[7:source.length() - 1].to_owned()) + "?"
  }
  if source.has_prefix("tuple<") && source.has_suffix(">") {
    return "(" +
      split_wit_items(source[6:source.length() - 1].to_owned())
      .map(wit_type_to_moon)
      .join(", ") +
      ")"
  }
  match source {
    "string" => "String"
    "bool" => "Bool"
    "u8" | "u16" | "u32" | "u64" => "UInt"
    "s8" | "s16" | "s32" | "s64" => "Int"
    "f32" => "Float"
    "f64" => "Double"
    _ if source.contains("<") || source.contains(">") =>
      raise InvalidContract("unsupported WIT business type: " + source)
    _ => pascal_case(source)
  }
}

///|
fn parse_tree_package(source : String) -> String raise ViewIRError {
  let marker = "import selene:ui-host/tree@"
  guard source.find(marker) is Some(start) else {
    raise InvalidContract("WIT world must import selene:ui-host/tree")
  }
  let remainder = source[start + 7:]
  let end = remainder.find(";").unwrap_or(remainder.length())
  remainder[:end].trim().to_owned()
}
