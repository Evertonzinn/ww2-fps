class_name FirstPersonWeaponHands
extends Node3D

# WW2 FPS v0.16 — optional licensed 52-bone BAMEN hand/forearm viewmodel.
# Physically attached to Weapon, NOT the world/Player collision capsule.
# This is visual-only: ammo, bolt, hitscan and scope remain authoritative.
const MODEL_1K: String = "res://assets/characters/bamen_fps_arms/bamen_arms_1k.glb"
const MODEL_2K: String = "res://assets/characters/bamen_fps_arms/bamen_arms_2k.glb"

const LEE_RIGHT_GRIP: Vector3 = Vector3(0.12, -0.15, -0.27)
const LEE_LEFT_SUPPORT: Vector3 = Vector3(-0.09, -0.14, -0.66)
const LEE_RIGHT_BOLT: Vector3 = Vector3(0.11, 0.04, -0.39)
const SNIPER_RIGHT_GRIP: Vector3 = Vector3(0.10, -0.12, -0.18)
const SNIPER_LEFT_SUPPORT: Vector3 = Vector3(-0.08, -0.13, -0.47)
const SNIPER_RIGHT_BOLT: Vector3 = Vector3(0.18, 0.04, -0.27)
const SNIPER_LEFT_MAGAZINE: Vector3 = Vector3(-0.07, -0.30, -0.29)

# Shoulder midpoint in Weapon local coordinates, not Camera world space.
# Lee's Weapon moves for hip/ADS. SniperView moves inside Weapon.
const LEE_SHOULDERS: Vector3 = Vector3(0.03, -0.30, -0.10)
const SNIPER_SHOULDERS: Vector3 = Vector3(0.18, -0.32, -0.57)
const MAX_REACH: float = 0.96
# Stable elbow pole positions in Weapon-local space. These are recalculated
# in skeleton space AFTER repositioning the rig every frame.
const RIGHT_ELBOW_POLE: Vector3 = Vector3(0.43, -0.55, 0.10)
const LEFT_ELBOW_POLE: Vector3 = Vector3(-0.43, -0.55, -0.12)

@export_range(3.0, 30.0, 0.5) var pose_speed: float = 15.0
@export_range(-180.0, 180.0, 1.0) var rig_yaw_degrees: float = 0.0
@export var enable_rigged_hands: bool = true

var weapon: Variant
var model_root: Node3D
var skeleton: Skeleton3D
var right_target: Marker3D
var left_target: Marker3D
var right_ik: SkeletonIK3D
var left_ik: SkeletonIK3D
var right_chain: Array[int] = []
var left_chain: Array[int] = []
var resting_shoulder_mid: Vector3 = Vector3.ZERO
var current_right: Vector3 = Vector3.ZERO
var current_left: Vector3 = Vector3.ZERO
var hands_initialized: bool = false
var active_quality: int = 0
var reach_limited_frames: int = 0

# Godot 4's SkeletonModifier3D runs in deferred skeleton processing.
# get_bone_global_pose() in the test's process_frame sees PRE-MODIFIER
# poses. Sample actual solved joints while modification_processed fires.
var ik_modifier_samples: int = 0
var ik_right_error: float = INF
var ik_left_error: float = INF
var ik_right_wrist_world: Vector3 = Vector3.ZERO
var ik_left_wrist_world: Vector3 = Vector3.ZERO
var ik_sample_weapon_slot: int = 1
var pose_safe: bool = false
var bad_pose_samples: int = 0
var invalid_pose_reported: bool = false
var last_weapon_slot: int = 1
var last_pose_target_delta: float = 0.0
const MAX_FINAL_GRIP_ERROR: float = 0.025
const BAD_POSE_GRACE_FRAMES: int = 4

func _ready() -> void:
	weapon = get_parent()
	# Weapon and SniperView update first, then sample their final transforms.
	process_priority = 10
	# The weapon script preloads this file. Keep this reference dynamic to
	# avoid an import cycle (WeaponController -> FirstPersonWeaponHands -> WeaponController).
	if weapon == null or not weapon.has_method("select_weapon"):
		push_warning("FPS hands disabled: expected WeaponController parent")
		return
	right_target = Marker3D.new()
	right_target.name = "RightHandOnGrip"
	add_child(right_target)
	left_target = Marker3D.new()
	left_target.name = "LeftHandOnStock"
	add_child(left_target)
	if enable_rigged_hands:
		set_texture_quality(weapon.requested_high_texture)

func set_texture_quality(high: bool) -> bool:
	var preferred: int = 2 if high else 1
	var chosen: int = preferred
	var path: String = MODEL_2K if high else MODEL_1K
	if not ResourceLoader.exists(path):
		if high and ResourceLoader.exists(MODEL_1K):
			path = MODEL_1K
			chosen = 1
		elif not high and ResourceLoader.exists(MODEL_2K):
			# A locally installed 2K-only arm rig must still render.
			path = MODEL_2K
			chosen = 2
			push_warning("FPS hands: 1K asset missing, using 2K (higher VRAM cost)")
		else:
			push_warning("FPS hands optional GLB absent: " + path +
				" (install the v0.16 rigged-hands kit)")
			return false
	if hands_initialized and chosen == active_quality:
		return true
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		push_warning("FPS hands: invalid GLB " + path)
		return false
	var replacement: Node3D = packed.instantiate() as Node3D
	if replacement == null:
		push_warning("FPS hands: asset scene is not Node3D")
		return false
	# Keep approved previous visuals intact if replacement is invalid.
	var candidates: Array[Node] = replacement.find_children("*", "Skeleton3D", true, false)
	var meshes: Array[Node] = replacement.find_children("*", "MeshInstance3D", true, false)
	if candidates.is_empty() or meshes.size() < 2:
		replacement.free()
		push_warning("FPS hands: missing skinned meshes/Skeleton3D")
		return false
	var candidate_rig: Skeleton3D = candidates[0] as Skeleton3D
	if candidate_rig == null or candidate_rig.get_bone_count() < 50:
		replacement.free()
		push_warning("FPS hands: unexpected skeleton/bone count")
		return false
	var right_indices: Array[int] = _chain(candidate_rig, "r")
	var left_indices: Array[int] = _chain(candidate_rig, "l")
	if right_indices.size() != 3 or left_indices.size() != 3:
		replacement.free()
		push_warning("FPS hands: shoulder/elbow/wrist chains not found")
		return false

	_shutdown_ik()
	if model_root != null and is_instance_valid(model_root):
		remove_child(model_root)
		model_root.queue_free()
	model_root = replacement
	model_root.name = "BAMEN_RiggedArms"
	model_root.visible = false
	add_child(model_root)
	model_root.rotation.y = deg_to_rad(rig_yaw_degrees)
	skeleton = candidate_rig
	# The camera/Weapon viewmodel, IK markers and cosmetic hands all
	# animate in _process. Run SkeletonModifier3D in IDLE too, otherwise
	# physics-tick modifiers can sample a different target pose and jitter.
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	right_chain = right_indices
	left_chain = left_indices
	var right_rest: Vector3 = _rest_in_weapon(right_chain[0])
	var left_rest: Vector3 = _rest_in_weapon(left_chain[0])
	# Anchor actual shoulder bones instead of moving the entire arm to
	# the wrist as in the deprecated v0.8.2 prototype.
	resting_shoulder_mid = (right_rest + left_rest) * 0.5 - model_root.position
	var shoulder: Vector3 = SNIPER_SHOULDERS if weapon.sniper_equipped else LEE_SHOULDERS
	model_root.position = shoulder - resting_shoulder_mid
	right_ik = _make_ik("RightArmGripIK", right_chain, right_target,
		RIGHT_ELBOW_POLE)
	left_ik = _make_ik("LeftArmSupportIK", left_chain, left_target,
		LEFT_ELBOW_POLE)
	# A previous release called start() with invalid target_node paths,
	# printed READY, and left both wrists >30cm from the rifle. Never
	# start or expose the rig until BOTH IK paths resolve to the markers.
	if right_ik == null or left_ik == null:
		_disable_invalid_rig("an IK target NodePath does not resolve")
		return false
	if not _ik_paths_resolve():
		_disable_invalid_rig("two-arm IK does not resolve both grip markers")
		return false
	current_right = _target_right()
	current_left = _target_left()
	right_target.position = current_right
	left_target.position = current_left
	_fit_shoulders_to_grips(current_right, current_left)
	_refresh_elbow_poles()
	# The left modifier was appended after the right: when its signal
	# fires, both arm chains have been modified on the SAME frame.
	# Do not sample after process_frame (the engine can restore the
	# pre-modifier pose before ordinary GDScript processing resumes).
	left_ik.modification_processed.connect(_on_final_ik_pose)
	right_ik.start()
	left_ik.start()
	if not right_ik.is_running() or not left_ik.is_running():
		_disable_invalid_rig("IK solver failed to start")
		return false
	active_quality = chosen
	last_weapon_slot = 2 if weapon.sniper_equipped else 1
	hands_initialized = true
	# Never show hands until final solved wrists are measured (v0.16.3).
	# Report actual per-bone arm lengths to distinguish unreachable grips.
	print("WW2 FPS HANDS READY: %d bones, %d skinned meshes, quality=%dk, dual IK" % [
		skeleton.get_bone_count(), meshes.size(), active_quality
	])
	print("WW2 FPS HANDS ANATOMY: right=%.3fm left=%.3fm shoulders=%s" % [
		_rest_chain_length(right_chain), _rest_chain_length(left_chain),
		str(resting_shoulder_mid)
	])
	return true

func _on_final_ik_pose() -> void:
	if skeleton == null or right_chain.size() != 3 or left_chain.size() != 3:
		return
	# This callback runs during SkeletonModifier3D.modification_processed:
	# ONLY now are the modified bone poses authoritative in Godot 4.
	ik_right_wrist_world = skeleton.to_global(
		skeleton.get_bone_global_pose(right_chain[2]).origin)
	ik_left_wrist_world = skeleton.to_global(
		skeleton.get_bone_global_pose(left_chain[2]).origin)
	# Measure against the requested weapon contact, not a clamped surrogate.
	ik_right_error = ik_right_wrist_world.distance_to(to_global(current_right))
	ik_left_error = ik_left_wrist_world.distance_to(to_global(current_left))
	ik_sample_weapon_slot = 2 if weapon.sniper_equipped else 1
	ik_modifier_samples += 1
	var valid_sample: bool = (
		ik_right_wrist_world.is_finite() and ik_left_wrist_world.is_finite() and
		is_finite(ik_right_error) and is_finite(ik_left_error) and
		ik_right_error <= MAX_FINAL_GRIP_ERROR and
		ik_left_error <= MAX_FINAL_GRIP_ERROR)
	if valid_sample:
		pose_safe = true
		bad_pose_samples = 0
		invalid_pose_reported = false
	else:
		bad_pose_samples += 1
		if bad_pose_samples >= BAD_POSE_GRACE_FRAMES:
			pose_safe = false
			if not invalid_pose_reported:
				invalid_pose_reported = true
				push_warning("WW2 FPS HANDS POSE UNSAFE: slot=%d right=%.3fm left=%.3fm; hiding floating arms" % [
					ik_sample_weapon_slot, ik_right_error, ik_left_error
				])

func _ik_paths_resolve() -> bool:
	return right_ik != null and left_ik != null and (
		right_ik.get_parent_skeleton() == skeleton and
		left_ik.get_parent_skeleton() == skeleton and
		right_ik.get_node_or_null(right_ik.target_node) == right_target and
		left_ik.get_node_or_null(left_ik.target_node) == left_target)

func _disable_invalid_rig(reason: String) -> void:
	# Fail closed: the rifles are playable, but invalid IK must never
	# place detached forearms over the screen.
	push_warning("WW2 FPS HANDS DISABLED: " + reason)
	_shutdown_ik()
	if model_root != null and is_instance_valid(model_root):
		model_root.visible = false

func _shutdown_ik() -> void:
	# On quality changes, old modifier signals must not leave a
	# previous pose sample masquerading as a solved new rig.
	ik_modifier_samples = 0
	ik_right_error = INF
	ik_left_error = INF
	ik_sample_weapon_slot = 1
	pose_safe = false
	bad_pose_samples = 0
	invalid_pose_reported = false
	if right_ik != null and is_instance_valid(right_ik):
		right_ik.stop()
	if left_ik != null and is_instance_valid(left_ik):
		left_ik.stop()
	right_ik = null
	left_ik = null
	hands_initialized = false

func _chain(rig: Skeleton3D, side: String) -> Array[int]:
	var upper: int = _find_bone(rig, "arm1" + side)
	var elbow: int = _find_bone(rig, "arm2" + side)
	var wrist: int = _find_bone(rig, "hand1" + side)
	if upper < 0 or elbow < 0 or wrist < 0:
		return []
	if rig.get_bone_parent(elbow) != upper or rig.get_bone_parent(wrist) != elbow:
		return []
	return [upper, elbow, wrist]

func _find_bone(rig: Skeleton3D, prefix: String) -> int:
	for i in range(rig.get_bone_count()):
		var name: String = String(rig.get_bone_name(i)).to_lower()
		name = name.replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
		if name.begins_with(prefix):
			return i
	return -1

func _make_ik(label: String, chain: Array[int], marker: Marker3D,
		pole: Vector3) -> SkeletonIK3D:
	var ik: SkeletonIK3D = SkeletonIK3D.new()
	ik.name = label
	ik.root_bone = skeleton.get_bone_name(chain[0])
	ik.tip_bone = skeleton.get_bone_name(chain[2])
	ik.override_tip_basis = false
	ik.max_iterations = 24
	ik.min_distance = 0.003
	skeleton.add_child(ik)
	# target_node belongs to SkeletonIK3D, NOT to its Skeleton3D parent.
	# Calculating skeleton.get_path_to(marker) made NodePaths one "../"
	# short: Godot reported ".../RightHandOnGrip" not found from the IK.
	ik.target_node = ik.get_path_to(marker)
	if ik.get_node_or_null(ik.target_node) != marker:
		push_warning("FPS hands IK: failed to resolve " + str(ik.target_node) +
			" from " + str(ik.get_path()))
		ik.queue_free()
		return null
	ik.use_magnet = true
	ik.magnet = skeleton.to_local(to_global(pole))
	return ik

func _rest_in_weapon(index: int) -> Vector3:
	return to_local(skeleton.to_global(skeleton.get_bone_global_rest(index).origin))

func _rest_chain_length(chain: Array[int]) -> float:
	if chain.size() != 3:
		return 0.0
	var a: Vector3 = _rest_in_weapon(chain[0])
	var b: Vector3 = _rest_in_weapon(chain[1])
	var c: Vector3 = _rest_in_weapon(chain[2])
	return a.distance_to(b) + b.distance_to(c)

func _refresh_elbow_poles() -> void:
	if skeleton == null or right_ik == null or left_ik == null:
		return
	# Godot IK magnet is a position in SKELETON coordinates. A constant
	# calculated only during _ready becomes stale while shoulders shift
	# for sniper/Lee and ADS. Refresh after repositioning the rig.
	right_ik.magnet = skeleton.to_local(to_global(RIGHT_ELBOW_POLE))
	left_ik.magnet = skeleton.to_local(to_global(LEFT_ELBOW_POLE))

func _fit_shoulders_to_grips(right_grip: Vector3, left_grip: Vector3) -> void:
	# A whole-rig translation preserves arm lengths and the shoulder span.
	# Project the translation into each arm's reachable ball; never move
	# the contact markers off the rifle merely to satisfy the IK solver.
	for iteration in range(12):
		var correction: float = 0.0
		for side in range(2):
			var chain: Array[int] = right_chain if side == 0 else left_chain
			var grip: Vector3 = right_grip if side == 0 else left_grip
			var shoulder: Vector3 = _rest_in_weapon(chain[0])
			var reach: float = _rest_chain_length(chain) * MAX_REACH
			var offset: Vector3 = grip - shoulder
			if reach > 0.10 and offset.length() > reach:
				var shift: Vector3 = offset.normalized() * (offset.length() - reach)
				model_root.position += shift
				correction = maxf(correction, shift.length())
		if correction < 0.0001:
			break

func _target_right() -> Vector3:
	if weapon.sniper_equipped and weapon.sniper_view != null:
		var view: SniperView = weapon.sniper_view
		var spot: Vector3 = SNIPER_RIGHT_BOLT if view.bolt_running else SNIPER_RIGHT_GRIP
		return to_local(view.to_global(spot))
	# Preserve the Lee's original bolt movement; this hand is only visual.
	if weapon.bolt_timer > 0.0 or (weapon.reloading and weapon.reload_phase == 1):
		return LEE_RIGHT_BOLT
	return LEE_RIGHT_GRIP

func _target_left() -> Vector3:
	if weapon.sniper_equipped and weapon.sniper_view != null:
		var view: SniperView = weapon.sniper_view
		var spot: Vector3 = SNIPER_LEFT_MAGAZINE if view.reload_timer > 0.0 else SNIPER_LEFT_SUPPORT
		return to_local(view.to_global(spot))
	if weapon.reloading and weapon.reload_phase == 2 and weapon.reload_fx != null:
		var charger: Node3D = weapon.reload_fx.active_charger
		if charger != null and is_instance_valid(charger):
			return to_local(charger.to_global(Vector3(-0.04, 0.06, 0.0)))
	return LEE_LEFT_SUPPORT

func _process(delta: float) -> void:
	if not hands_initialized or model_root == null or not is_instance_valid(model_root):
		return
	if weapon == null or weapon.player_body == null:
		return
	if weapon.player_body.is_dead:
		model_root.visible = false
		return
	var sniper: bool = weapon.sniper_equipped
	var scope_shown: bool = sniper and weapon.sniper_view != null and (
		weapon.sniper_view.scope_layer != null and weapon.sniper_view.scope_layer.visible)
	# Never draw forearms in front of the telescope's scope overlay.
	# Never display detached/T-pose arms until BOTH IK chains are
	# confirmed close to the grips by the FINAL modifier output.
	# Missing or unsafe pose must not cover rifle, scope or HUD.
	model_root.visible = not scope_shown and pose_safe
	# Update IK targets even when the model is hidden: the pose
	# must be allowed to converge and recover without toggling.
	# Scope visibility alone does not control the solver.
	var active_slot: int = 2 if sniper else 1
	var target_shoulder: Vector3 = SNIPER_SHOULDERS if sniper else LEE_SHOULDERS
	var blend: float = minf(1.0, delta * pose_speed)
	# Camera and hands share this _process phase. Do not animate an
	# IK target in physics while the weapon itself animates in idle.
	model_root.position = model_root.position.lerp(
		target_shoulder - resting_shoulder_mid, blend)
	_refresh_elbow_poles()
	var wanted_right: Vector3 = _target_right()
	var wanted_left: Vector3 = _target_left()
	if active_slot != last_weapon_slot:
		# A weapon switch changes grip locations immediately. Avoid
		# retaining stale 'pose_safe' from the previous rifle.
		pose_safe = false
		bad_pose_samples = 0
		last_weapon_slot = active_slot
	# Keep contact in the weapon frame: smoothing these world-relative
	# positions made the sniper outrun its hands during recoil/ADS.
	# Smooth only deliberate hand travel during bolt/reload state changes.
	var right_action: bool = weapon.sniper_view.bolt_running if sniper else (
		weapon.bolt_timer > 0.0 or (weapon.reloading and weapon.reload_phase == 1))
	var left_action: bool = weapon.sniper_view.reload_timer > 0.0 if sniper else weapon.reloading
	current_right = current_right.lerp(wanted_right, blend) if right_action else wanted_right
	current_left = current_left.lerp(wanted_left, blend) if left_action else wanted_left
	right_target.position = current_right
	left_target.position = current_left
	_fit_shoulders_to_grips(current_right, current_left)
	_refresh_elbow_poles()
	last_pose_target_delta = maxf(
		right_target.position.distance_to(wanted_right),
		left_target.position.distance_to(wanted_left))
