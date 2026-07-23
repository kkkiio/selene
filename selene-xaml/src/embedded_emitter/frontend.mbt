///|
pub fn generate_embedded_view_package(
  source_uri : String,
  source : String,
  contract_uri : String,
  contract_source : String,
) -> GeneratedPackage raise {
  let ir = @viewir.compile(source_uri, source, contract_source)
  emit(ir, source_uri, source, contract_uri, contract_source)
}
