# WW2 FPS v0.18 — Mainline consolidation candidate

Source: `fix/v172-enemy-swept-collision` @ `f16d04045a0571f8a4e923e5f84e134054fd7aef`, ancestry 58 commits ahead of existing main, zero commits behind.
Inventory: 51 branches and 47 open PRs. This release branch is the
single main development chain, not a merge of obsolete divergent
early experimental branches (v0.6 bolt experiments, v0.8 initial arms).

## Runtime defect
Godot v4.7.2 user smoke v172 logs repeated `Enemy movement blocked:
original capsule collider missing` plus `enemy capsule shape missing`.
`enemy_soldier.tscn` does author `CollisionShape3D` with CapsuleShape3D
radius=0.33m height=1.8m offset y=0.9m, but the loaded runtime
does not reliably return it. The root has collision layer/mask zero
to avoid intercepting seven child hitboxes. The old sweep made the
collider node a mandatory runtime dependency.

## Change
- `_movement_capsule_shape()` reads the original authored resource
  when available, else builds a cached identical CapsuleShape3D,
  limited to non-registering shape casts. It does not add a collider
  to enemy physics or change weapon damage zones.
- Sweep transform uses the real collider global_transform or
  reconstruction at authored centre 0.9m above enemy root.
- Log capsule source only once rather than warnings every tick.
- Keep motion cast, target heading, collision mask, 6mm skin margin.
- Smoke v172 now checks effective capsule size and actual swept
  obstacle movement rather than assuming the disabled root node exists.
- Additional v0180 smoke temporarily detaches the original node to
  exercise fallback deterministically.

## Mainline merge policy
Don't merge experimental divergent branches over this release.
Main consolidation should be a single branch/PR once physics
smokes are run on Debian. 3D asset binaries stay in local gitignore
and are NOT committed or uploaded.

## Test
```bash
cd /mnt/ows-data/games/ww2-fps
git status --short
git fetch origin
git switch --track origin/release/v0180-consolidated-capsule-fix
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v0180_enemy_capsule_fallback_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v172_enemy_sweep_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v170_enemy_prone_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v160_weapon_hands_smoke.gd
```
User confirmation is still required for v0.16 rigged arm visual quality.
Do not claim a runtime PASS without test logs, or assume the bare
BAMEN arms match the British uniform reference.

GitHub connector does not expose deletion of branch refs. Delete only
merged/superseded branch refs using user's authenticated local git
after verifying main ancestry; never delete any unmerged independent
feature branch without explicitly reviewing it.