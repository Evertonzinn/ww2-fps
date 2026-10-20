# WW2 FPS v0.15.5 — Character Creator skinned model scale recovery

Base audited at `feature/v154-player-body-presence-space-rise`, HEAD `22ace63a46f32d1558ade59bb8aa2837ae017bc3`.

## User's actual smoke output

```
WW2 British PlayerBody: unusable Pants/Boots height 0.011m; verify GLB scale
v0.15 BODY SMOKE FAIL: British body not ready (visual_loaded=false)
WW2 FPS v0.14 PLAYER STANCE SMOKE: PASS
```

The v0.14 smoke shows Space-to-rise, crouch, prone, no ceiling penetration
and AI footstep hearing are all working. Do not modify those systems.

## Root cause / uncertainty

FBX->Blender->GLB conversion normalizes the parent hierarchy in Blender,
and Godot's nested imported mesh transforms may leave static
`MeshInstance3D.get_aabb()` with a tiny 0.011m garment span.
The previous body loader incorrectly **treated this bound as physical
proof that the entire skinned model was unusable** and hid it.
This is not proof the asset is 1.1cm when animated.

The revised loader measures:
- the actual imported Pants/Boots mesh AABBs after node transforms, AND
- the Character Creator thigh-to-foot **global rest positions** in the
  same model-local coordinate space, including the imported skeleton
  transform.

If rest bones have a usable span (>0.003m), they are authoritative:
the entire imported GLB scene (rig + skinned meshes) is normalized to
0.86m thigh-to-ankle. Otherwise it falls back to 1.03m lower-garment
height from the measured mesh. The computed scale is checked for
finite range (0.003..300); never blindly multiply by 100. Foot anchor
and lateral centre likewise prefer ankle/thigh positions over
an AABB that is inconsistent with skinned deformation.

`WW2 British PlayerBody BOUNDS` reports:
`mesh`, `rig`, `source`, `scale`, `normalized`, and `offset`.
This is necessary to verify which measurement governs. No GLB,
FBX or Blender changes are needed. Existing upper mesh visibility
allowlist protects camera from torso/vest/helmet again.

## Scope / verification

Changes ONLY: `player_body_visual.gd`, `tests/v150_player_body_smoke.gd`
and this report. No changes to gameplay physics, Space/C/Ctrl,
player.gd, enemy AI, Lee-Enfield, sniper scope, scene graph or textures.
Existing stance smoke already **passed** on user's machine.

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v155-player-body-cc-scale
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v150_player_body_smoke.gd
```

Expected new BOUNDS diagnostics followed by
`WW2 British PlayerBody READY`, `PASS: British body normalized`,
and `WW2 FPS v0.15 PLAYER BODY SMOKE: PASS`.
If this fails with another error, preserve the full print of
`mesh` and `rig` instead of adjusting an arbitrary constant.

F5: rifles and ADS unobstructed; look down at skinned pants and boots;
press C, Ctrl, Space, try walking, running, shooting and sniper ADS.
This is still a lower-body preview; no full professional animation
was present in the source FBX. License not independently verified;
3D assets remain local and out of the GitHub commit.

Godot unavailable in authoring sandbox; runtime visual PASS
requires user testing. Draft PR; main untouched.
