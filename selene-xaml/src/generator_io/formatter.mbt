///|
priv struct GeneratedSourceMapping {
  source : String
  original_offset : Int
  generated_offset : Int
  length : Int
} derive(FromJson, ToJson)

///|
priv struct GeneratedSourceMap {
  mappings : Array[GeneratedSourceMapping]
} derive(FromJson, ToJson)

///|
/// Format generated MoonBit with the formatter shipped in the active Moon
/// toolchain, then relocate diagnostic mappings and ownership hashes against
/// the formatter's exact output before the package enters its write transaction.
pub async fn format_generated_package(
  generated : GeneratedPackage,
) -> GeneratedPackage {
  @async.with_task_group() <| group => {
    let temporary = @fs.tmpdir(prefix="selene-xaml-format")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @fs.rmdir(temporary, recursive=true))
    }
    let raw_by_path : Map[String, String] = Map([])
    let rewritten_by_path : Map[String, String] = Map([])
    for file in generated.files {
      if raw_by_path.contains(file.path) {
        raise GeneratedPackageWriteError::InvalidGeneratedPackage(
          "generated package contains a duplicate output path: " + file.path,
        )
      }
      raw_by_path[file.path] = file.content
      rewritten_by_path[file.path] = file.content
    }
    let mut format_index = 0
    for file in generated.files {
      if !file.path.has_suffix(".mbt") {
        continue
      }
      let input_path = temporary + "/" + format_index.to_string() + ".input.mbt"
      let output_path = temporary +
        "/" +
        format_index.to_string() +
        ".output.mbt"
      format_index += 1
      @fs.write_file(input_path, file.content, create_mode=CreateNew)
      let (exit_code, _, stderr) = @process.collect_output(
        "moonfmt",
        [input_path, "-o", output_path],
        inherit_env=true,
      ) catch {
        error =>
          raise GeneratedPackageWriteError::FormatterFailed(
            "cannot execute moonfmt from the active Moon toolchain: " +
            error.to_string(),
          )
      }
      if exit_code != 0 {
        raise GeneratedPackageWriteError::FormatterFailed(
          "moonfmt rejected " +
          file.path +
          " with exit code " +
          exit_code.to_string() +
          ": " +
          stderr.text().trim().to_owned(),
        )
      }
      rewritten_by_path[file.path] = @fs.read_file(output_path).text()
    }
    for file in generated.files {
      if !file.path.has_suffix(".mbt.map.json") {
        continue
      }
      let source_path = file.path[:file.path.length() - ".map.json".length()].to_owned()
      guard raw_by_path.get(source_path) is Some(raw_source) else {
        raise GeneratedPackageWriteError::SourceMapRelocationFailed(
          "source map has no generated MoonBit source: " + file.path,
        )
      }
      guard rewritten_by_path.get(source_path) is Some(formatted_source) else {
        raise GeneratedPackageWriteError::SourceMapRelocationFailed(
          "formatted MoonBit source is missing: " + source_path,
        )
      }
      let source_map : GeneratedSourceMap = @json.from_json(
        @json.parse(file.content),
      ) catch {
        error =>
          raise GeneratedPackageWriteError::SourceMapRelocationFailed(
            "cannot parse " + file.path + ": " + error.to_string(),
          )
      }
      let relocated : Array[GeneratedSourceMapping] = []
      let mut search_offset = 0
      for mapping in source_map.mappings {
        let end = mapping.generated_offset + mapping.length
        if mapping.generated_offset < 0 ||
          mapping.length <= 0 ||
          end > raw_source.length() {
          raise GeneratedPackageWriteError::SourceMapRelocationFailed(
            "source map range is outside " + source_path,
          )
        }
        let expression = raw_source[mapping.generated_offset:end].to_owned()
        guard formatted_source[search_offset:].find(expression)
          is Some(relative) else {
          raise GeneratedPackageWriteError::SourceMapRelocationFailed(
            "moonfmt changed a mapped expression in " +
            source_path +
            ": " +
            expression,
          )
        }
        let generated_offset = search_offset + relative
        relocated.push({ ..mapping, generated_offset, })
        search_offset = generated_offset + expression.length()
      }
      rewritten_by_path[file.path] = ToJson::to_json(
          ({ mappings: relocated } : GeneratedSourceMap),
        ).stringify(indent=2) +
        "\n"
    }
    guard raw_by_path.get("selene-xaml.lock.json") is Some(raw_lock) else {
      raise GeneratedPackageWriteError::InvalidGeneratedPackage(
        "generated package does not contain selene-xaml.lock.json",
      )
    }
    let mut rewritten_lock = raw_lock
    for file in generated.files {
      if file.path == "selene-xaml.lock.json" {
        continue
      }
      let old_hash = @crypto.bytes_to_hex_string(
        @crypto.sha256(@encoding.encode(@encoding.Encoding::UTF8, file.content)),
      )
      let content = rewritten_by_path[file.path]
      let new_hash = @crypto.bytes_to_hex_string(
        @crypto.sha256(@encoding.encode(@encoding.Encoding::UTF8, content)),
      )
      if old_hash == new_hash {
        continue
      }
      let old_entry = "\"path\": " +
        file.path.escape() +
        ", \"sha256\": \"" +
        old_hash +
        "\""
      let new_entry = "\"path\": " +
        file.path.escape() +
        ", \"sha256\": \"" +
        new_hash +
        "\""
      let updated = rewritten_lock.replace(old=old_entry, new=new_entry)
      if updated == rewritten_lock {
        raise GeneratedPackageWriteError::InvalidGeneratedPackage(
          "ownership lock does not contain the generated output hash: " +
          file.path,
        )
      }
      rewritten_lock = updated
    }
    rewritten_by_path["selene-xaml.lock.json"] = rewritten_lock
    {
      files: generated.files.map(file => {
        path: file.path,
        content: rewritten_by_path[file.path],
      }),
    }
  }
}
