#!/usr/bin/env python3
"""Install licensed Sketchfab glTF ZIP assets into the local Godot project.

Never downloads, modifies originals or places vendor meshes in public git.
Requires Pillow for *downscaling* textures; run offline with local archives.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import shutil
import sys
import tempfile
from pathlib import Path, PurePosixPath
from zipfile import ZipFile, BadZipFile

PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = PROJECT / "assets" / "remaster_imported"
ASSETS = {
    "stone_house.zip": "environment/stone_house",
    "french_house_ww2.zip": "environment/french_house",
    "realistic_tree.zip": "environment/realistic_tree",
    "realistic_tree_models_for_games.zip": "environment/beech_tree",
    "kar98k_mauser_karabiner_98k_bolt_action_rifle.zip": "weapons/kar98k",
    "kar98k.zip": "weapons/kar98k_scoped",
    "realistic_m1_garand.zip": "weapons/m1_garand",
    "rusty_sten_british_submachine_gun.zip": "weapons/sten",
    "thompson_submachine_gun.zip": "weapons/thompson",
    "ww2_panzergrenadier_fbx_tpose_cc0.zip": "characters/panzergrenadier_reference",
    "fps_hands_rigged_by_evolvegames.zip": "characters/fps_hands_reference",
    "animated_fps_hands_rifle_animation_pack.zip": "characters/animated_fps_hands_reference",
}
MAX_ZIP_MEMBERS = 300
MAX_MEMBER_BYTES = 512 * 1024 * 1024
MAX_TOTAL_BYTES = 3 * 1024 * 1024 * 1024
ALLOWED = {".gltf", ".bin", ".png", ".jpg", ".jpeg", ".webp", ".txt", ".md"}

def safe_members(archive: ZipFile):
    items = archive.infolist()
    if len(items) > MAX_ZIP_MEMBERS:
        raise ValueError("too many entries")
    if sum(i.file_size for i in items) > MAX_TOTAL_BYTES:
        raise ValueError("uncompressed archive too large")
    for info in items:
        if info.is_dir():
            continue
        p = PurePosixPath(info.filename)
        if p.is_absolute() or ".." in p.parts or "\\" in info.filename:
            raise ValueError("unsafe zip member: " + info.filename)
        if not p.parts or p.suffix.lower() not in ALLOWED:
            raise ValueError("unexpected entry: " + info.filename)
        if info.file_size > MAX_MEMBER_BYTES:
            raise ValueError("oversized member: " + info.filename)
        # Refuse special files and symlinks; ordinary ZIPs often have no UNIX mode.
        mode = (info.external_attr >> 16) & 0o170000
        if mode not in (0, 0o100000):
            raise ValueError("non-regular file: " + info.filename)
        yield info

def validate_gltf(scene_file: Path) -> dict:
    data = json.loads(scene_file.read_text(encoding="utf-8"))
    if data.get("asset", {}).get("version") != "2.0":
        raise ValueError("not a glTF 2.0 asset")
    # All external refs must stay within this isolated asset folder.
    for obj in data.get("buffers", []) + data.get("images", []):
        uri = obj.get("uri")
        if not isinstance(uri, str) or uri.startswith("data:"):
            continue
        if "%" in uri:
            from urllib.parse import unquote
            uri = unquote(uri)
        if uri.startswith(("http:", "https:", "/", "\\")):
            raise ValueError("external resource URL/path rejected: " + uri)
        rel = posixpath.normpath(uri)
        if rel == ".." or rel.startswith("../") or not (scene_file.parent / rel).is_file():
            raise ValueError("missing/unsafe referenced file: " + uri)
    return {
        "mesh_count": len(data.get("meshes", [])),
        "skin_count": len(data.get("skins", [])),
        "animation_count": len(data.get("animations", [])),
        "node_count": len(data.get("nodes", [])),
    }

def optimize_texture(src: Path, dst: Path, max_side: int, image_lib):
    from PIL import Image
    with Image.open(src) as original:
        original.load()
        image = original.copy()
    if max(image.size) > max_side:
        image.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.suffix.lower() in (".jpg", ".jpeg"):
        if image.mode not in ("RGB", "L"):
            image = image.convert("RGB")
        image.save(dst, quality=86, subsampling=0, optimize=True)
    elif src.suffix.lower() == ".webp":
        image.save(dst, format="WEBP", quality=85, method=5)
    else:
        image.save(dst, format="PNG", optimize=True, compress_level=6)
    return {"width": image.width, "height": image.height}

def install_one(archive_path: Path, dest: Path, max_side: int, image_lib) -> dict:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ww2-asset-", dir=dest.parent) as td:
        temp = Path(td)
        with ZipFile(archive_path) as archive:
            members = list(safe_members(archive))
            names = {x.filename for x in members}
            license_name = next((n for n in names if n.lower().endswith("license.txt")), None)
            if not license_name:
                raise ValueError("Sketchfab asset missing license.txt")
            license_text = archive.read(license_name).decode("utf-8", errors="replace")
            if "CC-BY-4.0" not in license_text and "creativecommons.org/licenses/by/4.0" not in license_text:
                raise ValueError("unexpected/unsupported asset license")
            for member in members:
                out = temp / member.filename
                out.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(member) as stream, out.open("wb") as target:
                    shutil.copyfileobj(stream, target, 1024 * 1024)
        scenes = list(temp.rglob("*.gltf"))
        if len(scenes) != 1:
            raise ValueError("expected exactly one glTF scene, got %d" % len(scenes))
        details = validate_gltf(scenes[0])
        if scenes[0].parent != temp:
            raise ValueError("model scene needs root-level scene.gltf")
        texture_info = {}
        for source in list(temp.rglob("*")):
            if not source.is_file() or source.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
                continue
            output = source.with_name(source.stem + ".ww2_tmp" + source.suffix)
            texture_info[source.relative_to(temp).as_posix()] = optimize_texture(
                source, output, max_side, image_lib)
            output.replace(source)
        details["textures"] = texture_info
        details["license"] = "CC BY 4.0"
        details["source_file"] = archive_path.name
        digest = hashlib.sha256()
        with archive_path.open("rb") as original_zip:
            for chunk in iter(lambda: original_zip.read(1024 * 1024), b""):
                digest.update(chunk)
        details["sha256_zip"] = digest.hexdigest()
        # Place only *validated*, complete packages. Never overwrite the
        # existing verified installation until the replacement is ready.
        old = dest.with_name(dest.name + ".previous")
        if old.exists():
            shutil.rmtree(old)
        if dest.exists():
            dest.rename(old)
        try:
            temp.rename(dest)
            if old.exists():
                shutil.rmtree(old)
        except Exception:
            if old.exists() and not dest.exists():
                old.rename(dest)
            raise
        return details

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archives", type=Path, required=True,
                        help="directory with downloaded original ZIPs")
    parser.add_argument("--texture-size", type=int, choices=(512, 1024, 2048),
                        default=1024)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        import PIL
    except ImportError:
        print("ERROR: Pillow required for safe texture optimization (pip install Pillow)", file=sys.stderr)
        return 2
    if not args.archives.is_dir():
        print("ERROR: archive directory does not exist", file=sys.stderr)
        return 2
    manifest = {}
    installed = 0
    for archive_name, relative in ASSETS.items():
        archive_path = args.archives / archive_name
        if not archive_path.is_file():
            print("SKIP: %s not supplied" % archive_name)
            continue
        try:
            details = install_one(archive_path, args.output / relative, args.texture_size, PIL)
            manifest[relative] = details
            installed += 1
            print("OK: %s -> %s (%d meshes, %d skins, %d animations)" % (
                archive_name, relative, details["mesh_count"],
                details["skin_count"], details["animation_count"]))
            if "panzergrenadier_reference" in relative and details["skin_count"] == 0:
                print("NOTICE: Panzergrenadier T-pose is NON-RIGGED; do not swap live enemy rig")
        except (OSError, ValueError, BadZipFile, json.JSONDecodeError) as exc:
            print("ERROR: %s: %s" % (archive_name, exc), file=sys.stderr)
            return 1
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "asset_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("Installed %d glTF packages. Restart Godot editor to import .gltf scenes." % installed)
    return 0 if installed else 2

if __name__ == "__main__":
    sys.exit(main())
