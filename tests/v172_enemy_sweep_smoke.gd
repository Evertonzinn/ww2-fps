extends SceneTree
# Real physics regression: obstacle is offset from the enemy centreline,
# so the obsolete 0.7m-height ray misses but the capsule must collide.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		_fail("failed to instantiate world")
		return
	for i in range(8):
		await process_frame
	for i in range(5):
		await physics_frame
	var world: Node3D = current_scene as Node3D
	var soldier: AnimatableBody3D = world.get_node_or_null("EnemySoldierTest") as AnimatableBody3D
	var combat: Node = world.get_node_or_null("EnemySoldierTest/EnemyCombat")
	if soldier == null or combat == null:
		_fail("soldier or EnemyCombat missing")
		return
	combat.set_physics_process(false)
	var original_collision: CollisionShape3D = soldier.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if original_collision == null or not original_collision.shape is CapsuleShape3D:
		_fail("enemy capsule shape missing")
		return
	var start: Vector3 = Vector3(1.0, 0.0, -4.0)
	soldier.global_position = start
	soldier.rotation.y = PI
	await physics_frame
	# Thin wall narrowly off centreline: ray x=1.0 misses (wall x>=1.19)
	# while body radius 0.33m overlaps, so a swept capsule must stop.
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = "SmokeOffsetCorner"
	wall.collision_layer = 1
	world.add_child(wall)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.24, 1.8, 0.50)
	collision.shape = shape
	wall.add_child(collision)
	wall.global_position = Vector3(1.31, 0.9, -2.5)
	await physics_frame
	for i in range(160):
		combat.call("_move_towards", Vector3(1.0, 0.0, 2.0), 0.05, 0.1)
		await physics_frame
	if soldier.global_position.z >= -2.72:
		_fail("enemy passed offset wall despite capsule radius (z=%.3f)" % soldier.global_position.z)
		return
	if soldier.global_position.z <= start.z + 0.05:
		_fail("enemy never approached offset wall; sweep may be blocked by floor")
		return
	print("PASS: swept capsule moved to wall but did not tunnel through corner")
	print("WW2 FPS v0.17.2 ENEMY SWEPT MOVEMENT SMOKE: PASS")
	quit(0)

func _fail(msg: String) -> void:
	push_error("WW2 FPS v0.17.2 ENEMY MOVEMENT SMOKE FAIL: " + msg)
	quit(1)
