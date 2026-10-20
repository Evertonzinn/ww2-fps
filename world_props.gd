extends Node3D

const VillageProps = preload("res://environment/prop_builder.gd")
const EnemySoldierScene = preload("res://enemy_soldier.tscn")

# Vila de testes gerada em tempo de execucao: sem downloads, texturas ou assets externos.
var stone: StandardMaterial3D
var plaster: StandardMaterial3D
var plaster_warm: StandardMaterial3D
var brick: StandardMaterial3D
var timber: StandardMaterial3D
var window_dark: StandardMaterial3D
var asphalt: StandardMaterial3D
var grass: StandardMaterial3D

func _ready() -> void:
	_setup_daylight()
	stone = _textured_material(Color(0.60, 0.56, 0.49), 17)
	plaster = _textured_material(Color(0.84, 0.77, 0.64), 29)
	plaster_warm = _textured_material(Color(0.93, 0.76, 0.59), 37)
	brick = _textured_material(Color(0.55, 0.29, 0.23), 48)
	timber = _textured_material(Color(0.39, 0.26, 0.16), 55)
	window_dark = _material(Color(0.12, 0.19, 0.23))
	asphalt = _textured_material(Color(0.42, 0.40, 0.36), 63)
	grass = _textured_material(Color(0.43, 0.47, 0.32), 72)

	var ground_mesh: MeshInstance3D = get_node("Ground/MeshInstance3D") as MeshInstance3D
	ground_mesh.material_override = grass

	# Estrada e acostamentos sem colisoes extras.
	_visual_box(self, "Road", Vector3(0, 0.014, 0), Vector3(8.0, 0.026, 39.0), asphalt)
	_visual_box(self, "SidewalkLeft", Vector3(-4.5, 0.045, 0), Vector3(1.0, 0.09, 39.0), stone)
	_visual_box(self, "SidewalkRight", Vector3(4.5, 0.045, 0), Vector3(1.0, 0.09, 39.0), stone)
	_street_paving()

	_house("LeftHouseA", -12.0, -10.0, plaster)
	_house("LeftHouseB", -12.0, 4.0, plaster_warm)
	_house("RightHouseA", 12.0, -10.0, plaster_warm)
	_house("RightHouseB", 12.0, 4.0, plaster)

	# Coberturas laterais: o corredor dos alvos continua desobstruido.
	_static_box("SandbagLeft", Vector3(-5.8, 0.55, -3.5), Vector3(2.1, 1.1, 0.85), stone)
	_static_box("SandbagRight", Vector3(5.8, 0.55, -5.5), Vector3(2.0, 1.1, 0.85), stone)
	_static_box("SupplyCrateA", Vector3(-6.0, 0.54, 2.0), Vector3(1.05, 1.08, 1.05), timber)
	_static_box("SupplyCrateB", Vector3(6.0, 0.54, -1.0), Vector3(1.05, 1.08, 1.05), timber)
	_barrel("BarrelLeft", Vector3(-6.7, 0.52, -5.5))
	_barrel("BarrelRight", Vector3(6.7, 0.52, 4.0))
	_tree("TreeWest", Vector3(-18.0, 0.0, 12.0))
	_tree("TreeEast", Vector3(18.0, 0.0, -17.0))
	VillageProps.populate(self, stone, timber, grass, brick)
	# Defer instantiation until the World finishes its setup and child ready pass.
	call_deferred("_spawn_initial_enemy")
	print("WW2 FPS world: enemy spawn scheduled")

func _spawn_initial_enemy() -> void:
	# Idempotent: levels with an authored enemy won't create a duplicate.
	var existing: Node3D = get_node_or_null("EnemySoldierTest") as Node3D
	if existing != null:
		print("WW2 FPS world: EnemySoldierTest already in tree at ", existing.global_position)
		return
	var soldier: Node3D = EnemySoldierScene.instantiate() as Node3D
	if soldier == null:
		push_error("WW2 FPS world: cannot instantiate res://enemy_soldier.tscn")
		return
	soldier.name = "EnemySoldierTest"
	soldier.position = Vector3(1.0, 0.0, -4.0)
	soldier.rotation.y = PI
	add_child(soldier)
	print("WW2 FPS world: EnemySoldierTest added to SceneTree at ", soldier.global_position)

func _material(tint: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	return material

func _visual_box(parent_node: Node3D, node_name: String, offset: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = dimensions
	visual.mesh = box
	visual.material_override = surface
	visual.position = offset
	parent_node.add_child(visual)
	return visual

func _static_box(node_name: String, world_position: Vector3, dimensions: Vector3, surface: Material) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = world_position
	add_child(body)

	_visual_box(body, "MeshInstance3D", Vector3.ZERO, dimensions, surface)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	return body

func _house(node_name: String, x: float, z: float, wall_material: Material) -> void:
	var house: StaticBody3D = _static_box(node_name, Vector3(x, 2.35, z), Vector3(5.6, 4.7, 5.8), wall_material)
	var face: float = 1.0 if x < 0.0 else -1.0
	var facade_x: float = face * 2.84

	# Telhado em duas aguas: inclinacao corrigida para a cumeeira ficar no topo.
	_create_pitched_roof(house, wall_material)
	_visual_box(house, "RoofRidge", Vector3(0, 3.45, 0), Vector3(0.12, 0.12, 6.40), timber)
	_visual_box(house, "FasciaLeft", Vector3(-3.14, 2.27, 0), Vector3(0.15, 0.18, 6.45), timber)
	_visual_box(house, "FasciaRight", Vector3(3.14, 2.27, 0), Vector3(0.15, 0.18, 6.45), timber)
	var chimney_x: float = -1.45 if x < 0.0 else 1.45
	_visual_box(house, "Chimney", Vector3(chimney_x, 3.42, 1.10), Vector3(0.55, 1.50, 0.55), brick)
	_visual_box(house, "ChimneyCap", Vector3(chimney_x, 4.21, 1.10), Vector3(0.72, 0.13, 0.72), stone)

	# Fachada: embasamento, porta, batente e emolduramento real das duas janelas.
	_visual_box(house, "Foundation", Vector3(facade_x, -2.13, 0), Vector3(0.16, 0.48, 5.92), stone)
	_visual_box(house, "Cornice", Vector3(facade_x, 2.17, 0), Vector3(0.18, 0.20, 5.94), stone)
	_visual_box(house, "Door", Vector3(facade_x - face * 0.08, -1.31, 0), Vector3(0.12, 2.05, 1.10), timber)
	_visual_box(house, "DoorJambLeft", Vector3(facade_x + face * 0.14, -1.30, -0.62), Vector3(0.20, 2.23, 0.13), stone)
	_visual_box(house, "DoorJambRight", Vector3(facade_x + face * 0.14, -1.30, 0.62), Vector3(0.20, 2.23, 0.13), stone)
	_visual_box(house, "DoorHeader", Vector3(facade_x + face * 0.04, -0.19, 0), Vector3(0.15, 0.18, 1.27), stone)
	_visual_box(house, "DoorHandle", Vector3(facade_x + face * 0.10, -1.36, 0.37), Vector3(0.08, 0.08, 0.08), stone)

	for window_index in range(2):
		var window_z: float = -1.65 if window_index == 0 else 1.65
		var window_x: float = facade_x + face * 0.045
		_visual_box(house, "Glass%d" % window_index, Vector3(window_x, 0.67, window_z), Vector3(0.11, 1.00, 0.87), window_dark)
		_visual_box(house, "WindowTop%d" % window_index, Vector3(window_x + face * 0.05, 1.21, window_z), Vector3(0.16, 0.11, 1.03), stone)
		_visual_box(house, "WindowSill%d" % window_index, Vector3(window_x + face * 0.07, 0.10, window_z), Vector3(0.22, 0.10, 1.10), stone)
		_visual_box(house, "WindowMullion%d" % window_index, Vector3(window_x + face * 0.06, 0.67, window_z), Vector3(0.12, 1.05, 0.06), timber)
		_visual_box(house, "ShutterLeft%d" % window_index, Vector3(window_x, 0.69, window_z - 0.59), Vector3(0.13, 1.03, 0.25), timber)
		_visual_box(house, "ShutterRight%d" % window_index, Vector3(window_x, 0.69, window_z + 0.59), Vector3(0.13, 1.03, 0.25), timber)
		# Uma das casas tem janela improvisadamente fechada com tabuas.
		if x > 0.0 and z < 0.0 and window_index == 0:
			for plank in range(3):
				_visual_box(house, "Board%d" % plank, Vector3(window_x + face * 0.17, 0.34 + float(plank) * 0.31, window_z), Vector3(0.11, 0.12, 1.1), timber)

	# Vigas nas extremidades quebram a aparencia de cubos sem aumentar a colisao.
	for beam_index in range(2):
		var beam_z: float = -2.65 if beam_index == 0 else 2.65
		_visual_box(house, "CornerBeam%d" % beam_index, Vector3(facade_x + face * 0.05, 0.06, beam_z), Vector3(0.15, 4.15, 0.16), stone)

func _setup_daylight() -> void:
	# Cor ambiente e fundo leve para o OpenGL Compatibility / GT 730.
	# Sem GI dinamica, SSAO, glow ou sombras de alta resolucao.
	var env_resource: Environment = Environment.new()
	env_resource.background_mode = Environment.BG_COLOR
	env_resource.background_color = Color(0.60, 0.72, 0.83)
	env_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_resource.ambient_light_color = Color(0.84, 0.86, 0.88)
	env_resource.ambient_light_sky_contribution = 0.0
	env_resource.ambient_light_energy = 0.75

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "DaylightEnvironment"
	world_environment.environment = env_resource
	add_child(world_environment)

	var sun: DirectionalLight3D = get_node("DirectionalLight3D") as DirectionalLight3D
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.2
	sun.shadow_enabled = false

func _textured_material(base: Color, texture_seed: int) -> StandardMaterial3D:
	# Textura de 48x48 gerada uma unica vez, sem assets externos.
	var image: Image = Image.create(48, 48, false, Image.FORMAT_RGB8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = texture_seed
	noise.frequency = 0.18
	for y in range(48):
		for x in range(48):
			var n: float = clampf((noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5, 0.0, 1.0)
			var value: float = lerpf(0.82, 1.0, n)
			image.set_pixel(x, y, Color(value, value, value))
	var material: StandardMaterial3D = _material(base)
	material.albedo_texture = ImageTexture.create_from_image(image)
	return material

func _street_paving() -> void:
	# Multimesh: dezenas de pedras laterais com uma chamada de desenho.
	var paver_mesh: BoxMesh = BoxMesh.new()
	paver_mesh.size = Vector3(0.58, 0.025, 0.78)
	paver_mesh.material = _material(Color(0.53, 0.49, 0.42))
	var stones: MultiMesh = MultiMesh.new()
	stones.transform_format = MultiMesh.TRANSFORM_3D
	stones.mesh = paver_mesh
	stones.instance_count = 64
	for i in range(32):
		var z_pos: float = -17.7 + float(i) * 1.13
		stones.set_instance_transform(i * 2, Transform3D(Basis(), Vector3(-3.5, 0.034, z_pos)))
		stones.set_instance_transform(i * 2 + 1, Transform3D(Basis(), Vector3(3.5, 0.034, z_pos + 0.48)))
	var paving: MultiMeshInstance3D = MultiMeshInstance3D.new()
	paving.name = "RoadSidePaving"
	paving.multimesh = stones
	add_child(paving)

func _barrel(node_name: String, world_position: Vector3) -> void:
	var barrel: StaticBody3D = StaticBody3D.new()
	barrel.name = node_name
	barrel.position = world_position
	add_child(barrel)

	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.37
	cylinder.bottom_radius = 0.37
	cylinder.height = 1.04
	cylinder.radial_segments = 10
	var barrel_mesh: MeshInstance3D = MeshInstance3D.new()
	barrel_mesh.mesh = cylinder
	barrel_mesh.material_override = _material(Color(0.25, 0.32, 0.35))
	barrel.add_child(barrel_mesh)

	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.37
	shape.height = 1.04
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	barrel.add_child(collision)

	var band: Material = _material(Color(0.13, 0.15, 0.16))
	_visual_box(barrel, "BandFront", Vector3(0, 0.38, 0.36), Vector3(0.70, 0.08, 0.04), band)
	_visual_box(barrel, "BandBack", Vector3(0, -0.38, 0.36), Vector3(0.70, 0.08, 0.04), band)

func _tree(node_name: String, world_position: Vector3) -> void:
	var tree: Node3D = Node3D.new()
	tree.name = node_name
	tree.position = world_position
	add_child(tree)

	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.24
	trunk.height = 3.2
	trunk.radial_segments = 7
	var trunk_visual: MeshInstance3D = MeshInstance3D.new()
	trunk_visual.mesh = trunk
	trunk_visual.material_override = timber
	trunk_visual.position.y = 1.6
	tree.add_child(trunk_visual)

	var crown: SphereMesh = SphereMesh.new()
	crown.radius = 1.5
	crown.height = 2.9
	crown.radial_segments = 8
	crown.rings = 4
	var crown_visual: MeshInstance3D = MeshInstance3D.new()
	crown_visual.mesh = crown
	crown_visual.material_override = _material(Color(0.27, 0.38, 0.24))
	crown_visual.position.y = 3.6
	tree.add_child(crown_visual)


func _create_pitched_roof(house: Node3D, wall_material: Material) -> void:
	# Um telhado com aguas realmente inclinadas em vez de BoxMesh rotacionado.
	# Mantemos a colisao simplificada do edificio para nao penalizar a GPU/CPU.
	var roof_surface: SurfaceTool = SurfaceTool.new()
	roof_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z_front: float = -3.18
	var z_back: float = 3.18
	var west_front := Vector3(-3.22, 2.30, z_front)
	var west_back := Vector3(-3.22, 2.30, z_back)
	var ridge_front := Vector3(0, 3.44, z_front)
	var ridge_back := Vector3(0, 3.44, z_back)
	var east_front := Vector3(3.22, 2.30, z_front)
	var east_back := Vector3(3.22, 2.30, z_back)
	_add_roof_quad(roof_surface, west_front, west_back, ridge_back, ridge_front)
	_add_roof_quad(roof_surface, ridge_front, ridge_back, east_back, east_front)
	roof_surface.generate_normals()
	var roof: MeshInstance3D = MeshInstance3D.new()
	roof.name = "PitchedRoof"
	roof.mesh = roof_surface.commit()
	roof.material_override = brick
	house.add_child(roof)

	# Fechamento triangular visivel em ambas as extremidades do telhado.
	var gable_surface: SurfaceTool = SurfaceTool.new()
	gable_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for end_z in [-2.91, 2.91]:
		var west := Vector3(-2.80, 2.34, end_z)
		var east := Vector3(2.80, 2.34, end_z)
		var peak := Vector3(0, 3.36, end_z)
		_add_roof_triangle(gable_surface, west, east, peak)
		_add_roof_triangle(gable_surface, peak, east, west)
	gable_surface.generate_normals()
	var gables: MeshInstance3D = MeshInstance3D.new()
	gables.name = "RoofGables"
	gables.mesh = gable_surface.commit()
	gables.material_override = wall_material
	house.add_child(gables)

func _add_roof_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_roof_triangle(surface, a, b, c)
	_add_roof_triangle(surface, a, c, d)

func _add_roof_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(1.0, 0.0))
	surface.add_vertex(b)
	surface.set_uv(Vector2(0.5, 1.0))
	surface.add_vertex(c)
