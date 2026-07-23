///|
pub(all) struct DemoModel {
  title : String
} derive(Eq, Debug)

///|
pub(all) enum UiEvent {
  Click(String)
} derive(Eq, Debug)

///|
pub(all) enum DemoAction {
  Submit
} derive(Eq, Debug)

///|
