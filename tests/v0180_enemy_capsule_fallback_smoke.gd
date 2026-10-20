extends SceneTree
# Regression: the movement query must still exist without the
# original disabled CollisionShape3D node (exact user-reported runtime).

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		_fail("scene load failed")
		return
	for i in range(8):
		await process_frame
	var soldier: AnimatableBody3D = current_scene.get_node_or_null("EnemySoldierTest") as AnimatableBody3D
	var combat: Node = current_scene.get_node_or_null("EnemySoldierTest/EnemyCombat")
	if soldier == null or combat == null:
		_fail("enemy missing")
		return
	var original: CollisionShape3D = soldier.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if original != null:
		soldier.remove_child(original)
	# Re-check even if shape has already been queried during _ready:
	# the cached shape must reflect the physical authored dimensions.
	var capsule: CapsuleShape3D = combat.call("_movement_capsule_shape") as CapsuleShape3D
	if capsule == null:
		_fail("capsule fallback unavailable with original node removed")
		return
	if absf(capsule.radius - 0.33) > 0.001 or absf(capsule.height - 1.8) > 0.001:
		_fail("fallback capsule dimensions mismatch")
		return
	if original != null:
		soldier.add_child(original)
		original.owner = soldier
	print("PASS: movement shape fallback survives missing CollisionShape3D")
	print("WW2 FPS v0.18 ENEMY CAPSULE FALLBACK SMOKE: PASS")
	quit(0)

func _fail(reason: String) -> void:
	push_error("WW2 FPS v0.18 ENEMY CAPSULE SMOKE FAIL: " + reason)
	quit(1)
