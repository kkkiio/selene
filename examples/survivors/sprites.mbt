// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
let player_idle_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/whiteboy/idle.png",
    4,
    width=PLAYER_SIZE,
    height=PLAYER_SIZE,
    offset=Vec2D(32.0, 32.0),
    space_x=64.0,
  ),
  fps=12,
  loop_=true,
)

///|
let player_idle_up_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/whiteboy/idle.png",
    4,
    width=PLAYER_SIZE,
    height=PLAYER_SIZE,
    offset=Vec2D(32.0, 32.0 + 160.0),
    space_x=64.0,
  ),
  fps=12,
  loop_=true,
)

///|
let player_idle_down_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/whiteboy/idle.png",
    4,
    width=PLAYER_SIZE,
    height=PLAYER_SIZE,
    offset=Vec2D(32.0, 32.0 + 80.0),
    space_x=64.0,
  ),
  fps=12,
  loop_=true,
)

///|
let player_run_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/whiteboy/run.png",
    8,
    width=PLAYER_SIZE,
    height=PLAYER_SIZE,
    offset=Vec2D(32.0, 32.0),
    space_x=64.0,
  ),
  fps=12,
  loop_=true,
)

///|
let player_run_down_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/whiteboy/run.png",
    8,
    width=PLAYER_SIZE,
    height=PLAYER_SIZE,
    offset=Vec2D(32.0, 32.0 + 80.0),
    space_x=64.0,
  ),
  fps=12,
  loop_=true,
)

///|
let player_run_up_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/whiteboy/run.png",
    8,
    width=PLAYER_SIZE,
    height=PLAYER_SIZE,
    offset=Vec2D(32.0, 32.0 + 160.0),
    space_x=64.0,
  ),
  fps=12,
  loop_=true,
)

///|
let grass_sprite : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/tilesets/decor_16x16.png",
    1,
    width=16,
    height=16,
    offset=Vec2D(0, 0),
  ),
)

///|
let background_picture = "assets/tilesets/grass.png"

///|
let creeper_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/enemy/Creeper.png",
    4,
    width=16,
    height=24,
    offset=Vec2D(0, 48),
    space_x=0,
  ),
  fps=12,
  loop_=true,
)

///|
let icecream_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/enemy/Icecream.png",
    4,
    width=16,
    height=24,
    offset=Vec2D(0, 48),
    space_x=0,
  ),
  fps=12,
  loop_=true,
)

///|
let orc_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/enemy/Orc.png",
    4,
    width=16,
    height=24,
    offset=Vec2D(0, 48),
    space_x=0,
  ),
  fps=12,
  loop_=true,
)

///|
let skull_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/enemy/Skull.png",
    4,
    width=16,
    height=24,
    offset=Vec2D(0, 48),
    space_x=0,
  ),
  fps=12,
  loop_=true,
)

///|
let devil_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/enemy/Devil.png",
    4,
    width=16,
    height=24,
    offset=Vec2D(0, 48),
    space_x=0,
  ),
  fps=12,
  loop_=true,
)

///|
let pirate_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/enemy/Pirate.png",
    4,
    width=16,
    height=24,
    offset=Vec2D(0, 48),
    space_x=0,
  ),
  fps=12,
  loop_=true,
)

///|
let teleman_right_animation : @sprite.Animation = @sprite.Animation::new(
  @sprite.frames_from_atlas(
    "assets/enemy/Teleman.png",
    4,
    width=16,
    height=24,
    offset=Vec2D(0, 0),
    space_x=0,
  ),
  fps=12,
  loop_=true,
)

///|
let powerup_range_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 6, 32 * 6),
)

///|
let powerup_attack_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 12, 32 * 4),
)

///|
let powerup_speed_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 2, 32 * 5),
)

///|
let powerup_cooldown_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 3, 32 * 5),
)

///|
let powerup_bandana_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 6, 32 * 9),
)

///|
let weapon_pistol_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 8, 32 * 6),
)

///|
let weapon_minigun_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 1, 32 * 7),
)

///|
let weapon_sniperrifle_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 4, 32 * 7),
)

///|
let weapon_sword_icon : @sprite.Animation = @sprite.Animation::single_frame(
  "assets/icon/icon.png",
  Vec2D(32, 32),
  offset=Vec2D(32 * 1, 32 * 6),
)
