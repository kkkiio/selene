///|
fn atlas_test_png(width : UInt, height : UInt) -> Bytes {
  let buffer = @buffer.Buffer()
  buffer.write_bytes(b"\x89PNG\r\n\x1a\n")
  buffer.write_uint_be(13U)
  buffer.write_bytes(b"IHDR")
  buffer.write_uint_be(width)
  buffer.write_uint_be(height)
  buffer.contents()
}

///|
test "asset path separates an atlas label" {
  debug_inspect(
    @asset.AssetPath::parse("assets/ui/inventory.atlas.json#equip.selected"),
    content=(
      #|{
      #|  path: "assets/ui/inventory.atlas.json",
      #|  label: Some("equip.selected"),
      #|}
    ),
  )
}

///|
test "loads canonical atlas and resolves a named image region" {
  clear_texture_atlas_cache()
  @asset.set_io(fn(path) {
    match path {
      "assets/ui/inventory.atlas.json" =>
        Some(
          @utf8.encode(
            (
              #|{"schema":"selene/atlas_asset_document","version":1,"data":{
              #|  "version":4,"name":"inventory","source_image":"inventory.png",
              #|  "tile_size":{"x":24,"y":24},"columns":2,"rows":1,
              #|  "spacing":{"x":0,"y":0},"margin":{"x":0,"y":0},
              #|  "default_anchor":{"x":0.5,"y":0.5},
              #|  "regions":[
              #|    {"name":"equip.normal","index":0,"rect":{"x":0,"y":0,"width":24,"height":24}},
              #|    {"name":"equip.selected","index":1,"rect":{"x":24,"y":0,"width":24,"height":24}}
              #|  ]}}
            ),
          ),
        )
      "assets/ui/inventory.png" => Some(atlas_test_png(48U, 24U))
      _ => None
    }
  })
  let resolved = resolve_texture_atlas_region(
    "assets/ui/inventory.atlas.json#equip.selected",
  )
  debug_inspect(
    (resolved.image, resolved.source.position, resolved.source.size),
    content=(
      #|(ImageHandle(0), Vec2(24, 0), Vec2(24, 24))
    ),
  )
}

///|
test "loads Aseprite and TexturePacker frame metadata" {
  clear_texture_atlas_cache()
  @asset.set_io(fn(path) {
    match path {
      "assets/ui/tabs.json" =>
        Some(
          @utf8.encode(
            (
              #|{"frames":{"use.selected":{
              #|  "frame":{"x":32,"y":0,"w":16,"h":20},
              #|  "rotated":false,"trimmed":true,
              #|  "spriteSourceSize":{"x":3,"y":2,"w":16,"h":20},
              #|  "sourceSize":{"w":24,"h":24}}},
              #|  "meta":{"image":"tabs.png","size":{"w":64,"h":32}}}
            ),
          ),
        )
      "assets/ui/tabs.png" => Some(atlas_test_png(64U, 32U))
      _ => None
    }
  })
  let atlas = load_texture_atlas("assets/ui/tabs.json")
  debug_inspect(
    atlas.regions.map(region => {
      (
        region.name,
        region.index,
        region.rect.position,
        region.rect.size,
        region.source_size,
        region.trim_offset,
        region.rotated,
      )
    }),
    content=(
      #|[
      #|  (
      #|    "use.selected",
      #|    0,
      #|    Vec2(32, 0),
      #|    Vec2(16, 20),
      #|    Vec2(24, 24),
      #|    Vec2(3, 2),
      #|    false,
      #|  ),
      #|]
    ),
  )
}
