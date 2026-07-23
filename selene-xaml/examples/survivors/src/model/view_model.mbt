///|
pub fn SurvivorsUiState::level_label(self : SurvivorsUiState) -> String {
  "Level: " + self.level.to_string()
}

///|
pub fn SurvivorsUiState::experience_label(self : SurvivorsUiState) -> String {
  "EXP: " + self.experience.to_string() + "/" + self.experience_goal.to_string()
}

///|
pub fn SurvivorsUiState::wave_label(self : SurvivorsUiState) -> String {
  "Wave: " + self.wave.to_string()
}

///|
pub fn SurvivorsUiState::score_label(self : SurvivorsUiState) -> String {
  "Score: " + self.score.to_string()
}

///|
pub fn SurvivorsUiState::timer_label(self : SurvivorsUiState) -> String {
  "Time: " +
  (self.remaining_seconds / 60).to_string() +
  ":" +
  (self.remaining_seconds % 60).to_string().pad_start(2, '0')
}

///|
pub fn SurvivorsUiState::game_over_title(self : SurvivorsUiState) -> String {
  if self.victory {
    "VICTORY!"
  } else {
    "GAME OVER"
  }
}

///|
pub fn SurvivorsUiState::final_score_label(self : SurvivorsUiState) -> String {
  "Final Score: " + self.score.to_string()
}
