extends Node3D

const CoverPlanner = preload("res://enemy_cover.gd")
enum Tactic { PATROL, INVESTIGATE, ADVANCE, SEEK_COVER, IN_COVER }

# WW2 FPS v0.12 — fair combat: finite sight, reaction time, miss chance,
# obstruction-aware raycast, a torso-level visual gun and a tracer.
const SIGHT_RANGE: float = 27.0
const FIRE_RANGE: float = 21.0
const KEEP_DISTANCE: float = 8.0
const CHASE_SPEED: float = 2.1
const BULLET_DAMAGE: int = 13
const SIGHT_INTERVAL: float = 0.16
const MAGAZINE_SIZE: int = 5
const RELOAD_SECONDS: float = 2.7
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
var right_grip: Marker3D
var left_grip: Marker3D
var recoil_left: float = 0.0
var gun_rest: Transform3D
var mount_rest: Transform3D
var tactic: Tactic = Tactic.PATROL
var magazine: int = MAGAZINE_SIZE
var reloading: bool = false
var reload_left: float = 0.0
var cover_point: Vector3 = Vector3.ZERO
var cover_name: String = ""
var cover_check_left: float = 2.5
var cover_route_timeout: float = 0.0
var cover_hold_left: float = 0.0
var exposure_left: float = 0.0
var peek_exposed: bool = false
var peek_left: float = 0.0
var leg_injured: bool = false

func _ready() -> void:
	# Gait/spine pose must finish before mounting the gun and solving the arms.
	process_priority = 1
	soldier = get_parent() as AnimatableBody3D
	player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_warning("Enemy combat: Player not found")
		set_physics_process(false)
		return
	last_seen = soldier.global_position
	magazine = MAGAZINE_SIZE
	if player.has_signal("gunshot"):
		player.connect("gunshot", Callable(self, "_on_player_gunshot"))
	_create_gun()
	_create_audio()
	print("WW2 FPS enemy combat READY")

func is_engaged() -> bool:
	return alert

func tactical_status() -> String:
	return Tactic.keys()[tactic] + (" / RELOAD" if reloading else "")

func _physics_process(delta: float) -> void:
	if soldier == null or bool(soldier.get("eliminated")):
		if gun != null:
			gun.visible = false
		return
	if player == null or bool(player.get("is_dead")):
		alert = false
		tactic = Tactic.PATROL
		soldier.set("combat_crouch_target", 0.0)
		return

	sight_time -= delta
	if sight_time <= 0.0:
		sight_time = SIGHT_INTERVAL
		sees_player = _can_see_player()
		if sees_player:
			last_seen = player.global_position
			lost_time = 6.0
			if not alert:
				_alert_at(last_seen, false)
		elif alert:
			lost_time = maxf(0.0, lost_time - SIGHT_INTERVAL)
			if lost_time <= 0.0 and tactic != Tactic.IN_COVER:
				alert = false
				tactic = Tactic.PATROL
				print("WW2 FPS enemy: resumed patrol")

	if not alert:
		soldier.set("combat_crouch_target", 0.0)
		return

	# One finite magazine: no endless gunfire, no shot during reload.
	if reloading:
		reload_left = maxf(0.0, reload_left - delta)
		soldier.set("combat_crouch_target", 1.0 if tactic == Tactic.IN_COVER else 0.0)
		if reload_left <= 0.0:
			reloading = false
			magazine = MAGAZINE_SIZE
			print("WW2 FPS enemy RELOADED: %d" % magazine)
	elif magazine <= 0:
		_begin_reload()

	cover_check_left = maxf(0.0, cover_check_left - delta)
	if tactic == Tactic.IN_COVER:
		cover_hold_left -= delta
		peek_left -= delta
		if peek_left <= 0.0:
			peek_exposed = not peek_exposed
			peek_left = 0.95 if peek_exposed else 1.30
		# Duck fully between bursts and while reloading.
		soldier.set("combat_crouch_target", 0.0 if peek_exposed and not reloading else 1.0)
		soldier.set("is_walking", false)
		_face_towards(player.global_position, delta)
		if cover_hold_left <= 0.0 or soldier.global_position.distance_to(player.global_position) < 4.0:
			tactic = Tactic.ADVANCE
			cover_check_left = 4.0
	elif tactic == Tactic.SEEK_COVER:
		soldier.set("combat_crouch_target", 0.0)
		if soldier.global_position.distance_to(cover_point) <= 0.52:
			tactic = Tactic.IN_COVER
			cover_hold_left = 9.0
			peek_exposed = false
			peek_left = 1.2
			print("WW2 FPS enemy COVER reached: ", cover_name)
		else:
			_move_towards(cover_point, delta, 0.48)
			cover_route_timeout -= delta
			if cover_route_timeout <= 0.0:
				tactic = Tactic.ADVANCE
				cover_check_left = 5.0
				print("WW2 FPS enemy: unreachable cover abandoned")
	else:
		soldier.set("combat_crouch_target", 0.0)
		# Move deliberately to sound/last seen location, not through walls.
		var point: Vector3 = player.global_position if sees_player else last_seen
		var stop_radius: float = KEEP_DISTANCE if sees_player else 0.65
		if tactic == Tactic.INVESTIGATE and sees_player:
			tactic = Tactic.ADVANCE
		if tactic == Tactic.INVESTIGATE and soldier.global_position.distance_to(last_seen) < 0.7:
			tactic = Tactic.ADVANCE
		_move_towards(point, delta, stop_radius)

	if sees_player and tactic == Tactic.ADVANCE:
		exposure_left += delta
	else:
		exposure_left = maxf(0.0, exposure_left - delta * 0.6)
	# Cover prioritizes wounded soldiers, low ammo and prolonged exposure.
	var wounded: bool = int(soldier.get("health")) <= 65
	if tactic == Tactic.ADVANCE and cover_check_left <= 0.0 and (
			wounded or magazine <= 2 or exposure_left > 2.5):
		cover_check_left = 5.0
		_try_cover()

	reaction_time = maxf(0.0, reaction_time - delta)
	shot_time = maxf(0.0, shot_time - delta)
	if sees_player and not reloading and magazine > 0 and (
			tactic != Tactic.IN_COVER or peek_exposed):
		var range_to_player: float = soldier.global_position.distance_to(player.global_position)
		if range_to_player <= FIRE_RANGE and reaction_time <= 0.0 and shot_time <= 0.0:
			_fire(range_to_player)
			magazine -= 1
			shot_time = randf_range(1.35, 2.15)
			if magazine <= 0:
				_begin_reload()

func _process(delta: float) -> void:
	if gun == null or soldier == null or bool(soldier.get("eliminated")):
		return
	recoil_left = maxf(0.0, recoil_left - delta)
	var mount: Transform3D = soldier.call("get_rifle_mount_transform")
	gun.transform = mount * mount_rest.affine_inverse() * gun_rest
	var aim_lift: float = 0.22 if reloading else 0.0
	gun.transform = gun.transform * Transform3D(
		Basis(Vector3.RIGHT, 0.11 * (recoil_left / 0.16) + aim_lift), Vector3.ZERO)
	if right_grip != null and left_grip != null:
		soldier.call("pose_rifle_hands", right_grip.global_transform, left_grip.global_transform)

func _excluded() -> Array[RID]:
	var rids: Array[RID] = [soldier.get_rid()]
	for child in soldier.get_children():
		if child is CollisionObject3D:
			rids.append((child as CollisionObject3D).get_rid())
	return rids

func _can_see_player() -> bool:
	var crouch: float = float(soldier.get("combat_crouch_blend"))
	var eye: Vector3 = soldier.global_position + Vector3.UP * (1.53 - 0.44 * crouch)
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
	recoil_left = 0.16
	shot_audio.play()

func _create_gun() -> void:
	# Temporary wooden/metal long-gun; not a licensed German rifle asset.
	gun = Node3D.new()
	gun.name = "EnemyRiflePrototype"
	# Orient the complete rifle muzzle-forward in the model's -Z axis,
	# just in front of the sternum, not behind its back.
	gun.position = Vector3(0.13, 1.36, -0.23)
	gun.rotation.x = -0.045
	soldier.add_child(gun)
	gun_rest = gun.transform
	mount_rest = soldier.call("get_rifle_mount_transform")
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.25, 0.12, 0.058)
	wood.roughness = 0.83
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.09, 0.10, 0.11)
	steel.metallic = 0.68
	steel.roughness = 0.48
	_box("Stock", Vector3(0.025, -0.02, 0.12), Vector3(0.065, 0.09, 0.30), wood)
	_box("Receiver", Vector3(0, 0, -0.07), Vector3(0.055, 0.065, 0.23), steel)
	_box("Handguard", Vector3(0, -0.015, -0.32), Vector3(0.05, 0.055, 0.33), wood)
	var barrel: MeshInstance3D = MeshInstance3D.new()
	barrel.name = "Barrel"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.009
	mesh.bottom_radius = 0.011
	mesh.height = 0.58
	mesh.radial_segments = 12
	barrel.mesh = mesh
	barrel.material_override = steel
	barrel.position.z = -0.43
	barrel.rotation.x = PI / 2.0
	gun.add_child(barrel)
	# IK markers in the exact same visual-gun coordinate system.
	right_grip = Marker3D.new()
	right_grip.name = "TriggerGrip"
	right_grip.position = Vector3(0.02, -0.06, 0.065)
	var trigger_fingers: Vector3 = Vector3(-0.4, 0.65, -0.65).normalized()
	var trigger_across: Vector3 = Vector3.BACK.slide(trigger_fingers).normalized()
	right_grip.basis = Basis(trigger_fingers.cross(trigger_across).normalized(), trigger_fingers, trigger_across)
	gun.add_child(right_grip)
	left_grip = Marker3D.new()
	left_grip.name = "SupportGrip"
	left_grip.position = Vector3(-0.025, -0.05, -0.10)
	# Palm faces up; fingers follow the forearm diagonally, avoiding a bent wrist.
	var support_fingers: Vector3 = Vector3(0.8, 0, -0.6)
	left_grip.basis = Basis(Vector3.UP, support_fingers, Vector3.UP.cross(support_fingers))
	gun.add_child(left_grip)

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

func _alert_at(location: Vector3, from_sound: bool) -> void:
	alert = true
	last_seen = location
	lost_time = 7.0 if from_sound else 6.0
	reaction_time = 0.90
	shot_time = 0.90
	tactic = Tactic.INVESTIGATE if from_sound else Tactic.ADVANCE
	print("WW2 FPS enemy ", "HEARD SHOT" if from_sound else "ALERT")

func _on_player_gunshot(location: Vector3) -> void:
	if soldier == null or bool(soldier.get("eliminated")):
		return
	if soldier.global_position.distance_to(location) > 32.0:
		return
	if not alert:
		_alert_at(location, true)
	elif not sees_player:
		last_seen = location
		lost_time = 6.0
		if tactic == Tactic.PATROL:
			tactic = Tactic.INVESTIGATE

func on_incoming_hit(region: String) -> void:
	if soldier == null or bool(soldier.get("eliminated")):
		return
	if region == "Perna":
		leg_injured = true
	if player == null:
		return
	if not alert:
		_alert_at(player.global_position, false)
	cover_check_left = 0.0
	exposure_left = 3.0

func _begin_reload() -> void:
	if reloading:
		return
	reloading = true
	reload_left = RELOAD_SECONDS
	shot_time = maxf(shot_time, RELOAD_SECONDS)
	print("WW2 FPS enemy RELOADING")

func _try_cover() -> void:
	var world: Node3D = soldier.get_parent() as Node3D
	if world == null:
		return
	var candidate: Dictionary = CoverPlanner.find_cover(world, soldier, player)
	if candidate.is_empty():
		return
	cover_point = candidate["point"]
	cover_name = String(candidate["obstacle"])
	cover_route_timeout = 7.0
	tactic = Tactic.SEEK_COVER
	print("WW2 FPS enemy SEEK_COVER: ", cover_name, " at ", cover_point)

func _face_towards(target: Vector3, delta: float) -> void:
	var delta_position: Vector3 = target - soldier.global_position
	delta_position.y = 0.0
	if delta_position.length_squared() <= 0.005:
		return
	var direction: Vector3 = delta_position.normalized()
	soldier.rotation.y = lerp_angle(soldier.rotation.y,
		atan2(-direction.x, -direction.z), minf(1.0, delta * 4.0))

func _move_towards(target: Vector3, delta: float, stop_radius: float) -> void:
	var vector: Vector3 = target - soldier.global_position
	vector.y = 0.0
	var distance: float = vector.length()
	soldier.set("is_walking", false)
	if distance <= stop_radius:
		_face_towards(player.global_position, delta)
		return
	_face_towards(target, delta)
	var forward: Vector3 = -soldier.global_transform.basis.z
	var direction: Vector3 = vector.normalized()
	if forward.dot(direction) < 0.78:
		return
	# Prevent sliding through houses, crates and sandbag collision meshes.
	# This remains local obstacle avoidance, not complete navigation.
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		soldier.global_position + Vector3.UP * 0.70,
		soldier.global_position + Vector3.UP * 0.70 + direction * 0.68)
	query.exclude = _excluded()
	var barrier: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not barrier.is_empty() and barrier.get("collider") != player:
		return
	var speed: float = CHASE_SPEED * (0.72 if leg_injured else 1.0)
	var movement: float = minf(speed * delta, distance - stop_radius)
	if movement > 0.0:
		soldier.global_position += direction * movement
		soldier.set("is_walking", true)

