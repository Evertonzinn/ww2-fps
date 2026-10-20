extends Node

# WW2 FPS v0.14.0 — player stance system. Existing player body is preserved.
# C toggles standing/crouch. Ctrl toggles prone/crouch. No installs/assets.
enum Stance { STAND, CROUCH, PRONE }

const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.26
const PRONE_LENGTH: float = 1.50
const PRONE_RADIUS: float = 0.29
const STAND_CENTER: float = 0.95
const CROUCH_CENTER: float = 0.68
const PRONE_CENTER: float = 0.34
const CROUCH_SPEED: float = 2.05
const PRONE_SPEED: float = 0.90

var stance: Stance = Stance.STAND
var player: CharacterBody3D
var standing_collider: CollisionShape3D
var prone_collider: CollisionShape3D
var standing_shape: CapsuleShape3D
var crouching_shape: CapsuleShape3D
var prone_shape: CapsuleShape3D
var head: Node3D
var last_step_position: Vector3 = Vector3.ZERO
var step_progress: float = 0.0
var last_standing_camera: Vector3 = Vector3(0.0, 0.6, 0.0)

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	standing_collider = player.get_node("CollisionShape3D") as CollisionShape3D
	head = player.get_node("Head") as Node3D
	var source: CapsuleShape3D = standing_collider.shape as CapsuleShape3D
	if source == null:
		push_error("WW2 player stance: expected an upright CapsuleShape3D")
		set_process(false)
		return
	standing_shape = source.duplicate(true) as CapsuleShape3D
	standing_shape.height = STAND_HEIGHT
	crouching_shape = source.duplicate(true) as CapsuleShape3D
	crouching_shape.height = CROUCH_HEIGHT
	prone_shape = CapsuleShape3D.new()
	prone_shape.radius = PRONE_RADIUS
	prone_shape.height = PRONE_LENGTH
	standing_collider.shape = standing_shape
	prone_collider = CollisionShape3D.new()
	prone_collider.name = "ProneCollisionShape3D"
	prone_collider.shape = prone_shape
	prone_collider.rotation.x = PI * 0.5
	prone_collider.disabled = true
	player.add_child(prone_collider)
	last_standing_camera = head.position
	last_step_position = player.global_position
	call_deferred("_notify_stance")

func _process(delta: float) -> void:
	if player == null or head == null:
		return
	var goal: Vector3 = _camera_offset(stance)
	head.position = head.position.lerp(goal, minf(1.0, delta * 9.0))

func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	# Physical Ctrl on Debian, including either left or right Control.
	var code: Key = key_event.physical_keycode
	if code == KEY_NONE:
		code = key_event.keycode
	if code == KEY_C:
		if stance == Stance.CROUCH:
			request_stance(Stance.STAND)
		else:
			request_stance(Stance.CROUCH)
		return true
	if code == KEY_CTRL:
		if stance == Stance.PRONE:
			request_stance(Stance.CROUCH)
		else:
			request_stance(Stance.PRONE)
		return true
	return false

func request_stance(requested: Stance) -> bool:
	if player == null or standing_collider == null or prone_collider == null:
		return false
	if requested == stance:
		return true
	if not _space_is_available(requested):
		print("WW2 FPS player: posture blocked by overhead/obstacle")
		return false
	var old_center: float = _body_center(stance)
	var next_center: float = _body_center(requested)
	var shift: float = next_center - old_center
	# Preserve the eyes' current global position while swapping colliders.
	# Camera glides to its final position over the next few frames.
	player.global_position.y += shift
	head.position.y -= shift
	if requested == Stance.PRONE:
		standing_collider.disabled = true
		prone_collider.disabled = false
	else:
		prone_collider.disabled = true
		standing_collider.shape = crouching_shape if requested == Stance.CROUCH else standing_shape
		standing_collider.disabled = false
	stance = requested
	step_progress = 0.0
	last_step_position = player.global_position
	_notify_stance()
	return true

func _body_center(value: Stance) -> float:
	match value:
		Stance.CROUCH:
			return CROUCH_CENTER
		Stance.PRONE:
			return PRONE_CENTER
	return STAND_CENTER

func _camera_offset(value: Stance) -> Vector3:
	match value:
		Stance.CROUCH:
			return Vector3(0.0, 0.47, 0.0)
		Stance.PRONE:
			return Vector3(0.0, 0.21, -0.32)
	return last_standing_camera

func _shape(value: Stance) -> Shape3D:
	if value == Stance.CROUCH:
		return crouching_shape
	if value == Stance.PRONE:
		return prone_shape
	return standing_shape

func _space_is_available(requested: Stance) -> bool:
	# Query actual body clearance before expanding collision or lying forward.
	# This prevents standing through a low ceiling and prone through a wall.
	var position: Vector3 = player.global_position
	position.y += _body_center(requested) - _body_center(stance)
	var basis: Basis = player.global_transform.basis
	if requested == Stance.PRONE:
		basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _shape(requested)
	query.transform = Transform3D(basis, position)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.005
	return player.get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()

func is_standing() -> bool:
	return stance == Stance.STAND

func movement_speed(sprinting: bool, standard_walk: float, standard_run: float) -> float:
	match stance:
		Stance.CROUCH:
			return CROUCH_SPEED
		Stance.PRONE:
			return PRONE_SPEED
	return standard_run if sprinting else standard_walk

func record_movement() -> void:
	if player == null:
		return
	var traveled: Vector3 = player.global_position - last_step_position
	traveled.y = 0.0
	last_step_position = player.global_position
	if not player.is_on_floor():
		step_progress = 0.0
		return
	step_progress += traveled.length()
	var interval: float = 1.45
	var radius: float = 7.0
	match stance:
		Stance.CROUCH:
			interval = 1.25
			radius = 1.5
		Stance.PRONE:
			interval = 1.30
			radius = 0.8
		_:
			if Input.is_key_pressed(KEY_SHIFT):
				radius = 14.0
				interval = 1.75
	while step_progress >= interval:
		step_progress -= interval
		player.call("report_footstep", radius)

func _notify_stance() -> void:
	if player == null or player.is_dead:
		return
	var hud: Node = player.get_tree().current_scene.get_node_or_null("HUD")
	if hud == null or not hud.has_method("show_player_stance"):
		return
	match stance:
		Stance.CROUCH:
			hud.call("show_player_stance", "AGACHADO", "PASSOS SILENCIOSOS")
		Stance.PRONE:
			hud.call("show_player_stance", "DEITADO", "RASTEJANDO")
		_:
			hud.call("show_player_stance", "EM PE", "SHIFT PARA CORRER")
