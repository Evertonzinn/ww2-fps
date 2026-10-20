extends SceneTree

# Godot 4.7.2 smoke:
# --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		_fail("main.tscn failed to load")
		return
	for index in range(20):
		await process_frame
	var world: Node3D = current_scene as Node3D
	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		_fail("player missing")
		return
	var posture: Node = player.get_node_or_null("StanceController")
	var standing: CollisionShape3D = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var prone: CollisionShape3D = player.get_node_or_null("ProneCollisionShape3D") as CollisionShape3D
	var head: Node3D = player.get_node_or_null("Head") as Node3D
	if posture == null or standing == null or prone == null or head == null:
		_fail("stance controller or colliders missing")
		return
	if not bool(posture.call("is_standing")) or prone.disabled:
		_fail("initial standing stance invalid")
		return
	print("PASS: initial stance standing; prone collider disabled")

	var key_c: InputEventKey = InputEventKey.new()
	key_c.physical_keycode = KEY_C
	key_c.pressed = true
	if not bool(posture.call("handle_input", key_c)):
		_fail("C key was ignored")
		return
	if int(posture.get("stance")) != 1 or standing.disabled or not prone.disabled:
		_fail("C did not activate crouching collision")
		return
	if absf(float(posture.call("movement_speed", true, 5.0, 8.0)) - 2.05) > 0.01:
		_fail("crouch incorrectly allows sprint")
		return
	print("PASS: C crouches, vertical collision and silent speed")

	var key_ctrl: InputEventKey = InputEventKey.new()
	key_ctrl.physical_keycode = KEY_CTRL
	key_ctrl.pressed = true
	if not bool(posture.call("handle_input", key_ctrl)):
		_fail("Ctrl key was ignored")
		return
	if int(posture.get("stance")) != 2 or not standing.disabled or prone.disabled:
		_fail("Ctrl did not enable horizontal prone collider")
		return
	if absf(float(posture.call("movement_speed", true, 5.0, 8.0)) - 0.9) > 0.01:
		_fail("prone speed incorrect")
		return
	if absf(prone.rotation.x - PI * 0.5) > 0.01:
		_fail("prone capsule not horizontal")
		return
	posture.call("_process", 0.45)
	if head.global_position.y > 0.75:
		_fail("prone view remained too high")
		return
	print("PASS: Ctrl prone, horizontal capsule, crawl speed and low camera")

	# Leaving prone with Ctrl enters crouch, avoiding accidental stand-up.
	if not bool(posture.call("handle_input", key_ctrl)) or int(posture.get("stance")) != 1:
		_fail("Ctrl did not return prone soldier to crouch")
		return
	# A low ceiling allows crouch but should prevent standing upright.
	var ceiling: StaticBody3D = StaticBody3D.new()
	ceiling.name = "TestLowCeiling"
	var ceiling_shape: CollisionShape3D = CollisionShape3D.new()
	var block: BoxShape3D = BoxShape3D.new()
	block.size = Vector3(1.4, 0.20, 1.4)
	ceiling_shape.shape = block
	ceiling.add_child(ceiling_shape)
	world.add_child(ceiling)
	ceiling.global_position = Vector3(player.global_position.x, 1.65, player.global_position.z)
	await physics_frame
	if bool(posture.call("request_stance", 0)):
		_fail("standing under a solid low ceiling was allowed")
		return
	if int(posture.get("stance")) != 1:
		_fail("ceiling rejection incorrectly changed stance")
		return
	print("PASS: no clipping/standing through a ceiling")
	ceiling.queue_free()
	await physics_frame

	if not bool(posture.call("handle_input", key_c)) or not bool(posture.call("is_standing")):
		_fail("C did not return player to standing")
		return
	if standing.disabled or not prone.disabled:
		_fail("standing collider was not restored")
		return
	print("PASS: player can stand after clearance")
	var enemy: Node = world.get_node_or_null("EnemySoldierTest/EnemyCombat")
	if enemy == null or not player.has_signal("footstep"):
		_fail("stealth AI footstep contract missing")
		return
	enemy.set("alert", false)
	enemy.set("sees_player", false)
	enemy.set("sight_time", 100.0)
	var position: Vector3 = player.global_position
	player.call("report_footstep", 0.75)
	if bool(enemy.get("alert")):
		_fail("extremely quiet footstep alerted distant enemy")
		return
	player.call("report_footstep", 30.0)
	if not bool(enemy.get("alert")):
		_fail("audible footstep did not alert enemy")
		return
	print("PASS: stealth hearing range changes enemy detection")
	print("WW2 FPS v0.14 PLAYER STANCE SMOKE: PASS")
	quit(0)

func _fail(why: String) -> void:
	push_error("WW2 FPS v0.14 PLAYER STANCE SMOKE: FAIL — " + why)
	quit(1)
