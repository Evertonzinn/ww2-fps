#!/usr/bin/env python3
"""Tests for defensive, local-only remaster importer. Uses only stdlib."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from install_remaster_assets import safe_members, validate_gltf  # noqa: E402


class InstallerSafetyTests(unittest.TestCase):
    def test_zip_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "attack.zip"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("../../escape.gltf", "{}")
            with zipfile.ZipFile(path) as z:
                with self.assertRaisesRegex(ValueError, "unsafe"):
                    list(safe_members(z))

    def test_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "link.zip"
            with zipfile.ZipFile(path, "w") as z:
                item = zipfile.ZipInfo("scene.gltf")
                item.create_system = 3
                item.external_attr = (0o120777 << 16)
                z.writestr(item, "{}")
            with zipfile.ZipFile(path) as z:
                with self.assertRaisesRegex(ValueError, "non-regular"):
                    list(safe_members(z))

    def _scene(self, root: Path, uri: str):
        path = root / "scene.gltf"
        path.write_text(json.dumps({
            "asset": {"version": "2.0"}, "buffers": [{"uri": uri}],
            "meshes": [{"primitives": []}], "nodes": [{}],
        }), encoding="utf-8")
        return path

    def test_gltf_local_buffer_is_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "model.bin").write_bytes(b"data")
            path = self._scene(root, "model.bin")
            result = validate_gltf(path, root)
            self.assertEqual(result["mesh_count"], 1)

    def test_gltf_missing_buffer_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaisesRegex(ValueError, "missing/unsafe"):
                validate_gltf(self._scene(root, "missing.bin"), root)

    def test_gltf_external_network_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaisesRegex(ValueError, "external"):
                validate_gltf(self._scene(root, "https://evil.example/model.bin"), root)

    def test_gltf_parent_path_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "models"
            root.mkdir()
            (root.parent / "other.bin").write_bytes(b"not allowed")
            with self.assertRaisesRegex(ValueError, "missing/unsafe"):
                validate_gltf(self._scene(root, "../other.bin"), root)

    def test_non_gltf_v2_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "scene.gltf"
            path.write_text('{"asset":{"version":"1.0"}}', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "glTF 2.0"):
                validate_gltf(path, root)


if __name__ == "__main__":
    unittest.main()
