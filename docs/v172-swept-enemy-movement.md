# v0.17.2 — Enemy capsule swept collision (no NavMesh)

Issue: `enemy_combat.gd::_move_towards` previously moved an
AnimatableBody3D with `soldier.global_position += direction * movement`,
relying on a single centreline ray at 0.70m. The enemy width is
0.66m; the ray can miss a wall edge intersecting its shoulder.

Fix: use Godot `PhysicsDirectSpaceState3D.cast_motion` with the
**actual existing** `enemy_soldier.tscn/CollisionShape3D` capsule,
not a hand-authored replacement. Query only scene layer 1,
exclude enemy and its hit-zone colliders, and deliberately exclude
the existing World/Ground resting contact so horizontal motion
is allowed. Move by the safe swept fraction minus a 6mm contact
skin. This blocks walls/crates and offset corners before moving.

The existing AnimatableBody3D type, position, root scene, health,
enemy procedural gait, cover tactic, facing, chase range and
leg injury speed remain unchanged. This is a swept collision
guard, **NOT** complete nav/pathfinding or physics-based sliding.

## Debian tests

```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/fix/v172-enemy-swept-collision
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v172_enemy_sweep_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v170_enemy_prone_smoke.gd
```

Smoke creates a wall 0.19m from the enemy centreline.
A ray misses it, but a 0.33m-radius capsule cannot.
It requires enemy movement to approach the wall while not
crossing into it over 160 frames.

Godot runtime not present in authoring container. The physics
collision smoke is not yet tested in the user's Debian. If
`cast_motion` returns zero from contact or hits unexpected props,
capture failure before considering PR merge. No new packages.
Main untouched.
