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
	if soldier_root.position.z > -0.15:
		push_error("v0.15 BODY SMOKE FAIL: legs not placed ahead of player view")
		quit(1)
		return
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
	head.rotation.x = -1.0
	body.call("_process", 0.016)
	if not visual.visible:
		push_error("v0.15 BODY SMOKE FAIL: skinned legs vanish when looking down")
		quit(1)
		return
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
