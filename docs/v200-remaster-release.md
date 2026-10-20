# WW2 FPS — v0.20 remaster hardening / playable vertical slice

Base: `main` @ `d7906e1688fb2045255d4771554cf20f43351514`.
This branch inherits v0.19 environment and sniper torso work from
`feature/v190-remaster-world-sniper`; it does **not** replace those changes.

## Architecture

- `combat/ballistic_trace.gd`: stateless, deterministic curved ray segments.
  Both the Lee-Enfield and scoped rifle share it. Gravity = 9.81m/s²,
  muzzle speed 744m/s / 790m/s. Ray origin is still the camera, so
  reticle alignment is stable; first-person muzzle/parallax, projectile
  flight time, drag and wind are **not** simulated.
- `combat/damage_profile.gd`: central weapon-specific anatomical rules.
  Scoped rifle damages torso 120 and head 150; normal enemy has 100HP.
  Limb shots are non-lethal, original Lee damage remains untouched.
- `enemy_hit_zone.gd`: collision/hitbox adapter with no duplicated sniper
  damage table. `sniper_view.gd` prefers `take_sniper_damage` on enemies,
  and remains compatible with other objects implementing `take_damage`.
- `environment/remaster_pass.gd`: existing v0.19 instanced vegetation,
  cobblestones, building materials. Adds local licensed 1K PBR ground
  and trunk bark, in addition to road, foundation, plaster and roof.
  No level collisions, cover placement or spawn transforms changed.
- `tools/install_remaster_pbr.py`: pulls six verified Poly Haven CC0
  materials on demand, only with explicit developer execution. Request
  uses a named User-Agent in accordance with Poly Haven API conditions.
  Does not require a Python package installation or download at runtime.

## Local required assets

Do not check in vendor binaries or redistribute without verifying
their individual licenses.

- `assets/characters/panzergrenadier/panzergrenadier_1k.glb` (or 2K)
- `assets/characters/player_british/british_soldier_fps.glb`
- `assets/characters/bamen_fps_arms/bamen_arms_1k.glb` (or 2K)
- `assets/weapons/lee_enfield/lee_enfield_charger_1k.glb` (or other
  `lee_enfield_1k.glb` / 2K variant implemented in `weapon.gd`)
- `assets/weapons/sniper/sniper_rifle_mag_v095_1k.glb`
  (or `sniper_rifle_1k.glb` / 2K variant)

The supplied `tools/check_remaster_assets.py` verifies real GLB magic
and file length, the five renderable asset groups, and six PBR maps.
It intentionally exits nonzero when a remaster-critical model is
missing; this is an art acceptance gate, **not** a gameplay dependency.

## Debian validation (required before merge)

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v200-remaster-ballistics-quality-20261020
# For an already existing local branch: git switch feature/v200-remaster-ballistics-quality-20261020
python3 tools/install_remaster_pbr.py
GODOT_BIN="$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64" \
  bash tools/run_remaster_smokes.sh
```

The smoke gate runs import, capsule fallback, swept enemy movement,
enemy prone stance, FPS arm IK, environment/torso damage and v0.20
projectile/drop/physics-exclusion tests. All must exit zero.
Run F5 after smoke and inspect: first-person sleeves and both grip hands
in hip/ADS, bolt/reload, sniper thorax one-shot, eye/feet alignment,
enemy navigation around cover, 1K PBR texture orientation, grass alpha
and sustained FPS on the user's GT 730.

## Verified source links

- https://polyhaven.com/a/cobblestone_01
- https://polyhaven.com/a/stone_wall
- https://polyhaven.com/a/plastered_wall_03
- https://polyhaven.com/a/clay_roof_tiles
- https://polyhaven.com/a/leafy_grass
- https://polyhaven.com/a/tree_bark_03
- https://polyhaven.com/license

## Known limitations (do not report as PASS)

There is no verified on-machine Godot 4.7.2 test execution here.
The source still has rectangular buildings and the human rigs depend
on user-local GLBs. Imported arms are gated by an IK convergence check,
which may hide hands rather than show visibly detached arms. Neither
issue is solved by a texture-only change. A commercial visual target
needs proper authored level meshes, fitted British sleeves, art LODs,
lighting and a GPU budget. Do not call this an AAA remaster.

## Rollback

Changes are isolated on the feature branch; `main` was not modified.
If the smoke or visual gate fails, keep the PR in draft and switch
back to `main`. No schema, savegame or asset conversion is destructive.
