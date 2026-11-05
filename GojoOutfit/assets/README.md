# Gojo Outfit textures

By default textures are built at runtime from `Characters/Satoru` (the `[CP] Satoru Gojo NPC` spritesheet):

| Item   | Source |
|--------|--------|
| Hair   | Top `HairRows` rows of each facing frame, skin pixels removed (hair + blindfold kept). |
| Hair kit icon | Top 16x16 of the down-facing frame. |
| Shirt  | 8x8 torso crop at `x 4-11, y ShirtTop` for each facing. |
| Pants  | Vanilla pants block tinted with the average NPC leg color. |
| Boots  | Shoe palette sampled from the NPC feet; icon is vanilla Dark Boots. |

Tune `HairRows`, `HairOffsetY`, `ShirtTop` in `config.json` if the crop looks off.

Optional overrides: drop a PNG here with the exact name and it wins over the generated texture.

| File              | Size     | Layout |
|-------------------|----------|--------|
| `hair.png`        | 16x128   | Rows of 16x32: down, right, up, left. Game tints by hair color (set to white on use). |
| `hair_item.png`   | 16x16    | Inventory icon for the hair kit. |
| `shirt.png`       | 256x32   | x 0-7: 8x8 per facing, down/right/left/up stacked. x 128-135: dye mask, leave transparent. |
| `pants.png`       | 192x688  | Same layout as one pants block in `Characters/Farmer/pants.png`. |
| `boots.png`       | 16x16    | Inventory icon. |
| `boots_color.png` | 4x1      | 4 shoe colors, dark to light. |
