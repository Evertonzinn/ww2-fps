# v0.6.5 — Correction: single Lee-Enfield and iron sights

## Incident
User screenshots confirm duplicate bolt in the 0.6.4 experimental overlay, and ADS iron sights visually compromised.
Root cause: a generated BoltAssemblyVisual was superimposed on an imported model which already contains the original metallic mechanism; generic mesh guesses concealed the wrong parts.

## Surgical resolution
- Restore weapon.gd **exactly** to feature/v061-auto-reload-graphics, the latest user-tested auto-reload + menu + original Lee-Enfield visual controller.
- Remove obsolete weapon_bolt.gd and its unverified mesh selection logic.
- Leave the original local GLB untouched; no guessed mesh visibility toggles or extra bolt assembly.
- Preserve movement, recoil, iron-sight ADS interpolation, raycast, reload, cartridge effect and menu.
- This does **not** yet animate the physical original bolt. That feature requires isolating and rigging it in Blender using verified pivots.

## Manual validation
1. Open Godot project and run F5. Confirm exactly one bolt/handle when looking from the side, not two.
2. Hold right mouse button: front/rear sight line should be centered as in tested v0.6.1; the center reticle intentionally hides while aiming.
3. Check 5 shots result in auto reload 5/25. Press R with partial magazine for manual reload.
4. Confirm cartridge flash, target damage, pause Esc, 1K/2K textures, FPS stable.
5. Do not merge this fix until screenshot shows a single aligned mechanism.

## Rollback
From this branch switch back to feature/v061-auto-reload-graphics (same weapon controller) or main (initial prototype). Do not reset / hard-clean local licensed GLB assets.