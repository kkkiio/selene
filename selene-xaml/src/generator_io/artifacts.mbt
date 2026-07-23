///|
pub(all) struct GeneratedFile {
  path : String
  content : String
} derive(Eq, Debug)

///|
pub(all) struct GeneratedPackage {
  files : Array[GeneratedFile]
} derive(Eq, Debug)
