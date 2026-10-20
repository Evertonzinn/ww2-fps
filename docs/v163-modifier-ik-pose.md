# WW2 FPS v0.16.3 — Godot 4 skeleton modifier pose measurement

## User-reported incident

The latest v0.16.2 run showed a real screenshot with bare skinned
arms disconnected from the Lee-Enfield while the smoke continued
to print **the exact same** 0.466m and 0.301m errors after fixing
the `SkeletonIK3D.target_node` paths.

The target clamp diagnostics were small:
`Lee right=0.000m left=0.059m`, i.e. the IK targets themselves were
not displaced far from the intended gun grips. The repeated wrist
numbers alone do NOT prove the IK is disabled.

## Why the previous wrist smoke could be misleading

Godot 4's `SkeletonIK3D` extends `SkeletonModifier3D`. Its
`get_bone_global_pose()` results outside modifier processing may
represent pre-modifier rest/animation poses. Official Godot API
requires reading the final modified pose while
`SkeletonModifier3D.modification_processed` fires.

Official references:
- https://docs.godotengine.org/en/4.6/classes/class_skeletonmodifier3d.html
- https://docs.godotengine.org/en/4.5/classes/class_skeleton3d.html

The original smoke used ordinary `await process_frame` and then
`get_bone_global_pose()`, so it could read the same old pose
independently of whether IK was working. No previous measurement
actually recorded the final skinned wrist position during a
modifier signal.

## Surgical update

- Connect `left_ik.modification_processed` (last modifier added)
  to `_on_final_ik_pose`.
- Read both wrist bone positions and marker globals at that moment,
  convert to the same world coordinate system, record relative error,
  associated selected weapon slot and modifier sample count.
- Change smoke to inspect those actual final-solver samples after
  allowing updates, instead of reading `Skeleton3D` outside the
  deferred modifier callback. The test FAILS if modifiers don't run
  or samples correspond to the wrong selected weapon.
- Make render fail-safe. If the final pose exceeds 10cm error for
  four consecutive modifier passes, hide only the cosmetic hands
  (weapon/ADS still playable) and print a single diagnostic warning.
  Recover automatically if a later valid sample is measured.
  New rig loads start hidden until a valid sample is measured,
  preventing initial floating/T-pose flashes.

## Scope

Only `weapon_hands.gd`, `tests/v160_weapon_hands_smoke.gd`,
this report. No edits to `weapon.gd`, `sniper_view.gd`,
`player.gd`, postures, AI, GLBs, texture quality, muzzle/firing,
reload state machine, camera FOV, scene, HUD or physics. Do not
reconvert or redownload any local BAMEN assets.

## Validation

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v163-hands-ik-modifier-pose
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v160_weapon_hands_smoke.gd
```

Expected output includes `PASS: two IK targets resolve...`,
followed by `HANDS FINAL IK: Lee right=... left=... samples=...`
AND `HANDS FINAL IK: sniper ...`. A passed smoke is not
proof that the palms and fingers face the stock correctly. Next,
inspect F5 hands orientation and capture exact error readings.
If errors remain above 10cm, the visible arm rig is hidden until
further calibration, not shown in the broken Parkinson pose.

## Status

Static audit grounded in Godot's modifier API and local original
BAMEN 1K/2K GLB (52 bones, 2 skinned mesh nodes). We can inspect
GLB source, but do not have the Godot binary and local game import
pipeline, so no claim of runtime success. PR must remain draft.
