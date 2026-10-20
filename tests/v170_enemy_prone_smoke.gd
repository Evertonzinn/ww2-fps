extends SceneTree
const CoverPlanner = preload("res://enemy_cover.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		_fail("main scene not loaded")
		return
	for i in range(8):
		await process_frame
	for i in range(5):
		await physics_frame
	var world: Node3D = current_scene as Node3D
	var enemy: Node3D = world.get_node_or_null("EnemySoldierTest") as Node3D
	var combat: Node = world.get_node_or_null("EnemySoldierTest/EnemyCombat")
	var player: CharacterBody3D = world.get_node_or_null("Player") as CharacterBody3D
	if enemy == null or combat == null or player == null:
		_fail("enemy, Player or Combat missing")
		return
	combat.set_physics_process(false)
	var stance: Node = player.get_node_or_null("StanceController")
	if stance == null:
		_fail("stance controller missing")
		return
	player.global_position = enemy.global_position + Vector3(0.0, 0.95, 3.4)
	combat.set("alert", false)
	await physics_frame
	if combat.call("_can_see_player") != true:
		_fail("enemy cannot see exposed standing player")
		return
	if stance.call("request_stance", 1) != true:
		_fail("cannot crouch in test corridor")
		return
	await physics_frame
	if combat.call("_can_see_player") != true:
		_fail("enemy cannot see exposed crouching player")
		return
	if stance.call("request_stance", 2) != true:
		_fail("cannot lie prone in test corridor")
		return
	await physics_frame
	if combat.call("_can_see_player") != true:
		_fail("enemy cannot see exposed PRONE player")
		return
	var aim: Vector3 = combat.call("_player_aim_point")
	if aim.distance_to(player.global_position) > 0.001:
		_fail("enemy firing still aims outside prone collider")
		return
	print("PASS: exposed stand, crouch and prone all visible")

	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.name = "TestOpaqueWall"
	obstacle.collision_layer = 1
	obstacle.collision_mask = 1
	world.add_child(obstacle)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(2.0, 3.0, 0.5)
	collision.shape = shape
	obstacle.add_child(collision)
	obstacle.global_position = (enemy.global_position + player.global_position) * 0.5
	obstacle.global_position.y = 1.5
	await physics_frame
	if combat.call("_can_see_player") == true:
		_fail("prone sight penetrates solid wall")
		return
	print("PASS: wall stops sight of prone player")

	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 0.37
	cylinder.height = 1.04
	var crate: BoxShape3D = BoxShape3D.new()
	crate.size = Vector3(2.0, 1.0, 0.8)
	if absf(CoverPlanner._cover_edge_distance(cylinder, Vector3.FORWARD) - 0.37) > 0.001 or absf(CoverPlanner._cover_edge_distance(crate, Vector3.FORWARD) - 0.40) > 0.001:
		_fail("barrel/box cover shape ignored")
		return
	print("PASS: barrel cylindrical geometry supported")
	var audio: AudioStreamPlayer3D = combat.get("shot_audio") as AudioStreamPlayer3D
	if audio == null or not audio.stream is AudioStreamWAV:
		_fail("enemy shot audio missing")
		return
	var wave: AudioStreamWAV = audio.stream as AudioStreamWAV
	var negatives: int = 0
	var positives: int = 0
	var sum_values: int = 0
	for byte in wave.data:
		var v: int = int(byte) if byte < 128 else int(byte) - 256
		if v < 0:
			negatives += 1
		elif v > 0:
			positives += 1
		sum_values += v
	if wave.format != AudioStreamWAV.FORMAT_8_BITS or negatives == 0 or positives == 0 or absf(float(sum_values) / float(wave.data.size())) > 12.0:
		_fail("signed PCM output has DC bias")
		return
	print("PASS: signed 8-bit enemy PCM is centered at zero")
	print("WW2 FPS v0.17 ENEMY PRONE/AUDIO/COVER SMOKE: PASS")
	quit(0)

func _fail(msg: String) -> void:
	push_error("WW2 FPS v0.17 ENEMY SMOKE FAIL: " + msg)
	quit(1)
