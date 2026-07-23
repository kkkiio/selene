///|
pub(all) struct Selection {
  key : String
  label : String
  icon : String
  background : String
} derive(Eq, Debug)

///|
pub(all) struct SurvivorsUiState {
  score : UInt
  remaining_seconds : UInt
  wave : UInt
  level : UInt
  experience : UInt
  experience_goal : UInt
  level_up_visible : Bool
  game_over_visible : Bool
  victory : Bool
  selections : Array[Selection]
} derive(Eq, Debug)

///|
pub(all) enum SurvivorsUiPatch {
  SelectionsReplace(Array[Selection])
  SelectionUpsert(Selection)
  SelectionRemove(String)
  SelectionMove((String, UInt))
} derive(Eq, Debug)
