extends SceneTree

# Run after unpacking the CC BY 4.0 BAMEN hands kit into the project root.
# Godot 4.7.2: --headless --path "$PWD" --script res://tests/v160_weapon_hands_smoke.gd
const MODEL: String = "res://assets/characters/bamen_fps_arms/bamen_arms_1k.glb"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(MODEL):
		push_error("v0.16 HANDS SMOKE BLOCKED: unpack the supplied arms ZIP first")
		quit(2)
		return
	if change_scene_to_file("res://main.tscn") != OK:
		push_error("v0.16 HANDS SMOKE FAIL: main scene unavailable")
		quit(1)
		return
	for i in range(6):
		await process_frame
	for i in range(4):
		await physics_frame
	var rifle: WeaponController = current_scene.get_node_or_null("Player/Head/Camera3D/Weapon") as WeaponController
	if rifle == null:
		_fail("WeaponController was changed or removed")
		return
	var hands: FirstPersonWeaponHands = rifle.get_node_or_null("WeaponHands") as FirstPersonWeaponHands
	if hands == null or hands.hands_initialized != true:
		_fail("both skinned FPS arms did not initialize")
		return
	if hands.skeleton == null or hands.skeleton.get_bone_count() < 50:
		_fail("invalid original rigged hand skeleton")
		return
	if hands.skeleton.modifier_callback_mode_process != Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
		_fail("IK modifier and Weapon viewmodel do not use the same idle frame timing")
		return
	if hands._rest_chain_length(hands.right_chain) < 0.45 or hands._rest_chain_length(hands.left_chain) < 0.45:
		_fail("real original arm length missing/incorrect scale")
		return
	if hands.right_ik == null or hands.left_ik == null:
		_fail("two arm IK chains were not created")
		return
	# Target path MUST resolve from the SkeletonIK3D node itself.
	# Godot 4.7.2 previously logged "Node not found" while code still
	# announced HANDS READY, so verify actual node identity here.
	var right_resolved: Node = hands.right_ik.get_node_or_null(hands.right_ik.target_node)
	var left_resolved: Node = hands.left_ik.get_node_or_null(hands.left_ik.target_node)
	if right_resolved != hands.right_target or left_resolved != hands.left_target:
		_fail("IK target paths invalid: right=%s left=%s" % [
			str(hands.right_ik.target_node), str(hands.left_ik.target_node)
		])
		return
	if hands.right_ik.get_parent_skeleton() != hands.skeleton or hands.left_ik.get_parent_skeleton() != hands.skeleton:
		_fail("IK node is not attached to imported Skeleton3D")
		return
	if not hands.right_ik.is_running() or not hands.left_ik.is_running():
		_fail("IK was created but is not running")
		return
	print("PASS: two IK targets resolve from their OWN nodes and solvers are running")
	print("PASS: rigged skinned hands (bones=%d)" % hands.skeleton.get_bone_count())
	# SkeletonModifier3D runs DEFERRED: querying get_bone_global_pose()
	# after await process_frame reads the restored PRE-IK pose in Godot 4.
	# The rig now records real wrist positions IN the final IK modifier
	# signal, after both chains have run.
	for frame in range(8):
		await process_frame
	if hands.ik_modifier_samples < 2:
		_fail("IK modifiers never processed: samples=%d" % hands.ik_modifier_samples)
		return
	if hands.ik_sample_weapon_slot != 1:
		_fail("IK final sample belongs to wrong weapon")
		return
	var lee_right_error: float = hands.ik_right_error
	var lee_left_error: float = hands.ik_left_error
	print("WW2 FPS HANDS FINAL IK: Lee right=%.3fm left=%.3fm samples=%d" % [
		lee_right_error, lee_left_error, hands.ik_modifier_samples
	])
	var lee_right_clamp: float = hands.right_target.position.distance_to(hands._target_right())
	var lee_left_clamp: float = hands.left_target.position.distance_to(hands._target_left())
	print("WW2 FPS HANDS GRIP CLAMP: Lee right=%.3fm left=%.3fm" % [
		lee_right_clamp, lee_left_clamp
	])
	if lee_right_clamp > 0.12 or lee_left_clamp > 0.12:
		_fail("IK targets are clamped too far from actual rifle grips")
		return
	if not is_finite(lee_right_error) or not is_finite(lee_left_error):
		_fail("Lee grip IK produced non-finite wrist positions")
		return
	if lee_right_error > 0.10 or lee_left_error > 0.10 or hands.pose_safe != true:
		_fail("Lee wrists did not reach weapon grips (right=%.3fm left=%.3fm)" % [
			lee_right_error, lee_left_error
		])
		return
	print("PASS: both skinned hands converge onto Lee-Enfield grips")
	if hands.right_target.position.distance_to(hands.left_target.position) < 0.10:
		_fail("both hands collapsed into same target")
		return
	if rifle.sniper_view == null:
		_fail("SniperView missing")
		return
	# Switching should preserve gameplay ammo and attach new hand targets
	# to the new rifle without modifying the scope or muzzle direction.
	var lee_ammo: int = rifle.magazine
	rifle.select_weapon(2)
	if not rifle.sniper_equipped:
		_fail("sniper failed to equip, check local sniper GLB")
		return
	hands._process(0.2)
	if hands._target_right().distance_to(hands._target_left()) < 0.10:
		_fail("sniper support and grip targets are indistinguishable")
		return
	if not hands.current_right.is_finite() or not hands.current_left.is_finite():
		_fail("sniper hand pose is non-finite")
		return
	var previous_modifier_samples: int = hands.ik_modifier_samples
	for frame in range(8):
		await process_frame
	if hands.ik_modifier_samples <= previous_modifier_samples:
		_fail("sniper IK modifiers did not process new frames")
		return
	if hands.ik_sample_weapon_slot != 2:
		_fail("IK final sample still corresponds to Lee-Enfield")
		return
	var sniper_right_error: float = hands.ik_right_error
	var sniper_left_error: float = hands.ik_left_error
	print("WW2 FPS HANDS FINAL IK: sniper right=%.3fm left=%.3fm samples=%d" % [
		sniper_right_error, sniper_left_error, hands.ik_modifier_samples
	])
	if not is_finite(sniper_right_error) or not is_finite(sniper_left_error):
		_fail("sniper IK produced non-finite wrist positions")
		return
	if sniper_right_error > 0.10 or sniper_left_error > 0.10 or hands.pose_safe != true:
		_fail("sniper wrists did not reach weapon grips (right=%.3fm left=%.3fm)" % [
			sniper_right_error, sniper_left_error
		])
		return
	print("PASS: sniper selection retains two real wrist grip poses")
	rifle.select_weapon(1)
	hands._process(0.2)
	if rifle.sniper_equipped or rifle.magazine != lee_ammo:
		_fail("return to Lee-Enfield changed weapon state or ammo")
		return
	print("PASS: Lee-Enfield switching and ammo unaffected")
	var camera: Camera3D = current_scene.get_node_or_null("Player/Head/Camera3D") as Camera3D
	if camera == null or camera.fov < 10.0 or camera.fov > 120.0:
		_fail("camera FOV contract invalid")
		return
	print("WW2 FPS v0.16 RIGGED HANDS SMOKE: PASS")
	quit(0)

func _fail(reason: String) -> void:
	push_error("WW2 FPS v0.16 RIGGED HANDS SMOKE: FAIL — " + reason)
	quit(1)

# Wrist measurements are supplied exclusively by SkeletonModifier3D's
# modification_processed callback, not ordinary SceneTree frame loops.
