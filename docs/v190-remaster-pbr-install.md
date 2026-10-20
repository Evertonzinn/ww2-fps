# PBR asset pipeline — v0.20 (extends v0.19)

Run from the repository root:

```bash
python3 tools/install_remaster_pbr.py
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path "$PWD" --quit
```

The installer downloads up to six **verified CC0** Poly Haven materials
using its official HTTPS API. It selects 1K albedo, OpenGL normal
(NOR_GL, never NOR_DX) and roughness maps when available, follows only
allowlisted hosts, rejects downloads above 12MiB per image and does not
install Python packages. The request explicitly identifies the game
pipeline using a custom User-Agent.

Sources (Poly Haven CC0):
- https://polyhaven.com/a/cobblestone_01
- https://polyhaven.com/a/stone_wall
- https://polyhaven.com/a/plastered_wall_03
- https://polyhaven.com/a/clay_roof_tiles
- https://polyhaven.com/a/leafy_grass
- https://polyhaven.com/a/tree_bark_03

Paths under `assets/environment/remaster/textures/`:
- `cobblestone_*.jpg/png` on road and instanced cobblestones
- `stone_wall_*.jpg/png` on building foundations and rubble
- `plaster_*.jpg/png` on house walls
- `roof_tiles_*.jpg/png` on pitched roofs
- `grass_ground_*.jpg/png` on the terrain base
- `tree_bark_*.jpg/png` on tree trunks

Textures stay local/gitignored. If the source has no suitable 1K
image map, the installer logs the missing slot and Godot keeps its
existing fallback material. Runtime/exported games never perform
network requests. This only improves surfaces; it does not replace
rectangular architecture with historically accurate authored meshes.

For model integrity checks and Godot runtime smoke commands, read
`docs/v200-remaster-release.md`.
