# v0.8.2 — Rigged BAMEN FPS Arms prototype

Base: feature/v081-first-person-arms. Main is unchanged.

Binary model is in a separate ZIP in conversation: ww2fps-bamen-arms-v082.zip.
Contains Bamen_arms_1k.glb and bamen_arms_2k.glb (paths documented within).
Includes artist attribution. Do not claim model has animations: it has 52 bones but no animation clips.

The procedural arms are completely replaced by original skinned mesh. The weapon only changes two entrypoints: initial load of 1K arms and matching quality selection.
Right wrist targets weapon's grip; left wrist targets support when idle, bolt when opening/closing and charger during reload.
This first pass moves the whole arm via shoulder bone. It does NOT solve elbow IK or finger positions; preview may have anatomy/clipping issues that must be calibrated in Godot before any merge.

Install:
1. Close Godot; inspect git status --short; fetch; checkout feature/v082-bamen-rigged-arms from origin.
2. Unzip ww2fps-bamen-arms-v082.zip into the WW2 FPS root, where project.godot lives.
3. Import the project with Godot 4.7.2 headless --editor --path . --quit.
4. F5. Confirm log "BAMEN FPS arms imported: 52 bones; wrist targeting active".
5. Inspect right/left arm alignment and iron-sight ADS. Take side and ADS screenshots.
6. Press R at partial magazine; confirm left hand follows clip, reload and ammo still work.
7. Test 1K/2K quality, casings and FPS. On clipping, adjust constants in weapon_arms.gd.
8. Do not merge until visual review succeeds.

If missing imported model or skeleton/bones are invalid, arms do not render, but weapon gameplay is preserved.

Rollback: git switch feature/v081-first-person-arms (do not remove your local rifle or BAMEN assets).
