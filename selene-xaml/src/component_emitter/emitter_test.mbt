///|
async test "CE-01 snapshots the formatted Component Guest package" (
  t : @test.Test,
) {
  let xaml =
    #|<ui:View xmlns:ui="urn:selene:xaml:ui"
    #| xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    #| xmlns:model="moonbit:example/demo/component"
    #| x:Class="DemoView" ui:DataType="model:DemoModel" x:Name="root">
    #| <ui:Button x:Name="submit" OnClick="submit">
    #|  <ui:Text Text="Submit" />
    #| </ui:Button>
    #|</ui:View>
  let contract =
    #|package example:demo@0.1.0;
    #|interface demo-ui-api {
    #|  record demo-model { title: string }
    #|  variant ui-event { click(string) }
    #|  variant demo-view-action { submit }
    #|  mount: func(entity: u32, model: demo-model);
    #|  replace: func(entity: u32, model: demo-model);
    #|  handle-event: func(entity: u32, event: ui-event) -> option<demo-view-action>;
    #|  update: func();
    #|  unmount: func(entity: u32);
    #|}
    #|world demo-ui {
    #|  import selene:ui-host/tree@0.1.0;
    #|  export demo-ui-api;
    #|}
  let (ir, resolved) = @viewir.compile_wit(
    "fixtures/demo.xaml", xaml, "fixtures/demo.wit", contract,
  )
  let target : @component_emitter.ComponentGuestTarget = {
    event_type: resolved.event_type,
    action_type: resolved.action_type,
    tree_package: resolved.tree_package,
  }
  let generated = @generator_io.format_generated_package(
    @component_emitter.emit(
      ir, target, "fixtures/demo.xaml", xaml, "fixtures/demo.wit", contract,
    ),
  )
  let guest = generated.files[0].content
  assert_eq(generated.files.map(file => file.path), [
    "guest.generated.mbt", "guest.generated.mbt.map.json", "selene-xaml.lock.json",
  ])
  assert_eq(
    guest.contains("pub fn mount(entity : UInt, model : DemoModel) -> Unit"),
    true,
  )
  assert_eq(guest.contains("match @tree.apply(entity, initial)"), true)
  assert_eq(guest.contains("pub fn handle_event"), true)
  assert_eq(guest.contains("pub fn update() -> Unit"), true)
  assert_eq(guest.contains("pub fn unmount(entity : UInt) -> Unit"), true)
  assert_eq(guest.contains("@entity"), false)
  assert_eq(guest.contains("EventBus"), false)
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
  t.snapshot(filename="canonical_component_package.txt")
}
