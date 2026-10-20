extends StaticBody3D

# Enemy integration v0.10.0 — uses existing weapon take_damage contract.
# Source GLB: britdawgmasterfunk, CC BY 4.0, 65 bones, no animations.
const MODEL_1K: String = "res://assets/characters/panzergrenadier/panzergrenadier_1k.glb"
const MODEL_2K: String = "res://assets/characters/panzergrenadier/panzergrenadier_2k.glb"
const MODEL_SCALE: float = 0.019
const FOOT_LIFT: float = 0.046

@export_range(1, 20, 1) var max_health: int = 3
@export var high_quality: bool = false
@onready var hitbox: CollisionShape3D = $CollisionShape3D

var health: int = 3
var model: Node3D
var eliminated: bool = false

func _ready() -> void:
	health = max_health
	var path: String = MODEL_2K if high_quality else MODEL_1K
	if not ResourceLoader.exists(path):
		_disable_enemy("Panzergrenadier GLB not found: " + path)
		return
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		_disable_enemy("Panzergrenadier GLB did not import as PackedScene: " + path)
		return
	var imported: Node3D = packed.instantiate() as Node3D
	if imported == null:
		_disable_enemy("Panzergrenadier GLB does not instantiate as Node3D")
		return
	imported.name = "PanzergrenadierVisual"
	add_child(imported)
	imported.scale = Vector3.ONE * MODEL_SCALE
	imported.position.y = FOOT_LIFT
	model = imported

	var rig_nodes: Array[Node] = imported.find_children("*", "Skeleton3D", true, false)
	if rig_nodes.is_empty():
		_disable_enemy("Skeleton3D not found in imported Panzergrenadier")
		return
	var rig: Skeleton3D = rig_nodes[0] as Skeleton3D
	if rig == null or rig.get_bone_count() < 60:
		_disable_enemy("Panzergrenadier imported Skeleton3D lacks expected bones")
		return
	print("WW2 FPS enemy ready: %d bones, %d HP, 1K=%s" % [
		rig.get_bone_count(), health, str(not high_quality)
	])

func take_damage(amount: int) -> void:
	if eliminated or amount <= 0:
		return
	health = maxi(0, health - amount)
	if health <= 0:
		_die()

func _die() -> void:
	eliminated = true
	hitbox.set_deferred("disabled", true)
	queue_free()

func _disable_enemy(message: String) -> void:
	push_warning("WW2 FPS enemy disabled: " + message)
	hitbox.set_deferred("disabled", true)
	if model != null and is_instance_valid(model):
		model.visible = false
