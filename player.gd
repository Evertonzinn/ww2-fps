extends CharacterBody3D

signal gunshot(location: Vector3)

const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const JUMP_SPEED: float = 4.5
const GRAVITY: float = 9.8
const MOUSE_SENSITIVITY: float = 0.002

@export_range(1, 500, 1) var max_health: int = 100
var health: int = 100
var is_dead: bool = false

@onready var head: Node3D = $Head
@onready var weapon: WeaponController = $Head/Camera3D/Weapon
@onready var graphics_menu: GraphicsSettingsMenu = $"../GraphicsMenu"

func _ready() -> void:
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	call_deferred("_update_health_hud")

func _update_health_hud() -> void:
	var ui: Node = get_tree().current_scene.get_node_or_null("HUD")
	if ui != null:
		ui.call("show_player_health", health, max_health)

func report_gunshot() -> void:
	if not is_dead:
		gunshot.emit(global_position)

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = maxi(0, health - amount)
	_update_health_hud()
	var ui: Node = get_tree().current_scene.get_node_or_null("HUD")
	if ui != null:
		ui.call("show_player_damage", amount)
	if health == 0:
		is_dead = true
		velocity = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if ui != null:
			ui.call("show_player_death")
		print("WW2 FPS player ELIMINATED")

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, -1.4, 1.4)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			graphics_menu.open_menu()
		elif event.keycode == KEY_R and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			weapon.request_reload()
		elif event.keycode == KEY_1 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			weapon.select_weapon(1)
		elif event.keycode == KEY_2 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			weapon.select_weapon(2)

	if graphics_menu.is_open:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				weapon.request_fire()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = JUMP_SPEED

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0

	input_dir = input_dir.normalized()
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed: float = RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
