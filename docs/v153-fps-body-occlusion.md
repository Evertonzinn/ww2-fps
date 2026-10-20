# WW2 FPS v0.15.3 — First-person camera occlusion correction

Base auditada: `fix/v152-player-body-constant-parse` at `53f30022dff3353f4f8302a592845276ad34908f`.

## User-reported defect

Godot screenshot shows giant dark character geometry obscuring centre of
first-person camera and weapon viewmodel. Game still has health and enemy combat;
weapons are hidden behind the player’s imported skinned mesh.

## Proven source structure

Original user-provided binary `ww2_soldier_fbx.Fbx`, inspected directly:
- Separate skinned Mesh geometry `CC_Base_Body`, `Vest`, `Pants`, `Boots`.
- Blender converter `convert_british_fbx.py` included `CC_Base_Body` and
  `Vest` in `british_soldier_fps.glb` in addition to `Pants` and `Boots`.
- It cut some head vertices, **not chest/backpack/torso vertices**.
- The camera is at standing body centre Y 0.95m + Head Y 0.60m (about 1.55m)
  inside the upper-body mesh. Hiding only rigged arms does not solve this.

## Surgical runtime fix

In `player_body_visual.gd`, enumerate all imported `MeshInstance3D` nodes
and **fail-closed**: only allow nodes named `Pants` or `Boots` to be visible.
Hide `CC_Base_Body`, `Vest`, and any other unmatched mesh.
If separate pants/boots are missing, disable the optional player visual and
emit a meaningful error rather than letting it obscure aiming again.

- Lower body is drawn only when looking down more than ~31.5°.
- Always hidden in prone (no source clip) or while holding RMB to aim.
- Existing procedural gait + crouch moves lower limbs; head, arms, torso and
  backpack are not yet implemented as camera-safe first-person rendering.
- The full third-person source GLB remains local and unchanged.
- Lee-Enfield and sniper continue using their existing weapon/camera scripts,
  without reparenting, FOV changes, transforms, or shader work.

## Test and expected behavior

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v153-player-body-fps-occlusion
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v150_player_body_smoke.gd
```

Test now asserts only Pants/Boots meshes are visible, horizontal aim
hides all skinned preview, and deliberately looking down enables it.
Original rig, stance controller, weapon viewmodel contracts must pass.

F5: verify forward view clear with Lee-Enfield, select sniper (2), ADS/bolt,
look downward to see legs/boots, C crouch, Ctrl prone (visual hidden),
press RMB while looking down (legs hidden to preserve ADS). No replacement
of GLBs needed, no Blender, no npm or package installs.

## Limits

This is **camera occlusion stabilization**, not a complete visible animated
torso/arm rig. Professional upper-body, IK hands and prone clip remain future
work. Godot unavailable in authoring container; runtime PASS depends on
user testing. Do not merge draft PR until smoke/F5 pass.

4 file scope? Actual: 3 files — player_body_visual.gd, smoke test,
this report. No private GLB/FBX committed; main untouched.
