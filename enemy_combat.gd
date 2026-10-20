extends Node3D

# WW2 FPS v0.12 — fair combat: finite sight, reaction time, miss chance,
# obstruction-aware raycast, a torso-level visual gun and a tracer.
const SIGHT_RANGE: float = 27.0
const FIRE_RANGE: float = 21.0
const KEEP_DISTANCE: float = 8.0
const CHASE_SPEED: float = 2.1
const BULLET_DAMAGE: int = 13
const SIGHT_INTERVAL: float = 0.16
var soldier: AnimatableBody3D
var player: CharacterBody3D
var gun: Node3D
var shot_audio: AudioStreamPlayer3D
var alert: bool = false
var sees_player: bool = false
var lost_time: float = 0.0
var sight_time: float = 0.05
var reaction_time: float = 0.0
var shot_time: float = 1.5
var last_seen: Vector3

func _ready() -> void:
	soldier = get_parent() as AnimatableBody3D
	player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_warning("Enemy combat: Player not found")
		set_physics_process(false)
		return
	last_seen = soldier.global_position
	_create_gun()
	_create_audio()
	print("WW2 FPS enemy combat READY")

func is_engaged() -> bool:
	return alert

func _physics_process(delta: float) -> void:
	if soldier == null or bool(soldier.get("eliminated")):
		if gun != null:
			gun.visible = false
		return
	if player == null or bool(player.get("is_dead")):
		alert = false
		return
	sight_time -= delta
	if sight_time <= 0.0:
		sight_time = SIGHT_INTERVAL
		sees_player = _can_see_player()
		if sees_player:
			last_seen = player.global_position
			lost_time = 4.0
			if not alert:
				alert = true
				reaction_time = 0.85
				shot_time = 0.85
				print("WW2 FPS enemy ALERT")
		elif alert:
			lost_time -= SIGHT_INTERVAL
			if lost_time <= 0.0:
				alert = false
				print("WW2 FPS enemy LOST player")
	if not alert:
		return

	soldier.set("is_walking", false)
	var destination: Vector3 = player.global_position if sees_player else last_seen
	var vector: Vector3 = destination - soldier.global_position
	vector.y = 0.0
	var dist: float = vector.length()
	if dist > 0.1:
		var bearing: Vector3 = vector.normalized()
		var target_yaw: float = atan2(-bearing.x, -bearing.z)
		soldier.rotation.y = lerp_angle(soldier.rotation.y, target_yaw, minf(1.0, delta * 4.0))
	if dist > KEEP_DISTANCE and float(soldier.get("flinch_left")) <= 0.0:
		soldier.global_position = soldier.global_position.move_toward(destination, minf(CHASE_SPEED * delta, dist))
		soldier.set("is_walking", true)

	reaction_time = maxf(0.0, reaction_time - delta)
	shot_time = maxf(0.0, shot_time - delta)
	if sees_player and dist <= FIRE_RANGE and reaction_time <= 0.0 and shot_time <= 0.0:
		_fire(dist)
		shot_time = randf_range(1.45, 2.20)

func _excluded() -> Array[RID]:
	var rids: Array[RID] = [soldier.get_rid()]
	for child in soldier.get_children():
		if child is CollisionObject3D:
			rids.append((child as CollisionObject3D).get_rid())
	return rids

func _can_see_player() -> bool:
	var eye: Vector3 = soldier.global_position + Vector3.UP * 1.53
	var target: Vector3 = player.global_position + Vector3.UP * 0.43
	var toward: Vector3 = target - eye
	if toward.length_squared() > SIGHT_RANGE * SIGHT_RANGE:
		return false
	if not alert:
		var a: Vector3 = toward
		a.y = 0.0
		var facing: Vector3 = -soldier.global_transform.basis.z
		facing.y = 0.0
		if a.length_squared() > 0.01 and facing.normalized().dot(a.normalized()) < 0.45:
			return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = _excluded()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player

func _fire(distance: float) -> void:
	var muzzle: Vector3 = gun.to_global(Vector3(0, 0, -0.65))
	var aim: Vector3 = player.global_position + Vector3.UP * 0.43
	var spread: float = 0.09 + distance * 0.022
	aim += soldier.global_transform.basis.x * randf_range(-spread, spread)
	aim.y += randf_range(-spread, spread)
	var far: Vector3 = muzzle + (aim - muzzle).normalized() * 55.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle, far)
	query.exclude = _excluded()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var endpoint: Vector3 = far
	if not hit.is_empty():
		endpoint = hit["position"]
		if hit.get("collider") == player:
			player.call("take_damage", BULLET_DAMAGE)
	_tracer(muzzle, endpoint)
	shot_audio.play()

func _create_gun() -> void:
	# Temporary wooden/metal long-gun; not a licensed German rifle asset.
	gun = Node3D.new()
	gun.name = "EnemyRiflePrototype"
	gun.position = Vector3(0.17, 1.27, -0.18)
	soldier.add_child(gun)
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.25, 0.12, 0.058)
	wood.roughness = 0.83
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.09, 0.10, 0.11)
	steel.metallic = 0.68
	steel.roughness = 0.48
	_box("Stock", Vector3(0, -0.02, 0.22), Vector3(0.11, 0.10, 0.44), wood)
	_box("Receiver", Vector3(0, 0, -0.07), Vector3(0.12, 0.12, 0.23), steel)
	_box("Handguard", Vector3(0, -0.015, -0.32), Vector3(0.085, 0.075, 0.33), wood)
	var barrel: MeshInstance3D = MeshInstance3D.new()
	barrel.name = "Barrel"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.013
	mesh.bottom_radius = 0.015
	mesh.height = 0.58
	mesh.radial_segments = 12
	barrel.mesh = mesh
	barrel.material_override = steel
	barrel.position.z = -0.43
	barrel.rotation.x = PI / 2.0
	gun.add_child(barrel)

func _box(part: String, where: Vector3, dimensions: Vector3, material: Material) -> void:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = part
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material
	node.position = where
	gun.add_child(node)

func _create_audio() -> void:
	shot_audio = AudioStreamPlayer3D.new()
	shot_audio.name = "EnemyFireAudio"
	shot_audio.max_distance = 65.0
	soldier.add_child(shot_audio)
	var sound: AudioStreamWAV = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_8_BITS
	sound.mix_rate = 22050
	var data: PackedByteArray = PackedByteArray()
	data.resize(2700)
	for i in range(data.size()):
		var falloff: float = pow(1.0 - float(i) / float(data.size()), 2.7)
		data[i] = clampi(int(128.0 + randf_range(-110.0, 110.0) * falloff), 0, 255)
	sound.data = data
	shot_audio.stream = sound

func _tracer(start: Vector3, target: Vector3) -> void:
	var delta: Vector3 = target - start
	if delta.length_squared() <= 0.001:
		return
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.name = "EnemyBulletTracer"
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.006
	cylinder.bottom_radius = 0.006
	cylinder.height = delta.length()
	cylinder.radial_segments = 6
	tracer.mesh = cylinder
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.73, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = mat
	soldier.get_parent().add_child(tracer)
	tracer.global_position = (start + target) * 0.5
	tracer.global_transform.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))
	get_tree().create_timer(0.085).timeout.connect(func() -> void:
		if is_instance_valid(tracer):
			tracer.queue_free()
	)
