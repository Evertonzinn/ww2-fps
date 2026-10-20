extends SceneTree

const BallisticTrace = preload("res://combat/ballistic_trace.gd")
const DamageProfile = preload("res://combat/damage_profile.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# 800m/s, 100m: 0.125s flight, ~7.66cm gravity drop.
	var origin: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD
	var point: Vector3 = BallisticTrace.point_at(origin, forward, 100.0, 800.0, 9.81)
	if absf(point.z + 100.0) > 0.0001 or absf(point.y + 0.076640625) > 0.0001:
		_fail("ballistic trajectory/drop changed: " + str(point))
		return
	if BallisticTrace.point_at(origin, forward, 0.0, 800.0, 9.81) != origin:
		_fail("zero-distance shot displaced origin")
		return
	if DamageProfile.sniper_damage("Torax") < 100:
		_fail("sniper chest does not kill default 100HP soldier")
		return
	if DamageProfile.sniper_damage("Braco") >= 100 or (
			DamageProfile.sniper_damage("Perna") >= 100):
		_fail("sniper limb hits are incorrectly lethal")
		return
	if DamageProfile.sniper_damage("Cabeca") <= DamageProfile.sniper_damage("Torax"):
		_fail("head hit no longer exceeds chest damage")
		return
	# Integration: an actual collision body must be hit before full range.
	var probe: Node3D = Node3D.new()
	probe.name = "BallisticPhysicsProbe"
	root.add_child(probe)
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.position = Vector3(0.0, 0.0, -18.0)
	probe.add_child(obstacle)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 0.5)
	shape_node.shape = box
	obstacle.add_child(shape_node)
	await physics_frame
	await physics_frame
	var excluded: Array[RID] = []
	var hit: Dictionary = BallisticTrace.trace(probe.get_world_3d().direct_space_state,
		Vector3.ZERO, Vector3.FORWARD, 40.0, 790.0, 9.81, excluded)
	if hit.get("collider") != obstacle:
		_fail("ballistic ray did not hit real physics obstacle")
		return
	excluded.append(obstacle.get_rid())
	var ignored: Dictionary = BallisticTrace.trace(probe.get_world_3d().direct_space_state,
		Vector3.ZERO, Vector3.FORWARD, 40.0, 790.0, 9.81, excluded)
	if not ignored.is_empty():
		_fail("ballistic ray ignored exclusion RIDs")
		return
	probe.queue_free()
	print("WW2 FPS v0.20 BALLISTIC + ANATOMICAL DAMAGE SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("WW2 FPS v0.20 BALLISTIC SMOKE FAIL: " + message)
	quit(1)
