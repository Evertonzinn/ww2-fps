# WW2 FPS v0.15.6 — Anatomical FPS leg framing

Base: `fix/v155-player-body-cc-scale`, SHA `8d72f542c6360ded926628760fe187763b595c8b`.

User screenshot of v0.15.5 shows a huge trousers/hip area ABOVE
the boots in the down-facing FPS camera. The weapon and crosshair
are visible. This is not simply wrong scale; it is the sign and
anchor of the cosmetic depth offset.

## Corrected geometry

Godot faces forward on -Z. The prior `leg_preview_forward=0.46`
placed the **whole hip region 46 centimetres in FRONT of the eyes**,
which makes the waistband project toward the top of the screen, while
the ankles project lower. In a human body, eyes are ahead of the hips.

The loader now anchors the hips (from CC5 left/right thigh rest bones)
**+0.14m behind the camera's horizontal position**. It keeps the
scale from skeletal leg measurements and the already-tested boot
ground alignment. No other visual hierarchy or collision change.

The FPS mesh allowlist still limits drawing to Pants and Boots;
full torso, vest, arms, helmet remain hidden to protect both rifles
and sniper ADS. A genuine full body rig with weapon IK and prone
animation is a distinct later task.

## Regression that would have caught this

The updated body smoke now fails if the hip is not behind the eyes,
if hips/ankles have an invalid vertical ordering or if their
screen projections are inverted when the camera looks steeply down
(-1.30 rad). `Camera3D.unproject_position()` uses the runtime
camera and imported CC5 skeleton points, not a guessed AABB.

Prints two new lines:
- `WW2 British PlayerBody ANATOMY: hip=... boot=...`
- `WW2 British PlayerBody SCREEN: hip=... boot=...`

Expected `PASS: hips project lower on screen than boots`.
Runtime pass is NOT claimed until tested on user's Debian.

## Test

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v156-player-body-anatomical-framing
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v150_player_body_smoke.gd
```

Then F5: forward Lee-Enfield and sniper clear; look down about
70–80 degrees. Skinned waist should attach from lower edge of
screen and boots appear toward the centre, rather than showing
a detached backwards trouser blob. Check C, Ctrl and Space as
previously approved; test rifle fire, ADS/scope, reload and enemy AI.

This is a draft PR; main unchanged, no new asset or GLB export,
and NO changes to Space movement, physics, guns, main scene or AI.
