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
	if hands == null or hands.ready != true:
		_fail("both skinned FPS arms did not initialize")
		return
	if hands.skeleton == null or hands.skeleton.get_bone_count() < 50:
		_fail("invalid original rigged hand skeleton")
		return
	if hands.right_ik == null or hands.left_ik == null:
		_fail("two arm IK chains were not created")
		return
	print("PASS: rigged skinned hands (bones=%d) and two arm IK targets" % hands.skeleton.get_bone_count())
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
	print("PASS: sniper selection retains independently posed hand grip/support")
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
