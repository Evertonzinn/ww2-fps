# WW2 FPS v0.12.1 — Rifles + arm IK + locomotion

## Why
User-approved v0.12 combat kills player but soldier visibly glides sideways
in a reference T/A-pose with a placeholder weapon not properly supported by hands.

## Diagnosis
Original Panzergrenadier glTF (britdawgmasterfunk, CC BY 4.0)
contains 65 Mixamo-compatible joints but **zero authored animation clips**.
v0.12 only used small independent rotations on arm bones and moved the
enemy via direct global_position toward target before it fully turned.
The prototype enemy gun was attached directly to torso, not hand grips.

## Scoped correction (no new assets)
- **enemy_soldier.gd**: identify actual LeftArm/LeftForeArm/LeftHand
  and RightArm/RightForeArm/RightHand; apply analytical two-bone IK
  per arm, using the original imported skeleton and its own rest/pose.
  Clamp unreachable targets, choose elbow pole hints, restore initial poses
  before each solve to avoid accumulating twist.
- **enemy_combat.gd**: rifle placed forward of the sternum and
  3D right trigger / left support grip markers added. Child _process
  solves the two arms to the visual rifle every frame, after the parent
  sets procedural idle/walk; gun recoils slightly.
- Patrol first heads toward the initial player side (+Z). Both patrol
  and pursuit **rotate before moving**, avoiding side strafing.
- Walking leg swing uses the body/world right axis transformed into
  the Mixamo joint's parent coordinate system.
- No changes to weapon, sniper ADS, scope, ammo, damage, player death,
  main scene, rendering, animations inside GLB, or graphics menu.

## Geometric checks before committing
Original Mixamo bone positions/scales analyzed from glTF:
each upper+lower arm length approximately 0.48 m. Initial left
support-hand target would have been 0.70 m from shoulder (unreachable).
Corrected grips are 0.42 m (left) and 0.18 m (right) away from their
respective shoulders. Both targets within the actual reach.
Consulted Godot Skeleton3D implementation: global_pose accumulates
get_bone_pose directly, so rest is not multiplied twice.

## Debian: verification
Close editor, then:
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v121-enemy-rifle-ik-locomotion
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v121_enemy_ik_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v120_combat_smoke.gd
```
Verify headless tests, then F5 to inspect actual right hand on grip,
left on foregrip, elbows bent, hip/knee motion while approaching the
player, barrel pointing at the player, shot recoil, headshots,
player death/restart and 1K/2K. Send full output/print if unexpected.
Test scene is still not equipped with a complete author-made
combat animation set. Foot contact may slide, and hitboxes are
not bone-attached yet. Gun is a **temporary procedural rifle**;
source does not include an authentic German rifle model.

## Scope and status
Static/source review only in this authoring environment. No Godot installed,
so F5, parser, hand contact and combat timing are **not claimed as tested**.
Draft PR only; no merge to main.
Rollback with `git switch feature/v120-enemy-combat-player-health`
without deleting local GLB or resetting modifications.
