extends SceneTree
# Gameplay + art integration smoke. The 3D view still needs F5 validation.
func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		_fail("main scene failed")
		return
	for i in range(7):
		await process_frame
	for i in range(4):
		await physics_frame
	var world: Node3D = current_scene as Node3D
	var art: Node3D = world.get_node_or_null("RemasterEnvironment") as Node3D
	if art == null:
		_fail("remaster environment not constructed")
		return
	var stones: MultiMeshInstance3D = art.get_node_or_null("RemasterCobblestones") as MultiMeshInstance3D
	var grass: MultiMeshInstance3D = art.get_node_or_null("RemasterGrassTufts") as MultiMeshInstance3D
	if stones == null or stones.multimesh.instance_count < 1000 or grass == null or grass.multimesh.instance_count < 500:
		_fail("instanced 3D road and vegetation missing")
		return
	for tree in ["TreeWest", "TreeEast"]:
		var foliage: MultiMeshInstance3D = world.get_node_or_null(tree + "/RemasterLeafClusters") as MultiMeshInstance3D
		if foliage == null or foliage.multimesh.instance_count < 100:
			_fail("tree has no leaf clusters: " + tree)
			return
	if world.get_node_or_null("Player/Head/Camera3D/Weapon") == null:
		_fail("weapon viewmodel hierarchy regressed")
		return
	print("PASS: instanced cobblestones, tree leaves, roadside grass and rifle preserved")
	var enemy: Node3D = world.get_node_or_null("EnemySoldierTest") as Node3D
	if enemy == null:
		_fail("enemy failed to spawn")
		return
	var torso: Node = enemy.get_node_or_null("TorsoHitbox")
	if torso == null or not torso.has_method("take_sniper_damage"):
		_fail("sniper torso damage receiver missing")
		return
	if int(torso.get("damage_per_hit")) != 40:
		_fail("Lee-Enfield torso damage was changed")
		return
	torso.call("take_sniper_damage")
	if int(enemy.get("health")) != 0:
		_fail("sniper torso hit was not lethal at 100HP")
		return
	print("PASS: sniper torso one-shot, legacy Lee-Enfield torso damage remains 40")
	print("WW2 FPS v0.19 REMASTER GAMEPLAY SMOKE: PASS")
	quit(0)

func _fail(reason: String) -> void:
	push_error("WW2 FPS v0.19 REMASTER SMOKE: FAIL — " + reason)
	quit(1)
