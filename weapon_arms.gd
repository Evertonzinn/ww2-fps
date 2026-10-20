class_name FirstPersonArms
extends Node3D

# BAMEN FPS Arms, CC BY 4.0. 52-bone glTF model; no primitive placeholders.
# FIRST PASS ONLY: aligns wrist positions; no full-body IK or finger animations.
const MODEL_1K: String = "res://assets/characters/bamen_fps_arms/bamen_arms_1k.glb"
const MODEL_2K: String = "res://assets/characters/bamen_fps_arms/bamen_arms_2k.glb"

@export var right_hand_grip: Vector3 = Vector3(0.12, -0.15, -0.27)
@export var left_hand_support: Vector3 = Vector3(-0.08, -0.14, -0.80)
@export var left_hand_bolt: Vector3 = Vector3(-0.07, 0.055, -0.48)
@export var clip_hand_offset: Vector3 = Vector3(-0.055, 0.058, 0.005)
@export_range(2.0, 30.0, 0.5) var blend_speed: float = 12.0

var model_root: Node3D
var skeleton: Skeleton3D
var right_shoulder: int = -1
var left_shoulder: int = -1
var right_wrist: int = -1
var left_wrist: int = -1
var right_shoulder_rest: Transform3D
var left_shoulder_rest: Transform3D
var right_wrist_rest: Vector3
var left_wrist_rest: Vector3
var current_left_target: Vector3
var active_quality: int = 0

func _ready() -> void:
	current_left_target = left_hand_support
	# WeaponController loads the real model after instantiation.

func set_texture_quality(high_quality: bool) -> bool:
	var quality: int = 2 if high_quality else 1
	if model_root != null and is_instance_valid(model_root) and active_quality == quality:
		return true
	var path: String = MODEL_2K if quality == 2 else MODEL_1K
	if not ResourceLoader.exists(path):
		if quality == 2 and ResourceLoader.exists(MODEL_1K):
			path = MODEL_1K
			quality = 1
		else:
			push_warning("BAMEN FPS Arms: GLB missing: " + path)
			return false
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		push_warning("BAMEN FPS Arms: cannot import GLB: " + path)
		return false
	var replacement: Node3D = packed.instantiate() as Node3D
	if replacement == null:
		return false
	if model_root != null and is_instance_valid(model_root):
		model_root.queue_free()
	model_root = replacement
	model_root.name = "BamenRiggedArms"
	add_child(model_root)
	skeleton = null
	active_quality = quality
	call_deferred("_bind_skeleton", replacement)
	return true

func _bind_skeleton(expected_model: Node3D) -> void:
	if model_root != expected_model or not is_instance_valid(model_root):
		return
	var rigs: Array[Node] = model_root.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		push_warning("BAMEN FPS Arms: no Skeleton3D after import")
		model_root.visible = false
		return
	skeleton = rigs[0] as Skeleton3D
	if skeleton == null:
		model_root.visible = false
		return
	right_shoulder = _find_bone("arm1r")
	left_shoulder = _find_bone("arm1l")
	right_wrist = _find_bone("hand1r")
	left_wrist = _find_bone("hand1l")
	if right_shoulder < 0 or left_shoulder < 0 or right_wrist < 0 or left_wrist < 0:
		push_warning("BAMEN FPS Arms: shoulder or wrist bones not recognized")
		model_root.visible = false
		skeleton = null
		return
	# Cache bones in Skeleton3D local coordinates before modifying either shoulder.
	right_shoulder_rest = skeleton.get_bone_global_pose(right_shoulder)
	left_shoulder_rest = skeleton.get_bone_global_pose(left_shoulder)
	right_wrist_rest = skeleton.get_bone_global_pose(right_wrist).origin
	left_wrist_rest = skeleton.get_bone_global_pose(left_wrist).origin
	current_left_target = left_hand_support
	_apply_target(right_shoulder, right_shoulder_rest, right_wrist_rest, right_hand_grip)
	_apply_target(left_shoulder, left_shoulder_rest, left_wrist_rest, current_left_target)
	print("BAMEN FPS arms imported: %d bones; wrist targeting active." % skeleton.get_bone_count())

func update_pose(reloading: bool, phase: int, clip_position: Vector3, delta: float) -> void:
	if skeleton == null or not is_instance_valid(skeleton):
		return
	var target: Vector3 = left_hand_support
	if reloading:
		match phase:
			1, 3:
				target = left_hand_bolt
			2:
				target = clip_position + clip_hand_offset
	current_left_target = current_left_target.lerp(target, clampf(delta * blend_speed, 0.0, 1.0))
	_apply_target(left_shoulder, left_shoulder_rest, left_wrist_rest, current_left_target)

func _find_bone(prefix: String) -> int:
	for i in range(skeleton.get_bone_count()):
		var normalized: String = String(skeleton.get_bone_name(i)).to_lower()
		normalized = normalized.replace(".", "").replace("_", "").replace("-", "").replace(" ", "")
		if normalized.begins_with(prefix):
			return i
	return -1

func _apply_target(shoulder: int, base: Transform3D, rest_wrist: Vector3, weapon_point: Vector3) -> void:
	# Shift shoulder root and its complete skinned arm together to place wrist.
	# This is intentionally limited: elbow IK / finger grasp require a later rigging pass.
	var target_world: Vector3 = global_transform * weapon_point
	var target_local: Vector3 = skeleton.global_transform.affine_inverse() * target_world
	var desired: Transform3D = base
	desired.origin += target_local - rest_wrist
	skeleton.set_bone_global_pose(shoulder, desired)
