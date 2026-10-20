extends SceneTree

# v0.15 test REQUIRES the user-converted British .glb, which is gitignored.
const MODEL: String = "res://assets/characters/player_british/british_soldier_fps.glb"
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(MODEL):
		push_error("v0.15 BODY SMOKE BLOCKED: convert the uploaded FBX to british_soldier_fps.glb first")
		quit(2)
		return
	if change_scene_to_file("res://main.tscn") != OK:
		push_error("v0.15 BODY SMOKE FAIL: could not load main.tscn")
		quit(1)
		return
	for i in range(5):
		await process_frame
	for i in range(4):
		await physics_frame
	var player: Node3D = current_scene.get_node_or_null("Player") as Node3D
	if player == null:
		push_error("v0.15 BODY SMOKE FAIL: missing Player")
		quit(1)
		return
	var body: Node3D = player.get_node_or_null("BodyVisual") as Node3D
	if body == null:
		push_error("v0.15 BODY SMOKE FAIL: Player/BodyVisual node missing")
		quit(1)
		return
	# Do not invoke bool() on a dynamically fetched property: this runtime
	# reports "Invalid call. Nonexistent 'bool' constructor" for that case.
	# Strict equality also distinguishes a missing/false readiness flag.
	var loaded: Variant = body.get("visual_loaded")
	if loaded != true:
		push_error("v0.15 BODY SMOKE FAIL: British body not ready (visual_loaded=%s)" % str(loaded))
		quit(1)
		return
	var rig: Skeleton3D = body.get("rig") as Skeleton3D
	if rig == null or rig.get_bone_count() < 80:
		push_error("v0.15 BODY SMOKE FAIL: invalid CC skeleton")
		quit(1)
		return
	print("PASS: rigged British body with %d bones" % rig.get_bone_count())
	var bounds: AABB = body.get("lower_body_bounds")
	var raw_height: float = bounds.size.y
	var normalized: float = float(body.get("corrected_visual_height"))
	var scale_factor: float = float(body.get("imported_visual_scale"))
	var source_kind: String = str(body.get("visual_bounds_source"))
	if body.get("measured_lower_body") != true or raw_height <= 0.001:
		push_error("v0.15 BODY SMOKE FAIL: source skinned lower-body bounds missing")
		quit(1)
		return
	if not is_finite(scale_factor) or scale_factor <= 0.0 or scale_factor > 300.0:
		push_error("v0.15 BODY SMOKE FAIL: invalid imported rig scale")
		quit(1)
		return
	if normalized < 0.75 or normalized > 1.20:
		push_error("v0.15 BODY SMOKE FAIL: body normalization out of range")
		quit(1)
		return
	var soldier_root: Node3D = body.get("soldier") as Node3D
	if soldier_root == null or absf(soldier_root.scale.x - scale_factor) > 0.001:
		push_error("v0.15 BODY SMOKE FAIL: imported rig/mesh scale was not applied")
		quit(1)
		return
	if body.get("anatomical_anchors_valid") != true:
		push_error("v0.15 BODY SMOKE FAIL: hip and boot rest-bone anchors missing")
		quit(1)
		return
	var hip_local: Vector3 = body.get("fps_hip_local")
	var foot_local: Vector3 = body.get("fps_foot_local")
	var hip_world: Vector3 = soldier_root.to_global(hip_local)
	var boot_world: Vector3 = soldier_root.to_global(foot_local)
	var hip_in_player: Vector3 = player.to_local(hip_world)
	var boot_in_player: Vector3 = player.to_local(boot_world)
	var expected_offset: float = float(body.get("eye_ahead_of_hips"))
	if absf(hip_in_player.z - expected_offset) > 0.03:
		push_error("v0.15 BODY SMOKE FAIL: hips are not behind eyes: actual z=%.3f target=%.3f" % [
			hip_in_player.z, expected_offset
		])
		quit(1)
		return
	if hip_in_player.y < boot_in_player.y + 0.70:
		push_error("v0.15 BODY SMOKE FAIL: hip/boot anatomy has invalid vertical ordering")
		quit(1)
		return
	print("PASS: hips %.2fm behind first-person eyes; feet anchored below" % hip_in_player.z)
	print("PASS: British body normalized; source=%s raw=%.4fm scale=%.4f" % [
		source_kind, raw_height, scale_factor
	])
	# Regression for v0.15.3: the complete torso/vest occupied the FPS
	# viewport and hid both rifles. Only Pants and Boots may be visible.
	var visual: Node3D = body.get_node_or_null("BritishSoldierFPS") as Node3D
	if visual == null:
		push_error("v0.15 BODY SMOKE FAIL: no BritishSoldierFPS instance")
		quit(1)
		return
	var visible_pants: bool = false
	var visible_boots: bool = false
	for item in visual.find_children("*", "MeshInstance3D", true, false):
		var piece: MeshInstance3D = item as MeshInstance3D
		var part_name: String = str(piece.name).to_lower()
		var expected_lower: bool = part_name.contains("pants") or part_name.contains("boots")
		if piece.visible != expected_lower:
			push_error("v0.15 BODY SMOKE FAIL: unsafe FPS mesh visibility: " + str(piece.name))
			quit(1)
			return
		visible_pants = visible_pants or (piece.visible and part_name.contains("pants"))
		visible_boots = visible_boots or (piece.visible and part_name.contains("boots"))
	if not visible_pants or not visible_boots:
		push_error("v0.15 BODY SMOKE FAIL: expected both trousers and boots")
		quit(1)
		return
	var head: Node3D = player.get_node_or_null("Head") as Node3D
	if head == null:
		push_error("v0.15 BODY SMOKE FAIL: FPS camera head missing")
		quit(1)
		return
	# Lower body must not disappear when the view pitch changes. Meshes
	# above the belt stay hidden individually (checked above).
	head.rotation.x = 0.0
	body.call("_process", 0.016)
	if not visual.visible:
		push_error("v0.15 BODY SMOKE FAIL: skinned legs vanish in normal stance")
		quit(1)
		return
	head.rotation.x = -1.30
	body.call("_process", 0.016)
	if not visual.visible:
		push_error("v0.15 BODY SMOKE FAIL: skinned legs vanish when looking down")
		quit(1)
		return
	# A valid mesh visibility flag never guaranteed correct FPS framing.
	# Project actual thigh and ankle rest points into the game camera.
	var camera: Camera3D = player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		push_error("v0.15 BODY SMOKE FAIL: camera missing")
		quit(1)
		return
	if camera.is_position_behind(hip_world) or camera.is_position_behind(boot_world):
		push_error("v0.15 BODY SMOKE FAIL: legs are behind the downward-facing camera")
		quit(1)
		return
	var projected_hip: Vector2 = camera.unproject_position(hip_world)
	var projected_boot: Vector2 = camera.unproject_position(boot_world)
	print("WW2 British PlayerBody SCREEN: hip=%s boot=%s" % [
		str(projected_hip), str(projected_boot)
	])
	if projected_hip.y <= projected_boot.y:
		push_error("v0.15 BODY SMOKE FAIL: first-person anatomy inverted in screen projection")
		quit(1)
		return
	print("PASS: hips project lower on screen than boots when looking down")
	var visible_in_tree: int = 0
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var piece: MeshInstance3D = node as MeshInstance3D
		if piece.visible and piece.is_visible_in_tree():
			visible_in_tree += 1
	if visible_in_tree < 2:
		push_error("v0.15 BODY SMOKE FAIL: lower-body mesh ancestors are hidden")
		quit(1)
		return
	head.rotation.x = 0.0
	body.call("_process", 0.016)
	print("PASS: skinned trousers/boots remain present across pitch; vest/head hidden")
	if player.get_node_or_null("StanceController") == null or player.get_node_or_null("Head/Camera3D/Weapon") == null:
		push_error("v0.15 BODY SMOKE FAIL: previous stance or rifle contracts lost")
		quit(1)
		return
	print("PASS: v0.14 stance + camera rifle preserved")
	print("WW2 FPS v0.15 PLAYER BODY SMOKE: PASS")
	quit(0)
