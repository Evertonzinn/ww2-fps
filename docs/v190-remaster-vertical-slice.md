# WW2 FPS v0.19 — First remaster vertical slice (actual Godot code)

Base: `main` @ `d7906e1688fb2045255d4771554cf20f43351514`. Feature branch `feature/v190-remaster-world-sniper`.
This changes executable game files, not a screenshot or image generation.

## What is implemented

- `world_props.gd` invokes `environment/remaster_pass.gd` after
  the legacy village. 1152 rounded instanced 3D road setts,
  alpha-scissored vegetation in 2 trees, 1040 instanced grasses,
  192 hedge cross-plane sprites and 180 roadside stones.
  No new physics obstacles or collision-layer changes.
- Optional 1K real CC0 photo-scanned PBR textures for cobblestone,
  stone wall, roof and plaster via conventional path
  `res://assets/environment/remaster/textures/...`.
  Missing materials gracefully leave original game playable.
- Color-grading approximation via daylight/ambient adjustments that
  work under OpenGL Compatibility (no mandatory SSAO, GI or RT).
- Gameplay: `enemy_hit_zone.gd` has **dedicated**
  `take_sniper_damage` per anatomical zone; sniper `_fire` invokes
  this if available. A chest hit deals 120, killing a full 100HP
  regular enemy; limb hits are NOT automatic one-shot. Original
  Lee-Enfield regional damage, reload, zoom, scope and shooting
  state remain untouched.
- `tests/v190_remaster_smoke.gd` checks real scene tree
  instancing, lack of weapon hierarchy regression, sniper chest lethal
  and unchanged Lee damage receiver. Run it on user's Debian.

## Why this is NOT yet a photoreal AAA remaster

The source village has four BoxMesh placeholder buildings and the
first-person rigged BAMEN arms were previously visually misaligned.
They need proper high-resolution 3D meshes, British sleeves and
artist-calibrated weapon grips, not fake primitive replacement.
This release is a real first visual/gameplay step, NOT a claim of
photorealistic completion.

## Verified CC0 asset sources for next art import

- Poly Haven Cobblestone 01:
  https://polyhaven.com/a/cobblestone_01
- Poly Haven stone and plaster:
  https://polyhaven.com/textures
- Quaternius Medieval Village MegaKit (CC0):
  https://quaternius.com/packs/medievalvillagemegakit.html
  Free Standard includes ~176 modular models, compatible FBX/OBJ/glTF,
  but medieval/fantasy motifs must be adapted to WWII France.
- Quaternius Nature:
  https://quaternius.com/packs/ultimatestylizednature.html
  Free CC0, but stylized and will not satisfy a photoreal target alone.

Do NOT add third-party arm/weapon textures to public repository
unless license rights are confirmed. Use 1K albedo/normal/roughness
for GT 730, check memory and FPS before 2K.

## Install PBR files (optional)

Copy your licensed texture maps into:
`assets/environment/remaster/textures/`

Supported filenames:
`cobblestone_albedo.jpg, cobblestone_normal.jpg,
cobblestone_roughness.jpg`,
`stone_wall_albedo.jpg` etc, plus `plaster_` and `roof_tiles_`.
All maps must be UV tileable, roughness/normal should be linear.

## Test

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v190-remaster-world-sniper
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v190_remaster_smoke.gd
```

Then F5: shoot enemy in chest with sniper from full HP,
compare Lee chest damage, inspect cobbles/hedges/tree silhouettes
and hold FPS frame rate. The generated grass uses cutout alpha
to avoid blended overdraw and batching to reduce draw calls.
Tests were NOT run on author's machine (Godot unavailable).
Keep PR draft until user's actual smoke and visuals.
