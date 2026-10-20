class_name FirstPersonArms
extends Node3D

# BAMEN CC BY 4.0: existing 52-bone skinned GLB, no duplicated meshes.
# Fix: DO NOT move entire shoulders to wrist destinations.
# Pin each shoulder behind/below the camera, then use two-chain SkeletonIK3D.
# This is a prototype IK solve; anatomical calibration needs visual testing.

const MODEL_1K: String = "res://assets/characters/bamen_fps_arms/bamen_arms_1k.glb"
const MODEL_2K: String = "res://assets/characters/bamen_fps_arms/bamen_arms_2k.glb"

# Controls in Weapon local space (meters). Exposed for Godot inspector tuning.
@export var rig_offset: Vector3 = Vector3(0.0, -0.27, -1.45)
@export var right_hand_grip: Vector3 = Vector3(0.12, -0.15, -0.27)
@export var left_hand_support: Vector3 = Vector3(-0.09, -0.14, -0.66)
@export var left_hand_bolt: Vector3 = Vector3(-0.07, 0.045, -0.48)
@export var clip_hand_offset: Vector3 = Vector3(-0.055, 0.058, 0.005)
@export_range(2.0, 30.0, 0.5) var blend_speed: float = 11.0

const MAX_REACH_FRACTION: float = 0.95

var model_root: Node3D
var skeleton: Skeleton3D
var right_target: Marker3D
var left_target: Marker3D
var right_ik: SkeletonIK3D
var left_ik: SkeletonIK3D
var right_upper_idx: int = -1
var right_elbow_idx: int = -1
var right_wrist_idx: int = -1
var left_upper_idx: int = -1
var left_elbow_idx: int = -1
var left_wrist_idx: int = -1
var current_left_target: Vector3
var active_quality: int = 0

func _ready() -> void:
	current_left_target = left_hand_support
	right_target = Marker3D.new()
	right_target.name = "RightGripTarget"
	add_child(right_target)
	right_target.position = right_hand_grip
	left_target = Marker3D.new()
	left_target.name = "LeftSupportTarget"
	add_child(left_target)
	left_target.position = left_hand_support

func set_texture_quality(high_quality: bool) -> bool:
	var requested: int = 2 if high_quality else 1
	if model_root != null and is_instance_valid(model_root) and requested == active_quality:
		return true
	var path: String = MODEL_2K if requested == 2 else MODEL_1K
	if not ResourceLoader.exists(path):
		if requested == 2 and ResourceLoader.exists(MODEL_1K):
			path = MODEL_1K
			requested = 1
		else:
			push_warning("BAMEN IK: missing licensed GLB: " + path)
			return false
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		push_warning("BAMEN IK: invalid GLB scene: " + path)
		return false
	var replacement: Node3D = packed.instantiate() as Node3D
	if replacement == null:
		return false

	_stop_ik()
	if model_root != null and is_instance_valid(model_root):
		model_root.queue_free()
	model_root = replacement
	model_root.name = "BamenArmsIK"
	add_child(model_root)
	model_root.position = rig_offset
	skeleton = null
	active_quality = requested
	call_deferred("_bind_skeleton", replacement)
	return true

func _stop_ik() -> void:
	if right_ik != null and is_instance_valid(right_ik):
		right_ik.stop()
	if left_ik != null and is_instance_valid(left_ik):
		left_ik.stop()
	right_ik = null
	left_ik = null

func _bind_skeleton(expected_model: Node3D) -> void:
	if model_root != expected_model or not is_instance_valid(expected_model):
		return
	var found: Array[Node] = expected_model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		_fail_safely("Skeleton3D missing after import")
		return
	skeleton = found[0] as Skeleton3D
	if skeleton == null:
		_fail_safely("import did not yield valid Skeleton3D")
		return
	right_upper_idx = _bone_index("arm1r")
	right_elbow_idx = _bone_index("arm2r")
	right_wrist_idx = _bone_index("hand1r")
	left_upper_idx = _bone_index("arm1l")
	left_elbow_idx = _bone_index("arm2l")
	left_wrist_idx = _bone_index("hand1l")

	var indices: Array[int] = [right_upper_idx, right_elbow_idx, right_wrist_idx,
		left_upper_idx, left_elbow_idx, left_wrist_idx]
	for idx in indices:
		if idx < 0:
			_fail_safely("required shoulder/elbow/wrist bone was renamed")
			return
	if skeleton.get_bone_parent(right_elbow_idx) != right_upper_idx or skeleton.get_bone_parent(right_wrist_idx) != right_elbow_idx:
		_fail_safely("right arm bone chain not contiguous")
		return
	if skeleton.get_bone_parent(left_elbow_idx) != left_upper_idx or skeleton.get_bone_parent(left_wrist_idx) != left_elbow_idx:
		_fail_safely("left arm bone chain not contiguous")
		return

	# Never apply wrist displacement to shoulders. Shoulder remains anchored
	# at its imported rest position offset behind/below first-person camera.
	right_target.position = _reachable_target(right_hand_grip, right_upper_idx, right_elbow_idx, right_wrist_idx)
	left_target.position = _reachable_target(left_hand_support, left_upper_idx, left_elbow_idx, left_wrist_idx)
	current_left_target = left_target.position
	right_ik = _make_ik("RightArmIK", right_upper_idx, right_wrist_idx, right_target,
		Vector3(0.46, -0.48, -0.39))
	left_ik = _make_ik("LeftArmIK", left_upper_idx, left_wrist_idx, left_target,
		Vector3(-0.47, -0.44, -0.46))
	right_ik.start()
	left_ik.start()
	print("BAMEN FPS IK ready: %d bones, two IK chains, shoulders anchored." % skeleton.get_bone_count())

func _make_ik(label: String, upper_idx: int, wrist_idx: int, target_node: Marker3D,
		pole_weapon_space: Vector3) -> SkeletonIK3D:
	var ik: SkeletonIK3D = SkeletonIK3D.new()
	ik.name = label
	ik.root_bone = StringName(skeleton.get_bone_name(upper_idx))
	ik.tip_bone = StringName(skeleton.get_bone_name(wrist_idx))
	ik.override_tip_basis = false
	ik.max_iterations = 18
	ik.min_distance = 0.004
	skeleton.add_child(ik)
	ik.target_node = skeleton.get_path_to(target_node)
	# Bend elbows below/outside sightline rather than allowing a reversed arm.
	ik.use_magnet = true
	ik.magnet = skeleton.to_local(global_transform * pole_weapon_space)
	return ik

func _bone_index(prefix: String) -> int:
	if skeleton == null:
		return -1
	for idx in range(skeleton.get_bone_count()):
		var normalized: String = String(skeleton.get_bone_name(idx)).to_lower()
		normalized = normalized.replace(".", "").replace("_", "").replace("-", "").replace(" ", "")
		if normalized.begins_with(prefix):
			return idx
	return -1

func _reachable_target(wanted: Vector3, shoulder_idx: int, elbow_idx: int, wrist_idx: int) -> Vector3:
	# All targets, including reload targets, must stay within bone lengths.
	var a: Vector3 = skeleton.get_bone_global_rest(shoulder_idx).origin
	var b: Vector3 = skeleton.get_bone_global_rest(elbow_idx).origin
	var c: Vector3 = skeleton.get_bone_global_rest(wrist_idx).origin
	var maximum: float = (a.distance_to(b) + b.distance_to(c)) * MAX_REACH_FRACTION
	var shoulder_in_weapon: Vector3 = to_local(skeleton.to_global(a))
	var vector: Vector3 = wanted - shoulder_in_weapon
	if maximum < 0.05:
		return shoulder_in_weapon
	if vector.length() > maximum:
		return shoulder_in_weapon + vector.normalized() * maximum
	return wanted

func update_pose(in_reload: bool, phase: int, charger_position: Vector3, delta: float) -> void:
	if skeleton == null or not is_instance_valid(skeleton) or left_ik == null:
		return
	var wanted: Vector3 = left_hand_support
	if in_reload:
		match phase:
			1, 3:
				wanted = left_hand_bolt
			2:
				wanted = charger_position + clip_hand_offset
	var reachable: Vector3 = _reachable_target(wanted, left_upper_idx, left_elbow_idx, left_wrist_idx)
	current_left_target = current_left_target.lerp(reachable, minf(1.0, delta * blend_speed))
	left_target.position = current_left_target

func _fail_safely(message: String) -> void:
	push_warning("BAMEN FPS IK disabled: " + message)
	_stop_ik()
	skeleton = null
	if model_root != null and is_instance_valid(model_root):
		model_root.visible = false
