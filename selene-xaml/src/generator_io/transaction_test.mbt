///|
struct FormattedSourceMapping {
  source : String
  original_offset : Int
  generated_offset : Int
  length : Int
} derive(FromJson)

///|
struct FormattedSourceMap {
  mappings : Array[FormattedSourceMapping]
} derive(FromJson)

///|
struct FormattedLockedOutput {
  owner : String
  path : String
  sha256 : String
} derive(FromJson)

///|
struct FormattedOwnershipLock {
  outputs : Array[FormattedLockedOutput]
} derive(FromJson)

///|
async test "CG-FORMAT-02 snapshots relocated generated package" (t : @test.Test) {
  let source = "fn answer(model : Model)->Int{model.value}\n"
  let expression = "model.value"
  let generated_offset = source.find(expression).unwrap()
  let source_map =
    $|{
    $|  "mappings": [
    $|    {
    $|      "source": "fixtures/view.xaml",
    $|      "original_offset": 42,
    $|      "generated_offset": \{generated_offset},
    $|      "length": \{expression.length()}
    $|    }
    $|  ]
    $|}
    $|
  let source_hash = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding.encode(@encoding.Encoding::UTF8, source)),
  )
  let source_map_hash = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding.encode(@encoding.Encoding::UTF8, source_map)),
  )
  let lock =
    $|{
    $|  "format_version": 1,
    $|  "generator": "selene-xaml@0.1.0",
    $|  "inputs": [{}],
    $|  "outputs": [
    $|    { "owner": "selene-xaml", "path": "view.generated.mbt", "sha256": "\{source_hash}" },
    $|    { "owner": "selene-xaml", "path": "view.generated.mbt.map.json", "sha256": "\{source_map_hash}" }
    $|  ],
    $|  "lock_path": "selene-xaml.lock.json"
    $|}
    $|
  let formatted = @generator_io.format_generated_package({
    files: [
      { path: "view.generated.mbt", content: source },
      { path: "view.generated.mbt.map.json", content: source_map },
      { path: "selene-xaml.lock.json", content: lock },
    ],
  })
  let formatted_by_path : Map[String, String] = Map([])
  for file in formatted.files {
    formatted_by_path[file.path] = file.content
  }
  guard formatted_by_path.get("view.generated.mbt") is Some(formatted_source) else {
    fail("formatted package must contain view.generated.mbt")
  }
  guard formatted_by_path.get("view.generated.mbt.map.json")
    is Some(formatted_source_map) else {
    fail("formatted package must contain view.generated.mbt.map.json")
  }
  guard formatted_by_path.get("selene-xaml.lock.json") is Some(formatted_lock) else {
    fail("formatted package must contain selene-xaml.lock.json")
  }
  let relocated_offset = formatted_source.find(expression).unwrap()
  let formatted_source_hash = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding.encode(@encoding.Encoding::UTF8, formatted_source)),
  )
  let formatted_source_map_hash = @crypto.bytes_to_hex_string(
    @crypto.sha256(
      @encoding.encode(@encoding.Encoding::UTF8, formatted_source_map),
    ),
  )
  let decoded_source_map : FormattedSourceMap = @json.from_json(
    @json.parse(formatted_source_map),
  )
  assert_eq(decoded_source_map.mappings.length(), 1)
  let mapping = decoded_source_map.mappings[0]
  assert_eq(mapping.source, "fixtures/view.xaml")
  assert_eq(mapping.original_offset, 42)
  assert_eq(mapping.generated_offset, relocated_offset)
  assert_eq(mapping.length, expression.length())
  assert_eq(
    formatted_source[mapping.generated_offset:mapping.generated_offset +
    mapping.length],
    expression,
  )
  let decoded_lock : FormattedOwnershipLock = @json.from_json(
    @json.parse(formatted_lock),
  )
  assert_eq(decoded_lock.outputs.length(), 2)
  let output_hashes : Map[String, String] = Map([])
  for output in decoded_lock.outputs {
    assert_eq(output.owner, "selene-xaml")
    output_hashes[output.path] = output.sha256
  }
  assert_eq(output_hashes.length(), decoded_lock.outputs.length())
  assert_eq(
    output_hashes.get("view.generated.mbt"),
    Some(formatted_source_hash),
  )
  assert_eq(
    output_hashes.get("view.generated.mbt.map.json"),
    Some(formatted_source_map_hash),
  )
  for file in formatted.files {
    let header =
      $|===== \{file.path} =====
    t.writeln(header)
    t.write(file.content)
    if !file.content.has_suffix("\n") {
      t.writeln("")
    }
    t.writeln("")
  }
  t.snapshot(filename="relocated_generated_package.txt")
}

///|
async test "CG-GENERATE-03 overwrites edited owned outputs and preserves user files" {
  @async.with_task_group() <| group => {
    let temporary = @fs.tmpdir(prefix="selene-xaml-ownership")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @fs.rmdir(temporary, recursive=true))
    }
    let output = temporary + "/view"
    @fs.mkdir(output)
    let previous_lock =
      #|{
      #|  "format_version": 1,
      #|  "generator": "selene-xaml@0.1.0",
      #|  "inputs": [{}],
      #|  "outputs": [
      #|    { "owner": "selene-xaml", "path": "view.generated.mbt", "sha256": "b68aac6c503e31d251313d5cd88bf7debd83d89770b4c0db26ccb34312bbdfcf" },
      #|    { "owner": "selene-xaml", "path": "obsolete.generated.mbt", "sha256": "b80cd861051aa5903ae63197c8a1e586800bfb3c45b8e3ab44e5892aa93f5975" },
      #|    { "owner": "user", "path": "view_model.mbt", "sha256": "user" }
      #|  ],
      #|  "lock_path": "selene-xaml.lock.json"
      #|}
    @fs.write_file(
      output + "/selene-xaml.lock.json",
      previous_lock,
      create_mode=CreateNew,
    )
    @fs.write_file(
      output + "/view.generated.mbt",
      "manually edited view",
      create_mode=CreateNew,
    )
    @fs.write_file(
      output + "/obsolete.generated.mbt",
      "manually edited obsolete output",
      create_mode=CreateNew,
    )
    @fs.write_file(
      output + "/view_model.mbt",
      "user projection",
      create_mode=CreateNew,
    )
    @fs.write_file(output + "/README.md", "user readme", create_mode=CreateNew)
    let next_lock =
      #|{
      #|  "format_version": 1,
      #|  "generator": "selene-xaml@0.1.0",
      #|  "inputs": [{}],
      #|  "outputs": [
      #|    { "owner": "selene-xaml", "path": "moon.pkg", "sha256": "ed0ce439ed72bd0de7c1bfd2a0763918d9ffebfcf6499f5931646ff253a25ef3" },
      #|    { "owner": "selene-xaml", "path": "view.generated.mbt", "sha256": "b64b53ef67879092650c391c7c9a597844e81492f262f790a3c7140d2a5f974a" }
      #|  ],
      #|  "lock_path": "selene-xaml.lock.json"
      #|}
    let generated : @generator_io.GeneratedPackage = {
      files: [
        { path: "moon.pkg", content: "generated package" },
        { path: "view.generated.mbt", content: "new view" },
        { path: "selene-xaml.lock.json", content: next_lock },
      ],
    }
    @generator_io.commit_generated_package(output, generated)
    debug_inspect(
      (
        @fs.read_file(output + "/view_model.mbt").text(),
        @fs.read_file(output + "/README.md").text(),
        @fs.read_file(output + "/moon.pkg").text(),
        @fs.read_file(output + "/view.generated.mbt").text(),
        @fs.read_file(output + "/selene-xaml.lock.json").text() == next_lock,
        @fs.exists(output + "/obsolete.generated.mbt"),
        @fs.exists(output + "/.selene-xaml.transaction"),
      ),
      content=(
        #|(
        #|  "user projection",
        #|  "user readme",
        #|  "generated package",
        #|  "new view",
        #|  true,
        #|  false,
        #|  false,
        #|)
      ),
    )
  }
}

///|
async test "CG-GENERATE-04 rejects unowned collisions without mutation" {
  @async.with_task_group() <| group => {
    let temporary = @fs.tmpdir(prefix="selene-xaml-unowned")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @fs.rmdir(temporary, recursive=true))
    }
    let output = temporary + "/view"
    @fs.mkdir(output)
    @fs.write_file(
      output + "/view.generated.mbt",
      "user-owned source",
      create_mode=CreateNew,
    )
    let next_lock =
      #|{
      #|  "format_version": 1,
      #|  "generator": "selene-xaml@0.1.0",
      #|  "inputs": [{}],
      #|  "outputs": [
      #|    { "owner": "selene-xaml", "path": "view.generated.mbt", "sha256": "18fdd58e1597c70435f9c6063cd401fc3fb9e7b3a888c85434e4befffb78f0f1" }
      #|  ],
      #|  "lock_path": "selene-xaml.lock.json"
      #|}
    let generated : @generator_io.GeneratedPackage = {
      files: [
        { path: "view.generated.mbt", content: "generated source" },
        { path: "selene-xaml.lock.json", content: next_lock },
      ],
    }
    let result = try {
      @generator_io.commit_generated_package(output, generated)
      "committed"
    } catch {
      @generator_io.GeneratedPackageWriteError::UnownedOutput(path) =>
        "unowned:" + path
      error => raise error
    }
    debug_inspect(
      (
        result,
        @fs.read_file(output + "/view.generated.mbt").text(),
        @fs.exists(output + "/selene-xaml.lock.json"),
        @fs.exists(output + "/.selene-xaml.transaction"),
      ),
      content=(
        #|("unowned:view.generated.mbt", "user-owned source", false, false)
      ),
    )
  }
}

///|
async test "CG-GENERATE-05 rejects forged previous ownership locks" {
  @async.with_task_group() <| group => {
    let temporary = @fs.tmpdir(prefix="selene-xaml-forged-ownership")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @fs.rmdir(temporary, recursive=true))
    }
    let output = temporary + "/view"
    @fs.mkdir(output)
    @fs.write_file(
      output + "/view.generated.mbt",
      "user source",
      create_mode=CreateNew,
    )
    let next_lock =
      #|{
      #|  "format_version": 1,
      #|  "generator": "selene-xaml@0.1.0",
      #|  "inputs": [{}],
      #|  "outputs": [
      #|    { "owner": "selene-xaml", "path": "view.generated.mbt", "sha256": "18fdd58e1597c70435f9c6063cd401fc3fb9e7b3a888c85434e4befffb78f0f1" }
      #|  ],
      #|  "lock_path": "selene-xaml.lock.json"
      #|}
    let generated : @generator_io.GeneratedPackage = {
      files: [
        { path: "view.generated.mbt", content: "generated source" },
        { path: "selene-xaml.lock.json", content: next_lock },
      ],
    }
    let invalid_locks = [
      (
        "foreign generator",
        (
          #|{"format_version":1,"generator":"foreign@1","inputs":[{}],"outputs":[{"owner":"selene-xaml","path":"view.generated.mbt","sha256":"old"}],"lock_path":"selene-xaml.lock.json"}
        ),
      ),
      (
        "empty inputs",
        (
          #|{"format_version":1,"generator":"selene-xaml@0.1.0","inputs":[],"outputs":[{"owner":"selene-xaml","path":"view.generated.mbt","sha256":"old"}],"lock_path":"selene-xaml.lock.json"}
        ),
      ),
      (
        "unsafe path",
        (
          #|{"format_version":1,"generator":"selene-xaml@0.1.0","inputs":[{}],"outputs":[{"owner":"selene-xaml","path":"../view.generated.mbt","sha256":"old"}],"lock_path":"selene-xaml.lock.json"}
        ),
      ),
      (
        "empty hash",
        (
          #|{"format_version":1,"generator":"selene-xaml@0.1.0","inputs":[{}],"outputs":[{"owner":"selene-xaml","path":"view.generated.mbt","sha256":""}],"lock_path":"selene-xaml.lock.json"}
        ),
      ),
      (
        "duplicate path",
        (
          #|{"format_version":1,"generator":"selene-xaml@0.1.0","inputs":[{}],"outputs":[{"owner":"selene-xaml","path":"view.generated.mbt","sha256":"b7bb79bdab6100398cb821facefb1bcca60c88bb5f5e6355a9c5985cb40d44be"},{"owner":"selene-xaml","path":"view.generated.mbt","sha256":"b7bb79bdab6100398cb821facefb1bcca60c88bb5f5e6355a9c5985cb40d44be"}],"lock_path":"selene-xaml.lock.json"}
        ),
      ),
    ]
    let results : Array[String] = []
    for entry in invalid_locks {
      let (label, lock) = entry
      @fs.write_file(
        output + "/selene-xaml.lock.json",
        lock,
        create_mode=CreateOrTruncate,
      )
      let result = try {
        @generator_io.commit_generated_package(output, generated)
        "committed"
      } catch {
        @generator_io.GeneratedPackageWriteError::InvalidOwnershipLock(_) =>
          "invalid"
        error => raise error
      }
      results.push(label + ":" + result)
    }
    let invalid_generated : @generator_io.GeneratedPackage = {
      files: [
        { path: "view.generated.mbt", content: "generated source" },
        {
          path: "selene-xaml.lock.json",
          content: (
            #|{"format_version":1,"generator":"selene-xaml@0.1.0","inputs":[{}],"outputs":[{"owner":"selene-xaml","path":"view.generated.mbt","sha256":"0000000000000000000000000000000000000000000000000000000000000000"}],"lock_path":"selene-xaml.lock.json"},
          ),
        },
      ],
    }
    let invalid_generated_result = try {
      @generator_io.commit_generated_package(output, invalid_generated)
      "committed"
    } catch {
      @generator_io.GeneratedPackageWriteError::InvalidGeneratedPackage(_) =>
        "invalid"
      error => raise error
    }
    let fresh_output = temporary + "/fresh-view"
    let foreign_generated : @generator_io.GeneratedPackage = {
      files: [
        { path: "view.generated.mbt", content: "generated source" },
        {
          path: "selene-xaml.lock.json",
          content: (
            #|{"format_version":1,"generator":"foreign@1","inputs":[{}],"outputs":[{"owner":"selene-xaml","path":"view.generated.mbt","sha256":"18fdd58e1597c70435f9c6063cd401fc3fb9e7b3a888c85434e4befffb78f0f1"}],"lock_path":"selene-xaml.lock.json"},
          ),
        },
      ],
    }
    let foreign_generated_result = try {
      @generator_io.commit_generated_package(fresh_output, foreign_generated)
      "committed"
    } catch {
      @generator_io.GeneratedPackageWriteError::InvalidGeneratedPackage(_) =>
        "invalid"
      error => raise error
    }
    debug_inspect(
      (
        results,
        invalid_generated_result,
        foreign_generated_result,
        @fs.read_file(output + "/view.generated.mbt").text(),
        @fs.exists(fresh_output),
        @fs.exists(output + "/.selene-xaml.transaction"),
      ),
      content=(
        #|(
        #|  [
        #|    "foreign generator:invalid",
        #|    "empty inputs:invalid",
        #|    "unsafe path:invalid",
        #|    "empty hash:invalid",
        #|    "duplicate path:invalid",
        #|  ],
        #|  "invalid",
        #|  "invalid",
        #|  "user source",
        #|  false,
        #|  false,
        #|)
      ),
    )
  }
}
