#!/usr/bin/env python3
"""Download only the 11 explicitly shared WW2 asset ZIPs into a local staging folder.

The original Drive folder is currently anyone-writer: restrict permissions to
viewer before downloading. This script pins file IDs and exact size, rejects
oversized/changed files, and never opens or executes ZIP payloads.
Requires gdown installed in a developer-controlled Python venv.
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import subprocess
import sys
from pathlib import Path

# IDs and sizes were read through the user's connected Google Drive account.
FILES: dict[str, tuple[str, int]] = {
    "tree_bark_03_4k.blend.zip": ("1T4bTtfmoQSdTcITWSqdnYof-LcQ03vjt", 86840945),
    "leafy_grass_4k.blend.zip": ("1MzvmtDmt4Rv4xppN7FqJlbKeBewCrSag", 131353998),
    "fps_hands_rigged_by_evolvegames.zip": ("1TLuRwmZsstd2azgLryyQYGDdpscFsWQI", 8228729),
    "clay_roof_tiles_4k.blend.zip": ("17D50O3rUaCVSzdaHbz6sAOkoyffnCxRe", 62666330),
    "plastered_wall_03_4k.blend.zip": ("1d7pI8JzvJsdrCROCBLlOpfHPN1d37bdC", 48618161),
    "stone_wall_4k.blend.zip": ("1zFhdzW6Y1yr2g0U9iv510HsX8Ug8i73Q", 59071835),
    "cobblestone_01_4k.blend.zip": ("1EfChol6z67Rzs6Y-MXXTEhBWLqkb9xMQ", 34127206),
    "animated_fps_hands_rifle_animation_pack.zip": ("1F_kNgRZdYG-OtKfoEdTxjpqSFZRRnJ7r", 107463967),
    "modular_fort_01_4k.blend.zip": ("1__J5xZE00_6BFOpVDsxdN1-dHgjBDWg5", 646683227),
    "french_house_ww2.zip": ("1zog5LqSOevBSllqmIb_KpnT5muaseSwn", 317998070),
    "tree_small_02_4k.blend.zip": ("1IDiPcXEtnbW2557f30CQ7fKWvTmUG441", 263020905),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--only", choices=sorted(FILES))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    requested = {args.only: FILES[args.only]} if args.only else FILES
    if not args.dry_run and importlib.util.find_spec("gdown") is None:
        print("ERROR: install gdown in your local virtualenv: python -m pip install gdown", file=sys.stderr)
        return 2
    if not args.dry_run:
        args.output.mkdir(parents=True, exist_ok=True)
    for name, (file_id, expected_size) in requested.items():
        destination = args.output / name
        if destination.is_file() and destination.stat().st_size == expected_size:
            print("SKIP: validated existing size:", name)
            continue
        print("FETCH:", name, "(", expected_size, "bytes )")
        if args.dry_run:
            continue
        pending = destination.with_name(destination.name + ".download")
        if pending.exists():
            pending.unlink()
        try:
            subprocess.run([
                sys.executable, "-m", "gdown", "--id", file_id,
                "--output", str(pending),
            ], check=True, timeout=1200)
            actual_size = pending.stat().st_size
            if actual_size != expected_size:
                raise ValueError(f"Drive asset changed/truncated: {name}, {actual_size} != {expected_size}")
            os.replace(pending, destination)
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as exc:
            pending.unlink(missing_ok=True)
            print("ERROR:", name, exc, file=sys.stderr)
            return 1
    print("DONE: Drive ZIPs staged locally; not executed or added to git.")
    print("Reminder: review source licenses; expected sizes are not cryptographic hashes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
