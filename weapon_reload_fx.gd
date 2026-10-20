class_name RifleReloadFx
extends Node3D

# Lightweight first-person charger and one real physics shell per shot.
# No modifications to the original licensed Lee-Enfield GLB.
var active_charger: Node3D
var spawned_cases: Array[RigidBody3D] = []
const MAX_CASES: int = 18

func show_charger(rounds: int) -> void:
	hide_charger()
	active_charger = Node3D.new()
	active_charger.name = "FiveRoundCharger"
	active_charger.position = Vector3(0.03, 0.22, -0.46)
	add_child(active_charger)

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.26, 0.27, 0.26)
	steel.metallic = 0.6
	steel.roughness = 0.42
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.67, 0.46, 0.16)
	brass.metallic = 0.5
	brass.roughness = 0.38
	var tip := StandardMaterial3D.new()
	tip.albedo_color = Color(0.40, 0.24, 0.18)
	tip.metallic = 0.45

	var holder := BoxMesh.new()
	holder.size = Vector3(0.09, 0.018, 0.013)
	_add_mesh(active_charger, "ChargerRail", holder, steel, Vector3(0, 0.06, 0))
	for i in range(rounds):
		var offset: float = (float(i) - float(rounds - 1) * 0.5) * 0.017
		var brass_mesh := CylinderMesh.new()
		brass_mesh.top_radius = 0.006
		brass_mesh.bottom_radius = 0.006
		brass_mesh.height = 0.064
		brass_mesh.radial_segments = 8
		_add_mesh(active_charger, "Cartridge%d" % i, brass_mesh, brass, Vector3(offset, 0.025, 0))
		var lead := SphereMesh.new()
		lead.radius = 0.006
		lead.height = 0.012
		lead.radial_segments = 8
		lead.rings = 4
		_add_mesh(active_charger, "Bullet%d" % i, lead, tip, Vector3(offset, -0.011, 0))

func animate_charger(progress: float) -> void:
	if active_charger == null or not is_instance_valid(active_charger):
		return
	var p: float = clampf(progress, 0.0, 1.0)
	# Enters from above, cartridges are pressed into the fixed magazine.
	var slide: float = clampf((p - 0.15) / 0.72, 0.0, 1.0)
	slide = slide * slide * (3.0 - 2.0 * slide)
	active_charger.position.y = 0.22 - slide * 0.15
	active_charger.rotation.z = (1.0 - slide) * 0.06

func hide_charger() -> void:
	if active_charger != null and is_instance_valid(active_charger):
		active_charger.queue_free()
	active_charger = null

func get_charger_position() -> Vector3:
	if active_charger != null and is_instance_valid(active_charger):
		return active_charger.position
	return Vector3(0.03, 0.22, -0.46)

func eject_case(weapon_transform: Transform3D, player_body: CharacterBody3D) -> void:
	var origin: Vector3 = weapon_transform * Vector3(0.13, 0.11, -0.34)
	var right: Vector3 = weapon_transform.basis.x.normalized()
	var back: Vector3 = weapon_transform.basis.z.normalized()
	# Physics world must be changed outside the physics-space flush.
	call_deferred("_spawn_case_deferred", origin, right, back, player_body)

func _spawn_case_deferred(origin: Vector3, right: Vector3, back: Vector3, player_body: CharacterBody3D) -> void:
	var world: Node3D = get_tree().current_scene as Node3D
	if world == null:
		return
	var shell := RigidBody3D.new()
	shell.name = "Ejected303Case"
	shell.mass = 0.012
	shell.collision_layer = 0
	shell.collision_mask = 1
	shell.position = origin

	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.014, 0.055, 0.014)
	collision.shape = box
	shell.add_child(collision)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.51, 0.15)
	metal.metallic = 0.60
	metal.roughness = 0.35
	var case_mesh := CylinderMesh.new()
	case_mesh.top_radius = 0.0065
	case_mesh.bottom_radius = 0.007
	case_mesh.height = 0.055
	case_mesh.radial_segments = 8
	_add_mesh(shell, "Brass", case_mesh, metal, Vector3.ZERO)

	world.add_child(shell)
	if is_instance_valid(player_body):
		shell.add_collision_exception_with(player_body)
	shell.apply_central_impulse(right * 0.020 + Vector3.UP * 0.015 + back * 0.006)
	shell.angular_velocity = right * 9.0 + back * 5.0

	spawned_cases.append(shell)
	while spawned_cases.size() > MAX_CASES:
		var old: RigidBody3D = spawned_cases.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(8.0, false)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(shell):
			shell.queue_free()
	)

func _add_mesh(parent_node: Node3D, label: String, mesh: Mesh, material: Material, position: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.position = position
	parent_node.add_child(node)
