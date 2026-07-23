///|
pub fn parse_markup_extension(
  source_uri : String,
  text : String,
  namespaces : Map[String, String],
  span? : XamlSourceSpan = XamlSourceSpan::unknown(source_uri),
) -> XamlMarkupExtension raise XamlError {
  let trimmed = text.trim().to_owned()
  if !trimmed.has_prefix("{") ||
    !trimmed.has_suffix("}") ||
    trimmed.has_prefix("{}") {
    raise XamlError::Diagnostic({
      code: "SX1201",
      message: "markup extension must be enclosed by one pair of braces",
      severity: Error,
      span,
    })
  }
  let body = trimmed[1:trimmed.length() - 1].trim()
  let mut separator = body.length()
  let mut depth = 0
  let mut quote : Char? = None
  for index, ch in body {
    match quote {
      Some(expected) => if ch == expected { quote = None }
      None =>
        if ch == '\'' || ch == '"' {
          quote = Some(ch)
        } else if ch == '{' {
          depth += 1
        } else if ch == '}' {
          depth -= 1
        } else if depth == 0 && (ch == ' ' || ch == ',') {
          separator = index
          break
        }
    }
  }
  let lexical_type = body[:separator].trim().to_owned()
  let lexical_parts = lexical_type.split(":").to_array()
  let (prefix, local_name) = match lexical_parts {
    [value] => (None, value.to_owned())
    [prefix_value, value] => (Some(prefix_value.to_owned()), value.to_owned())
    _ =>
      raise XamlError::Diagnostic({
        code: "SX1202",
        message: "invalid markup extension type name: " + lexical_type,
        severity: Error,
        span,
      })
  }
  let namespace_uri = match prefix {
    Some(value) =>
      match namespaces.get(value) {
        Some(uri) => uri
        None =>
          raise XamlError::Diagnostic({
            code: "SX1203",
            message: "unknown namespace prefix in markup extension: " + value,
            severity: Error,
            span,
          })
      }
    None => namespaces.get("").unwrap_or("")
  }
  let arguments : Array[XamlMarkupArgument] = []
  let mut argument_start = separator
  while argument_start < body.length() &&
        (body[argument_start] == ' ' || body[argument_start] == ',') {
    argument_start += 1
  }
  let argument_text = body[argument_start:]
  let argument_chars = argument_text.to_array()
  let mut start = 0
  depth = 0
  quote = None
  for index = 0; index <= argument_chars.length(); index = index + 1 {
    let at_end = index == argument_chars.length()
    let ch = if at_end { ',' } else { argument_chars[index] }
    match quote {
      Some(expected) => if ch == expected { quote = None }
      None =>
        if ch == '\'' || ch == '"' {
          quote = Some(ch)
        } else if ch == '{' {
          depth += 1
        } else if ch == '}' {
          depth -= 1
        } else if depth == 0 && (ch == ',' || at_end) {
          let token_buffer = StringBuilder::new()
          for token_index = start
              token_index < index
              token_index = token_index + 1 {
            token_buffer.write_char(argument_chars[token_index])
          }
          let token = token_buffer.to_string().trim().to_owned()
          if token != "" {
            let mut equals = -1
            let mut nested_depth = 0
            let mut nested_quote : Char? = None
            for token_index, token_ch in token {
              match nested_quote {
                Some(expected) =>
                  if token_ch == expected {
                    nested_quote = None
                  }
                None =>
                  if token_ch == '\'' || token_ch == '"' {
                    nested_quote = Some(token_ch)
                  } else if token_ch == '{' {
                    nested_depth += 1
                  } else if token_ch == '}' {
                    nested_depth -= 1
                  } else if nested_depth == 0 && token_ch == '=' {
                    equals = token_index
                    break
                  }
              }
            }
            let name = if equals >= 0 {
              Some(token[:equals].trim().to_owned())
            } else {
              None
            }
            let value_text = if equals >= 0 {
              token[equals + 1:].trim().to_owned()
            } else {
              token
            }
            let value = if value_text.has_prefix("{") {
              XamlMarkupValue::Extension(
                parse_markup_extension(
                  source_uri,
                  value_text,
                  namespaces,
                  span~,
                ),
              )
            } else {
              let value_chars = value_text.to_array()
              let unquoted = if value_chars.length() >= 2 &&
                (
                  (
                    value_chars[0] == '"' &&
                    value_chars[value_chars.length() - 1] == '"'
                  ) ||
                  (
                    value_chars[0] == '\'' &&
                    value_chars[value_chars.length() - 1] == '\''
                  )
                ) {
                let value_buffer = StringBuilder::new()
                for value_index = 1
                    value_index < value_chars.length() - 1
                    value_index = value_index + 1 {
                  value_buffer.write_char(value_chars[value_index])
                }
                value_buffer.to_string()
              } else {
                value_text
              }
              XamlMarkupValue::Literal(unquoted)
            }
            arguments.push({ name, value })
          }
          start = index + 1
        }
    }
  }
  if depth != 0 || quote is Some(_) {
    raise XamlError::Diagnostic({
      code: "SX1204",
      message: "unbalanced markup extension expression",
      severity: Error,
      span,
    })
  }
  {
    type_name: XamlQualifiedName(namespace_uri, local_name, prefix~),
    arguments,
    span,
  }
}
