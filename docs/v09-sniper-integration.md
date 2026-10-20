WW2 FPS v0.9 — scoped sniper second weapon.
Base branch: feature/v08-enfield-authentic-reload; excludes experimental floating arms.
Assets: download ww2fps-sniper-v09-models.zip from the conversation and unzip in root alongside project.godot. Binary assets not tracked in repo.
Model: CC BY 4.0 Martin Trafas, 39742 triangles, four meshes, three PBR materials, 1K/2K, no animations.
Keys: 1 Lee-Enfield; 2 sniper; right mouse scoped zoom; R reload; left mouse fire; Esc menu.
Separate sniper ammo 5/20, reload 2.4 seconds, shot interval 1.35 seconds; auto reload when empty. No sniper bolt animation in this prototype.
Switch blocked during rifle reload/bolt and during sniper reload/shot cooldown. One-pass screen shader for scope, no secondary camera.
Test: headless Godot import, then FPS/ADS/scope screenshot, five sniper shots 5/20 -> 0/20 -> 5/15, return to Lee-Enfield unchanged.
Manual test of rifle orientation, scale, zoom and scope shader is REQUIRED; don't merge before it passes. Rollback by switching to feature/v08-enfield-authentic-reload without removing local GLB.
