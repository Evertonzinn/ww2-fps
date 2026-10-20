# v0.15 British player body: local asset import

Base: `fix/v142-stance-floor-clearance` (the latest user-tested C/Ctrl branch).

User uploaded `ww2_soldier_fbx.Fbx` (162,605,168 bytes, binary FBX 7200).
Structural analysis: 107 LimbNode skeleton nodes, 9 meshes, 9 skinned
deformers, 30 materials and 102 embedded image payloads.
`TempMotion` has 1130 animation curves, **each with exactly one key**.
Consequently the FBX DOES NOT contain working walking, running or prone clips.

## Conversion (needs Blender 4.x on the user's Debian)

1. Download the `convert_british_fbx.py` companion script provided in chat.
2. Save the original FBX in your local Downloads, without tracking it in Git.
3. Execute, adjusting its path:

```bash
cd /mnt/ows-data/games/ww2-fps
mkdir -p assets/characters/player_british
blender --background --python /PATH/convert_british_fbx.py -- \
  /PATH/ww2_soldier_fbx.Fbx "$PWD/assets/characters/player_british"
```

Outputs (not committed): `british_soldier_full.glb` for future third
person, and `british_soldier_fps.glb` excluding separate helmet, rifle,
teeth and eyes, with high head vertices removed to prevent camera occlusion.
The script retains the Character Creator skeleton and skin weights,
normalizes the character to ~1.78 m and repacks available textures.

## Gameplay staging

Scene adds only a `Player/BodyVisual` Node3D referencing
`player_body_visual.gd`. This loads the local FPS model when present.
When absent, the previous game is unchanged. It does not modify
the Weapon node, Lee-Enfield, sniper, scope, damage or movement scripts.
The initial preview hides rigged FPS arms to avoid duplicate model hands
until they're constrained to the gun; small procedural leg gait exists.
Body mesh is hidden while prone, until a genuine crawl clip is authored.
Therefore **this is v0.15 asset integration stage, not completed
professional first-person animation**.

## Tests

```bash
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v150_player_body_smoke.gd
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
```

Smoke BLOCKED exit code 2 if imported local GLB is missing. Test F5
and visually confirm proportions, hands hidden, feet, camera direction
and C/Ctrl transitions before approving the draft PR.

Vendor license was not supplied with the FBX. Do not redistribute FBX,
GLBs or packed textures in public GitHub until license is verified.
Blender and Godot not installed in the authoring sandbox; no claim that
conversion/animation/smoke passed. Main and earlier assets are untouched.