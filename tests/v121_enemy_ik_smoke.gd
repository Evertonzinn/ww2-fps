extends SceneTree

# Rig and gun regression smoke for Godot 4.7.2:
# godot --headless --path PROJECT --script res://tests/v121_enemy_ik_smoke.gd
# Uses original local Panzergrenadier GLB; does not install anything.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		push_error("WW2 v0.12.1 IK SMOKE: main.tscn failed to load")
		quit(1)
		return
	for i in range(16):
		await process_frame
	var soldier: Node3D = current_scene.get_node_or_null("EnemySoldierTest") as Node3D
	if soldier == null:
		push_error("WW2 v0.12.1 IK SMOKE: enemy missing")
		quit(1)
		return
	var rig: Skeleton3D = soldier.get("rig") as Skeleton3D
	var combat: Node3D = soldier.get_node_or_null("EnemyCombat") as Node3D
	if rig == null or combat == null:
		push_error("WW2 v0.12.1 IK SMOKE: skeleton or combat missing")
		quit(1)
		return
	var gun: Node3D = combat.get_node_or_null("EnemyRiflePrototype") as Node3D
	# Gun is parented directly to soldier, not to the combat script.
	gun = soldier.get_node_or_null("EnemyRiflePrototype") as Node3D
	if gun == null:
		push_error("WW2 v0.12.1 IK SMOKE: gun missing")
		quit(1)
		return
	var right_grip: Marker3D = gun.get_node_or_null("TriggerGrip") as Marker3D
	var left_grip: Marker3D = gun.get_node_or_null("SupportGrip") as Marker3D
	if right_grip == null or left_grip == null:
		push_error("WW2 v0.12.1 IK SMOKE: 3D hand grip markers missing")
		quit(1)
		return
	var right_bone: int = -1
	var left_bone: int = -1
	var arm_count: int = 0
	for b in range(rig.get_bone_count()):
		var label: String = rig.get_bone_name(b)
		if label.contains("RightHand_"):
			right_bone = b
		if label.contains("LeftHand_"):
			left_bone = b
		if label.contains("ForeArm_"):
			arm_count += 1
	if right_bone < 0 or left_bone < 0 or arm_count < 2:
		push_error("WW2 v0.12.1 IK SMOKE: expected Mixamo hand/forearm joints absent")
		quit(1)
		return
	var right_hand: Vector3 = rig.to_global(rig.get_bone_global_pose(right_bone).origin)
	var left_hand: Vector3 = rig.to_global(rig.get_bone_global_pose(left_bone).origin)
	var d_right: float = right_hand.distance_to(right_grip.global_position)
	var d_left: float = left_hand.distance_to(left_grip.global_position)
	print("WW2 v0.12.1 IK: right hand %.3f m, left hand %.3f m from rifle grips" % [d_right, d_left])
	if d_right > 0.18 or d_left > 0.18:
		push_error("WW2 v0.12.1 IK SMOKE: weapon grip too far from hand bones")
		quit(1)
		return
	var direction: Vector3 = -gun.global_transform.basis.z.normalized()
	var target: Node3D = current_scene.get_node_or_null("Player") as Node3D
	if target != null:
		var to_player: Vector3 = target.global_position - soldier.global_position
		to_player.y = 0.0
		var fwd: Vector3 = direction
		fwd.y = 0.0
		var alignment: float = fwd.normalized().dot(to_player.normalized())
		print("WW2 v0.12.1 IK: rifle facing player alignment=%.3f" % alignment)
		if alignment < 0.60:
			push_error("WW2 v0.12.1 IK SMOKE: gun direction inconsistent with target")
			quit(1)
			return
	print("WW2 FPS v0.12.1 IK SMOKE: PASS")
	quit(0)
