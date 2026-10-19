extends Node3D

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
	stone = _material(Color(0.40, 0.39, 0.35))
	plaster = _material(Color(0.67, 0.63, 0.53))
	plaster_warm = _material(Color(0.76, 0.67, 0.54))
	brick = _material(Color(0.42, 0.22, 0.18))
	timber = _material(Color(0.29, 0.22, 0.14))
	window_dark = _material(Color(0.13, 0.17, 0.18))
	asphalt = _material(Color(0.31, 0.32, 0.31))
	grass = _material(Color(0.35, 0.40, 0.29))

	var ground_mesh: MeshInstance3D = get_node("Ground/MeshInstance3D") as MeshInstance3D
	ground_mesh.material_override = grass

	# Estrada e acostamentos sem colisoes extras.
	_visual_box(self, "Road", Vector3(0, 0.014, 0), Vector3(8.0, 0.026, 39.0), asphalt)
	_visual_box(self, "SidewalkLeft", Vector3(-4.5, 0.045, 0), Vector3(1.0, 0.09, 39.0), stone)
	_visual_box(self, "SidewalkRight", Vector3(4.5, 0.045, 0), Vector3(1.0, 0.09, 39.0), stone)

	_house("LeftHouseA", -12.0, -10.0, plaster)
	_house("LeftHouseB", -12.0, 4.0, plaster_warm)
	_house("RightHouseA", 12.0, -10.0, plaster_warm)
	_house("RightHouseB", 12.0, 4.0, plaster)

	# Coberturas laterais: o corredor dos alvos continua desobstruido.
	_static_box("SandbagLeft", Vector3(-5.8, 0.55, -3.5), Vector3(2.1, 1.1, 0.85), stone)
	_static_box("SandbagRight", Vector3(5.8, 0.55, -5.5), Vector3(2.0, 1.1, 0.85), stone)
	_static_box("SupplyCrateA", Vector3(-6.0, 0.54, 2.0), Vector3(1.05, 1.08, 1.05), timber)
	_static_box("SupplyCrateB", Vector3(6.0, 0.54, -1.0), Vector3(1.05, 1.08, 1.05), timber)

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

	# Duas metades de telhado simples; nenhuma luz dinamica adicional.
	var roof_left: MeshInstance3D = _visual_box(house, "RoofLeft", Vector3(-1.48, 2.59, 0), Vector3(3.2, 0.18, 6.2), brick)
	roof_left.rotation.z = -0.24
	var roof_right: MeshInstance3D = _visual_box(house, "RoofRight", Vector3(1.48, 2.59, 0), Vector3(3.2, 0.18, 6.2), brick)
	roof_right.rotation.z = 0.24

	var face: float = 1.0 if x < 0.0 else -1.0
	_visual_box(house, "Door", Vector3(face * 2.83, -1.32, 0), Vector3(0.07, 2.05, 1.10), timber)
	_visual_box(house, "WindowLeft", Vector3(face * 2.83, 0.68, -1.65), Vector3(0.07, 0.95, 0.84), window_dark)
	_visual_box(house, "WindowRight", Vector3(face * 2.83, 0.68, 1.65), Vector3(0.07, 0.95, 0.84), window_dark)
	_visual_box(house, "WindowFrameLeft", Vector3(face * 2.88, 0.68, -1.65), Vector3(0.08, 0.07, 0.87), timber)
	_visual_box(house, "WindowFrameRight", Vector3(face * 2.88, 0.68, 1.65), Vector3(0.08, 0.07, 0.87), timber)
