extends Node3D

# v0.15: optional body-awareness preview. Real meshes stay in a local GLB,
# never in the Git repository. No weapon or camera transforms are changed.
const MODEL_PATH: String = "res://assets/characters/player_british/british_soldier_fps.glb"
const REQUIRED: PackedStringArray = PackedStringArray([
	"CC_Base_L_Thigh", "CC_Base_R_Thigh", "CC_Base_L_Calf",
	"CC_Base_R_Calf", "CC_Base_L_Hand", "CC_Base_R_Hand", "CC_Base_Head"
])
@export_range(-180.0, 180.0, 1.0) var body_yaw_degrees: float = 0.0
@export var conceal_unbound_fps_arms: bool = true
@export var preview_walk_legs: bool = true

var player: CharacterBody3D
var soldier: Node3D
var rig: Skeleton3D
var bones: Dictionary = {}
var original_rotations: Dictionary = {}
var previous_position: Vector3
var walk_cycle: float = 0.0
var walking_blend: float = 0.0
var visual_loaded: bool = false

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player == null:
		push_error("British PlayerBody: parent must be CharacterBody3D")
		return
	previous_position = player.global_position
	position.y = -0.95
	if not ResourceLoader.exists(MODEL_PATH):
		print("British PlayerBody: GLB not installed; previous FPS remains operational")
		return
	var packed: PackedScene = ResourceLoader.load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("British PlayerBody: cannot load " + MODEL_PATH)
		return
	soldier = packed.instantiate() as Node3D
	if soldier == null:
		push_error("British PlayerBody: GLB root must be Node3D")
		return
	add_child(soldier)
	soldier.name = "BritishSoldierFPS"
	soldier.rotation.y = deg_to_rad(body_yaw_degrees)
	var skeletons: Array[Node] = soldier.find_children("*", "Skeleton3D", true, false)
	var meshes: Array[Node] = soldier.find_children("*", "MeshInstance3D", true, false)
	if skeletons.is_empty() or meshes.size() < 3:
		_fail("missing Skeleton3D or insufficient meshes")
		return
	rig = skeletons[0] as Skeleton3D
	for name in REQUIRED:
		var index: int = rig.find_bone(name)
		if index < 0:
			_fail("required CC bone missing: " + name)
			return
		bones[name] = index
		original_rotations[index] = rig.get_bone_pose_rotation(index)
	if conceal_unbound_fps_arms:
		# Stage 1: use the original player rifle viewmodels; do not draw
		# detached T-pose arms while full rifle-grip IK is still pending.
		for name in ["CC_Base_L_Upperarm", "CC_Base_R_Upperarm"]:
			var arm: int = rig.find_bone(name)
			if arm >= 0:
				rig.set_bone_pose_scale(arm, Vector3.ZERO)
	visual_loaded = true
	print("WW2 British PlayerBody READY: %d meshes, %d bones" % [
		meshes.size(), rig.get_bone_count()
	])

func _fail(reason: String) -> void:
	push_error("WW2 British PlayerBody: " + reason)
	if soldier != null:
		soldier.visible = false

func _process(delta: float) -> void:
	if not visual_loaded or player == null or rig == null:
		return
	var controller: Node = player.get_node_or_null("StanceController")
	var stance: int = int(controller.get("stance")) if controller != null else 0
	var centre: float = 0.95
	if stance == 1:
		centre = 0.68
	elif stance == 2:
		centre = 0.34
	# Keep boots at the ground plane as Player's capsule changes height.
	position.y = -centre
	# Source FBX's TempMotion is a *single pose*, not a prone animation.
	# Do not render a rigid upright soldier through the road in prone.
	soldier.visible = stance != 2
	var displacement: Vector3 = player.global_position - previous_position
	displacement.y = 0.0
	previous_position = player.global_position
	if displacement.length() > 2.0:
		displacement = Vector3.ZERO
	if not preview_walk_legs or stance == 2:
		return
	walk_cycle += displacement.length() * TAU / 1.4
	walking_blend = move_toward(walking_blend,
		1.0 if displacement.length_squared() > 0.00000001 else 0.0,
		delta * 5.0)
	var gait: float = sin(walk_cycle) * walking_blend
	var crouch: float = 1.0 if stance == 1 else 0.0
	_pose_leg("CC_Base_L_Thigh", gait * 0.14 - crouch * 0.30)
	_pose_leg("CC_Base_R_Thigh", -gait * 0.14 - crouch * 0.30)
	_pose_leg("CC_Base_L_Calf", maxf(0.0, -gait) * 0.14 + crouch * 0.24)
	_pose_leg("CC_Base_R_Calf", maxf(0.0, gait) * 0.14 + crouch * 0.24)

func _pose_leg(name: String, angle: float) -> void:
	if not bones.has(name):
		return
	var index: int = int(bones[name])
	var parent_index: int = rig.get_bone_parent(index)
	var parent_rotation: Quaternion = Quaternion.IDENTITY
	if parent_index >= 0:
		parent_rotation = rig.get_bone_global_pose(parent_index).basis.get_rotation_quaternion()
	var world_axis: Vector3 = (global_transform.basis * Vector3.RIGHT).normalized()
	var rig_axis: Vector3 = (rig.global_transform.basis.inverse() * world_axis).normalized()
	var joint_axis: Vector3 = parent_rotation.inverse() * rig_axis
	rig.set_bone_pose_rotation(index,
		Quaternion(joint_axis.normalized(), angle) * original_rotations[index])
