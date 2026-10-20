extends AnimatableBody3D

# 65-bone Panzergrenadier, CC BY 4.0: docs/panzergrenadier-license.md.
# v0.11 lightweight procedural movement and localized damage.
const MODEL_1K: String = "res://assets/characters/panzergrenadier/panzergrenadier_1k.glb"
const MODEL_2K: String = "res://assets/characters/panzergrenadier/panzergrenadier_2k.glb"
const CombatScript = preload("res://enemy_combat.gd")
const MODEL_SCALE: float = 0.019
const FOOT_LIFT: float = 0.046
const PATROL_LENGTH: float = 1.6
const PATROL_SPEED: float = 0.7
const DEATH_TIME: float = 2.6

@export_range(1, 500, 1) var max_health: int = 100
@export var high_quality: bool = false
@export var patrol_enabled: bool = true
@export var show_debug_label: bool = false

var health: int = 100
var eliminated: bool = false
var model: Node3D
var rig: Skeleton3D
var combat: Node3D
var locator: Label3D
var feedback: Label3D
var feedback_left: float = 0.0
var origin: Vector3
var going_forward: bool = true
var pause_patrol: float = 1.8
var is_walking: bool = false
var walk_phase: float = 0.0
var flinch_left: float = 0.0
var death_elapsed: float = 0.0
var zones: Array[CollisionShape3D] = []
var bones: Dictionary = {}
var initial_rotations: Dictionary = {}

func _ready() -> void:
	health = max_health
	origin = global_position
	# Parent capsule cannot intercept the seven precise raycast hitboxes.
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is StaticBody3D:
			var shape: CollisionShape3D = child.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if shape != null:
				zones.append(shape)
	_setup_labels()
	var path: String = MODEL_2K if high_quality else MODEL_1K
	if not ResourceLoader.exists(path):
		path = MODEL_1K if high_quality else MODEL_2K
	if not ResourceLoader.exists(path):
		_model_error("Panzergrenadier 1K/2K GLB missing")
		return
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		_model_error("GLB failed import: " + path)
		return
	model = packed.instantiate() as Node3D
	if model == null:
		_model_error("GLB did not instantiate: " + path)
		return
	model.name = "PanzergrenadierVisual"
	add_child(model)
	model.scale = Vector3.ONE * MODEL_SCALE
	model.position.y = FOOT_LIFT
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		_model_error("No renderable meshes: " + path)
		return
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		rig = skeletons[0] as Skeleton3D
		_prepare_bone_tracks()
	else:
		push_warning("WW2 FPS enemy: no rig found; patrol works without bone animation.")
	locator.visible = show_debug_label
	combat = CombatScript.new() as Node3D
	combat.name = "EnemyCombat"
	add_child(combat)
	print("WW2 FPS enemy READY: meshes=%d bones=%d HP=%d zones=%d model=%s" % [
		meshes.size(), rig.get_bone_count() if rig != null else 0, health, zones.size(), path
	])

func _prepare_bone_tracks() -> void:
	if rig == null:
		return
	var expected: PackedStringArray = PackedStringArray([
		"Spine", "Spine1", "Spine2", "Head", "LeftUpLeg", "RightUpLeg",
		"LeftLeg", "RightLeg", "LeftArm", "RightArm",
		"LeftForeArm", "RightForeArm", "LeftHand", "RightHand"
	])
	for name in expected:
		for index in range(rig.get_bone_count()):
			var stem: String = rig.get_bone_name(index).split(":")[-1].split("_")[0]
			if stem == name:
				bones[name] = index
				initial_rotations[index] = rig.get_bone_pose_rotation(index)
				break
	print("WW2 FPS enemy: animation bones mapped=", bones.size())

func _physics_process(delta: float) -> void:
	is_walking = false
	if eliminated or model == null or flinch_left > 0.0:
		return
	if combat != null and bool(combat.call("is_engaged")):
		return
	if not patrol_enabled:
		return
	if pause_patrol > 0.0:
		pause_patrol = maxf(0.0, pause_patrol - delta)
		return
	var destination: Vector3 = origin + Vector3(0, 0, PATROL_LENGTH) if going_forward else origin
	var offset: Vector3 = destination - global_position
	offset.y = 0.0
	if offset.length() < 0.04:
		going_forward = not going_forward
		pause_patrol = 1.3
		return
	var direction: Vector3 = offset.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 3.0))
	# Turn to face the next patrol waypoint before translating: no strafing or moonwalk.
	var facing: Vector3 = -global_transform.basis.z
	if facing.dot(direction) > 0.80:
		global_position = global_position.move_toward(destination, PATROL_SPEED * delta)
		is_walking = true

func _process(delta: float) -> void:
	if model == null:
		return
	if eliminated:
		death_elapsed += delta
		var t: float = clampf(death_elapsed / 0.85, 0.0, 1.0)
		rotation.z = -1.25 * t * t * (3.0 - 2.0 * t)
		if death_elapsed > DEATH_TIME:
			queue_free()
		return
	flinch_left = maxf(0.0, flinch_left - delta)
	walk_phase += delta * (8.0 if is_walking else 1.8)
	model.position.y = FOOT_LIFT + (absf(sin(walk_phase)) * 0.012 if is_walking else sin(walk_phase) * 0.003)
	_update_bone_pose()
	if feedback_left > 0.0:
		feedback_left = maxf(0.0, feedback_left - delta)
		feedback.position.y += delta * 0.20
		var color: Color = feedback.modulate
		color.a = minf(1.0, feedback_left * 2.5)
		feedback.modulate = color
		if feedback_left <= 0.0:
			feedback.visible = false

func _update_bone_pose() -> void:
	if rig == null:
		return
	var gait: float = sin(walk_phase)
	var walk_factor: float = 1.0 if is_walking else 0.0
	var flinch: float = flinch_left / 0.35
	_pose("LeftUpLeg", Vector3.RIGHT, gait * 0.38 * walk_factor)
	_pose("RightUpLeg", Vector3.RIGHT, -gait * 0.38 * walk_factor)
	_pose("LeftLeg", Vector3.RIGHT, maxf(0.0, -gait) * 0.24 * walk_factor)
	_pose("RightLeg", Vector3.RIGHT, maxf(0.0, gait) * 0.24 * walk_factor)
	# Arms are solved to the rifle grips in the combat child, after gait.
	# Keep a neutral natural swing if the rifle has not been created.
	if combat == null:
		_pose("LeftArm", Vector3.RIGHT, -gait * 0.20 * walk_factor)
		_pose("RightArm", Vector3.RIGHT, gait * 0.20 * walk_factor)
	_pose("Spine", Vector3.RIGHT, sin(walk_phase * 0.6) * 0.015 - flinch * 0.13)
	_pose("Spine1", Vector3.FORWARD, sin(walk_phase * 0.5) * 0.01)
	_pose("Spine2", Vector3.RIGHT, -flinch * 0.06)
	_pose("Head", Vector3.UP, sin(walk_phase * 0.4) * 0.025)

func _pose(name: String, axis: Vector3, angle: float) -> void:
	if rig == null or not bones.has(name):
		return
	var index: int = int(bones[name])
	var parent_index: int = rig.get_bone_parent(index)
	var parent_rotation: Quaternion = Quaternion.IDENTITY
	if parent_index >= 0:
		parent_rotation = rig.get_bone_global_pose(parent_index).basis.get_rotation_quaternion()
	# Mixamo bone-local X is not always character-left/right. Express the
	# desired axis in the character's world frame, then in the joint parent.
	var world_axis: Vector3 = (global_transform.basis * axis).normalized()
	var skeleton_axis: Vector3 = (rig.global_transform.basis.inverse() * world_axis).normalized()
	var rest_rotation: Quaternion = rig.get_bone_rest(index).basis.get_rotation_quaternion()
	var parent_axis: Vector3 = (parent_rotation * rest_rotation).inverse() * skeleton_axis
	var baseline: Quaternion = initial_rotations[index]
	rig.set_bone_pose_rotation(index, Quaternion(parent_axis.normalized(), angle) * baseline)

func pose_rifle_hands(right_grip: Vector3, left_grip: Vector3) -> void:
	if rig == null or eliminated:
		return
	# Solve both upper arm + forearm to real 3D grip targets; no fake arms.
	_solve_two_bone_arm("RightArm", "RightForeArm", "RightHand",
		right_grip, to_global(Vector3(0.43, 1.10, 0.10)))
	_solve_two_bone_arm("LeftArm", "LeftForeArm", "LeftHand",
		left_grip, to_global(Vector3(-0.43, 1.10, 0.08)))

func _solve_two_bone_arm(upper_name: String, lower_name: String,
		hand_name: String, hand_world: Vector3, elbow_hint_world: Vector3) -> void:
	if not bones.has(upper_name) or not bones.has(lower_name) or not bones.has(hand_name):
		return
	var upper: int = int(bones[upper_name])
	var lower: int = int(bones[lower_name])
	var hand: int = int(bones[hand_name])
	# Always reset to imported rest pose before solving. This prevents
	# frame-to-frame quaternion accumulation and twisted elbows.
	rig.set_bone_pose_rotation(upper, initial_rotations[upper])
	rig.set_bone_pose_rotation(lower, initial_rotations[lower])
	var shoulder: Vector3 = rig.get_bone_global_pose(upper).origin
	var elbow: Vector3 = rig.get_bone_global_pose(lower).origin
	var wrist: Vector3 = rig.get_bone_global_pose(hand).origin
	var upper_length: float = shoulder.distance_to(elbow)
	var lower_length: float = elbow.distance_to(wrist)
	if upper_length < 0.001 or lower_length < 0.001:
		return
	var goal: Vector3 = rig.to_local(hand_world)
	var hint: Vector3 = rig.to_local(elbow_hint_world)
	var toward: Vector3 = goal - shoulder
	var distance: float = toward.length()
	if distance < 0.001:
		return
	var axis: Vector3 = toward / distance
	var clamped: float = clampf(distance,
		absf(upper_length - lower_length) + 0.001,
		upper_length + lower_length - 0.001)
	var along: float = (upper_length * upper_length
		- lower_length * lower_length + clamped * clamped) / (2.0 * clamped)
	var sideways: Vector3 = hint - shoulder
	sideways -= axis * sideways.dot(axis)
	if sideways.length_squared() < 0.00001:
		sideways = axis.cross(Vector3.UP)
	if sideways.length_squared() < 0.00001:
		sideways = axis.cross(Vector3.RIGHT)
	sideways = sideways.normalized()
	var height: float = sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var desired_elbow: Vector3 = shoulder + axis * along + sideways * height
	_align_bone_segment(upper, elbow - shoulder, desired_elbow - shoulder)
	var updated_elbow: Vector3 = rig.get_bone_global_pose(lower).origin
	var updated_wrist: Vector3 = rig.get_bone_global_pose(hand).origin
	_align_bone_segment(lower, updated_wrist - updated_elbow, goal - updated_elbow)

func _align_bone_segment(index: int, from_direction: Vector3,
		to_direction: Vector3) -> void:
	if from_direction.length_squared() < 0.00001 or to_direction.length_squared() < 0.00001:
		return
	var parent_index: int = rig.get_bone_parent(index)
	var parent_rotation: Quaternion = Quaternion.IDENTITY
	if parent_index >= 0:
		parent_rotation = rig.get_bone_global_pose(parent_index).basis.get_rotation_quaternion()
	var desired_change: Quaternion = Quaternion(from_direction.normalized(),
		to_direction.normalized())
	var rest_rotation: Quaternion = rig.get_bone_rest(index).basis.get_rotation_quaternion()
	var joint_frame: Quaternion = parent_rotation * rest_rotation
	var local_change: Quaternion = joint_frame.inverse() * desired_change * joint_frame
	var old_pose: Quaternion = rig.get_bone_pose_rotation(index)
	rig.set_bone_pose_rotation(index, (local_change * old_pose).normalized())

func receive_zone_damage(amount: int, region: String) -> void:
	if eliminated or model == null or amount <= 0:
		return
	health = maxi(0, health - amount)
	flinch_left = 0.35
	_show_damage(amount, region)
	print("WW2 FPS enemy HIT: %s damage=%d HP=%d/%d" % [region, amount, health, max_health])
	if health <= 0:
		_die()

func take_damage(amount: int) -> void:
	# Backward-compatible generic damage if caller holds the enemy root.
	receive_zone_damage(amount * 40, "Torax")

func _die() -> void:
	eliminated = true
	is_walking = false
	for shape in zones:
		if is_instance_valid(shape):
			shape.set_deferred("disabled", true)
	print("WW2 FPS enemy ELIMINATED")

func _setup_labels() -> void:
	locator = get_node_or_null("DebugMarker") as Label3D
	if locator == null:
		locator = Label3D.new()
		locator.name = "DebugMarker"
		locator.text = "SOLDADO TESTE"
		locator.position = Vector3(0, 2.17, 0)
		locator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		locator.pixel_size = 0.0038
		add_child(locator)
	locator.visible = show_debug_label
	feedback = Label3D.new()
	feedback.name = "DamageIndicator"
	feedback.position = Vector3(0, 2.08, 0)
	feedback.pixel_size = 0.004
	feedback.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	feedback.no_depth_test = true
	feedback.visible = false
	add_child(feedback)

func _show_damage(amount: int, region: String) -> void:
	feedback.text = "HEADSHOT" if region == "Cabeca" else "-%d" % amount
	feedback.position = Vector3(0, 2.08, 0)
	feedback.modulate = Color(1.0, 0.28, 0.20) if region == "Cabeca" else Color(1.0, 0.90, 0.32)
	feedback.visible = true
	feedback_left = 0.75

func _model_error(why: String) -> void:
	push_error("WW2 FPS enemy DISABLED: " + why)
	for shape in zones:
		if is_instance_valid(shape):
			shape.set_deferred("disabled", true)
	locator.visible = true
	locator.text = "SOLDADO SEM MODELO"
