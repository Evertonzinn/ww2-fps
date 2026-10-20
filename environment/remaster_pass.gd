extends RefCounted

# WW2 FPS REMASTER v0.19: real scene geometry and PBR material support.
# Runs on GL Compatibility (GT 730). No GI/SSAO/volumetric shader needed.
# All added details are VISUAL-ONLY so tested tactical cover, collision,
# bullets, player movement and enemy spawn coordinates do not change.
const PBR_DIR: String = "res://assets/environment/remaster/textures/"
const TREE_NAMES = ["TreeWest", "TreeEast"]

static func populate(world: Node3D) -> void:
	if world.has_node("RemasterEnvironment"):
		return
	var root: Node3D = Node3D.new()
	root.name = "RemasterEnvironment"
	world.add_child(root)
	_upgrade_materials(world)
	_make_cobblestones(root)
	var greenery: StandardMaterial3D = _cutout_leaves(Color(0.32, 0.40, 0.21))
	var grass: StandardMaterial3D = _cutout_grass()
	_rebuild_trees(world, greenery)
	_make_grass(root, grass)
	_make_hedgerows(root, greenery)
	_make_rubble(root)
	print("WW2 FPS REMASTER READY: instanced cobblestones, vegetation, shrubs and material slots")

static func _load_texture(name: String) -> Texture2D:
	var path: String = PBR_DIR + name
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D

static func _pbr(name: String, tint: Color, uv_repeat: Vector3) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = tint
	result.metallic = 0.0
	result.roughness = 0.90
	result.uv1_scale = uv_repeat
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var albedo: Texture2D = _load_texture(name + "_albedo.jpg")
	if albedo == null:
		albedo = _load_texture(name + "_albedo.png")
	if albedo == null:
		return null
	result.albedo_texture = albedo
	var normal_tex: Texture2D = _load_texture(name + "_normal.jpg")
	if normal_tex == null:
		normal_tex = _load_texture(name + "_normal.png")
	if normal_tex != null:
		result.normal_enabled = true
		result.normal_texture = normal_tex
	var rough_tex: Texture2D = _load_texture(name + "_roughness.jpg")
	if rough_tex == null:
		rough_tex = _load_texture(name + "_roughness.png")
	if rough_tex != null:
		result.roughness_texture = rough_tex
	return result

static func _upgrade_materials(world: Node3D) -> void:
	# When real CC0 Poly Haven maps are installed, they replace simple
	# 48px noise materials without altering collision or geometry.
	var cobble: StandardMaterial3D = _pbr("cobblestone", Color(0.79, 0.76, 0.71), Vector3(3.5, 14.0, 1.0))
	var stone: StandardMaterial3D = _pbr("stone_wall", Color(0.85, 0.82, 0.77), Vector3(2.0, 2.0, 1.0))
	var plaster: StandardMaterial3D = _pbr("plaster", Color(0.88, 0.82, 0.72), Vector3(1.2, 1.5, 1.0))
	var roof: StandardMaterial3D = _pbr("roof_tiles", Color(0.75, 0.56, 0.50), Vector3(2.5, 2.0, 1.0))
	var ground: StandardMaterial3D = _pbr("grass_ground", Color(0.83, 0.90, 0.80), Vector3(20.0, 20.0, 1.0))
	var bark: StandardMaterial3D = _pbr("tree_bark", Color(0.85, 0.79, 0.70), Vector3(1.0, 3.0, 1.0))
	if ground != null:
		var terrain: MeshInstance3D = world.get_node_or_null("Ground/MeshInstance3D") as MeshInstance3D
		if terrain != null:
			terrain.material_override = ground
	if bark != null:
		for tree_name in TREE_NAMES:
			var tree: Node3D = world.get_node_or_null(tree_name) as Node3D
			if tree != null:
				for child in tree.get_children():
					if child is MeshInstance3D and (child as MeshInstance3D).mesh is CylinderMesh:
						(child as MeshInstance3D).material_override = bark
	if cobble != null:
		var road: MeshInstance3D = world.get_node_or_null("Road") as MeshInstance3D
		if road != null:
			road.material_override = cobble
	if stone != null or plaster != null or roof != null:
		for building in ["LeftHouseA", "LeftHouseB", "RightHouseA", "RightHouseB"]:
			var house: Node3D = world.get_node_or_null(building) as Node3D
			if house == null:
				continue
			if plaster != null:
				var outer: MeshInstance3D = house.get_node_or_null("MeshInstance3D") as MeshInstance3D
				if outer != null:
					outer.material_override = plaster
			if stone != null:
				for part in house.get_children():
					if part is MeshInstance3D:
						var visual: MeshInstance3D = part as MeshInstance3D
						if visual.name.begins_with("Foundation") or visual.name.begins_with("CornerBeam") or visual.name.begins_with("WindowSill"):
							visual.material_override = stone
			if roof != null:
				var roof_mesh: MeshInstance3D = house.get_node_or_null("PitchedRoof") as MeshInstance3D
				if roof_mesh != null:
					roof_mesh.material_override = roof

static func _make_cobblestones(root: Node3D) -> void:
	# Irregular rounded setts rather than giant flat asphalt blocks.
	# 1 draw call for the whole road; ~1100 low-poly stones.
	var stone_mesh: SphereMesh = SphereMesh.new()
	stone_mesh.radius = 0.5
	stone_mesh.height = 1.0
	stone_mesh.radial_segments = 6
	stone_mesh.rings = 2
	var pbr: StandardMaterial3D = _pbr("cobblestone", Color.WHITE, Vector3.ONE)
	if pbr == null:
		pbr = StandardMaterial3D.new()
		pbr.albedo_color = Color(0.55, 0.52, 0.47)
		pbr.roughness = 0.94
	pbr.vertex_color_use_as_albedo = true
	stone_mesh.material = pbr
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = stone_mesh
	const COLS: int = 16
	const ROWS: int = 72
	mm.instance_count = COLS * ROWS
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 19440606
	var id: int = 0
	for row in range(ROWS):
		for col in range(COLS):
			var offset: float = 0.5 if row % 2 == 0 else 0.0
			var x: float = (float(col) - 7.5 + offset * 0.6) * 0.43
			var z: float = (float(row) - 35.5) * 0.52
			x += rng.randf_range(-0.055, 0.055)
			z += rng.randf_range(-0.052, 0.052)
			var yaw: float = rng.randf_range(-0.08, 0.08)
			var mat: Basis = Basis(Vector3.UP, yaw)
			mat = mat.scaled(Vector3(
				rng.randf_range(0.33, 0.40), 0.032,
				rng.randf_range(0.44, 0.51)))
			mm.set_instance_transform(id, Transform3D(mat, Vector3(x, 0.047, z)))
			var tint: float = rng.randf_range(0.72, 1.03)
			mm.set_instance_color(id, Color(tint, tint * 0.98, tint * 0.92))
			id += 1
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "RemasterCobblestones"
	node.multimesh = mm
	root.add_child(node)

static func _leaf_image(grass_variant: bool) -> ImageTexture:
	# Cutout atlas is generated on CPU once. Masked, irregular foliage,
	# unlike the previous solid spherical crowns.
	var size: int = 96
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var seed: int = 34 if grass_variant else 128
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.075
	for y in range(size):
		for x in range(size):
			var uv: Vector2 = Vector2(float(x) / 95.0, float(y) / 95.0)
			var n: float = noise.get_noise_2d(float(x), float(y))
			var present: bool = false
			if grass_variant:
				# Several pointed blades rising from the ground.
				for blade in range(6):
					var base_x: float = 0.23 + float(blade) * 0.105
					var top_x: float = base_x + (float(blade) - 2.5) * 0.055
					var apex: float = 0.12 + float(blade % 3) * 0.10
					var t: float = clampf((uv.y - apex) / maxf(0.01, 1.0 - apex), 0.0, 1.0)
					var center: float = lerpf(top_x, base_x, t)
					var width: float = 0.007 + t * 0.045
					if uv.y >= apex and absf(uv.x - center) < width:
						present = true
			else:
				# Three overlapping irregular leaf silhouettes.
				for leaf in range(3):
					var center: Vector2 = Vector2(0.26 + float(leaf) * 0.24, 0.38 + float(leaf % 2) * 0.12)
					var d: Vector2 = (uv - center) / Vector2(0.30, 0.34)
					if d.length() < 0.88 + n * 0.24:
						present = true
			if present:
				var tone: float = clampf(0.78 + n * 0.21, 0.43, 1.0)
				img.set_pixel(x, y, Color(tone, tone * 0.95, tone * 0.79, 1.0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

static func _cutout_leaves(base: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = base
	mat.albedo_texture = _leaf_image(false)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.50
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = true
	return mat

static func _cutout_grass() -> StandardMaterial3D:
	var mat: StandardMaterial3D = _cutout_leaves(Color(0.34, 0.42, 0.20))
	mat.albedo_texture = _leaf_image(true)
	return mat

static func _multifoliage(parent: Node3D, name: String, positions: Array[Vector3],
		mat: StandardMaterial3D, blade_scale: Vector3, deterministic_seed: int) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = positions.size() * 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = deterministic_seed
	for i in range(positions.size()):
		for cross in range(2):
			var yaw: float = rng.randf_range(-PI, PI) + float(cross) * PI * 0.5
			var scale: float = rng.randf_range(0.75, 1.25)
			var basis: Basis = Basis(Vector3.UP, yaw).scaled(blade_scale * scale)
			var loc: Vector3 = positions[i]
			mm.set_instance_transform(i * 2 + cross, Transform3D(basis, loc))
			var tone: float = rng.randf_range(0.72, 1.06)
			mm.set_instance_color(i * 2 + cross, Color(tone, tone * 1.05, tone * 0.87))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = mm
	parent.add_child(node)

static func _rebuild_trees(world: Node3D, leaf: StandardMaterial3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 194405
	for tree_name in TREE_NAMES:
		var tree: Node3D = world.get_node_or_null(tree_name) as Node3D
		if tree == null:
			continue
		for child in tree.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
				(child as MeshInstance3D).visible = false
		var foliage: Array[Vector3] = []
		for i in range(105):
			var angle: float = rng.randf_range(0.0, TAU)
			var radius: float = sqrt(rng.randf()) * 1.90
			var height: float = 3.2 + rng.randf_range(-0.42, 0.70) + (1.0 - radius / 1.9) * 0.57
			foliage.append(Vector3(cos(angle) * radius, height, sin(angle) * radius))
		_multifoliage(tree, "RemasterLeafClusters", foliage, leaf,
			Vector3(1.10, 1.06, 1.0), rng.randi())

static func _make_grass(root: Node3D, mat: StandardMaterial3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 194408
	var grass: Array[Vector3] = []
	for i in range(520):
		var x: float = rng.randf_range(4.9, 11.4)
		if i % 2 == 0:
			x = -x
		var z: float = rng.randf_range(-18.8, 18.8)
		grass.append(Vector3(x, rng.randf_range(0.08, 0.16), z))
	_multifoliage(root, "RemasterGrassTufts", grass, mat,
		Vector3(0.28, 0.48, 1.0), 65537)

static func _make_hedgerows(root: Node3D, mat: StandardMaterial3D) -> void:
	var shrubs: Array[Vector3] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1920
	for side in [-1, 1]:
		for i in range(48):
			# Keep passageways and tactical centre lane clear.
			var x: float = float(side) * rng.randf_range(7.95, 9.15)
			var z: float = -18.0 + float(i) * 0.77
			shrubs.append(Vector3(x, rng.randf_range(0.43, 0.95), z))
	_multifoliage(root, "RemasterHedgerows", shrubs, mat,
		Vector3(0.84, 1.18, 1.0), 2044)

static func _make_rubble(root: Node3D) -> void:
	var stone: StandardMaterial3D = _pbr("stone_wall", Color(0.70, 0.69, 0.63), Vector3.ONE)
	if stone == null:
		stone = StandardMaterial3D.new()
		stone.albedo_color = Color(0.42, 0.40, 0.36)
		stone.roughness = 0.98
	stone.vertex_color_use_as_albedo = true
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.50
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 2
	mesh.material = stone
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 180
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(mm.instance_count):
		var x: float = rng.randf_range(5.0, 10.8)
		if i % 2 == 0:
			x = -x
		var z: float = rng.randf_range(-18.0, 18.0)
		var r: float = rng.randf_range(0.12, 0.45)
		var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3(r, r * 0.35, r * 0.75))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.12, z)))
		var tone: float = rng.randf_range(0.64, 1.08)
		mm.set_instance_color(i, Color(tone, tone * 0.96, tone * 0.9))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "RemasterScatteredStones"
	node.multimesh = mm
	root.add_child(node)
