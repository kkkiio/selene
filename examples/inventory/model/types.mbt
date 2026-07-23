///|
pub(all) struct InventoryTab {
  id : String
  icon : String
  selected_icon : String
  selected : Bool
  layout_width : Double
} derive(Eq, Debug)

///|
pub(all) struct InventoryItem {
  id : String
  category : String
  name : String
  image : String
  count : Int
  rarity : String
  description : String
  selected : Bool
  layout_width : Double
} derive(Eq, Debug)

///|
pub(all) struct EquipmentItem {
  slot : String
  name : String
  image : String
  selected : Bool
  layout_width : Double
} derive(Eq, Debug)

///|
pub(all) struct InventoryUiState {
  viewport_width : Double
  capacity : Int
  tabs : Array[InventoryTab]
  all_items : Array[InventoryItem]
  items : Array[InventoryItem]
  equipment : Array[EquipmentItem]
  selected_tab_id : String
  selected_item_id : String
} derive(Eq, Debug)

///|
pub(all) enum InventoryUiPatch {
  ItemsReplace(Array[InventoryItem])
  ItemUpsert(InventoryItem)
  ItemRemove(String)
  ItemMove((String, UInt))
} derive(Eq, Debug)
