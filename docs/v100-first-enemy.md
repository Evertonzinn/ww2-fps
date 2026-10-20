# WW2 FPS v0.10.0 — first enemy soldier

Base: fix/v095-sniper-mag-quality-realism (Astra PR #21).
Files: enemy_soldier.gd, enemy_soldier.tscn, main.tscn, documentation.
No player / Lee-Enfield / sniper / HUD / menu / renderer changes.

Asset downloaded from user-supplied ZIP: five meshes, 27,005 triangles,
65 joints, one skin, five PBR materials, 15 images and ZERO animations.
License from license.txt is CC BY 4.0, despite the model title "(CC0)".
See docs/panzergrenadier-license.md.

The source geometry spans approx 95.63 glTF units high. Visual scale
0.019 and lift +0.046 place it at about 1.82m with feet near ground.
The test enemy is on the road at x=2.2, z=-10.0, turned toward spawn.

Enemy has 3 hit points, capsule collision and a take_damage(amount)
method compatible with both existing weapons. At zero health it despawns.
No AI, navigation, animations, procedural human geometry or other systems.
If the asset is missing or skeleton invalid, only enemy collision is
disabled and the existing game remains playable.

BINARY FILES ARE DELIVERED SEPARATELY, NOT COMMITTED TO GITHUB.
Extract ww2fps-v100-panzergrenadier-assets.zip in the directory containing
project.godot. Paths:
- assets/characters/panzergrenadier/panzergrenadier_1k.glb
- assets/characters/panzergrenadier/panzergrenadier_2k.glb
- assets/characters/panzergrenadier/LICENSE.txt

Install on Debian:
1. Close Godot, check git status --short, git fetch origin.
2. Switch to feature/v100-first-enemy-soldier (do not discard changes).
3. unzip -n ~/Downloads/ww2fps-v100-panzergrenadier-assets.zip -d .
4. Run the existing Godot 4.7.2 headless editor --path . --quit.
5. Open project and F5. Console should show "enemy ready: 65 bones".
6. Verify model orientation, scale, material, ground contact, and FPS.
7. Shoot enemy three times: should be removed from scene.
8. Confirm original targets, sniper ADS, magazine and Lee-Enfield remain.
9. If orientation needs tuning, change only EnemySoldierTest rotation in
   main.tscn, not camera or weapon transforms.

Limitations: torso capsule does not cover outstretched limbs. Death is
immediate despawn, not animated. Source has no animation tracks.
This environment cannot run the Debian Godot/GT730 scene; user graphical
smoke test is mandatory before merge. PR stays draft.

Rollback: git switch fix/v095-sniper-mag-quality-realism, without hard
reset/clean or deletion of licensed local assets.
