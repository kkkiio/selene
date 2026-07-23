///|
pub(all) struct TextureAtlasRegion {
  name : String
  index : Int
  rect : @math.Rect
  source_size : @math.Vec2
  trim_offset : @math.Vec2
  rotated : Bool
}

///|
pub(all) struct TextureAtlasAsset {
  image : @asset_types.ImageHandle
  image_path : String
  layout : @sprite.TextureAtlasLayoutHandle
  regions : Array[TextureAtlasRegion]
}

///|
pub(all) struct AtlasImage {
  image : @asset_types.ImageHandle
  source : @render2d_types.ImageRegion2D
}

///|
pub(all) suberror TextureAtlasError {
  MissingLabel(String)
  MissingDocument(String)
  InvalidUtf8(String)
  InvalidJson(String, String)
  InvalidDocument(String, String)
  MissingRegion(String, String)
  RotatedRegion(String, String)
} derive(Eq, Debug)

///|
pub impl Show for TextureAtlasError with fn output(self, logger) {
  match self {
    MissingLabel(path) =>
      logger.write_string("texture atlas source requires a #label: " + path)
    MissingDocument(path) =>
      logger.write_string("missing texture atlas document: " + path)
    InvalidUtf8(path) =>
      logger.write_string("texture atlas document is not UTF-8: " + path)
    InvalidJson(path, message) =>
      logger.write_string(
        "invalid texture atlas JSON at " + path + ": " + message,
      )
    InvalidDocument(path, message) =>
      logger.write_string(
        "invalid texture atlas document at " + path + ": " + message,
      )
    MissingRegion(path, label) =>
      logger.write_string(
        "texture atlas region does not exist: " + path + "#" + label,
      )
    RotatedRegion(path, label) =>
      logger.write_string(
        "rotated texture atlas region is unsupported: " + path + "#" + label,
      )
  }
}

///|
let texture_atlas_assets : Map[String, TextureAtlasAsset] = Map([])

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Object(object) => Some(object)
    _ => None
  }
}

///|
fn json_array(value : Json) -> Array[Json]? {
  match value {
    Array(array) => Some(array)
    _ => None
  }
}

///|
fn json_string(value : Json) -> String? {
  match value {
    String(text) => Some(text)
    _ => None
  }
}

///|
fn json_number(value : Json) -> Double? {
  match value {
    Number(number, ..) => Some(number)
    _ => None
  }
}

///|
fn json_bool(value : Json) -> Bool? {
  match value {
    True => Some(true)
    False => Some(false)
    _ => None
  }
}

///|
fn field_object(object : Map[String, Json], key : String) -> Map[String, Json]? {
  match object.get(key) {
    Some(value) => json_object(value)
    None => None
  }
}

///|
fn field_array(object : Map[String, Json], key : String) -> Array[Json]? {
  match object.get(key) {
    Some(value) => json_array(value)
    None => None
  }
}

///|
fn field_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(value) => json_string(value)
    None => None
  }
}

///|
fn field_number(object : Map[String, Json], key : String) -> Double? {
  match object.get(key) {
    Some(value) => json_number(value)
    None => None
  }
}

///|
fn field_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(value) => json_bool(value)
    None => None
  }
}

///|
fn vec2_document(
  object : Map[String, Json]?,
  x : String,
  y : String,
  default : @math.Vec2,
) -> @math.Vec2 {
  match object {
    Some(value) =>
      @math.Vec2(
        field_number(value, x).unwrap_or(default[X]),
        field_number(value, y).unwrap_or(default[Y]),
      )
    None => default
  }
}

///|
fn rect_document(object : Map[String, Json]?) -> @math.Rect? {
  guard object is Some(value) else { return None }
  let width = match field_number(value, "w") {
    Some(number) => Some(number)
    None => field_number(value, "width")
  }
  let height = match field_number(value, "h") {
    Some(number) => Some(number)
    None => field_number(value, "height")
  }
  guard width is Some(width) && height is Some(height) else { return None }
  Some({
    position: @math.Vec2(
      field_number(value, "x").unwrap_or(0.0),
      field_number(value, "y").unwrap_or(0.0),
    ),
    size: @math.Vec2(width, height),
  })
}

///|
fn resolve_relative_path(document_path : String, image_path : String) -> String {
  if image_path.has_prefix("/") || image_path.contains("://") {
    return image_path
  }
  let joined = match document_path.rev_find("/") {
    Some(index) =>
      document_path.unsafe_substring(start=0, end=index + 1) + image_path
    None => image_path
  }
  let segments : Array[String] = []
  for raw_segment in joined.split("/") {
    let segment = raw_segment.to_owned()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if segments.length() > 0 && segments.last().unwrap() != ".." {
        ignore(segments.pop())
      } else {
        segments.push(segment)
      }
      continue
    }
    segments.push(segment)
  }
  segments.join("/")
}

///|
fn parse_canonical_regions(
  path : String,
  root : Map[String, Json],
) -> (String, @math.Vec2, Array[TextureAtlasRegion]) raise TextureAtlasError {
  let data = field_object(root, "data").unwrap_or(root)
  guard field_string(data, "source_image") is Some(image_path) else {
    raise InvalidDocument(path, "canonical atlas requires source_image")
  }
  let regions_json = field_array(data, "regions").unwrap_or([])
  let regions : Array[TextureAtlasRegion] = []
  let mut atlas_size = @math.Vec2::zero()
  for entry in regions_json {
    guard json_object(entry) is Some(region) &&
      field_string(region, "name") is Some(name) &&
      rect_document(field_object(region, "rect")) is Some(rect) else {
      raise InvalidDocument(path, "canonical region requires name and rect")
    }
    let index = field_number(region, "index")
      .map(number => number.to_int())
      .unwrap_or(regions.length())
    regions.push({
      name,
      index,
      rect,
      source_size: rect.size,
      trim_offset: @math.Vec2::zero(),
      rotated: false,
    })
    atlas_size = @math.Vec2(
      atlas_size[X].max(rect.position[X] + rect.size[X]),
      atlas_size[Y].max(rect.position[Y] + rect.size[Y]),
    )
  }
  (resolve_relative_path(path, image_path), atlas_size, regions)
}

///|
fn parse_external_frame(
  path : String,
  name : String,
  frame : Map[String, Json],
  index : Int,
) -> TextureAtlasRegion raise TextureAtlasError {
  guard rect_document(field_object(frame, "frame")) is Some(rect) else {
    raise InvalidDocument(path, "frame " + name + " requires frame rectangle")
  }
  let source_size = vec2_document(
    field_object(frame, "sourceSize"),
    "w",
    "h",
    rect.size,
  )
  let source_rect = field_object(frame, "spriteSourceSize")
  let trim_offset = vec2_document(source_rect, "x", "y", @math.Vec2::zero())
  {
    name,
    index,
    rect,
    source_size,
    trim_offset,
    rotated: field_bool(frame, "rotated").unwrap_or(false),
  }
}

///|
fn parse_external_regions(
  path : String,
  root : Map[String, Json],
) -> (String, @math.Vec2, Array[TextureAtlasRegion]) raise TextureAtlasError {
  guard field_object(root, "meta") is Some(meta) &&
    field_string(meta, "image") is Some(image_path) else {
    raise InvalidDocument(
      path, "Aseprite/TexturePacker atlas requires meta.image",
    )
  }
  let regions : Array[TextureAtlasRegion] = []
  match root.get("frames") {
    Some(Object(frames)) => {
      let names = frames.keys().collect()
      names.sort()
      for name in names {
        guard json_object(frames[name]) is Some(frame) else {
          raise InvalidDocument(path, "frame " + name + " must be an object")
        }
        regions.push(parse_external_frame(path, name, frame, regions.length()))
      }
    }
    Some(Array(frames)) =>
      for frame_json in frames {
        guard json_object(frame_json) is Some(frame) &&
          field_string(frame, "filename") is Some(name) else {
          raise InvalidDocument(path, "array frame requires filename")
        }
        regions.push(parse_external_frame(path, name, frame, regions.length()))
      }
    _ => raise InvalidDocument(path, "atlas requires frames object or array")
  }
  let mut atlas_size = vec2_document(
    field_object(meta, "size"),
    "w",
    "h",
    @math.Vec2::zero(),
  )
  for region in regions {
    atlas_size = @math.Vec2(
      atlas_size[X].max(region.rect.position[X] + region.rect.size[X]),
      atlas_size[Y].max(region.rect.position[Y] + region.rect.size[Y]),
    )
  }
  (resolve_relative_path(path, image_path), atlas_size, regions)
}

///|
pub fn load_texture_atlas(
  path : String,
) -> TextureAtlasAsset raise TextureAtlasError {
  if texture_atlas_assets.get(path) is Some(asset) {
    return asset
  }
  guard @asset.read_bytes(path) is Some(bytes) else {
    raise MissingDocument(path)
  }
  let text = @utf8.decode(bytes) catch { _ => raise InvalidUtf8(path) }
  let json = @json.parse(text) catch {
    error => raise InvalidJson(path, error.to_string())
  }
  guard json_object(json) is Some(root) else {
    raise InvalidDocument(path, "root must be an object")
  }
  let canonical = field_string(root, "schema") ==
    Some("selene/atlas_asset_document") ||
    field_string(root, "source_image") is Some(_)
  let (image_path, size, regions) = if canonical {
    parse_canonical_regions(path, root)
  } else {
    parse_external_regions(path, root)
  }
  if regions.length() == 0 {
    raise InvalidDocument(path, "atlas requires at least one region")
  }
  let max_index = regions.fold(init=-1, fn(value, region) {
    value.max(region.index)
  })
  let empty_rect : @math.Rect = {
    position: @math.Vec2::zero(),
    size: @math.Vec2::zero(),
  }
  let rects = Array::make(max_index + 1, empty_rect)
  for region in regions {
    if region.index < 0 {
      raise InvalidDocument(path, "region index must be non-negative")
    }
    rects[region.index] = region.rect
  }
  let asset = {
    image: @asset.load_image(image_path),
    image_path,
    layout: @sprite.register_texture_atlas_layout(
      @sprite.TextureAtlasLayout(size, rects),
    ),
    regions,
  }
  texture_atlas_assets[path] = asset
  asset
}

///|
pub fn TextureAtlasAsset::region(
  self : TextureAtlasAsset,
  name : String,
) -> TextureAtlasRegion? {
  for region in self.regions {
    if region.name == name {
      return Some(region)
    }
  }
  None
}

///|
pub fn resolve_texture_atlas_region(
  value : String,
) -> AtlasImage raise TextureAtlasError {
  let asset_path = @asset.AssetPath::parse(value)
  guard asset_path.label is Some(label) else { raise MissingLabel(value) }
  let atlas = load_texture_atlas(asset_path.path)
  guard atlas.region(label) is Some(region) else {
    raise MissingRegion(asset_path.path, label)
  }
  if region.rotated {
    raise RotatedRegion(asset_path.path, label)
  }
  {
    image: atlas.image,
    source: { position: region.rect.position, size: region.rect.size },
  }
}

///|
pub fn clear_texture_atlas_cache() -> Unit {
  for _, asset in texture_atlas_assets {
    @sprite.release_texture_atlas_layout(asset.layout)
  }
  texture_atlas_assets.clear()
}
