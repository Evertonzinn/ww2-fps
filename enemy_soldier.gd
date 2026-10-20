extends StaticBody3D

# v0.10.1 visual-availability diagnostic for the original rigged character.
# Source: britdawgmasterfunk, CC BY 4.0 (credit in docs).
# No modifications to weapon, ADS, raycast, game ammo or imported geometry.
const MODEL_1K: String = "res://assets/characters/panzergrenadier/panzergrenadier_1k.glb"
const MODEL_2K: String = "res://assets/characters/panzergrenadier/panzergrenadier_2k.glb"
const SOURCE_GLTF: String = "res://assets/characters/panzergrenadier/scene.gltf"
const MODEL_SCALE: float = 0.019
const FOOT_LIFT: float = 0.046

@export_range(1, 20, 1) var max_health: int = 3
@export var high_quality: bool = false
@onready var hitbox: CollisionShape3D = $CollisionShape3D
@onready var locator: Label3D = $DebugMarker

var health: int = 3
var model: Node3D
var eliminated: bool = false
var warning_layer: CanvasLayer

func _ready() -> void:
	health = max_health
	# A separate ZIP contains the 3D data; the GitHub PR has only code.
	# Accept either 1K/2K variant, whichever has actually been extracted.
	var paths: PackedStringArray
	if high_quality:
		paths = PackedStringArray([MODEL_2K, MODEL_1K, SOURCE_GLTF])
	else:
		paths = PackedStringArray([MODEL_1K, MODEL_2K, SOURCE_GLTF])
	var chosen_path: String = ""
	for candidate in paths:
		if ResourceLoader.exists(candidate):
			chosen_path = candidate
			break
	if chosen_path.is_empty():
		var explanation: String = "Panzergrenadier asset absent or not imported.\nExpected: " + MODEL_1K + "\nUnpack ww2fps-v100-panzergrenadier-assets.zip at the project root and reopen Godot."
		if FileAccess.file_exists(MODEL_1K) or FileAccess.file_exists(MODEL_2K):
			explanation = "Panzergrenadier GLB exists but Godot has not imported it.\nClose editor, run Godot --headless --editor --path PROJECT --quit, then reopen."
		_disable_enemy(explanation)
		return

	print("WW2 FPS enemy: loading ", chosen_path)
	var packed: PackedScene = ResourceLoader.load(chosen_path) as PackedScene
	if packed == null:
		_disable_enemy("GLB / glTF found, but did not import as PackedScene: " + chosen_path)
		return
	var imported: Node3D = packed.instantiate() as Node3D
	if imported == null:
		_disable_enemy("Soldier packed scene did not instantiate as Node3D: " + chosen_path)
		return
	imported.name = "PanzergrenadierVisual"
	add_child(imported)
	imported.scale = Vector3.ONE * MODEL_SCALE
	imported.position.y = FOOT_LIFT
	model = imported

	# Skeleton is important for future animations, but lack of a named rig
	# must not silently hide a visual model that was loaded successfully.
	var meshes: Array[Node] = imported.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		_disable_enemy("Model loaded, but no MeshInstance3D found: " + chosen_path)
		return
	var rigs: Array[Node] = imported.find_children("*", "Skeleton3D", true, false)
	var bone_count: int = 0
	if not rigs.is_empty() and rigs[0] is Skeleton3D:
		bone_count = (rigs[0] as Skeleton3D).get_bone_count()
	if bone_count < 60:
		push_warning("WW2 FPS enemy: rig has %d bones; render kept visible for inspection." % bone_count)
	locator.visible = true
	print("WW2 FPS enemy READY: visual meshes=%d bones=%d HP=%d model=%s position=%s" % [
		meshes.size(), bone_count, health, chosen_path, str(global_position)
	])

func take_damage(amount: int) -> void:
	if eliminated or amount <= 0:
		return
	health = maxi(0, health - amount)
	if health == 0:
		_die()

func _die() -> void:
	eliminated = true
	hitbox.set_deferred("disabled", true)
	queue_free()

func _disable_enemy(message: String) -> void:
	push_error("WW2 FPS enemy disabled: " + message)
	hitbox.set_deferred("disabled", true)
	locator.visible = false
	if model != null and is_instance_valid(model):
		model.visible = false
	# This remains on screen until the user installs/imports the asset.
	# Explicit diagnostic rather than silently hiding the soldier.
	warning_layer = CanvasLayer.new()
	warning_layer.name = "EnemyAssetErrorHUD"
	warning_layer.layer = 8
	add_child(warning_layer)
	var notice: Label = Label.new()
	notice.name = "MissingPanzergrenadierWarning"
	notice.text = "SOLDADO NAO CARREGADO - ASSET AUSENTE OU SEM IMPORTACAO\nConsulte Output/Debugger e instale o ZIP do Panzergrenadier."
	notice.add_theme_color_override("font_color", Color(1.0, 0.36, 0.22, 1.0))
	notice.add_theme_font_size_override("font_size", 15)
	notice.position = Vector2(18.0, 50.0)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_layer.add_child(notice)
