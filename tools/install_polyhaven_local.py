#!/usr/bin/env python3
"""Offline installation of developer-provided Poly Haven .blend.zip PBR maps.

Only copies resized JPG/PNG maps. Never commits vendor files or imports .blend.
No network access; uses Pillow within a local venv.
"""
from __future__ import annotations
import argparse
import io
import re
import sys
from pathlib import Path, PurePosixPath
from zipfile import ZipFile, BadZipFile
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
MATERIALS = {
    "cobblestone_01_4k.blend.zip": "cobblestone",
    "stone_wall_4k.blend.zip": "stone_wall",
    "plastered_wall_03_4k.blend.zip": "plaster",
    "clay_roof_tiles_4k.blend.zip": "roof_tiles",
    "leafy_grass_4k.blend.zip": "grass_ground",
    "tree_bark_03_4k.blend.zip": "tree_bark",
}
MAP_ALIASES = {
    "albedo": ("diff", "diffuse", "albedo", "basecolor", "base_color", "col"),
    "normal": ("nor_gl", "normal_gl", "normalgl", "normal", "nor"),
    "roughness": ("rough", "roughness"),
}
MAX_IMAGE_BYTES = 200 * 1024 * 1024
MAX_IMAGE_PIXELS = 64_000_000

def classify(name: str) -> tuple[str, int] | None:
    stem = PurePosixPath(name.lower()).stem
    if "nor_dx" in stem or "normal_dx" in stem or "directx" in stem:
        return None
    words = re.split(r"[^a-z0-9]+", stem)
    joined = "_".join(words)
    scores = {}
    for kind, aliases in MAP_ALIASES.items():
        found = [a for a in aliases if (
            a in words or a in joined or joined.endswith("_" + a))]
        if not found:
            continue
        score = max(len(a) for a in found)
        if kind == "normal" and ("nor_gl" in joined or "normal_gl" in joined):
            score += 20
        if "4k" in words or "4k" in joined:
            score += 5
        scores[kind] = score
    if not scores:
        return None
    kind = max(scores, key=scores.get)
    return kind, scores[kind]

def candidate_maps(archive: ZipFile):
    best: dict[str, tuple[int, str]] = {}
    for entry in archive.infolist():
        if entry.is_dir() or entry.file_size < 400 or entry.file_size > MAX_IMAGE_BYTES:
            continue
        path = PurePosixPath(entry.filename)
        if path.is_absolute() or ".." in path.parts or "\\" in entry.filename:
            raise ValueError("unsafe archive member")
        if path.suffix.lower() not in (".jpg", ".jpeg", ".png"):
            continue
        kind_score = classify(path.name)
        if kind_score is None:
            continue
        kind, score = kind_score
        # Prefer textures over preview/renders and highest-quality source map.
        if "texture" in entry.filename.lower():
            score += 10
        if "preview" in entry.filename.lower():
            score -= 20
        if kind not in best or score > best[kind][0]:
            best[kind] = (score, entry.filename)
    return {k: value[1] for k, value in best.items()}

def save_image(archive: ZipFile, member: str, output: Path, size: int) -> None:
    from PIL import Image
    payload = archive.read(member)
    if len(payload) > MAX_IMAGE_BYTES:
        raise ValueError("image too large")
    with Image.open(io.BytesIO(payload)) as source:
        if source.width * source.height > MAX_IMAGE_PIXELS:
            raise ValueError("unsafe image dimensions")
        image = source.copy()
    if max(image.size) > size:
        image.thumbnail((size, size), Image.Resampling.LANCZOS)
    if image.mode not in ("RGB", "L"):
        image = image.convert("RGB")
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_name(output.stem + ".temporary.jpg")
    image.save(temp, format="JPEG", quality=87, subsampling=0, optimize=True)
    temp.replace(output)

def main() -> int:
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--archives", type=Path, required=True)
    cli.add_argument("--size", type=int, choices=(512, 1024, 2048), default=1024)
    cli.add_argument("--output", type=Path, default=PROJECT / "assets/environment/remaster/textures")
    args = cli.parse_args()
    problems: list[str] = []
    count = 0
    for zipname, prefix in MATERIALS.items():
        path = args.archives / zipname
        if not path.is_file():
            print("SKIP missing: " + zipname)
            continue
        try:
            with ZipFile(path) as archive:
                chosen = candidate_maps(archive)
                for kind in MAP_ALIASES:
                    if kind not in chosen:
                        print(f"WARNING {prefix}: no compatible {kind} JPG/PNG map; fallback stays active")
                        continue
                    output = args.output / f"{prefix}_{kind}.jpg"
                    save_image(archive, chosen[kind], output, args.size)
                    count += 1
                    print(f"OK {output.name} <= {chosen[kind]}")
        except (OSError, BadZipFile, ValueError) as exc:
            problems.append(f"{zipname}: {exc}")
    for problem in problems:
        print("ERROR " + problem, file=sys.stderr)
    print(f"Installed {count} 1K/2K maps in {args.output}")
    return 1 if problems or count == 0 else 0

if __name__ == "__main__":
    sys.exit(main())
