extends SceneTree

# Godot 4.7 headless tactical integration smoke:
# godot --headless --path PROJECT --script res://tests/v130_tactical_smoke.gd
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		push_error("v0.13 TACTICAL SMOKE: main failed to load")
		quit(1)
		return
	for i in range(18):
		await process_frame
	var world: Node3D = current_scene as Node3D
	var soldier: Node3D = world.get_node_or_null("EnemySoldierTest") as Node3D
	var player: Node3D = world.get_node_or_null("Player") as Node3D
	if soldier == null or player == null:
		push_error("v0.13 TACTICAL SMOKE: soldier or player absent")
		quit(1)
		return
	var combat: Node3D = soldier.get_node_or_null("EnemyCombat") as Node3D
	var rig: Skeleton3D = soldier.get("rig") as Skeleton3D
	if combat == null or rig == null or rig.get_bone_count() < 60:
		push_error("v0.13 TACTICAL SMOKE: combat node/rig not ready")
		quit(1)
		return
	print("PASS: v0.12.2 rig + combat preserved: %d bones" % rig.get_bone_count())
	if not player.has_signal("gunshot") or not player.has_method("report_gunshot"):
		push_error("v0.13 TACTICAL SMOKE: player noise signal absent")
		quit(1)
		return
	combat.set("alert", false)
	combat.set("sees_player", false)
	combat.set("sight_time", 8.0)
	player.call("report_gunshot")
	if not bool(combat.get("alert")):
		push_error("v0.13 TACTICAL SMOKE: fired rifle did not alert enemy")
		quit(1)
		return
	print("PASS: gunshot signal alerts enemy and stores investigation position")
	combat.set("magazine", 0)
	combat.call("_begin_reload")
	if not bool(combat.get("reloading")) or float(combat.get("reload_left")) <= 0.0:
		push_error("v0.13 TACTICAL SMOKE: empty-magazine reload failed")
		quit(1)
		return
	print("PASS: magazine exhaustion locks fire during reload")
	# The AI, not the test, owns combat_crouch_target. In INVESTIGATE it
	# correctly resets the requested crouch to 0 every physics tick.
	# Drive the real IN_COVER state with deterministic delta, independent
	# of headless process_frame timing (which may be faster than physics).
	combat.set_process(false)
	combat.set_physics_process(false)
	soldier.set_process(false)
	soldier.set_physics_process(false)
	var head_shape: CollisionShape3D = soldier.get_node_or_null(
		"HeadHitbox/CollisionShape3D") as CollisionShape3D
	if head_shape == null:
		push_error("v0.13 TACTICAL SMOKE: head hitbox missing")
		quit(1)
		return
	var standing_head_y: float = head_shape.position.y
	combat.set("tactic", 4) # Tactic.IN_COVER
	combat.set("cover_hold_left", 10.0)
	combat.set("peek_left", 3.0)
	combat.set("peek_exposed", false)
	# Reload remains active from the preceding test.
	combat.call("_physics_process", 1.0 / 60.0)
	if float(soldier.get("combat_crouch_target")) < 0.9:
		push_error("v0.13 TACTICAL SMOKE: covered soldier did not request crouch")
		quit(1)
		return
	soldier.call("_process", 0.25)
	var crouch_blend: float = float(soldier.get("combat_crouch_blend"))
	if crouch_blend <= 0.1 or head_shape.position.y >= standing_head_y - 0.05:
		push_error("v0.13 TACTICAL SMOKE: covered crouch/hitboxes did not lower")
		quit(1)
		return
	print("PASS: cover + reload crouch lowers rig and head hitbox (blend=%.2f)" % crouch_blend)
	# An exposed, reloaded soldier must restore the standing pose and hitboxes.
	combat.set("reloading", false)
	combat.set("magazine", 5)
	combat.set("peek_exposed", true)
	combat.call("_physics_process", 1.0 / 60.0)
	soldier.call("_process", 0.25)
	if float(soldier.get("combat_crouch_target")) > 0.1 \
			or float(soldier.get("combat_crouch_blend")) > 0.1 \
			or absf(head_shape.position.y - standing_head_y) > 0.05:
		push_error("v0.13 TACTICAL SMOKE: exposed soldier did not stand up")
		quit(1)
		return
	print("PASS: exposure restores standing pose and original hitboxes")
	var cover_script: Script = load("res://enemy_cover.gd") as Script
	var candidate: Dictionary = cover_script.find_cover(world, soldier, player)
	print("INFO: verified physical cover candidate=", candidate)
	if not candidate.is_empty() and not candidate.has("point"):
		push_error("v0.13 TACTICAL SMOKE: invalid cover payload")
		quit(1)
		return
	print("WW2 FPS v0.13 TACTICAL SMOKE: PASS")
	quit(0)
