///|
pub fn InventoryUiState::capacity_label(self : InventoryUiState) -> String {
  self.items.length().to_string() + " / " + self.capacity.to_string()
}

///|
pub fn InventoryUiState::wide_layout(self : InventoryUiState) -> Bool {
  self.viewport_width >= 900.0
}

///|
pub fn InventoryUiState::content_width(self : InventoryUiState) -> Double {
  let available = self.viewport_width - 40.0
  if available < 0.0 {
    0.0
  } else if available > 920.0 {
    920.0
  } else {
    available
  }
}

///|
pub fn InventoryUiState::narrow_content_width(
  self : InventoryUiState,
) -> Double {
  self.content_width() - 28.0
}

///|
pub fn InventoryUiState::narrow_label_width(self : InventoryUiState) -> Double {
  self.content_width() - 60.0
}

///|

///|
pub fn InventoryTab::tab_width(self : InventoryTab) -> Double {
  self.layout_width
}

///|
pub fn InventoryTab::tab_icon_left(self : InventoryTab) -> Double {
  (self.layout_width - 40.0) / 2.0
}

///|
pub fn InventoryItem::item_background(self : InventoryItem) -> String {
  if self.selected {
    "#59402d"
  } else {
    "#34231a"
  }
}

///|
pub fn InventoryItem::narrow_content_width(self : InventoryItem) -> Double {
  self.layout_width
}

///|
pub fn InventoryItem::narrow_label_width(self : InventoryItem) -> Double {
  self.layout_width - 86.0
}

///|
pub fn EquipmentItem::equipment_background(self : EquipmentItem) -> String {
  if self.selected {
    "#59402d"
  } else {
    "#3a281f"
  }
}

///|
pub fn EquipmentItem::narrow_content_width(self : EquipmentItem) -> Double {
  self.layout_width
}

///|
pub fn EquipmentItem::narrow_label_width(self : EquipmentItem) -> Double {
  self.layout_width - 82.0
}

///|
pub fn InventoryItem::count_label(self : InventoryItem) -> String {
  self.count.to_string()
}

///|
pub fn InventoryUiState::selected_image(self : InventoryUiState) -> String {
  for item in self.items {
    if item.id == self.selected_item_id {
      return item.image
    }
  }
  ""
}

///|
pub fn InventoryUiState::selected_name(self : InventoryUiState) -> String {
  for item in self.items {
    if item.id == self.selected_item_id {
      return item.name
    }
  }
  "Unknown relic"
}

///|
pub fn InventoryUiState::selected_rarity(self : InventoryUiState) -> String {
  for item in self.items {
    if item.id == self.selected_item_id {
      return item.rarity
    }
  }
  "UNCATALOGUED"
}

///|
pub fn InventoryUiState::selected_description(
  self : InventoryUiState,
) -> String {
  for item in self.items {
    if item.id == self.selected_item_id {
      return item.description
    }
  }
  "No field notes are available for this relic."
}
