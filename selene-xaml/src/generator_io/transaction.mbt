///|
priv struct LockedOutput {
  owner : String
  path : String
  sha256 : String
} derive(FromJson)

///|
priv struct OwnershipLock {
  format_version : Int
  generator : String
  inputs : Array[Json]
  outputs : Array[LockedOutput]
  lock_path : String
} derive(FromJson)

///|
priv struct TransactionEntry {
  target : String
  backup : String
  existed : Bool
}

///|
pub(all) suberror GeneratedPackageWriteError {
  InvalidGeneratedPackage(String)
  InvalidOwnershipLock(String)
  UnsafeOwnedPath(String)
  UnownedOutput(String)
  TransactionInProgress(String)
  FormatterFailed(String)
  SourceMapRelocationFailed(String)
  RollbackFailed(String)
} derive(Eq, Debug)

///|
pub impl Show for GeneratedPackageWriteError with fn output(self, logger) {
  match self {
    InvalidGeneratedPackage(message) => logger.write_string(message)
    InvalidOwnershipLock(message) => logger.write_string(message)
    UnsafeOwnedPath(path) =>
      logger.write_string("generated ownership path is unsafe: " + path)
    UnownedOutput(path) =>
      logger.write_string("refusing to overwrite an unowned output: " + path)
    TransactionInProgress(path) =>
      logger.write_string(
        "a generation transaction already exists: " +
        path +
        "; inspect its recovery files before retrying",
      )
    FormatterFailed(message) => logger.write_string(message)
    SourceMapRelocationFailed(message) => logger.write_string(message)
    RollbackFailed(message) => logger.write_string(message)
  }
}

///|
/// Commit generated files under lock ownership with process-local rollback.
/// The lock is installed last. A process crash may leave the transaction
/// directory as an explicit recovery boundary, and a later run will refuse to
/// overwrite it.
pub async fn commit_generated_package(
  out_dir : String,
  generated : GeneratedPackage,
) -> Unit {
  let lock_name = "selene-xaml.lock.json"
  let transaction_name = ".selene-xaml.transaction"
  if out_dir == "" || out_dir == "/" {
    raise GeneratedPackageWriteError::InvalidGeneratedPackage(
      "generated package requires a concrete output directory",
    )
  }
  let generated_by_path : Map[String, GeneratedFile] = Map([])
  for file in generated.files {
    let path = file.path
    let unsafe_path = path == "" ||
      path == "." ||
      path == ".." ||
      path.has_prefix("/") ||
      path.contains("/") ||
      path.contains("\\") ||
      path == transaction_name ||
      (path.length() >= 2 && path[1] == ':')
    if unsafe_path {
      raise GeneratedPackageWriteError::UnsafeOwnedPath(path)
    }
    if generated_by_path.contains(path) {
      raise GeneratedPackageWriteError::InvalidGeneratedPackage(
        "generated package contains a duplicate output path: " + path,
      )
    }
    generated_by_path[path] = file
  }
  guard generated_by_path.get(lock_name) is Some(generated_lock_file) else {
    raise GeneratedPackageWriteError::InvalidGeneratedPackage(
      "generated package does not contain " + lock_name,
    )
  }
  let generated_lock : OwnershipLock = @json.from_json(
    @json.parse(generated_lock_file.content),
  ) catch {
    error =>
      raise GeneratedPackageWriteError::InvalidGeneratedPackage(
        "generated ownership lock is invalid: " + error.to_string(),
      )
  }
  if generated_lock.format_version != 1 || generated_lock.lock_path != lock_name {
    raise GeneratedPackageWriteError::InvalidGeneratedPackage(
      "generated ownership lock has an unsupported format or lock path",
    )
  }
  if !generated_lock.generator.has_prefix("selene-xaml@") ||
    generated_lock.generator.length() == "selene-xaml@".length() ||
    generated_lock.inputs.length() == 0 {
    raise GeneratedPackageWriteError::InvalidGeneratedPackage(
      "generated ownership lock does not identify a selene-xaml generator and its inputs",
    )
  }
  let generated_owned : Map[String, String] = Map([])
  for output in generated_lock.outputs {
    let path = output.path
    let unsafe_path = path == "" ||
      path == "." ||
      path == ".." ||
      path.has_prefix("/") ||
      path.contains("/") ||
      path.contains("\\") ||
      (path.length() >= 2 && path[1] == ':')
    if unsafe_path {
      raise GeneratedPackageWriteError::UnsafeOwnedPath(path)
    }
    if output.owner != "selene-xaml" ||
      output.sha256 == "" ||
      generated_owned.contains(path) {
      raise GeneratedPackageWriteError::InvalidGeneratedPackage(
        "generated ownership lock contains an invalid output: " + path,
      )
    }
    guard generated_by_path.get(path) is Some(file) else {
      raise GeneratedPackageWriteError::InvalidGeneratedPackage(
        "generated ownership lock describes a missing output: " + path,
      )
    }
    let actual_sha256 = @crypto.bytes_to_hex_string(
      @crypto.sha256(@encoding.encode(@encoding.Encoding::UTF8, file.content)),
    )
    if output.sha256 != actual_sha256 {
      raise GeneratedPackageWriteError::InvalidGeneratedPackage(
        "generated ownership hash does not match output: " + path,
      )
    }
    generated_owned[path] = output.sha256
  }
  if generated_owned.length() + 1 != generated_by_path.length() {
    raise GeneratedPackageWriteError::InvalidGeneratedPackage(
      "generated ownership lock does not describe the generated output set",
    )
  }
  for path, _ in generated_by_path {
    if path != lock_name && !generated_owned.contains(path) {
      raise GeneratedPackageWriteError::InvalidGeneratedPackage(
        "generated ownership lock does not own output: " + path,
      )
    }
  }
  let transaction_root = out_dir + "/" + transaction_name
  let staged_root = transaction_root + "/new"
  let backup_root = transaction_root + "/backup"
  let mut created_out_dir = false
  let mut transaction_created = false
  let mut preserve_transaction = false
  try {
    if !@fs.exists(out_dir) {
      @fs.mkdir(out_dir, recursive=true)
      created_out_dir = true
    }
    let existing = @fs.readdir(out_dir, include_hidden=true, sort=true)
    if existing.contains(transaction_name) {
      raise GeneratedPackageWriteError::TransactionInProgress(transaction_root)
    }
    let previous_owned : Map[String, Bool] = Map([])
    if existing.contains(lock_name) {
      let lock_target = out_dir + "/" + lock_name
      if @fs.kind(lock_target, follow_symlink=false) != @fs.FileKind::Regular {
        raise GeneratedPackageWriteError::InvalidOwnershipLock(
          "ownership lock is not a regular file: " + lock_target,
        )
      }
      let previous_lock : OwnershipLock = @json.from_json(
        @json.parse(@fs.read_file(lock_target).text()),
      ) catch {
        error =>
          raise GeneratedPackageWriteError::InvalidOwnershipLock(
            "cannot read the previous ownership lock: " + error.to_string(),
          )
      }
      if previous_lock.format_version != 1 ||
        previous_lock.lock_path != lock_name {
        raise GeneratedPackageWriteError::InvalidOwnershipLock(
          "previous ownership lock has an unsupported format or lock path",
        )
      }
      if !previous_lock.generator.has_prefix("selene-xaml@") ||
        previous_lock.generator.length() == "selene-xaml@".length() ||
        previous_lock.inputs.length() == 0 {
        raise GeneratedPackageWriteError::InvalidOwnershipLock(
          "previous ownership lock does not identify a selene-xaml generator and its inputs",
        )
      }
      let previous_output_owned : Map[String, String] = Map([])
      for output in previous_lock.outputs {
        if output.owner == "selene-xaml" {
          let path = output.path
          let unsafe_path = path == "" ||
            path == "." ||
            path == ".." ||
            path.has_prefix("/") ||
            path.contains("/") ||
            path.contains("\\") ||
            path == transaction_name ||
            (path.length() >= 2 && path[1] == ':')
          if unsafe_path ||
            output.sha256 == "" ||
            previous_output_owned.contains(path) {
            raise GeneratedPackageWriteError::InvalidOwnershipLock(
              "previous ownership lock contains an invalid selene-xaml output: " +
              path,
            )
          }
          if existing.contains(path) {
            let target = out_dir + "/" + path
            if @fs.kind(target, follow_symlink=false) != @fs.FileKind::Regular {
              raise GeneratedPackageWriteError::InvalidOwnershipLock(
                "owned output is not a regular file: " + path,
              )
            }
          }
          previous_output_owned[path] = output.sha256
        }
      }
      previous_owned[lock_name] = true
      for path, _ in previous_output_owned {
        previous_owned[path] = true
      }
    }
    let overwritten : Map[String, Bool] = Map([])
    for path, _ in generated_by_path {
      if existing.contains(path) {
        if !previous_owned.contains(path) {
          raise GeneratedPackageWriteError::UnownedOutput(path)
        }
        if @fs.kind(out_dir + "/" + path, follow_symlink=false) ==
          @fs.FileKind::Directory {
          raise GeneratedPackageWriteError::InvalidOwnershipLock(
            "owned output is a directory: " + path,
          )
        }
        overwritten[path] = true
      }
    }
    let stale : Array[String] = []
    for path, _ in previous_owned {
      if path != lock_name &&
        !generated_by_path.contains(path) &&
        existing.contains(path) {
        if @fs.kind(out_dir + "/" + path, follow_symlink=false) ==
          @fs.FileKind::Directory {
          raise GeneratedPackageWriteError::InvalidOwnershipLock(
            "stale owned output is a directory: " + path,
          )
        }
        stale.push(path)
      }
    }
    stale.sort()
    @fs.mkdir(transaction_root)
    transaction_created = true
    @fs.mkdir(staged_root)
    @fs.mkdir(backup_root)
    for file in generated.files {
      @fs.write_file(
        staged_root + "/" + file.path,
        file.content,
        create_mode=CreateNew,
        sync=Full,
      )
    }
    let journal : Array[TransactionEntry] = []
    try {
      for file in generated.files {
        if file.path == lock_name {
          continue
        }
        let target = out_dir + "/" + file.path
        let backup = backup_root + "/" + file.path
        let existed = overwritten.contains(file.path)
        if existed {
          @fs.rename(target, backup, replace=false)
        }
        journal.push({ target, backup, existed })
        @fs.rename(staged_root + "/" + file.path, target, replace=false)
      }
      for path in stale {
        let target = out_dir + "/" + path
        let backup = backup_root + "/" + path
        @fs.rename(target, backup, replace=false)
        journal.push({ target, backup, existed: true })
      }
      let target = out_dir + "/" + lock_name
      let backup = backup_root + "/" + lock_name
      let existed = overwritten.contains(lock_name)
      if existed {
        @fs.rename(target, backup, replace=false)
      }
      journal.push({ target, backup, existed })
      @fs.rename(staged_root + "/" + lock_name, target, replace=false)
    } catch {
      transaction_error => {
        let mut rollback_error = ""
        for entry in journal.rev() {
          try {
            if @fs.exists(entry.target) {
              @fs.remove(entry.target)
            }
            if entry.existed && @fs.exists(entry.backup) {
              @fs.rename(entry.backup, entry.target, replace=false)
            }
          } catch {
            error =>
              if rollback_error == "" {
                rollback_error = error.to_string()
              }
          } noraise {
            _ => ()
          }
        }
        if rollback_error != "" {
          preserve_transaction = true
          raise GeneratedPackageWriteError::RollbackFailed(
            "generation failed and rollback is incomplete; recovery files remain in " +
            transaction_root +
            ": " +
            rollback_error,
          )
        }
        raise transaction_error
      }
    }
  } catch {
    error => {
      if transaction_created && !preserve_transaction {
        try @fs.rmdir(transaction_root, recursive=true) catch {
          _ => ()
        } noraise {
          _ => ()
        }
      }
      if created_out_dir && !preserve_transaction {
        try @fs.rmdir(out_dir) catch {
          _ => ()
        } noraise {
          _ => ()
        }
      }
      raise error
    }
  }
  if transaction_created {
    try @fs.rmdir(transaction_root, recursive=true) catch {
      _ => ()
    } noraise {
      _ => ()
    }
  }
}
