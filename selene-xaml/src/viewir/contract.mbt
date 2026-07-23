///|
fn parse_contract(source : String) -> ParsedContract raise ViewIRError {
  let structs : Map[String, IRStruct] = Map([])
  let enums : Map[String, IREnum] = Map([])
  let aliases : Map[String, String] = Map([])
  let functions : Map[String, IRFunction] = Map([])
  let mut package_path = ""
  let mut declaration_kind = ""
  let mut declaration_name = ""
  let declaration_body : Array[String] = []
  for raw_line in source.split("\n") {
    let line = raw_line.trim().to_owned()
    if package_path == "" && line.has_prefix("package \"") {
      let value = line[9:]
      match value.find("\"") {
        Some(index) => package_path = value[:index].to_owned()
        None => raise InvalidContract("invalid package declaration in .mbti")
      }
      continue
    }
    if declaration_kind == "" {
      if line.has_prefix("pub fn ") {
        let signature = line[7:].trim().to_owned()
        guard signature.split_once("(") is Some((raw_name, rest)) else {
          raise InvalidContract("invalid public function in .mbti: " + line)
        }
        guard rest.split_once(") -> ") is Some((raw_parameters, raw_return)) else {
          raise InvalidContract("invalid public function in .mbti: " + line)
        }
        let name = raw_name.trim().to_owned()
        let parameters = raw_parameters
          .split(",")
          .map(parameter => parameter.trim().to_owned())
          .filter(parameter => parameter != "")
          .collect()
        let return_type = raw_return
          .split(" ")
          .next()
          .unwrap_or("")
          .trim()
          .to_owned()
        if name == "" || return_type == "" {
          raise InvalidContract("invalid public function in .mbti: " + line)
        }
        functions[name] = { name, parameters, return_type }
        continue
      }
      let alias_prefix = if line.has_prefix("pub type ") {
        "pub type "
      } else if line.has_prefix("pub(all) type ") {
        "pub(all) type "
      } else {
        ""
      }
      if alias_prefix != "" {
        let declaration = line[alias_prefix.length():].trim().to_owned()
        match declaration.split_once("=") {
          Some((raw_name, raw_target)) => {
            let name = raw_name.trim().to_owned()
            let target = raw_target.trim().to_owned()
            if name == "" || target == "" {
              raise InvalidContract(
                "invalid public type alias in .mbti: " + line,
              )
            }
            aliases[name] = target
          }
          None => ()
        }
        continue
      }
      let struct_prefix = "pub(all) struct "
      let enum_prefix = "pub(all) enum "
      if !line.has_prefix(struct_prefix) && !line.has_prefix(enum_prefix) {
        continue
      }
      declaration_kind = if line.has_prefix(struct_prefix) {
        "struct"
      } else {
        "enum"
      }
      let prefix = if declaration_kind == "struct" {
        struct_prefix
      } else {
        enum_prefix
      }
      let rest = line[prefix.length():].to_owned()
      let name_end = rest
        .find(" ")
        .unwrap_or(
          rest.find("{").unwrap_or(rest.find("(").unwrap_or(rest.length())),
        )
      declaration_name = rest[:name_end].trim().to_owned()
      if declaration_name == "" {
        raise InvalidContract("invalid public declaration in .mbti: " + line)
      }
      match rest.find("{") {
        Some(open) => {
          let body = rest[open + 1:]
          match body.find("}") {
            Some(close) => declaration_body.push(body[:close].to_owned())
            None => declaration_body.push(body.to_owned())
          }
        }
        None => ()
      }
    } else if line.contains("}") {
      let body = line.split_once("}").unwrap().0.trim().to_owned()
      if body != "" {
        declaration_body.push(body)
      }
    } else if line != "" {
      declaration_body.push(line)
    }
    if declaration_kind == "" || !line.contains("}") {
      continue
    }
    if declaration_kind == "struct" {
      let fields : Array[IRField] = []
      for body_line in declaration_body {
        for raw_field in body_line.split(";") {
          let field = raw_field.trim().trim_end(chars=",").trim().to_owned()
          match field.split_once(":") {
            Some((raw_name, raw_type)) => {
              let name = raw_name.trim().to_owned()
              let field_type = raw_type.trim().to_owned()
              if name != "" && field_type != "" {
                fields.push({ name, field_type })
              }
            }
            None => ()
          }
        }
      }
      fields.sort_by(fn(lhs, rhs) { lhs.name.compare(rhs.name) })
      structs[declaration_name] = { name: declaration_name, fields }
    } else {
      let variants : Array[IRVariant] = []
      for body_line in declaration_body {
        let variant = body_line.trim().trim_end(chars=",").trim().to_owned()
        if variant == "" {
          continue
        }
        let open = variant.find("(")
        let name = match open {
          Some(index) => variant[:index].trim().to_owned()
          None => variant.split(" ").next().unwrap_or("").trim().to_owned()
        }
        let payload = match open {
          Some(index) => {
            let close = if variant.has_suffix(")") {
              variant.length() - 1
            } else {
              variant.length()
            }
            Some(variant[index + 1:close].trim().to_owned())
          }
          None => None
        }
        if name != "" {
          variants.push({ name, payload })
        }
      }
      enums[declaration_name] = { name: declaration_name, variants }
    }
    declaration_kind = ""
    declaration_name = ""
    declaration_body.clear()
  }
  if declaration_kind != "" {
    raise InvalidContract("unterminated .mbti declaration: " + declaration_name)
  }
  if package_path == "" {
    raise InvalidContract(".mbti requires a package declaration")
  }
  { package_path, structs, enums, aliases, functions }
}

///|
fn base_type_name(value : String) -> String {
  let trimmed = value.trim().trim_end(chars="?").trim().to_owned()
  let unwrapped = array_item_type(trimmed).unwrap_or(trimmed)
  unwrapped.split(".").last().map_or(unwrapped, part => part.to_owned())
}

///|
fn array_item_type(value : String) -> String? {
  let trimmed = value.trim()
  if !trimmed.has_prefix("Array[") || !trimmed.has_suffix("]") {
    return None
  }
  Some(base_type_name(trimmed[6:trimmed.length() - 1].to_owned()))
}

///|
fn ParsedContract::resolve_named_alias(
  self : ParsedContract,
  value : String,
) -> String raise ViewIRError {
  let mut current = value.trim().to_owned()
  let visited : Map[String, Bool] = Map([])
  while self.aliases.contains(current) {
    if visited.contains(current) {
      raise InvalidContract("cyclic public type alias in .mbti: " + current)
    }
    visited[current] = true
    let target = self.aliases[current].trim().to_owned()
    if target == "" ||
      target.has_prefix("@") ||
      target.has_suffix("?") ||
      target.contains("[") ||
      target.contains("(") ||
      target.contains(" ") {
      return current
    }
    current = target.split(".").last().map_or(target, part => part.to_owned())
  }
  current
}
