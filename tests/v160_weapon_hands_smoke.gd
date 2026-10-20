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
	# Merely constructing IK targets was a false-positive risk in older
	# prototypes. The actual wrist joints must converge to rifle targets.
	for frame in range(8):
		await process_frame
	var lee_right_error: float = _wrist_error(hands, hands.right_chain,
		hands.right_target.position)
	var lee_left_error: float = _wrist_error(hands, hands.left_chain,
		hands.left_target.position)
	print("WW2 FPS HANDS GRIP: Lee right=%.3fm left=%.3fm" % [
		lee_right_error, lee_left_error
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
	if lee_right_error > 0.18 or lee_left_error > 0.18:
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
	for frame in range(8):
		await process_frame
	var sniper_right_error: float = _wrist_error(hands, hands.right_chain,
		hands.right_target.position)
	var sniper_left_error: float = _wrist_error(hands, hands.left_chain,
		hands.left_target.position)
	print("WW2 FPS HANDS GRIP: sniper right=%.3fm left=%.3fm" % [
		sniper_right_error, sniper_left_error
	])
	if not is_finite(sniper_right_error) or not is_finite(sniper_left_error):
		_fail("sniper IK produced non-finite wrist positions")
		return
	if sniper_right_error > 0.18 or sniper_left_error > 0.18:
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

func _wrist_error(hands: FirstPersonWeaponHands, chain: Array[int],
		target: Vector3) -> float:
	if chain.size() != 3 or hands.skeleton == null:
		return INF
	var wrist_local: Vector3 = hands.to_local(hands.skeleton.to_global(
		hands.skeleton.get_bone_global_pose(chain[2]).origin))
	return wrist_local.distance_to(target)
