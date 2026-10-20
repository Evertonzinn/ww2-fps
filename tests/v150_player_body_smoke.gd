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
	if player.get_node_or_null("StanceController") == null or player.get_node_or_null("Head/Camera3D/Weapon") == null:
		push_error("v0.15 BODY SMOKE FAIL: previous stance or rifle contracts lost")
		quit(1)
		return
	print("PASS: v0.14 stance + camera rifle preserved")
	print("WW2 FPS v0.15 PLAYER BODY SMOKE: PASS")
	quit(0)
