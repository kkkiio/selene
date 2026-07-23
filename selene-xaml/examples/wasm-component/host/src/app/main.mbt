///|
extern "js" fn publish_component_entity(entity : UInt) -> Unit =
  #| (entity) => {
  #|   globalThis.__seleneWasmExample = {
  #|     ...(globalThis.__seleneWasmExample || {}),
  #|     entity,
  #|   };
  #| }

///|
fn main {
  let world = @ecs.World()
  @ecs.set_current_world(world)
  let host = @entity.Entity()
  @ui.nodes()[host] = @ui.Node(
    width=@ui.Val::Percent(100.0),
    height=@ui.Val::Percent(100.0),
  )
  @component_host.install_browser_host()
  publish_component_entity(@component_host.register_browser_entity(host))
  @selene_app.App()
  .with_world(world)
  .with_viewport_width(960.0)
  .with_viewport_height(540.0)
  .with_image_smooth(false)
  .add_plugin(@plugins.default_plugin)
  .add_plugin(@component_host.plugin)
  .run()
}
