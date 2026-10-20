# PBR asset pipeline — v0.19

Run from the repository root:

```bash
python3 tools/install_remaster_pbr.py
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
```

The installer uses HTTPS and the Poly Haven **official API** to choose
1K OpenGL normal, diffuse and roughness maps for two **verified CC0**
sources, `cobblestone_01` and `stone_wall`. It verifies allowed
hosts, refuses downloads >12MiB and never installs Python packages.
The files stay local/gitignored. The game runs without them, but
will use real PBR textures when they exist.

Source pages:
- https://polyhaven.com/a/cobblestone_01
- https://polyhaven.com/a/stone_wall

Material slot mapping:
- `cobblestone_*.jpg` on road and instanced stones
- `stone_wall_*.jpg` on building foundations and rubble
- Optional user-provided `plaster_*.jpg` and `roof_tiles_*.jpg`

Fallback: Godot's existing materials, plus improved low-poly visual
geometry. No API requests at runtime or on players' computers when
running the exported game. Assets are fetched only once by the
developer's explicit local command.
