# WW2 FPS v0.7 — Real original-mesh glTF animation

**Base:** v0.6.1, previously confirmed by user for ADS, 3D rifle, auto-reload and graphics menu. No inherited experimental overlay v0.6.2-0.6.4.

## Model changes (separate ZIP)
- Input: original Talamander CC BY 4.0 Lee Enfield Rifle model provided by owner of repo.
- Output: lee_enfield_rigged_1k.glb / lee_enfield_rigged_2k.glb.
- Retains all 44 original meshes, 8,497 triangles, UVs, materials, and bounding box exactly unchanged in rest pose.
- Four original component nodes grouped: Cylinder_Low, Cylinder.001_Low, Cylinder.002_Low (lateral handle), Cylinder.004_Low.
- BoltSlide, BoltPivot, BoltLift, BoltPivotInverse added as transform rig; GLB animation BoltCycle lasts 0.86s.
- It does not create a second procedural handle or hide the rear/front sights.
- Root transforms preserve Godot scale/camera alignment as before.

## Godot integration
- Prefers `res://assets/weapons/lee_enfield/lee_enfield_rigged_2k.glb` or the 1K variant from graphics menu.
- If rigged model absent, reverts to the existing local old GLB; if absent too, to procedural weapon.
- Discovers imported AnimationPlayer and calls BoltCycle once per shot. Blocks repeated shot until cycle done.
- Cartridge ejection begins during the pull phase; automatic and manual reload wait for the cycle when an animation is present.
- All damage, FOV, 4K menu, reload count and movement logic preserved.

## Install
Close Godot, run `git status --short`, `git fetch origin`, `git switch --track origin/feature/v07-animated-gltf-bolt`.
Download `ww2fps-v07-lee-enfield-bolt-animated.zip` from the chat; unzip into project root.
Run: `~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit`
Then F5. Console should print `Lee-Enfield: GLB BoltCycle importado: BoltCycle` (sometimes with library prefix).

## Acceptance tests
1. One bolt visible and no duplicate handle; aim still aligned.
2. Operating handle rotates, recoils and locks within 0.86s after the shot.
3. No second shot during bolt animation.
4. After 5 shots, auto reload begins only after bolt cycle and refills from reserve.
5. Manual R, no ammo duplication, menu pause, quality 1K/2K both functional.
6. Stable FPS on GT 730 at prior settings; no errors in debugger.

## Limitations and rollback
- Animates original GLB geometry without Blender. The grouping is determined from offline geometry and must be visually validated in Godot; not yet a historical re-enactment certified by a rig artist.
- Binary asset is not in repo; delivered separately in the ZIP with CC BY 4.0 attribution.
- No changes to main. Roll back simply by `git switch feature/v061-auto-reload-graphics`; leave binary local.
- Do not merge before visual and runtime verification.