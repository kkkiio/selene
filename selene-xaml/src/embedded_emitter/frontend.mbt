///|
pub fn generate_embedded_view_package(
  source_uri : String,
  source : String,
  contract_uri : String,
  contract_source : String,
) -> GeneratedPackage raise {
  generate_embedded_view_package_with_resources(
    source_uri,
    source,
    contract_uri,
    contract_source,
    [],
  )
}

///|
pub fn generate_embedded_view_package_with_resources(
  source_uri : String,
  source : String,
  contract_uri : String,
  contract_source : String,
  resources : Array[@viewir.ResourceDocument],
) -> GeneratedPackage raise {
  let ir = @viewir.compile_with_resources(
    source_uri, source, contract_source, resources,
  )
  emit_with_resources(
    ir, source_uri, source, contract_uri, contract_source, resources,
  )
}
