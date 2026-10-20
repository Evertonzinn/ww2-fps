# WW2 FPS v0.11: skeleton patrol and regional hitzones

Based on verified fix/v103-runtime-enemy-spawn, commit 58ae3bab1d5b178c40169bc2262c1f08b7392685.
Rigged Panzergrenadier asset by britdawgmasterfunk is licensed CC BY 4.0.
Required credit: docs/panzergrenadier-license.md. No GLBs changed or redownloaded.

Enemy health=100. Seven independent StaticBody3D hitzones:
Head 100 damage (1 hit), Torso 40 (3), Abdomen 25 (4),
Arms 15 (7), Legs 20 (5). The zone's take_damage(amount)
forwards to its parent; no edits to weapon.gd or sniper_view.gd.
Old root capsule is collision-layer=0 to avoid masking hitzones.
Zones use default layer1 and approximate anatomical dimensions.
The existing target.gd collision and player raycasts are unchanged.

Movement: 1.6m deterministic patrol at 0.7m/s, idle breathing,
procedural upper/lower leg and arm bone poses, lightweight impact
flinch, body tilt on death and cleanup after 2.6 seconds.
A brief floating label shows region and damage number.
No imported animation clips are present in user GLB, and this
is NOT IK, authored AAA animation, ragdoll, or combat AI.

Close Godot and preserve local changes before switching:
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v110-enemy-hit-zones-animations
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" res://main.tscn --quit-after 90

F5 checklist:
- Verify 7 zones via Debug > Visible Collision Shapes.
- Head 1 shot, Torso 3, Abdomen 4, Arms 7, Legs 5.
- Check patrol, idle sway, impact, fall, label, collision, 60 FPS.
- Lee-Enfield/sniper ADS, magazine reload and menu unchanged.
Hitboxes are not bone-following; tune positions after visual test.
Main unchanged; draft PR only; no Godot runtime validation here.
Rollback: git switch fix/v103-runtime-enemy-spawn (preserves GLBs).
