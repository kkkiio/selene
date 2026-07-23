///|
async test "EE-01 snapshots the formatted Embedded package" (t : @test.Test) {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"
    #| xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/model"
    #| x:Class="DemoView" ui:DataType="model:DemoState" x:Name="root">
    #| <ui:Text Text="{ui:Binding Path=title}" />
    #|</ui:View>
  let contract =
    #|package "example/demo/model"
    #|pub(all) struct DemoState { title : String }
  let ir = @viewir.compile("fixtures/demo.xaml", xaml, contract)
  let generated = @embedded_emitter.format_generated_package(
    @embedded_emitter.emit(
      ir, "fixtures/demo.xaml", xaml, "fixtures/model.mbti", contract,
    ),
  )
  let view = generated.files[2].content
  assert_eq(generated.files.map(file => file.path), [
    "moon.pkg", "state.generated.mbt", "view.generated.mbt", "view.generated.mbt.map.json",
    "selene-xaml.lock.json",
  ])
  assert_eq(view.contains("pub struct DemoView {}"), true)
  assert_eq(view.contains("pub fn DemoView::mount("), true)
  assert_eq(view.contains("entity : @entity.Entity"), true)
  assert_eq(view.contains(") -> Unit raise DemoViewError"), true)
  assert_eq(view.contains("generated_view_records[entity]"), true)
  assert_eq(view.contains("pub let action_event_bus"), true)
  assert_eq(view.contains("pub fn plugin(app : @app.App)"), true)
  assert_eq(view.contains("pub fn DemoView::handle_event"), false)
  assert_eq(view.contains("@ui_view.ViewHost::new()"), true)
  for file in generated.files {
    let header =
      $|===== \{file.path} =====
    t.writeln(header)
    t.write(file.content)
    if !file.content.has_suffix("\n") {
      t.writeln("")
    }
    t.writeln("")
  }
  t.snapshot(filename="canonical_embedded_package.txt")
}
