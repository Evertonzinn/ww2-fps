extends SceneTree

const SoldierScript = preload("res://enemy_soldier.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("v122 POSE: " + message)

func _run() -> void:
	# This catches the original namespace bug without accepting an unmapped rig.
	for label in ["mixamorig:RightArm_48", "mixamorig_RightArm_48", "RightArm"]:
		_check(SoldierScript._bone_stem(label) == "RightArm", "bone normalization: " + label)
	if change_scene_to_file("res://main.tscn") != OK:
		push_error("v122 POSE: main scene unavailable")
		quit(1)
		return
	for frame in range(16):
		await process_frame
	var original: Node = current_scene.get_node_or_null("EnemySoldierTest")
	if original != null:
		original.queue_free()
		await process_frame
	# Reinstantiate the actual scene/GLBs; no fabricated skeleton or substitute gun.
	var packed: PackedScene = load("res://enemy_soldier.tscn") as PackedScene
	for high in [false, true]:
		var path: String = SoldierScript.MODEL_2K if high else SoldierScript.MODEL_1K
		_check(ResourceLoader.exists(path), "required asset missing: " + path)
		if not ResourceLoader.exists(path):
			continue
		var soldier: Node3D = packed.instantiate() as Node3D
		soldier.set("high_quality", high)
		soldier.set("patrol_enabled", false)
		soldier.position = Vector3(1, 0, -4)
		current_scene.add_child(soldier)
		soldier.set_process(false)
		soldier.set_physics_process(false)
		var combat: Node3D = soldier.get("combat") as Node3D
		var rig: Skeleton3D = soldier.get("rig") as Skeleton3D
		_check(combat != null and rig != null, "actual rig/combat not initialized")
		if combat == null or rig == null:
			soldier.queue_free()
			await process_frame
			continue
		combat.set_process(false)
		combat.set_physics_process(false)
		var mapped: Dictionary = soldier.get("bones")
		# Check the actual imported model's front, not just the gun/root agreement.
		for side in ["Left", "Right"]:
			var foot_index: int = -1
			var toe_index: int = -1
			for index in range(rig.get_bone_count()):
				var stem: String = SoldierScript._bone_stem(rig.get_bone_name(index))
				if stem == side + "Foot":
					foot_index = index
				if stem == side + "ToeBase":
					toe_index = index
			_check(foot_index >= 0 and toe_index >= 0, side + " foot/toe missing")
			if foot_index >= 0 and toe_index >= 0:
				var foot: Vector3 = soldier.to_local(rig.to_global(rig.get_bone_global_rest(foot_index).origin))
				var toe: Vector3 = soldier.to_local(rig.to_global(rig.get_bone_global_rest(toe_index).origin))
				_check(toe.z < foot.z - 0.05, side + " model faces opposite combat -Z")
		for name in ["Spine2", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "LeftLeg", "RightLeg"]:
			_check(mapped.has(name), "required mapped bone absent: " + name)
		var gun: Node3D = combat.get("gun") as Node3D
		if gun == null or not mapped.has("LeftHand") or not mapped.has("RightHand"):
			_check(false, "cannot test grip without gun/hands")
			soldier.queue_free()
			await process_frame
			continue
		for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
			soldier.rotation.y = yaw
			for flinch in [0.0, 0.20]:
				soldier.set("flinch_left", flinch)
				soldier.call("_update_bone_pose")
				combat.call("_process", 0.0)
				for side in ["Right", "Left"]:
					var hand_index: int = int(mapped[side + "Hand"])
					var hand: Transform3D = rig.global_transform * rig.get_bone_global_pose(hand_index)
					var marker: Marker3D = combat.get("right_grip" if side == "Right" else "left_grip") as Marker3D
					var palm: Vector3 = hand.origin + hand.basis.orthonormalized() * Vector3(0, 0.045, 0)
					var error: float = palm.distance_to(marker.global_position)
					_check(error < 0.025, "%s palm gap %.4f m, 2K=%s yaw=%.2f" % [side, error, high, yaw])
					_check(hand.basis.y.normalized().dot(marker.global_basis.y.normalized()) > 0.99, side + " wrist orientation")
					var elbow_index: int = int(mapped[side + "ForeArm"])
					var elbow_world: Vector3 = rig.to_global(rig.get_bone_global_pose(elbow_index).origin)
					var elbow: Vector3 = soldier.to_local(elbow_world)
					_check(elbow.y < 1.37, side + " elbow remains raised like A-pose")
					_check((hand.origin - elbow_world).normalized().dot(hand.basis.y.normalized()) > 0.64, side + " excessive wrist bend")
				var local_gun: Vector3 = soldier.to_local(gun.global_position)
				_check(local_gun.z < -0.12, "gun behind torso")
				_check((-gun.global_basis.z.normalized()).dot(-soldier.global_basis.z.normalized()) > 0.97, "gun facing opposite combat forward")
		# Repeated evaluations must not accumulate rotation or move the gun.
		var stable: Transform3D = gun.transform
		for repeat in range(120):
			soldier.call("_update_bone_pose")
			combat.call("_process", 0.0)
		_check(gun.transform.is_equal_approx(stable), "mount accumulates transform")
		var phase_before: float = float(soldier.get("walk_phase"))
		soldier.set("is_walking", true)
		soldier.position.x += 0.115
		soldier.call("_process", 0.0)
		var phase_after: float = float(soldier.get("walk_phase"))
		_check(absf((phase_after - phase_before) - TAU * 0.1) < 0.001, "gait does not follow traveled distance")
		print("v122 POSE inspected actual variant: ", "2K" if high else "1K")
		soldier.queue_free()
		await process_frame
	if failures == 0:
		print("WW2 FPS v0.12.2 POSE SMOKE: PASS (geometry only; visual acceptance still required)")
	else:
		push_error("WW2 FPS v0.12.2 POSE SMOKE: FAIL count=%d" % failures)
	quit(0 if failures == 0 else 1)
