# WW2 FPS v0.12.0 — First combat encounter

## Base
`feature/v110-enemy-hit-zones-animations` at `1654f79053ea2de21e9b4f2d9b8790fbfe8be5dc`.
The player's last visual approval covered the soldier death/hit zones.
Panzergrenadier glTF and local GLBs unchanged; author britdawgmasterfunk,
CC BY 4.0 (see docs/panzergrenadier-license.md). No new downloaded assets.

## Combat system
- New enemy_combat.gd attached by enemy_soldier.gd once the GLB is loaded.
- Enemy scans within 27m, uses ~125° forward FOV before initial detection,
  raycasts to Player and refuses to shoot through walls or solid props.
- Reaction time 0.85s; seeks the player's last seen point for up to 4s.
- Approaches to 8m at 2.1m/s; fires inside 21m at random 1.45–2.2s intervals.
- Enemy has imperfect accuracy increasing with range. Each real raycast
  hit on Player causes 13 HP damage; shots behind obstacles do not.
- Temporary procedural rifle placed around torso (NOT rigged hands),
  inexpensive tracer and procedurally generated 3D gunshot audio.
- No global raycast or hitbox changes in either player weapon.
- This is a first-stage finite-state adversary, NOT NavMesh cover AI.
  Walking toward last seen coordinates may cross obstacles because
  navmesh pathfinding is deliberately not part of v0.12.0.

## Player
- 100 HP, take_damage with dead guard and death flag; running and weapon
  controls stop at death; pressing Enter restarts active scene.
- HUD with VIDA 100/100 at top-left, red damage vignette, restart button.
- Existing graphic menu remains intact and still pauses gameplay.
- Enemy hit label shows HEADSHOT instead of "CABECA -100"; body hit feedback
  shows only numeric damage. Existing damage zone values remain unchanged.

## Files
`enemy_combat.gd` new, `enemy_soldier.gd`, `player.gd`, `hud.gd` touched.
`tests/v120_combat_smoke.gd` validates scene, combat, damage, UI
and dead-player invulnerability. WeaponController, sniper scope and magazines
are not modified.

## Debian validation (no installation)
Close editor and inspect local edits:
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v120-enemy-combat-player-health
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v120_combat_smoke.gd
```
If smoke passes, run F5 and verify:
1. Enemy detects player and alerts, then moves toward them.
2. Shots have visible tracer and sound; some miss; walls stop rays.
3. VIDA ticks 100 to 87 on hit. At zero, character stops moving,
   death overlay and retry button work (including Enter).
4. Headshot on enemy shows HEADSHOT; limb/torso damage still works.
5. No gameplay regression Lee-Enfield, sniper scope, bolt, magazine,
   ammo, GraphicsMenu Esc, restart and texture 1K/2K.

## Honest limitations
No Godot binary in authoring environment; static checks only.
Actual parsing, graphics, sound and performance require Debian F5 acceptance.
Enemy gun is a temporary prototype with no hand authored rig; cover,
navmesh, reload and polished motion are future tasks.
No merge to main. Rollback via
`git switch feature/v110-enemy-hit-zones-animations`
after preserving local changes. Never delete user GLBs or caches to rollback.
