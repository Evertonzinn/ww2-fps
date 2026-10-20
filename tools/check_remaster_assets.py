#!/usr/bin/env python3
"""WW2 FPS remaster asset preflight. Standard library only; read-only."""
from __future__ import annotations

import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS: dict[str, tuple[bool, tuple[str, ...]]] = {
    "German enemy rig": (True, (
        "assets/characters/panzergrenadier/panzergrenadier_1k.glb",
        "assets/characters/panzergrenadier/panzergrenadier_2k.glb",
    )),
    "Lee-Enfield rifle": (True, (
        "assets/weapons/lee_enfield/lee_enfield_charger_1k.glb",
        "assets/weapons/lee_enfield/lee_enfield_rigged_once_1k.glb",
        "assets/weapons/lee_enfield/lee_enfield_rigged_1k.glb",
        "assets/weapons/lee_enfield/lee_enfield_1k.glb",
        "assets/weapons/lee_enfield/lee_enfield_charger_2k.glb",
        "assets/weapons/lee_enfield/lee_enfield_rigged_once_2k.glb",
        "assets/weapons/lee_enfield/lee_enfield_rigged_2k.glb",
        "assets/weapons/lee_enfield/lee_enfield_2k.glb",
    )),
    "Scoped rifle": (True, (
        "assets/weapons/sniper/sniper_rifle_mag_v095_1k.glb",
        "assets/weapons/sniper/sniper_rifle_1k.glb",
        "assets/weapons/sniper/sniper_rifle_mag_v095_2k.glb",
        "assets/weapons/sniper/sniper_rifle_2k.glb",
    )),
    "Rigged FPS arms": (True, (
        "assets/characters/bamen_fps_arms/bamen_arms_1k.glb",
        "assets/characters/bamen_fps_arms/bamen_arms_2k.glb",
    )),
    "British soldier lower-body": (True, (
        "assets/characters/player_british/british_soldier_fps.glb",
    )),
}
TEXTURE_DIR = ROOT / "assets/environment/remaster/textures"
MATERIALS = ("cobblestone", "stone_wall", "plaster", "roof_tiles", "grass_ground", "tree_bark")


def valid_glb(path: Path) -> bool:
    try:
        with path.open("rb") as stream:
            magic, version, declared_size = struct.unpack("<4sII", stream.read(12))
        return magic == b"glTF" and version == 2 and declared_size == path.stat().st_size
    except (OSError, ValueError, struct.error):
        return False


def main() -> int:
    print("WW2 FPS remaster preflight — offline, no asset mutation")
    fatal = 0
    for label, (required, candidates) in MODELS.items():
        existing = [ROOT / name for name in candidates if (ROOT / name).is_file()]
        if not existing:
            print(f"{'ERROR' if required else 'OPTIONAL'}: {label} GLB unavailable")
            fatal += int(required)
            continue
        valid = [f for f in existing if valid_glb(f)]
        if not valid:
            print(f"ERROR: {label} GLB file header/length invalid")
            fatal += int(required)
        else:
            print(f"OK: {label}: {valid[0].relative_to(ROOT)}")
    installed = 0
    for material in MATERIALS:
        maps = {}
        for kind in ("albedo", "normal", "roughness"):
            maps[kind] = next((f for ext in (".jpg", ".png")
                               if (f := TEXTURE_DIR / f"{material}_{kind}{ext}").is_file()
                               and f.stat().st_size > 400), None)
        if maps["albedo"]:
            installed += 1
            extras = " | ".join(f"{key}={bool(value)}" for key, value in maps.items())
            print(f"PBR: {material}: {extras}")
        else:
            print(f"PBR FALLBACK: {material} uses procedural base (no albedo)")
    if installed == 0:
        print("PBR: run python3 tools/install_remaster_pbr.py for real CC0 materials")
    print(f"RESULT: {fatal} missing/corrupt required model groups; {installed}/{len(MATERIALS)} PBR surfaces")
    return 1 if fatal else 0


if __name__ == "__main__":
    sys.exit(main())
