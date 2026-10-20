# WW2 FPS v0.16 — Real skinned FPS hands / weapon grip

Base: `fix/v157-player-body-fps-visibility` HEAD `389104187a58b296a3d5dd75223c177ce0fba676`; previous #42 remains untouched.

## Actual code delivery (NOT an image or mockup)

Add `weapon_hands.gd` as an OPTIONAL skinned 3D model attached to the
existing `Player/Head/Camera3D/Weapon` node. It uses the CC BY 4.0
BAMEN model (52 bones, 2 skinned meshes and PBR textures) already
provided earlier in the project. The hands form two IK chains,
shoulders anchored in Weapon space, right grip and left forestock
support; poses follow active Lee-Enfield or sniper and the current
bolt / charger / magazine reload states. With sniper ADS scope overlay,
hands are hidden so they cannot cover the reticle.

**The existing Lee-Enfield/sniper GLBs are ALREADY textured** (1K
fallback and 2K quality). These GLBs, plus their model transforms,
HUD, gun firing, sniper zoom/ADS, bolt animations and gameplay ammo
remain unchanged. Extra rendering detail comes from actual skinned
hands and appropriate grip poses, not a generated screenshot.

If arms asset is missing, prints one warning and leaves original
weapons playable, without placeholder boxes or a half-rig.

## Separate local asset package

Installer ZIP `ww2fps-v160-rigged-hands-assets.zip` contains the same
two licensed binaries:
- `assets/characters/bamen_fps_arms/bamen_arms_1k.glb`
- `assets/characters/bamen_fps_arms/bamen_arms_2k.glb`

These large binaries stay outside public Git history and must be
installed locally. A README and license attribution are included.

## Test

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/feature/v160-rigged-weapon-hands
unzip -o ~/Downloads/ww2fps-v160-rigged-hands-assets.zip -d "$PWD"
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v160_weapon_hands_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
```

After PASS, F5: press 1 Lee-Enfield, look at hands touching
stock/trigger; press 2 sniper, confirm both reposition; right-click
ADS in both modes (scope unobstructed), fire and cycle bolt, R
reload and confirm hand follows charger/magazine. Test C/Ctrl/Space
and frame rate on the GT 730/Nouveau.

## Realistic quality vs visual reference

The supplied screenshot is visual quality target, not a usable asset.
The original BAMEN viewmodel is bare FPS arms/hands with 2K textures.
It is NOT yet the player's British uniform sleeves nor full-body
animation. A Blender-extracted British-soldier sleeve viewmodel and
artist-tuned grip markers, finger animations and weapon detail pass
are a future milestone after observing the real Godot v0.16 F5
screenshots. This PR does not claim that every joint anatomically
matches both independently sourced guns without calibration.

Godot is unavailable in the editing container; no runtime PASS
claimed. Branch is a draft; never merge to main without testing.
