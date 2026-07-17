///|
/// Load a Tiled world and enumerate local sibling files for world patterns.
///
/// Import this package only in runtimes with ordinary file-system access.
/// Browser runtimes should call `@tiled.load_tiled_world` and obtain pattern
/// file names from their resource manifest when pattern expansion is needed.
pub fn load_world(path : String) -> @tiled.TiledWorld raise @system_fs.IOError {
  let directory = @path.Path(path).dirname()
  let entries = @system_fs.read_dir(directory.to_string())
  let pattern_files : Array[String] = []
  for entry in entries {
    let resolved = directory.join(@path.Path(entry)).to_string()
    if @system_fs.is_file(resolved) {
      pattern_files.push(entry)
    }
  }
  @tiled.load_tiled_world(path, pattern_files~)
}
