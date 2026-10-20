extends SceneTree

# v157: structural/geometric diagnostic, never a claim of visual acceptance.
# Optional -- --inspect opens this same frozen scene with external cameras.
const MODEL: String = "res://assets/characters/player_british/british_soldier_fps.glb"
const FULL_MODEL: String = "res://assets/characters/player_british/british_soldier_full.glb"
const Probe = preload("res://tests/support/player_body_probe.gd")
var report: Dictionary = {"version": "v157", "failures": [], "samples": []}
var failures: Array = []
var player: CharacterBody3D
var body: Node3D
var camera: Camera3D
var head: Node3D
var visual: Node3D
var inspection: bool = false
var inspection_ready: bool = false
var external_camera: Camera3D
var full_visual: Node3D
var full_target: Vector3
var full_radius: float = 2.0
var label: Label

func _initialize() -> void:
	inspection = OS.get_cmdline_user_args().has("--inspect")
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(MODEL):
		push_error("v157 BODY BLOCKED: missing local FPS GLB/import: " + MODEL)
		quit(2)
		return
	if inspection and DisplayServer.get_name() == "headless":
		push_error("v157 BODY BLOCKED: --inspect requires a graphical display")
		quit(2)
		return
	report["engine"] = Engine.get_version_info()
	report["display"] = DisplayServer.get_name()
	report["model_sha256"] = FileAccess.get_sha256(MODEL)
	if FileAccess.file_exists(MODEL + ".import"):
		report["import_config"] = FileAccess.get_file_as_string(MODEL + ".import")
	if change_scene_to_file("res://main.tscn") != OK:
		push_error("v157 BODY FAIL: main.tscn failed to load")
		quit(1)
		return
	for frame_index in range(8):
		await process_frame
	# Stop AI, physics, recoil and automatic animation for reproducible samples.
	# This modifies only the test process, not main.tscn or gameplay scripts.
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	player = current_scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_error("v157 BODY FAIL: Player missing")
		quit(1)
		return
	body = player.get_node_or_null("BodyVisual") as Node3D
	head = player.get_node_or_null("Head") as Node3D
	camera = player.get_node_or_null("Head/Camera3D") as Camera3D
	if body == null or head == null or camera == null:
		push_error("v157 BODY FAIL: BodyVisual/Head/Camera3D missing")
		quit(1)
		return
	visual = body.get("soldier") as Node3D
	var rig: Skeleton3D = body.get("rig") as Skeleton3D
	_check(body.get("visual_loaded") == true, "body initialization failed")
	_check(visual != null and rig != null, "missing visual or rig")
	if visual == null or rig == null:
		_finish()
		return
	report["hierarchy"] = Probe.hierarchy(visual)
	report["bones"] = []
	for index in range(rig.get_bone_count()):
		report["bones"].append({"index": index, "name": str(rig.get_bone_name(index)),
			"parent": rig.get_bone_parent(index), "rest_in_rig": str(rig.get_bone_global_rest(index)),
			"pose_in_rig": str(rig.get_bone_global_pose(index)),
			"pose_world": str(rig.to_global(rig.get_bone_global_pose(index).origin)),
			"enabled": rig.is_bone_enabled(index)})
	# Independently report foot-to-toe direction; not a substitute for mesh bounds.
	for side in ["L", "R"]:
		var foot_index: int = rig.find_bone("CC_Base_" + side + "_Foot")
		var toe_index: int = -1
		if foot_index >= 0:
			for child_index in rig.get_bone_children(foot_index):
				if str(rig.get_bone_name(child_index)).to_lower().contains("toe"):
					toe_index = child_index
		_check(foot_index >= 0 and toe_index >= 0, "cannot verify " + side + " foot-to-toe orientation")
		if foot_index >= 0 and toe_index >= 0:
			var foot: Vector3 = player.to_local(rig.to_global(rig.get_bone_global_pose(foot_index).origin))
			var toe: Vector3 = player.to_local(rig.to_global(rig.get_bone_global_pose(toe_index).origin))
			report[side + "_foot_to_toe_player"] = str(toe - foot)
			_check(toe.z < foot.z - 0.01, side + " foot-to-toe direction is not player forward (-Z)")
	report["camera"] = {"world": str(camera.global_transform), "fov": camera.fov,
		"near": camera.near, "far": camera.far, "mask": camera.cull_mask,
		"keep_aspect": camera.keep_aspect, "viewport": str(root.get_visible_rect())}
	report["body_world"] = str(body.global_transform)
	var weapons: Dictionary = _weapon_snapshot()
	_check(not weapons.is_empty(), "weapon hierarchy absent")
	var camera_local: Transform3D = camera.transform
	var head_local: Transform3D = head.transform
	var player_start: Vector3 = player.position
	var posture: Node = player.get_node_or_null("StanceController")
	_check(posture != null, "StanceController absent")
	if posture == null:
		_finish()
		return
	# Direct diagnostic pose selection avoids exercising controls here.
	# The independent v140 test retains C/Ctrl/Space/ceiling coverage.
	for stance in [0, 1]:
		posture.set("stance", stance)
		player.position = player_start + Vector3(0, -0.27 if stance == 1 else 0.0, 0)
		head.position = Vector3(0, 0.47 if stance == 1 else 0.6, 0)
		body.set("walking_blend", 0.0)
		body.set("walk_cycle", 0.0)
		body.set("previous_position", player.global_position)
		for pitch in [0.0, -1.04719755, -1.30899694]:
			head.rotation.x = pitch
			body.call("_process", 0.016)
			_sample("stance=%d pitch=%.3f" % [stance, pitch], pitch < -1.3, stance == 0)
			_check(camera.transform.is_equal_approx(camera_local), "body moved camera local transform")
			_check(_weapon_snapshot() == weapons, "body changed weapon nodes/transforms")
	posture.set("stance", 2)
	body.call("_process", 0.016)
	_check(not visual.visible, "prone body must remain hidden until a suitable pose exists")
	posture.set("stance", 0)
	player.position = player_start
	head.transform = head_local
	head.rotation.x = -1.30899694
	body.set("previous_position", player.global_position)
	body.call("_process", 0.016)
	var first_piece: MeshInstance3D = _first_lower_mesh()
	if first_piece != null:
		var before: Dictionary = Probe.geometry(first_piece, camera, player)
		var camera_before: Transform3D = camera.global_transform
		# Quarter stride, based on actual body script stride 1.4m; no asset edits.
		player.position.x += 0.35
		body.call("_process", 0.2)
		player.position = player_start
		var after: Dictionary = Probe.geometry(first_piece, camera, player)
		var before_points: PackedVector3Array = before["points"]
		var after_points: PackedVector3Array = after["points"]
		var motion: float = 0.0
		if before_points.size() == after_points.size():
			for index in range(before_points.size()):
				motion = maxf(motion, before_points[index].distance_to(after_points[index]))
		_check(motion > 0.001, "leg pose does not deform garment vertices")
		_check(camera.global_transform.is_equal_approx(camera_before), "body animation changed camera")
		report["gait_max_vertex_motion_m"] = motion
	# Restore a neutral standing sample for inspection.
	body.set("previous_position", player.global_position)
	body.set("walking_blend", 0.0)
	body.set("walk_cycle", 0.0)
	body.call("_process", 0.016)
	_check(_weapon_snapshot() == weapons, "weapon hierarchy changed during diagnostic")
	if inspection:
		await process_frame
		await RenderingServer.frame_post_draw
		_compare_engine_bake()
		await _setup_inspection()
	_finish()

func _sample(tag: String, require_projection: bool, standing: bool) -> void:
	var sample: Dictionary = {"tag": tag, "camera_world": str(camera.global_transform), "meshes": []}
	var pants: int = 0
	var boots: int = 0
	for item in visual.find_children("*", "MeshInstance3D", true, false):
		var piece: MeshInstance3D = item as MeshInstance3D
		var lower: bool = _is_lower(piece)
		if not lower:
			_check(not piece.is_visible_in_tree(), tag + ": upper mesh visible: " + str(piece.name))
			continue
		var measurement: Dictionary = Probe.geometry(piece, camera, player)
		for error in measurement["errors"]:
			_check(false, tag + ": " + str(piece.name) + ": " + str(error))
		_check(piece.is_visible_in_tree(), tag + ": hidden lower garment ancestor")
		_check((piece.layers & camera.cull_mask) != 0, tag + ": camera culls lower garment layer")
		_check(piece.transparency < 1.0, tag + ": fully transparent lower garment")
		if str(piece.name).to_lower().contains("pants"):
			pants += 1
		if str(piece.name).to_lower().contains("boots"):
			boots += 1
		if require_projection:
			_check(int(measurement.get("left_in_frustum", 0)) > 0 and int(measurement.get("right_in_frustum", 0)) > 0,
				tag + ": " + str(piece.name) + " not projected on both sides of player")
			# Conservative rejection of a microscopic projection, not a visual-quality score.
			_check(float(measurement.get("screen_area_ratio", 0.0)) > 0.0005,
				tag + ": " + str(piece.name) + " negligible or absent projected area")
		if standing and measurement.has("bounds"):
			var bounds: AABB = measurement["bounds"]
			if str(piece.name).to_lower().contains("pants"):
				_check(bounds.size.y > 0.50 and bounds.size.y < 1.4, "deformed Pants height implausible: " + str(bounds.size.y))
			if str(piece.name).to_lower().contains("boots"):
				_check(absf(bounds.position.y + 0.95) < 0.15, "deformed Boots sole not at player ground plane: " + str(bounds.position.y))
		if not require_projection and absf(head.rotation.x) < 0.001 and measurement["errors"].is_empty():
			var hits: int = Probe.forward_hits(piece, measurement["points"], camera)
			measurement["forward_center_ray_hits"] = hits
			_check(hits == 0, tag + ": garment obstructs forward camera centre ray")
		sample["meshes"].append(Probe.serializable(measurement))
	_check(pants > 0 and boots > 0, "Pants/Boots absent")
	report["samples"].append(sample)

func _compare_engine_bake() -> void:
	# Graphics only: independent engine snapshot, including the registered palette.
	# Baking ignores blendshapes; the CPU probe rejects active blendshapes too.
	var comparisons: Array = []
	for item in visual.find_children("*", "MeshInstance3D", true, false):
		var piece: MeshInstance3D = item as MeshInstance3D
		if not _is_lower(piece) or piece.get_skin_reference() == null:
			continue
		var predicted: Dictionary = Probe.geometry(piece, camera, player)
		var points: PackedVector3Array = predicted["points"]
		var baked: ArrayMesh = piece.bake_mesh_from_current_skeleton_pose()
		_check(baked != null, "engine skin bake unavailable")
		if baked == null:
			continue
		var index: int = 0
		var max_error: float = 0.0
		for surface in range(baked.get_surface_count()):
			var arrays: Array = baked.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				if index < points.size():
					max_error = maxf(max_error, piece.to_global(vertex).distance_to(points[index]))
				index += 1
		_check(index == points.size() and index > 0 and max_error < 0.001, "CPU prediction disagrees with engine bake: " + str(piece.name))
		comparisons.append({"mesh": str(piece.name), "vertices": index, "max_error_m": max_error})
	report["engine_bake_comparison"] = comparisons

func _is_lower(piece: MeshInstance3D) -> bool:
	var part: String = str(piece.name).to_lower()
	return part.contains("pants") or part.contains("boots")

func _first_lower_mesh() -> MeshInstance3D:
	for item in visual.find_children("*", "MeshInstance3D", true, false):
		if _is_lower(item as MeshInstance3D):
			return item as MeshInstance3D
	return null

func _weapon_snapshot() -> Dictionary:
	var result: Dictionary = {}
	var weapon: Node3D = player.get_node_or_null("Head/Camera3D/Weapon") as Node3D
	if weapon == null:
		return result
	result[str(weapon.get_path())] = weapon.transform
	for child in weapon.find_children("*", "Node3D", true, false):
		result[str(child.get_path())] = (child as Node3D).transform
	return result

func _check(condition: bool, why: String) -> void:
	if not condition and not failures.has(why):
		failures.append(why)
		push_error("v157 BODY: " + why)

func _finish() -> void:
	report["failures"] = failures
	report["visual_acceptance"] = "PENDING: inspect rendered gameplay; geometry is not rasterization"
	var path: String = "user://v157-player-body-diagnostic.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		print("v157 REPORT: ", ProjectSettings.globalize_path(path))
	else:
		push_error("v157: cannot write diagnostic JSON")
		failures.append("report write failed")
	print("v157 BODY GEOMETRY: ", "PASS" if failures.is_empty() else "FAIL", "; VISUAL ACCEPTANCE PENDING")
	if not inspection or not inspection_ready:
		quit(0 if failures.is_empty() else 1)

func _setup_inspection() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	external_camera = Camera3D.new()
	root.add_child(external_camera)
	external_camera.fov = 60.0
	var canvas: CanvasLayer = CanvasLayer.new()
	root.add_child(canvas)
	canvas.layer = 100
	label = Label.new()
	canvas.add_child(label)
	label.position = Vector2(16, 70)
	label.text = "v157 DIAGNOSTIC ONLY - gameplay frozen\n1 FPS -75 deg | 2 front | 3 side | 4 full GLB | Esc exit\nSend JSON + screenshots. No automatic visual approval."
	if ResourceLoader.exists(FULL_MODEL):
		var packed: PackedScene = load(FULL_MODEL) as PackedScene
		if packed != null:
			full_visual = packed.instantiate() as Node3D
			root.add_child(full_visual)
			full_visual.process_mode = Node.PROCESS_MODE_DISABLED
			full_visual.visible = false
			await process_frame
			full_visual.position = player.global_position + Vector3(5, 0, 0)
			# Fit camera to predicted skinned geometry without scaling the source.
			var low: Vector3 = Vector3(INF, INF, INF)
			var high: Vector3 = Vector3(-INF, -INF, -INF)
			var found: bool = false
			for item in full_visual.find_children("*", "MeshInstance3D", true, false):
				var measured: Dictionary = Probe.geometry(item as MeshInstance3D, camera, full_visual)
				if measured.has("bounds"):
					var bounds: AABB = measured["bounds"]
					low = low.min(bounds.position)
					high = high.max(bounds.end)
					found = true
			if found:
				full_target = full_visual.to_global((low + high) * 0.5)
				full_radius = maxf((high - low).length(), 0.1)
			else:
				full_target = full_visual.global_position
			report["full_model_sha256"] = FileAccess.get_sha256(FULL_MODEL)
			report["full_hierarchy"] = Probe.hierarchy(full_visual)
			full_visual.visible = false
	else:
		label.text += "\nFull GLB unavailable (key 4 disabled)."
	inspection_ready = true
	camera.make_current()

func _process(_delta: float) -> bool:
	if not inspection_ready:
		return false
	if Input.is_key_pressed(KEY_ESCAPE):
		quit(0 if failures.is_empty() else 1)
	if Input.is_key_pressed(KEY_1):
		if full_visual != null:
			full_visual.visible = false
		camera.make_current()
	if Input.is_key_pressed(KEY_2) or Input.is_key_pressed(KEY_3):
		if full_visual != null:
			full_visual.visible = false
		var target: Vector3 = player.to_global(Vector3(0, -0.40, 0))
		var offset: Vector3 = Vector3(0, 0.4, -2.6) if Input.is_key_pressed(KEY_2) else Vector3(2.6, 0.4, 0)
		external_camera.global_position = target + offset
		external_camera.look_at(target)
		external_camera.make_current()
	if Input.is_key_pressed(KEY_4) and full_visual != null:
		full_visual.visible = true
		external_camera.global_position = full_target + Vector3(0, 0, -full_radius * 1.5)
		external_camera.look_at(full_target)
		external_camera.make_current()
	return false
