///|
test "CE-COMPILE-01 generated Component Guest record compiles and routes Action" {
  mount(7U, { title: "Demo" })
  debug_inspect(handle_event(7U, Click("submit")), content="Some(Submit)")
  replace(7U, { title: "Updated" })
  update()
  unmount(7U)
}
