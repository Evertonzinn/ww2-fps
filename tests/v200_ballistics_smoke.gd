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
	print("WW2 FPS v0.20 BALLISTIC + ANATOMICAL DAMAGE SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("WW2 FPS v0.20 BALLISTIC SMOKE FAIL: " + message)
	quit(1)
