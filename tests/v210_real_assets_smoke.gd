extends SceneTree
# Verifies asset-based visuals without relying on external graphical inspection.
# By default missing vendor GLBs are tolerated as intentional legacy fallbacks.
# To require real visuals: WW2_REQUIRE_REAL_ASSETS=1 <godot> --headless ...

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		_fail("main scene not loaded")
		return
	for i in range(12):
		await process_frame
	for i in range(4):
		await physics_frame
	var scene: Node3D = current_scene as Node3D
	if scene == null:
		_fail("scene root must be Node3D")
		return
	var strict: bool = OS.get_environment("WW2_REQUIRE_REAL_ASSETS") == "1"
	var checks: Dictionary = {
		"LeftHouseA": "environment/french_house",
		"RightHouseA": "environment/stone_house",
		"TreeWest": "environment/beech_tree",
		"TreeEast": "environment/realistic_tree"
	}
	var installed: int = 0
	for name in checks:
		var original: Node3D = scene.get_node_or_null(String(name)) as Node3D
		if original == null:
			_fail("authored world prop missing: " + String(name))
			return
		var real: Node3D = original.get_node_or_null("WW2RealVisual") as Node3D
		if real == null:
			if strict:
				_fail("real mesh missing for: " + String(name))
				return
			continue
		installed += 1
		if not real.global_transform.origin.is_finite():
			_fail("real visual has invalid transform: " + String(name))
			return
		if real.scale.x <= 0.0 or real.scale.x > 10000.0:
			_fail("real visual scale out of bounds: " + String(name))
			return
		var mesh_count: int = real.find_children("*", "MeshInstance3D", true, false).size()
		if mesh_count <= 0:
			_fail("real asset has no renderable meshes: " + String(name))
			return
		var original_shape: CollisionShape3D = original.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if original is StaticBody3D and (original_shape == null or original_shape.disabled):
			_fail("authored static collision was changed: " + String(name))
			return
	var enemy: Node3D = scene.get_node_or_null("EnemySoldierTest") as Node3D
	if enemy == null:
		_fail("enemy not spawned")
		return
	var weapon: Node3D = enemy.get_node_or_null("EnemyRiflePrototype") as Node3D
	if weapon == null:
		_fail("enemy rifle mount missing")
		return
	var rifle: Node3D = weapon.get_node_or_null("WW2RealGun") as Node3D
	if strict and rifle == null:
		_fail("Kar98k real gun was not imported")
		return
	if rifle != null:
		if rifle.find_children("*", "MeshInstance3D", true, false).is_empty():
			_fail("imported Kar98k has no visible geometry")
			return
	print("WW2 FPS v0.21 REAL-ASSET SMOKE: PASS: %d real world props, rifle=%s strict=%s" % [
		installed, str(rifle != null), str(strict)])
	quit(0)

func _fail(message: String) -> void:
	push_error("WW2 FPS v0.21 REAL-ASSET SMOKE FAIL: " + message)
	quit(1)
