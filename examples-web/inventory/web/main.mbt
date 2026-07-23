///|
extern "js" fn browser_viewport_width() -> Double =
  #| () => Number(globalThis.__seleneExampleViewportWidth ?? 960)

///|
extern "js" fn mark_inventory_mounted() -> Unit =
  #| () => { globalThis.__seleneInventoryExample = { mounted: true }; }

///|
fn main {
  @inventory.run(browser_viewport_width(), mark_inventory_mounted)
}
