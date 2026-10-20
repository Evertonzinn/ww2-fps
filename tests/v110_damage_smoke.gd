extends SceneTree

# Run with Godot --headless --path PROJECT --script res://tests/v110_damage_smoke.gd
# Validates health bookkeeping through the actual seven zone scripts.
const SOLDIER_SCENE: PackedScene = preload("res://enemy_soldier.tscn")

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var cases: Array[Dictionary] = [
		{"zone": "HeadHitbox", "damage": 100, "region": "Cabeca"},
		{"zone": "TorsoHitbox", "damage": 40, "region": "Torax"},
		{"zone": "AbdomenHitbox", "damage": 25, "region": "Abdomen"},
		{"zone": "LeftArmHitbox", "damage": 15, "region": "Braco"},
		{"zone": "RightArmHitbox", "damage": 15, "region": "Braco"},
		{"zone": "LeftLegHitbox", "damage": 20, "region": "Perna"},
		{"zone": "RightLegHitbox", "damage": 20, "region": "Perna"}
	]
	var failures: int = 0
	for test in cases:
		var soldier: Node = SOLDIER_SCENE.instantiate()
		if soldier == null:
			push_error("FAIL: Soldier did not instantiate")
			quit(1)
			return
		root.add_child(soldier)
		var zone: Node = soldier.get_node_or_null(String(test["zone"]))
		if zone == null:
			push_error("FAIL: Missing hit zone: " + String(test["zone"]))
			failures += 1
		else:
			zone.call("take_damage", 1)
			var expected: int = maxi(0, 100 - int(test["damage"]))
			var actual: int = int(soldier.get("health"))
			if actual != expected:
				failures += 1
				push_error("FAIL: %s expected HP=%d actual=%d" % [test["zone"], expected, actual])
			else:
				print("PASS: %s damage=%d remaining=%d" % [test["region"], test["damage"], actual])
		root.remove_child(soldier)
		soldier.free()
	if failures == 0:
		print("WW2 FPS v0.11 HIT-ZONE SMOKE: PASS (7/7)")
		quit(0)
	else:
		push_error("WW2 FPS v0.11 HIT-ZONE SMOKE: FAIL (%d errors)" % failures)
		quit(1)
