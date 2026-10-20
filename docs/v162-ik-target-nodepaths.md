# v0.16.2 — Rigged weapon hands: IK NodePath fix

## Reproduced bug
User Godot 4.7.2 reports both `RightHandOnGrip` and
`LeftHandOnStock` "Node not found" from paths relative to
`.../Skeleton3D/RightArmGripIK` and
`.../Skeleton3D/LeftArmSupportIK`.
Wrist errors: **0.466m right**, **0.301m left** on Lee-Enfield.
Despite this, earlier code printed `HANDS READY` and a superficial
smoke printed `PASS: two arm IK targets`.

## Root cause (source-proven)
In `weapon_hands.gd::_make_ik` the script added an IK node under
the skeleton but assigned `ik.target_node = skeleton.get_path_to(marker)`.
The NodePath property belongs to the child `SkeletonIK3D`, not
the `Skeleton3D`. Thus the path is one parent (`..`) short and
cannot resolve the marker. No solver could follow either target.
This explains both `Node not found` messages and the wrist offsets.

## Surgical repair
- After `skeleton.add_child(ik)`, use
  `ik.target_node = ik.get_path_to(marker)` so the relative
  path originates at the IK, then verify
  `ik.get_node_or_null(ik.target_node) == marker`.
- Before calling `start`, enforce that BOTH IK target paths
  resolve to the expected Marker3D and that both IK nodes have the
  imported Skeleton3D as their parent skeleton. Confirm that both
  solvers are running before setting `hands_initialized=true`.
- On invalid paths, disable only the cosmetic rig and log a warning;
  leave Lee-Enfield/sniper fire, ADS, ammo and weapon switching intact.
- Expand the smoke to check real resolved node identities, active IK
  solvers, wrist endpoint error after 8 frames, and whether reach
  clamping moves the marker more than 12cm from the rifle grip.

## What was NOT changed
- No changes to `weapon.gd`, `sniper_view.gd`, `player.gd`,
  `player_stance.gd`, `main.tscn`, collision, health, gameplay,
  player body, physics, AI, graphics or the 1K/2K GLBs.
- Existing Godot PBR asset contains 52 bones, 2 skinned meshes
  and arm lengths about 0.35m upper + 0.25m forearm per side.
  Model geometry/appearance have NOT been retouched.
- No package installations or GLB replacement required.

## Validation in Debian
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v162-weapon-hands-ik-target-path
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v160_weapon_hands_smoke.gd
```
Expected first smoke PASS:
`PASS: two IK targets resolve from their OWN nodes and solvers are running`.
Then wrist errors MUST be within smoke thresholds on Lee and sniper.
If not, collect `HANDS GRIP`/`CLAMP` numbers; do not misrepresent
an IK target lookup fix as complete weapon-hand rig calibration.

The Godot runtime is not available in the authoring environment;
validation by the user's Debian is mandatory. Keep draft; main intact.
