# v0.17.1 — FPS rig stability and animation timing

Base: `fix/v170-prone-los-audio-barrel` at `b376f4eb29024f81e47e7a9b451e11241057014c`.

## Observable defect
User's earlier F5 still showed two bare, incorrectly posed forearms
detached from the Lee-Enfield. The Blender-derived BAMEN model is REAL
3D with 52 bones/2 skinned mesh nodes; both arm chains total approx.
0.593m. Incorrect target/node links from v0.16.2 were fixed, while
v0.16.3 began sampling authoritative IK output during
`SkeletonModifier3D.modification_processed`. That sampled smoke was
not yet executed by user.

## Rig stability changes
- Require the imported arm `Skeleton3D` to run modifiers in
  `MODIFIER_CALLBACK_MODE_PROCESS_IDLE`, synchronized with the
  camera's `WeaponController._process` and `FirstPersonWeaponHands._process`.
  This avoids a physics-processed IK following render-updated rifle
  targets at a different frequency.
- Recalculate the right/left elbow magnets every idle frame AFTER
  smoothly moving the arm root; magnets are Skeleton3D-local
  while the weapon anchors are Weapon-local. Previous startup-only
  magnet values went stale during switching and ADS.
- Invalidate prior weapon grip pose when switching rifle slots,
  keep both hands hidden until the new slot has valid FINAL IK
  samples, and do not let a stale successful sample reveal
  misaligned forearms. Report original arm lengths and target
  clamping distances for diagnosis.
- Make the smoke check that both modifiers share idle cadence
  with Weapon and **both** final wrists are <=10cm from their
  grip markers (previous test allowed 18cm even though renderer
  would hide above 10cm).

## Important quality distinction
This change addresses animation stability and diagnostics for actual
52-bone skinned 3D forearms, NOT missing British uniform sleeves,
fingers on the trigger or highly accurate grip-marker calibration
against the geometry of BOTH third-party rifle models. Real
photo-quality like the reference will also require artist-authored
uniform sleeves, detailed materials/meshes and a field-tested
viewmodel pose. Do not claim that the screenshots already
match it without F5 validation.

## Debian tests
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v171-fps-arms-ik-stability
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v160_weapon_hands_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v170_enemy_prone_smoke.gd
```

If both pass, run F5 and record HIP and ADS screenshots for Lee and
sniper; verify both bare hands naturally gripping the geometry,
stable while turning/moving and during bolt/reload. Screen-space
rendering and finger curl are not tested headlessly.

Never disable the `pose_safe` guard or increase grip error
tolerance to force a visible but disconnected rig. The arm visual
is optional: gun gameplay must remain functional if IK fails.

No Godot in authoring environment. Static diff only. Main untouched.
