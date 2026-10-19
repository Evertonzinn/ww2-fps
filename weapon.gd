class_name WeaponController
extends Node3D

const MAGAZINE_SIZE: int = 5
const STARTING_RESERVE: int = 30
const MAX_RANGE: float = 90.0
const SHOT_INTERVAL: float = 0.55
const RELOAD_DURATION: float = 1.8
const HIP_POSITION: Vector3 = Vector3(0.30, -0.28, -0.56)
const AIM_POSITION: Vector3 = Vector3(0.0, -0.15, -0.48)
const HIP_FOV: float = 75.0
const AIM_FOV: float = 55.0

@onready var view_camera: Camera3D = get_parent() as Camera3D
@onready var ammo_label: Label = get_tree().current_scene.get_node_or_null("HUD/AmmoLabel") as Label
@onready var crosshair: Label = get_tree().current_scene.get_node_or_null("HUD/Crosshair") as Label

var magazine: int = MAGAZINE_SIZE
var reserve_ammo: int = STARTING_RESERVE
var shot_cooldown: float = 0.0
var reload_timer: float = 0.0
var reloading: bool = false
var pending_shot: bool = false
var recoil: float = 0.0

func _ready() -> void:
	position = HIP_POSITION
	_update_hud()

func request_fire() -> void:
	pending_shot = true

func request_reload() -> void:
	if reloading or magazine == MAGAZINE_SIZE or reserve_ammo <= 0:
		return
	reloading = true
	reload_timer = RELOAD_DURATION
	_update_hud()

func _physics_process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)

	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			var count: int = mini(MAGAZINE_SIZE - magazine, reserve_ammo)
			magazine += count
			reserve_ammo -= count
			reloading = false
			_update_hud()

	if pending_shot:
		pending_shot = false
		if not reloading and shot_cooldown <= 0.0 and magazine > 0:
			_fire_hitscan()

func _process(delta: float) -> void:
	var aiming: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var target_pos: Vector3 = AIM_POSITION if aiming else HIP_POSITION
	target_pos.z += recoil
	position = position.lerp(target_pos, minf(1.0, delta * 12.0))
	view_camera.fov = lerpf(view_camera.fov, AIM_FOV if aiming else HIP_FOV, minf(1.0, delta * 10.0))
	recoil = move_toward(recoil, 0.0, delta * 0.5)
	if crosshair != null:
		crosshair.visible = not aiming

func _fire_hitscan() -> void:
	magazine -= 1
	shot_cooldown = SHOT_INTERVAL
	recoil = 0.09
	_update_hud()

	var origin: Vector3 = view_camera.global_position
	var destination: Vector3 = origin - view_camera.global_transform.basis.z * MAX_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	var player_body := view_camera.get_parent().get_parent() as CharacterBody3D
	query.exclude = [player_body.get_rid()]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit.get("collider")
		if target != null and target.has_method("take_damage"):
			target.call("take_damage", 1)

func _update_hud() -> void:
	if ammo_label == null:
		return
	ammo_label.text = "%d / %d" % [magazine, reserve_ammo]
	if reloading:
		ammo_label.text += "  RECARREGANDO..."
