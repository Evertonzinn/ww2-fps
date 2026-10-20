# WW2 FPS v0.17 — Enemy prone perception and PCM/cover remediation

Base: `fix/v163-hands-ik-modifier-pose` HEAD `2bee808081eba545489078bfe2d33eb8cea0d575`.

High: `enemy_combat.gd` erroneously aimed LOS and shots at
`player.global_position + Vector3.UP * 0.43`. The prone capsule
has radius 0.29m around its origin, so +0.43 is outside.
Vision now traces to Player collision centre and ±0.16m inside
the capsule. The first hit must be the real Player collider;
obstacles still block all LOS samples. Firing targets capsule
centre, keeping the existing dispersion and hit detection.

Medium: official Godot AudioStreamWAV API requires signed 8bit PCM,
not +128 biased bytes; the procedural enemy shot now encodes
signed samples as two's-complement. Reference:
https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html

Cover: barrel props use CylinderShape3D radius 0.37m; prior planner
discarded them by enforcing BoxShape3D. Helper now accepts both
cylinders and boxes, retaining collision/ray shield/path tests.

## Validation on Debian
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v170-prone-los-audio-barrel
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v170_enemy_prone_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
```

The smoke tests real raycasts for standing, crouching, prone; a
physical wall; cylindrical barrel dimensions; signed audio samples.
No assertion that enemy navigation was fixed: it still uses manual
AnimatableBody3D movement and a single thin ray; requires a separate
swept-shape/physics audit with runtime collision tests.

No guns, FPS arms, player movement, enemy rig, geometry, assets,
graphics settings or main affected. Godot unavailable in authoring
environment, so runtime PASS remains pending. PR draft.
