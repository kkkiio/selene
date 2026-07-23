///|
#cfg(target="js")
extern "js" fn browser_bridge_apply(entity : UInt, payload : String) -> String =
  #| (entity, payload) => globalThis.__seleneUiComponentHost.apply(entity, payload)

///|
#cfg(target="js")
extern "js" fn browser_bridge_release(entity : UInt) -> Unit =
  #| (entity) => globalThis.__seleneUiComponentHost.release(entity)

///|
#cfg(target="js")
test "CH-BROWSER-01 bridge commits batches and isolates Entity IDs by World" {
  with_component_host_world(fn() raise {
    @component_host.install_browser_host()
    let owner_world = @ecs.require_current_world()
    let root = @entity.Entity()
    @ui.nodes()[root] = @ui.Node()
    let entity_id = @component_host.register_browser_entity(root)
    let null_mount =
      #|[{"tag":"mount","key":"","text_value":"","bool_value":false,"number_value":0,"parent":"","index":0,"spec":null}]
    let null_update =
      #|[{"tag":"update","key":"","text_value":"","bool_value":false,"number_value":0,"parent":"","index":0,"spec":null}]
    debug_inspect(
      (
        browser_bridge_apply(entity_id, null_mount),
        browser_bridge_apply(entity_id, null_update),
      ),
      content=(
        #|(
        #|  "SH3004: browser mount mutation requires spec",
        #|  "SH3004: browser update mutation requires spec",
        #|)
      ),
    )
    let payload : Json = [
      {
        "tag": "mount",
        "key": "",
        "text_value": "",
        "bool_value": false,
        "number_value": 0,
        "parent": "",
        "index": 0,
        "spec": {
          "key": "title",
          "parent": "",
          "kind": "text",
          "text": "Browser component",
          "source": "",
          "active": true,
          "enabled": true,
          "focusable": false,
          "style": {
            "absolute": true,
            "left": 12,
            "top": 18,
            "width_kind": "percent",
            "width_value": 0.5,
            "height_kind": "px",
            "height_value": 32,
            "margin_left": 0,
            "margin_top": 0,
            "margin_right": 0,
            "margin_bottom": 0,
            "padding_left": 5,
            "padding_top": 6,
            "padding_right": 7,
            "padding_bottom": 8,
            "background": "",
            "border_color": "",
            "outline_color": "",
            "outline_width": 0,
            "outline_offset": 0,
            "border": 0,
            "radius": 0,
            "color": "white",
            "font_family": "ThaleahFat",
            "font_size": 24,
            "bold": false,
            "align": "center",
            "wrap": false,
            "z_index": 10,
            "fit": "fill",
            "direction": "column",
            "flex_basis_kind": "auto",
            "flex_basis_value": 0,
            "flex_grow": 1,
            "flex_shrink": 0,
            "row_gap": 0,
            "column_gap": 0,
            "horizontal_scroll": false,
            "vertical_scroll": false,
            "scrollbar_width": 0,
          },
          "visual_state_groups": [],
        },
      },
    ]
    inspect(browser_bridge_apply(entity_id, payload.stringify()), content="")
    let other_world = @ecs.World()
    @ecs.set_current_world(other_world)
    browser_bridge_release(entity_id)
    let other_root = @entity.Entity()
    @ui.nodes()[other_root] = @ui.Node()
    let other_id = @component_host.register_browser_entity(other_root)
    debug_inspect((other_root.is_alive(), other_id), content="(true, 0)")
    browser_bridge_release(other_id)
    @ecs.set_current_world(owner_world)
    let host = @component_host.SeleneHost::new()
    let title = host.entity(root, "title").unwrap()
    inspect(@ui.texts()[title].content, content="Browser component")
    inspect(@ui.nodes()[title].left == @ui.Val::Px(12.0), content="true")
    debug_inspect(
      (
        @ui.nodes()[title].width,
        @ui.nodes()[title].height,
        @ui.nodes()[title].flex_grow,
        @ui.nodes()[title].flex_shrink,
      ),
      content="(Percent(0.5), Px(32), 1, 0)",
    )
    inspect(
      @ui.nodes()[title].padding ==
      @ui.UiRectValues::px(left=5.0, top=6.0, right=7.0, bottom=8.0),
      content="true",
    )
    inspect(@ui.text_fonts()[title].family, content="ThaleahFat")
    let update_payload : Json = [
      {
        "tag": "update",
        "key": "",
        "text_value": "",
        "bool_value": false,
        "number_value": 0,
        "parent": "",
        "index": 0,
        "spec": {
          "key": "title",
          "parent": "",
          "kind": "text",
          "text": "Updated component",
          "source": "",
          "active": true,
          "enabled": true,
          "focusable": true,
          "style": {
            "absolute": true,
            "left": 12,
            "top": 20,
            "width_kind": "percent",
            "width_value": 0.5,
            "height_kind": "px",
            "height_value": 32,
            "margin_left": 0,
            "margin_top": 0,
            "margin_right": 0,
            "margin_bottom": 0,
            "padding_left": 5,
            "padding_top": 6,
            "padding_right": 7,
            "padding_bottom": 8,
            "background": "",
            "border_color": "",
            "outline_color": "",
            "outline_width": 0,
            "outline_offset": 0,
            "border": 0,
            "radius": 0,
            "color": "white",
            "font_family": "ThaleahFat",
            "font_size": 24,
            "bold": true,
            "align": "center",
            "wrap": true,
            "z_index": 10,
            "fit": "fill",
            "direction": "column",
            "flex_basis_kind": "auto",
            "flex_basis_value": 0,
            "flex_grow": 1,
            "flex_shrink": 0,
            "row_gap": 0,
            "column_gap": 0,
            "horizontal_scroll": false,
            "vertical_scroll": false,
            "scrollbar_width": 0,
          },
          "visual_state_groups": [],
        },
      },
    ]
    inspect(
      browser_bridge_apply(entity_id, update_payload.stringify()),
      content="",
    )
    inspect(host.entity(root, "title") == Some(title), content="true")
    inspect(@ui.texts()[title].content, content="Updated component")
    inspect(@ui.text_layouts()[title].wrap == @ui.WordWrap, content="true")
    inspect(@ui.focusables().contains(title), content="true")
    browser_bridge_release(entity_id)
    try host.entity(root, "title") catch {
      @ui_host.HostError::Released => ()
      error => raise error
    } noraise {
      _ => fail("the owner World must be able to release its retained handle")
    }
  })
}
