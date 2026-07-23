# Inventory artwork

The inventory example uses a curated subset of **496 pixel art icons for
medieval/fantasy RPG** by Henrique Lazarini (7Soul1), distributed under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

Source: <https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg>

The original 34 × 34 PNG files contain a one-pixel transparent border. The
checked-in files crop that border and scale the remaining 32 × 32 artwork to
64 × 64 with nearest-neighbor sampling. Filenames were changed to match the
example's game-owned item data.

`ui/inventory-tabs.png` is a derived six-region spritesheet assembled from the
Sunblade, Crimson Tonic, and Ancient Map icons. The adjacent canonical Selene
atlas manifest names each normal/selected region so XAML can use
`inventory-tabs.atlas.json#region`.

| Checked-in file | Original file |
| --- | --- |
| `icons/ancient-map.png` | `I_Map.png` |
| `icons/brass-key.png` | `I_Key04.png` |
| `icons/ember-torch.png` | `I_Torch02.png` |
| `icons/crimson-tonic.png` | `P_Red04.png` |
| `icons/sun-coin.png` | `I_GoldCoin.png` |
| `icons/ruby.png` | `I_Ruby.png` |
| `icons/sunblade.png` | `W_Gold_Sword.png` |
| `icons/ember-mail.png` | `A_Armor05.png` |
