extends SceneTree

# Godot 4.7.2 smoke:
# --headless --path "$PWD" --script res://tests/v140_player_stance_smoke.gd
func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		_fail("main.tscn failed to load")
		return
	# Rendering and physics loops are independent in headless mode.
	# Wait for deferred World enemy spawn and Jolt collider registration.
	for index in range(4):
		await process_frame
	for index in range(4):
		await physics_frame
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
	# Initial stance is STAND: upright enabled, horizontal prone disabled.
	# v0.14 erroneously FAILED when prone.disabled == true (expected).
	if not bool(posture.call("is_standing")) or standing.disabled or not prone.disabled:
		_fail("invalid startup colliders: stance=%d upright_disabled=%s prone_disabled=%s" % [
			int(posture.get("stance")), str(standing.disabled), str(prone.disabled)
		])
		return
	var standing_shape: CapsuleShape3D = standing.shape as CapsuleShape3D
	if standing_shape == null or absf(standing_shape.height - 1.8) > 0.01:
		_fail("initial upright shape is not a 1.8m capsule")
		return
	print("PASS: initial stance standing; upright enabled and prone disabled")
	# Entering crouch from standing must never be blocked by normal
	# ground contact; stand->crouch is a strictly smaller collider.
	var ground: CollisionObject3D = world.get_node_or_null("Ground") as CollisionObject3D
	if ground == null:
		_fail("World/Ground collider missing; clearance test invalid")
		return
	print("PASS: World/Ground identified; floor is excluded from posture expansion")


	var key_c: InputEventKey = InputEventKey.new()
	key_c.physical_keycode = KEY_C
	key_c.pressed = true
	if not bool(posture.call("handle_input", key_c)):
		_fail("C key was ignored")
		return
	if int(posture.get("stance")) != 1 or standing.disabled or not prone.disabled:
		_fail("C did not activate crouching collision (stance=%d upright_disabled=%s prone_disabled=%s)" % [
			int(posture.get("stance")), str(standing.disabled), str(prone.disabled)
		])
		return
	var crouch_shape: CapsuleShape3D = standing.shape as CapsuleShape3D
	if crouch_shape == null or absf(crouch_shape.height - 1.26) > 0.01:
		_fail("C did not activate 1.26m crouching capsule")
		return
	if absf(float(posture.call("movement_speed", true, 5.0, 8.0)) - 2.05) > 0.01:
		_fail("crouch incorrectly allows sprint")
		return
	print("PASS: C crouches, vertical collision and silent speed")

	var key_space: InputEventKey = InputEventKey.new()
	key_space.physical_keycode = KEY_SPACE
	key_space.pressed = true
	if posture.call("handle_input", key_space) != true or posture.call("is_standing") != true:
		_fail("Space did not raise crouched player to standing")
		return
	if posture.call("allows_jump_from_space") != false:
		_fail("rising Space also enabled jump")
		return
	key_space.pressed = false
	posture.call("handle_input", key_space)
	if posture.call("allows_jump_from_space") != true:
		_fail("Space release did not rearm normal jump")
		return
	if posture.call("handle_input", key_c) != true or int(posture.get("stance")) != 1:
		_fail("C cannot return to crouch after Space rise")
		return
	print("PASS: Space crouch->stand, jump suppressed until release")

	var key_ctrl: InputEventKey = InputEventKey.new()
	key_ctrl.physical_keycode = KEY_CTRL
	key_ctrl.pressed = true
	if not bool(posture.call("handle_input", key_ctrl)):
		_fail("Ctrl key was ignored")
		return
	if int(posture.get("stance")) != 2 or not standing.disabled or prone.disabled:
		_fail("Ctrl did not enable prone collision (stance=%d upright_disabled=%s prone_disabled=%s)" % [
			int(posture.get("stance")), str(standing.disabled), str(prone.disabled)
		])
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

	key_space.pressed = true
	if posture.call("handle_input", key_space) != true or int(posture.get("stance")) != 1:
		_fail("Space did not rise from prone to crouch")
		return
	key_space.pressed = false
	posture.call("handle_input", key_space)
	if posture.call("handle_input", key_ctrl) != true or int(posture.get("stance")) != 2:
		_fail("Ctrl failed to return to prone after Space")
		return
	print("PASS: Space prone->crouch, Ctrl still enters prone")

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
	key_space.pressed = true
	if posture.call("handle_input", key_space) != true or int(posture.get("stance")) != 1:
		_fail("Space bypassed low ceiling or was not handled")
		return
	if posture.call("allows_jump_from_space") != false:
		_fail("Space attempted to jump under low ceiling")
		return
	key_space.pressed = false
	posture.call("handle_input", key_space)
	if int(posture.get("stance")) != 1:
		_fail("ceiling rejection incorrectly changed stance")
		return
	print("PASS: no clipping/standing through a ceiling")
	ceiling.queue_free()
	await physics_frame

	key_space.pressed = true
	if posture.call("handle_input", key_space) != true or posture.call("is_standing") != true:
		_fail("Space did not return player to standing after ceiling cleared")
		return
	if posture.call("allows_jump_from_space") != false:
		_fail("post-ceiling Space incorrectly enabled jump")
		return
	key_space.pressed = false
	posture.call("handle_input", key_space)
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
	var enemy_body: Node3D = world.get_node_or_null("EnemySoldierTest") as Node3D
	var separation: float = player.global_position.distance_to(enemy_body.global_position)
	if separation <= 0.75 or separation >= 30.0:
		_fail("footstep test requires 0.75m < enemy distance < 30m; actual %.2fm" % separation)
		return
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
