///|
pub fn generate_embedded_view_package(
  source_uri : String,
  source : String,
  contract_uri : String,
  contract_source : String,
) -> @generator_io.GeneratedPackage raise {
  let ir = @viewir.compile(source_uri, source, contract_source)
  @embedded_emitter.emit(ir, source_uri, source, contract_uri, contract_source)
}

///|
pub fn generate_component_guest_package(
  source_uri : String,
  source : String,
  contract_uri : String,
  contract_source : String,
) -> @generator_io.GeneratedPackage raise {
  let (ir, resolved) = @viewir.compile_wit(
    source_uri, source, contract_uri, contract_source,
  )
  let target : @component_emitter.ComponentGuestTarget = {
    event_type: resolved.event_type,
    action_type: resolved.action_type,
    tree_package: resolved.tree_package,
  }
  @component_emitter.emit(
    ir, target, source_uri, source, contract_uri, contract_source,
  )
}
