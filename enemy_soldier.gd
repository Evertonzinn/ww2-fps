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
var last_visual_position: Vector3
var walk_blend: float = 0.0
var breath_phase: float = 0.0
var combat_crouch_target: float = 0.0
var combat_crouch_blend: float = 0.0
var zone_original_y: Dictionary = {}

func _ready() -> void:
	health = max_health
	origin = global_position
	last_visual_position = global_position
	# Parent capsule cannot intercept the seven precise raycast hitboxes.
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is StaticBody3D:
			var shape: CollisionShape3D = child.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if shape != null:
				zones.append(shape)
				zone_original_y[shape] = shape.position.y
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
	# The supplied Mixamo mesh/toes face +Z; combat and gun use -Z.
	# Rotate only the visual, never the combat root or hitboxes.
	model.rotation.y = PI
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
			var stem: String = _bone_stem(rig.get_bone_name(index))
			if stem == name:
				bones[name] = index
				initial_rotations[index] = rig.get_bone_pose_rotation(index)
				break
	# Finger joints are visual only; use the same verified namespace handling.
	for index in range(rig.get_bone_count()):
		var stem: String = _bone_stem(rig.get_bone_name(index))
		if stem.begins_with("LeftHand") or stem.begins_with("RightHand"):
			bones[stem] = index
			initial_rotations[index] = rig.get_bone_pose_rotation(index)
	for name in expected:
		if not bones.has(name):
			push_error("Enemy rig: required bone not mapped: " + name)
	print("WW2 FPS enemy: animation bones mapped=", bones.size())

static func _bone_stem(bone_name: String) -> String:
	# Godot sanitizes glTF ':' to '_': mixamorig:RightArm_48 becomes
	# mixamorig_RightArm_48. Remove the namespace BEFORE the numeric suffix.
	return bone_name.replace(":", "_").trim_prefix("mixamorig_").get_slice("_", 0)

func get_rifle_mount_transform() -> Transform3D:
	if rig == null or not bones.has("Spine2"):
		return Transform3D.IDENTITY
	return global_transform.affine_inverse() * rig.global_transform * rig.get_bone_global_pose(int(bones["Spine2"]))

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
	var displacement: Vector3 = global_position - last_visual_position
	displacement.y = 0.0
	last_visual_position = global_position
	walk_phase += displacement.length() * TAU / 1.15
	walk_blend = move_toward(walk_blend, 1.0 if is_walking else 0.0, delta * 6.0)
	breath_phase += delta * 1.8
	combat_crouch_blend = move_toward(combat_crouch_blend, combat_crouch_target, delta * 2.9)
	model.position.y = FOOT_LIFT + absf(sin(walk_phase)) * 0.008 * walk_blend + sin(breath_phase) * 0.002 - combat_crouch_blend * 0.43
	# Match damage regions to the lowered visual body when crouching.
	for shape in zones:
		if is_instance_valid(shape):
			var initial_y: float = float(zone_original_y.get(shape, shape.position.y))
			shape.position.y = initial_y - minf(combat_crouch_blend * 0.43, maxf(0.0, initial_y - 0.25))
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
	var walk_factor: float = walk_blend
	var flinch: float = flinch_left / 0.35
	# Blend tactical crouch into the same four walking joints.
	_pose("LeftUpLeg", Vector3.RIGHT, gait * 0.38 * walk_factor - combat_crouch_blend * 0.62)
	_pose("RightUpLeg", Vector3.RIGHT, -gait * 0.38 * walk_factor - combat_crouch_blend * 0.62)
	_pose("LeftLeg", Vector3.RIGHT, -maxf(0.0, gait) * 0.55 * walk_factor + combat_crouch_blend * 0.72)
	_pose("RightLeg", Vector3.RIGHT, -maxf(0.0, -gait) * 0.55 * walk_factor + combat_crouch_blend * 0.72)
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
	var parent_axis: Vector3 = parent_rotation.inverse() * skeleton_axis
	var baseline: Quaternion = initial_rotations[index]
	rig.set_bone_pose_rotation(index, Quaternion(parent_axis.normalized(), angle) * baseline)

func pose_rifle_hands(right_grip: Transform3D, left_grip: Transform3D) -> void:
	if rig == null or eliminated:
		return
	# Solve both upper arm + forearm to real 3D grip targets; no fake arms.
	# Markers locate palm contact, not the wrist joint. +Y follows the fingers.
	var palm_offset: Vector3 = Vector3(0, 0.045, 0)
	_solve_two_bone_arm("RightArm", "RightForeArm", "RightHand",
		right_grip.origin - right_grip.basis * palm_offset, to_global(Vector3(0.34, 1.09, 0.02)))
	_solve_two_bone_arm("LeftArm", "LeftForeArm", "LeftHand",
		left_grip.origin - left_grip.basis * palm_offset, to_global(Vector3(-0.30, 1.10, -0.12)))
	_orient_hand("RightHand", right_grip.basis)
	_orient_hand("LeftHand", left_grip.basis)
	_curl_fingers("Right", 1.0)
	_curl_fingers("Left", -1.0)

func _orient_hand(hand_name: String, world_basis: Basis) -> void:
	if not bones.has(hand_name):
		return
	var index: int = int(bones[hand_name])
	var parent_basis: Basis = rig.get_bone_global_pose(rig.get_bone_parent(index)).basis.orthonormalized()
	var desired: Basis = rig.global_transform.basis.orthonormalized().inverse() * world_basis.orthonormalized()
	rig.set_bone_pose_rotation(index, (parent_basis.inverse() * desired).get_rotation_quaternion())

func _curl_fingers(side: String, curl_sign: float) -> void:
	# Local +Y is along each phalanx in this rig; local Z closes the fingers.
	# Keep the firing index less curled. Preserve original thumb opposition.
	for finger in ["Index", "Middle", "Ring", "Pinky"]:
		for joint in range(1, 4):
			var name: String = side + "Hand" + finger + str(joint)
			if not bones.has(name):
				continue
			var index: int = int(bones[name])
			var angle: float = 0.30 if finger == "Index" and side == "Right" else 0.65
			var baseline: Quaternion = initial_rotations[index]
			rig.set_bone_pose_rotation(index, baseline * Quaternion(Vector3.BACK, angle * curl_sign))

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
	var local_change: Quaternion = parent_rotation.inverse() * desired_change * parent_rotation
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
	elif combat != null and combat.has_method("on_incoming_hit"):
		combat.call("on_incoming_hit", region)

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
