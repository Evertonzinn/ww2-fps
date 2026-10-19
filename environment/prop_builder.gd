extends RefCounted

# Decoração original de geometria leve: mantém a rota central de tiro desobstruída.
# Toda cobertura alta tem colisão, pedras pequenas são visuais.
static func populate(world: Node3D, stone: Material, timber: Material, grass: Material, brick: Material) -> void:
	# Evita o aspecto de "caixas de areia": bolsas arredondadas em cima da colisão já existente.
	for side in [-1, 1]:
		var node: StaticBody3D = world.get_node("SandbagLeft" if side == -1 else "SandbagRight") as StaticBody3D
		var original_mesh: MeshInstance3D = node.get_node("MeshInstance3D") as MeshInstance3D
		original_mesh.visible = false
		_sandbag_stack(node, grass)

	for z in [-16.5, -7.5, 1.5, 10.5]:
		_fence(world, Vector3(-7.2, 0, z), timber)
		_fence(world, Vector3(7.2, 0, z), timber)

	_signpost(world, Vector3(-5.9, 0, 11.0), timber, stone)
	_destroyed_cart(world, Vector3(6.9, 0, 11.5), timber, stone)
	_small_rubble(world, Vector3(-7.2, 0, -13.0), brick, 144)
	_small_rubble(world, Vector3(7.1, 0, -13.8), stone, 235)
	_small_rubble(world, Vector3(-6.9, 0, 5.5), brick, 358)

static func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, mat: Material, rotation_y: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.rotation.y = rotation_y
	node.material_override = mat
	parent.add_child(node)
	return node

static func _sandbag_stack(parent: StaticBody3D, material: Material) -> void:
	var bag: CapsuleMesh = CapsuleMesh.new()
	bag.radius = 0.22
	bag.height = 1.07
	bag.radial_segments = 8
	bag.rings = 3
	var count: int = 0
	for layer in range(2):
		for z_index in range(2):
			for x_index in range(2):
				var node := MeshInstance3D.new()
				node.name = "Sandbag%d" % count
				count += 1
				node.mesh = bag
				node.material_override = material
				node.rotation.z = PI * 0.5
				node.position = Vector3(-0.39 + 0.78 * x_index, -0.30 + 0.47 * layer, -0.23 + 0.46 * z_index)
				parent.add_child(node)

static func _fence(world: Node3D, base: Vector3, wood: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "Fence"
	body.position = base
	world.add_child(body)

	# Cerca estreita ao lado da calçada, sem ultrapassar a rota central.
	_box(body, "RailLow", Vector3(0, 0.55, 0), Vector3(0.12, 0.13, 3.3), wood)
	_box(body, "RailHigh", Vector3(0, 1.12, 0), Vector3(0.12, 0.13, 3.3), wood)
	for index in range(5):
		var z: float = -1.55 + index * 0.78
		_box(body, "Picket%d" % index, Vector3(0, 0.85, z), Vector3(0.18, 1.7, 0.16), wood)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.24, 1.74, 3.38)
	collision.shape = shape
	collision.position.y = 0.87
	body.add_child(collision)

static func _signpost(world: Node3D, base: Vector3, wood: Material, stone: Material) -> void:
	var pole := StaticBody3D.new()
	pole.name = "Signpost"
	pole.position = base
	world.add_child(pole)
	_box(pole, "Post", Vector3(0, 1.05, 0), Vector3(0.16, 2.1, 0.16), wood)
	_box(pole, "Arrow", Vector3(0, 1.78, 0.45), Vector3(0.14, 0.34, 1.15), stone)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.20, 2.1, 0.20)
	collision.shape = shape
	collision.position.y = 1.05
	pole.add_child(collision)

static func _destroyed_cart(world: Node3D, base: Vector3, wood: Material, metal: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "BrokenCart"
	body.position = base
	world.add_child(body)
	_box(body, "CartBed", Vector3(0, 0.68, 0), Vector3(1.15, 0.18, 1.75), wood, 0.18)
	_box(body, "CartBoardLeft", Vector3(-0.55, 0.86, 0), Vector3(0.09, 0.45, 1.6), wood)
	_box(body, "CartBoardRight", Vector3(0.55, 0.86, 0), Vector3(0.09, 0.45, 1.6), wood)
	_box(body, "BrokenShaft", Vector3(0, 0.40, -1.40), Vector3(0.11, 0.11, 1.5), wood, -0.3)

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.50
	wheel_mesh.bottom_radius = 0.50
	wheel_mesh.height = 0.12
	wheel_mesh.radial_segments = 12
	for side in [-1, 1]:
		var wheel := MeshInstance3D.new()
		wheel.name = "Wheel"
		wheel.mesh = wheel_mesh
		wheel.material_override = metal
		wheel.position = Vector3(0.72 * side, 0.53, 0.18)
		wheel.rotation.z = PI * 0.5
		body.add_child(wheel)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.72, 1.20, 2.1)
	collision.position.y = 0.60
	collision.shape = shape
	body.add_child(collision)

static func _small_rubble(world: Node3D, base: Vector3, mat: Material, deterministic_seed: int) -> void:
	var rubble := MultiMeshInstance3D.new()
	rubble.name = "Rubble"
	var block_mesh := BoxMesh.new()
	block_mesh.size = Vector3(0.28, 0.16, 0.39)
	block_mesh.material = mat

	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = block_mesh
	mesh.instance_count = 24

	var random := RandomNumberGenerator.new()
	random.seed = deterministic_seed
	for i in range(mesh.instance_count):
		var p := Vector3(
			random.randf_range(-1.45, 1.45),
			random.randf_range(0.07, 0.25),
			random.randf_range(-1.15, 1.15)
		)
		var yaw: float = random.randf_range(-PI, PI)
		var size: float = random.randf_range(0.5, 1.3)
		mesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), base + p))
	rubble.multimesh = mesh
	world.add_child(rubble)
