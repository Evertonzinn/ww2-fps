#!/usr/bin/env python3
"""Install 1K CC0 Poly Haven textures for the Godot 4 GL remaster.

No packages required. Requires Python 3 with HTTPS connectivity.
Fetches exact assets through Poly Haven's published API; refuses
redirects to unknown hosts or excessively large assets.
"""
from __future__ import annotations

import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ASSETS = {
    "cobblestone": "cobblestone_01",
    "stone_wall": "stone_wall",
}
MAPS = {
    "albedo": ("diffuse", "diff", "albedo", "basecolor", "base_color"),
    "normal": ("nor_gl", "normal_gl", "normalgl", "normal", "nor"),
    "roughness": ("rough", "roughness"),
}
OUTPUT = Path(__file__).resolve().parent.parent / "assets/environment/remaster/textures"
MAX_BYTES = 12 * 1024 * 1024
API = "https://api.polyhaven.com/files/"

def _safe_url(url: str) -> str:
    p = urllib.parse.urlsplit(url)
    if p.scheme != "https" or not (
        p.hostname == "dl.polyhaven.org"
        or p.hostname == "cdn.polyhaven.com"
        or p.hostname == "api.polyhaven.com"
    ):
        raise RuntimeError("unexpected Poly Haven asset host: " + url)
    return url

def _json(url: str) -> object:
    request = urllib.request.Request(url, headers={"User-Agent": "WW2FPS-Remaster/0.20"})
    with urllib.request.urlopen(request, timeout=30) as r:
        return json.load(r)

def _leaf_urls(obj: object, trail: tuple[str, ...] = ()) -> list[tuple[tuple[str, ...], str]]:
    found: list[tuple[tuple[str, ...], str]] = []
    if isinstance(obj, dict):
        if isinstance(obj.get("url"), str):
            found.append((trail, obj["url"]))
        for key, val in obj.items():
            if key != "url":
                found.extend(_leaf_urls(val, trail + (str(key).lower(),)))
    elif isinstance(obj, list):
        for val in obj:
            found.extend(_leaf_urls(val, trail))
    return found

def _choose(data: object, kind: str) -> tuple[str, str] | None:
    aliases = MAPS[kind]
    # Prefer exact map matching on metadata paths over weak URL matching.
    entries: list[tuple[int, str, str]] = []
    for trail, url in _leaf_urls(data):
        words = [re.sub("[^a-z0-9_]", "", t) for t in trail]
        joined = "/".join(words)
        map_candidates = [i for i, w in enumerate(words) if any(
            w == alias or w.startswith(alias + "_") for alias in aliases)]
        if not map_candidates:
            continue
        # A normal encoded for DirectX is NOT correct for Godot; require OpenGL.
        if kind == "normal" and any("nor_dx" in w or "directx" in w for w in words):
            continue
        if "1k" not in joined and "1024" not in joined:
            continue
        suffix = Path(urllib.parse.urlsplit(url).path).suffix.lower()
        if suffix not in (".jpg", ".jpeg", ".png"):
            continue
        score = (15 if "1k" in joined else 0) + (8 if suffix == ".jpg" else 4)
        if kind == "normal" and "nor_gl" in joined:
            score += 10
        entries.append((score, url, ".jpg" if suffix in (".jpg", ".jpeg") else ".png"))
    if not entries:
        return None
    entries.sort(key=lambda x: x[0], reverse=True)
    return entries[0][1], entries[0][2]

def _save(url: str, dest: Path) -> int:
    _safe_url(url)
    # urllib redirects are validated again against the effective host.
    request = urllib.request.Request(url, headers={"User-Agent": "WW2FPS-Remaster/0.19"})
    with urllib.request.urlopen(request, timeout=90) as response:
        _safe_url(response.url)
        size = int(response.headers.get("Content-Length", "0"))
        if size > MAX_BYTES:
            raise RuntimeError("download exceeds 12MiB: " + url)
        payload = response.read(MAX_BYTES + 1)
    if len(payload) > MAX_BYTES or len(payload) < 400:
        raise RuntimeError("unexpected texture size: " + url)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(payload)
    return len(payload)

def main() -> int:
    print("Poly Haven CC0 PBR material installer — Godot Compatibility 1K")
    errors = 0
    done = 0
    for alias, asset_id in ASSETS.items():
        print(f"\nAsset: {asset_id} -> {alias}")
        try:
            data = _json(API + asset_id)
        except Exception as exc:
            print(f"  API ERROR: {exc}", file=sys.stderr)
            errors += 1
            continue
        for map_name in MAPS:
            selected = _choose(data, map_name)
            if selected is None:
                print(f"  WARNING: no {map_name} 1K jpg/png found")
                if map_name == "albedo":
                    errors += 1
                continue
            url, suffix = selected
            dest = OUTPUT / (alias + "_" + map_name + suffix)
            if dest.is_file() and dest.stat().st_size > 400:
                print("  exists: " + dest.name)
                done += 1
                continue
            try:
                size = _save(url, dest)
                print(f"  OK: {dest.name} ({size} B)")
                done += 1
            except Exception as exc:
                print(f"  ERROR: {map_name}: {exc}", file=sys.stderr)
                errors += 1
    print(f"\nFinished: {done} maps available, {errors} problems")
    print("Reimport via Godot --headless --editor --path \"$PWD\" --quit")
    return 1 if errors else 0

if __name__ == "__main__":
    raise SystemExit(main())
