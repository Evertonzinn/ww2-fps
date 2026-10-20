# v0.15.4 — Body-awareness geometry recovery + Space to rise

Base: `fix/v153-player-body-fps-occlusion` (SHA dd0720b16c31948aa2c4730efcdd654dea5b8c51).

User reports rifles work again but the British soldier disappears. v0.15.3
hid the entire FPS body unless Head pitch was below -0.55 radians;
a boolean visibility smoke test cannot confirm geometry is in view.

## Actual fixes

- Real imported skinned Pants/Boots AABB corners are transformed from the
  MeshInstance3D local coordinates through nested GLB transforms into the
  player model space. The legs are centered laterally, soles aligned with
  ground, moved 0.46m forward **for first-person framing only**.
  Existing physical collider/player position, aim ray and weapons untouched.
- **Remove pitch-driven vanishing**: lower-body mesh remains present while
  standing/crouching even when the view is level. Looking down reveals
  actual trousers and boots naturally; RMB aiming and prone hide the
  preview. The dangerous torso/head/vest/arms remain hidden by mesh
  allowlist; the shipped GLB stays unchanged.
- Leg preview responds to gait speed (walk/run), with gentler crouch
  movement. These procedural motions are a staging prototype, not
  handcrafted/re-targeted 3D animation clips.
- Space while crouched -> stand; Space while prone -> crouch, one level
  per press. Existing collision/ceiling protection still applies.
  The press is **consumed until Space release**, preventing the
  inadvertent jump the same frame; standing Space still jumps normally.
  C and Ctrl retain all their established actions.

## Smoke tests and real validation

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v154-player-body-presence-space-rise
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v150_player_body_smoke.gd
```

FPS F5: see the Lee-Enfield/sniper aiming forward; look downward
to see trousers/boots positioned at the bottom of the view; walk/run/
crouch to inspect leg motion. Space from prone -> crouch -> stand;
under a low ceiling Space must not pass through or jump; normal
standing jump remains. RMB and sniper ADS must never be occluded.

Diagnostics: `WW2 British PlayerBody BOUNDS: min=... size=...
preview=...` and `WW2 British PlayerBody READY`. Send these lines
plus screenshots if no mesh is visible, so the next correction uses
measured geometry rather than another visibility guess.

## Limits

The user-supplied FBX contained no real locomotion clips; only a
single-key TempMotion. This milestone provides an actually rigged,
textured, skinned lower-body preview, not completed upper torso,
rifle grip IK or prone animations. Full-body third-person/arm animation
remains future work. No files or assets from third parties are
committed to GitHub; no GLB reconversion or Blender package needed.

This is a static patch with smoke instructions; Godot 4.7.2 is only
available on the user's Debian, so runtime PASS is not claimed.
PR draft; main untouched.
