extends Node3D

# v0.15: optional body-awareness preview. Real meshes stay in a local GLB,
# never in the Git repository. No weapon or camera transforms are changed.
const MODEL_PATH: String = "res://assets/characters/player_british/british_soldier_fps.glb"
const REQUIRED = [
	"CC_Base_L_Thigh", "CC_Base_R_Thigh", "CC_Base_L_Calf",
	"CC_Base_R_Calf", "CC_Base_L_Hand", "CC_Base_R_Hand", "CC_Base_Head"
]
@export_range(-180.0, 180.0, 1.0) var body_yaw_degrees: float = 0.0
@export var conceal_unbound_fps_arms: bool = true
@export var preview_walk_legs: bool = true
# FPS anatomy: the hip is behind the eyes in +Z; -Z is forward in Godot.
# The previous 0.46m -Z shift projected the waistband ABOVE the boots.
@export_range(0.06, 0.28, 0.01) var eye_ahead_of_hips: float = 0.14

var player: CharacterBody3D
var soldier: Node3D
var rig: Skeleton3D
var bones: Dictionary = {}
var original_rotations: Dictionary = {}
var previous_position: Vector3
var walk_cycle: float = 0.0
var walking_blend: float = 0.0
var visual_loaded: bool = false
# In first-person only lower-body garment meshes may be rendered.
# Full CC_Base_Body and Vest occlude the camera even when head vertices
# were removed during conversion. Never expose those meshes in FPS.
var fps_lower_mesh_count: int = 0
var fps_hidden_upper_mesh_count: int = 0
var lower_body_bounds: AABB = AABB()
var measured_lower_body: bool = false
# Mesh AABBs and skinned rest bones can have different units after the
# Blender FBX->glTF export. Compare both before deciding a visual scale.
var raw_rig_leg_height: float = 0.0
var imported_visual_scale: float = 1.0
var corrected_visual_height: float = 0.0
var visual_bounds_source: String = "none"
var fps_hip_local: Vector3 = Vector3.ZERO
var fps_foot_local: Vector3 = Vector3.ZERO
var anatomical_anchors_valid: bool = false

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

	# Character Creator vendor asset has distinct CC_Base_Body, Vest,
	# Pants and Boots skinned meshes. The camera sits within the upper
	# torso: hiding the head bone is NOT enough to prevent occlusion.
	# Use a strict allowlist and fail closed if separate leg meshes are
	# unavailable. Do not mutate the GLB or the third-person mesh.
	var has_pants: bool = false
	var has_boots: bool = false
	for node in meshes:
		var piece: MeshInstance3D = node as MeshInstance3D
		if piece == null:
			continue
		var part_name: String = str(piece.name).to_lower()
		var pants: bool = part_name.contains("pants")
		var boots: bool = part_name.contains("boots")
		piece.visible = pants or boots
		if piece.visible:
			fps_lower_mesh_count += 1
			has_pants = has_pants or pants
			has_boots = has_boots or boots
		else:
			fps_hidden_upper_mesh_count += 1
	if not has_pants or not has_boots:
		_fail("FPS body requires separate Pants and Boots meshes; hiding unsafe model")
		return

	# Measure actual nested imported glTF transforms, not guessed source-FBX
	# coordinates. A visible=true flag alone does not put legs in camera.
	var min_corner: Vector3 = Vector3(INF, INF, INF)
	var max_corner: Vector3 = Vector3(-INF, -INF, -INF)
	for node in meshes:
		var piece: MeshInstance3D = node as MeshInstance3D
		if piece == null or not piece.visible:
			continue
		var garment_bounds: AABB = piece.get_aabb()
		for corner_index in range(8):
			var point: Vector3 = soldier.to_local(piece.to_global(
				garment_bounds.get_endpoint(corner_index)))
			min_corner = min_corner.min(point)
			max_corner = max_corner.max(point)
	lower_body_bounds = AABB(min_corner, max_corner - min_corner)
	var garment_height: float = lower_body_bounds.size.y
	if not is_finite(garment_height) or garment_height < 0.001:
		_fail("Pants/Boots AABB is empty or invalid")
		return

	# Prefer the actual rest-leg proportions over a skinned mesh AABB.
	# A Character Creator FBX can export a small mesh bounding box while
	# carrying its real deformation scale in the skeleton transforms.
	# Scaling by 1 / 0.011 blindly would then make a giant soldier.
	var thigh_index: int = rig.find_bone("CC_Base_L_Thigh")
	var foot_index: int = rig.find_bone("CC_Base_L_Foot")
	var have_rest_bones: bool = thigh_index >= 0 and foot_index >= 0
	var thigh_local: Vector3 = Vector3.ZERO
	var foot_local: Vector3 = Vector3.ZERO
	if have_rest_bones:
		thigh_local = soldier.to_local(rig.to_global(
			rig.get_bone_global_rest(thigh_index).origin))
		foot_local = soldier.to_local(rig.to_global(
			rig.get_bone_global_rest(foot_index).origin))
		raw_rig_leg_height = thigh_local.distance_to(foot_local)

	var reference_span: float = garment_height
	var floor_y: float = lower_body_bounds.position.y
	var mid_x: float = lower_body_bounds.position.x + lower_body_bounds.size.x * 0.5
	var mid_z: float = lower_body_bounds.position.z + lower_body_bounds.size.z * 0.5
	var target_span: float = 1.03  # lower garment: waist to boot sole, metres
	visual_bounds_source = "mesh"
	if have_rest_bones and is_finite(raw_rig_leg_height) and raw_rig_leg_height > 0.003:
		# Anatomical thigh-to-foot length is typically shorter than
		# trousers including boots. It remains valid when mesh AABB is tiny.
		reference_span = raw_rig_leg_height
		target_span = 0.86
		visual_bounds_source = "skeleton"
		if garment_height < raw_rig_leg_height * 0.25:
			print("WW2 British PlayerBody: tiny static mesh AABB vs rig; using rest bones")
		# Locate ankles from actual rest bones, not unreliable mesh origin.
		var right_foot_index: int = rig.find_bone("CC_Base_R_Foot")
		var right_thigh_index: int = rig.find_bone("CC_Base_R_Thigh")
		if right_foot_index >= 0 and right_thigh_index >= 0:
			var right_foot: Vector3 = soldier.to_local(rig.to_global(
				rig.get_bone_global_rest(right_foot_index).origin))
			var right_thigh: Vector3 = soldier.to_local(rig.to_global(
				rig.get_bone_global_rest(right_thigh_index).origin))
			floor_y = minf(foot_local.y, right_foot.y) - raw_rig_leg_height * 0.08
			mid_x = (thigh_local.x + right_thigh.x) * 0.5
			# Centre the player's hips below/behind the camera.
			mid_z = (thigh_local.z + right_thigh.z) * 0.5
			fps_hip_local = (thigh_local + right_thigh) * 0.5
			fps_foot_local = (foot_local + right_foot) * 0.5
		else:
			floor_y = foot_local.y - raw_rig_leg_height * 0.08
			mid_x = thigh_local.x
			mid_z = thigh_local.z
			fps_hip_local = thigh_local
			fps_foot_local = foot_local
		anatomical_anchors_valid = true

	imported_visual_scale = target_span / reference_span
	corrected_visual_height = reference_span * imported_visual_scale
	if not is_finite(imported_visual_scale) or imported_visual_scale < 0.003 or imported_visual_scale > 300.0:
		_fail("unsafe CC5 body scale %.4f (mesh=%.4fm, leg=%.4fm)" % [
			imported_visual_scale, garment_height, raw_rig_leg_height
		])
		return
	# Scale the imported rig and its skinned meshes TOGETHER. This is
	# outside the Player collider and does not alter physics or gun FOV.
	soldier.scale = Vector3.ONE * imported_visual_scale
	if not _align_feet_forward():
		return
	# Transform the measured anchor through the FINAL imported basis.
	# Subtracting unrotated X/Z coordinates would move the hips away from
	# the camera as soon as the source model needs a yaw correction.
	var source_anchor: Vector3 = Vector3(mid_x, floor_y, mid_z)
	soldier.position = Vector3(0.0, 0.0, eye_ahead_of_hips) - soldier.basis * source_anchor
	measured_lower_body = true
	print("WW2 British PlayerBody BOUNDS: mesh=%.4fm rig=%.4fm source=%s scale=%.4f normalized=%.3fm offset=%s" % [
		garment_height, raw_rig_leg_height, visual_bounds_source,
		imported_visual_scale, corrected_visual_height, str(soldier.position)
	])
	if anatomical_anchors_valid:
		var hip_in_player: Vector3 = player.to_local(soldier.to_global(fps_hip_local))
		var boot_in_player: Vector3 = player.to_local(soldier.to_global(fps_foot_local))
		print("WW2 British PlayerBody ANATOMY: hip=%s boot=%s" % [
			str(hip_in_player), str(boot_in_player)
		])
	if conceal_unbound_fps_arms:
		# Stage 1: use the original player rifle viewmodels; do not draw
		# detached T-pose arms while full rifle-grip IK is still pending.
		for name in ["CC_Base_L_Upperarm", "CC_Base_R_Upperarm"]:
			var arm: int = rig.find_bone(name)
			if arm >= 0:
				rig.set_bone_pose_scale(arm, Vector3.ZERO)
	visual_loaded = true
	print("WW2 British PlayerBody READY: %d meshes, %d bones; FPS legs=%d hidden_upper=%d" % [
		meshes.size(), rig.get_bone_count(),
		fps_lower_mesh_count, fps_hidden_upper_mesh_count
	])

func _align_feet_forward() -> bool:
	# Derive source forward from the imported rig, never assume FBX/glTF +Z/-Z.
	# Rest positions avoid recalibration from the procedural walking pose.
	var forwards: Array[Vector3] = []
	for side in ["L", "R"]:
		var foot_index: int = rig.find_bone("CC_Base_" + side + "_Foot")
		var toe_index: int = -1
		if foot_index >= 0:
			for child_index in rig.get_bone_children(foot_index):
				if str(rig.get_bone_name(child_index)).to_lower().contains("toe"):
					toe_index = child_index
					break
		if foot_index < 0 or toe_index < 0:
			_fail("cannot derive forward: missing foot/toe chain for " + side)
			return false
		var foot: Vector3 = to_local(rig.to_global(rig.get_bone_global_rest(foot_index).origin))
		var toe: Vector3 = to_local(rig.to_global(rig.get_bone_global_rest(toe_index).origin))
		var forward: Vector3 = toe - foot
		forward.y = 0.0
		if not forward.is_finite() or forward.length_squared() < 0.00000001:
			_fail("cannot derive forward: degenerate foot/toe direction for " + side)
			return false
		forwards.append(forward.normalized())
	if forwards[0].dot(forwards[1]) < 0.25:
		_fail("cannot derive forward: left/right feet disagree")
		return false
	var source_forward: Vector3 = (forwards[0] + forwards[1]).normalized()
	var correction: float = atan2(source_forward.x, -source_forward.z)
	# Rotate only the visual root; rig, skin and meshes stay together.
	# The existing exported yaw remains an optional adjustment AFTER calibration.
	soldier.basis = Basis(Vector3.UP, correction + deg_to_rad(body_yaw_degrees)) * soldier.basis
	print("WW2 British PlayerBody FORWARD: source=%s correction=%.2f degrees" % [
		str(source_forward), rad_to_deg(correction)
	])
	return true

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
	# The lower-body garments stay present. Their actual geometry is below
	# the eye position and outside the forward aim ray; looking downward
	# reveals them naturally, without the old artificial -31-degree gate.
	# Hide only in prone (missing authored clip) and while aiming RMB.
	var ads_active: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	soldier.visible = stance != 2 and not ads_active
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
	var pace: float = displacement.length() / maxf(delta, 0.001)
	var run_factor: float = clampf((pace - 4.0) / 4.0, 0.0, 1.0)
	var swing: float = lerpf(0.23, 0.35, run_factor)
	var crouch: float = 1.0 if stance == 1 else 0.0
	if stance == 1:
		swing = 0.12
	_pose_leg("CC_Base_L_Thigh", gait * swing - crouch * 0.30)
	_pose_leg("CC_Base_R_Thigh", -gait * swing - crouch * 0.30)
	_pose_leg("CC_Base_L_Calf", maxf(0.0, -gait) * swing * 0.66 + crouch * 0.24)
	_pose_leg("CC_Base_R_Calf", maxf(0.0, gait) * swing * 0.66 + crouch * 0.24)

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
