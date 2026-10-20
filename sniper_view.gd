class_name SniperView
extends Node3D

# Separate 5-round scoped gun with no imported animations. CC BY 4.0 asset.
const GLB_1K: String = "res://assets/weapons/sniper/sniper_rifle_1k.glb"
const GLB_2K: String = "res://assets/weapons/sniper/sniper_rifle_2k.glb"
const CAPACITY: int = 5
const RELOAD_TIME: float = 2.4
const SHOT_INTERVAL: float = 1.35
const MAX_RANGE: float = 160.0
const HIP: Vector3 = Vector3(0.27, -0.28, -0.60)
const ADS: Vector3 = Vector3(0, -0.10, -0.51)
var active: bool = false
var quality_high: bool = false
var rifle: Node3D
var magazine: int = CAPACITY
var reserve: int = 20
var reload_timer: float = 0.0
var shot_timer: float = 0.0
var flash_timer: float = 0.0
var pending_fire: bool = false
var recoil: float = 0.0
var camera: Camera3D
var player_body: CharacterBody3D
var hud: CanvasLayer
var ammo: Label
var crosshair: Label
var scope_layer: CanvasLayer
var flash: MeshInstance3D
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer

func _ready() -> void:
	camera = get_parent().get_parent() as Camera3D
	player_body = camera.get_parent().get_parent() as CharacterBody3D
	hud = get_tree().current_scene.get_node("HUD") as CanvasLayer
	ammo = hud.get_node("AmmoLabel") as Label
	crosshair = hud.get_node("Crosshair") as Label
	shot_audio = get_parent().get_node("ShotAudio") as AudioStreamPlayer
	reload_audio = get_parent().get_node("ReloadAudio") as AudioStreamPlayer
	position = HIP
	_make_scope()
	_make_flash()
	visible = false

func equip() -> bool:
	if rifle == null or not is_instance_valid(rifle):
		if not set_texture_quality(quality_high):
			return false
	active = true
	visible = true
	_update_hud()
	return true

func unequip() -> void:
	active = false
	pending_fire = false
	visible = false
	if scope_layer != null:
		scope_layer.visible = false

func is_busy() -> bool:
	return reload_timer > 0.0 or shot_timer > 0.0

func set_texture_quality(high: bool) -> bool:
	quality_high = high
	var path: String = GLB_2K if high else GLB_1K
	if not ResourceLoader.exists(path):
		push_warning("Sniper GLB ausente: " + path)
		return false
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		return false
	var new_rifle: Node3D = packed.instantiate() as Node3D
	if new_rifle == null:
		return false
	new_rifle.name = "MartinTrafasSniper"
	# Source muzzle points -Y, scope +Z. Reorient to Godot forward -Z, up +Y.
	new_rifle.basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI * 0.5)
	new_rifle.position = Vector3(0.0, 0.025, -0.30)
	add_child(new_rifle)
	if rifle != null and is_instance_valid(rifle):
		rifle.queue_free()
	rifle = new_rifle
	return true

func request_fire() -> void:
	if active:
		pending_fire = true

func request_reload() -> void:
	if not active or reload_timer > 0.0 or magazine >= CAPACITY or reserve <= 0:
		return
	reload_timer = RELOAD_TIME
	reload_audio.play()
	_update_hud()

func _physics_process(delta: float) -> void:
	if not active:
		return
	shot_timer = maxf(0.0, shot_timer - delta)
	if reload_timer > 0.0:
		reload_timer = maxf(0.0, reload_timer - delta)
		if reload_timer <= 0.0:
			var amount: int = mini(CAPACITY - magazine, reserve)
			magazine += amount
			reserve -= amount
			_update_hud()
	if pending_fire:
		pending_fire = false
		if reload_timer <= 0.0 and shot_timer <= 0.0 and magazine > 0:
			_fire()

func _process(delta: float) -> void:
	if not active:
		return
	var aiming: bool = reload_timer <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var desired: Vector3 = ADS if aiming else HIP
	desired.z += recoil
	position = position.lerp(desired, minf(1.0, delta * 12.0))
	rotation.x = lerpf(rotation.x, -0.15 if reload_timer > 0.0 else recoil * 0.6, minf(1.0, delta * 9.0))
	recoil = move_toward(recoil, 0.0, delta * 0.65)
	camera.fov = lerpf(camera.fov, 20.0 if aiming else 75.0, minf(1.0, delta * 9.0))
	crosshair.visible = not aiming
	scope_layer.visible = aiming
	if rifle != null:
		rifle.visible = not aiming
	flash_timer = maxf(0.0, flash_timer - delta)
	flash.visible = flash_timer > 0.0 and not aiming

func _fire() -> void:
	magazine -= 1
	shot_timer = SHOT_INTERVAL
	recoil = 0.11
	flash_timer = 0.06
	shot_audio.play()
	var origin: Vector3 = camera.global_position
	var dest: Vector3 = origin - camera.global_transform.basis.z * MAX_RANGE
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, dest)
	query.exclude = [player_body.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit.get("collider")
		if target != null and target.has_method("take_damage"):
			target.call("take_damage", 1)
			hud.call("show_hit_marker")
	if magazine == 0 and reserve > 0:
		request_reload()
	_update_hud()

func _update_hud() -> void:
	ammo.text = "SNIPER  %d / %d" % [magazine, reserve]
	if reload_timer > 0.0:
		ammo.text += "  RECARREGANDO..."
	elif magazine == 0 and reserve == 0:
		ammo.text += "  SEM MUNICAO"

func _make_scope() -> void:
	scope_layer = CanvasLayer.new()
	scope_layer.name = "SniperScopeHUD"
	scope_layer.layer = 6
	get_tree().current_scene.add_child(scope_layer)
	var mask: ColorRect = ColorRect.new()
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	# One overlay pass; no extra rendered 3D camera on GT 730.
	shader.code = "shader_type canvas_item;\nvoid fragment() {\nvec2 px=(UV-vec2(0.5))/SCREEN_PIXEL_SIZE;\nfloat r=min(1.0/SCREEN_PIXEL_SIZE.x,1.0/SCREEN_PIXEL_SIZE.y)*0.37;\nfloat d=length(px);\nfloat outside=smoothstep(r-2.0,r+2.0,d);\nfloat ring=1.0-smoothstep(1.0,3.0,abs(d-r));\nfloat cross=max(1.0-smoothstep(0.4,1.5,abs(px.x)),1.0-smoothstep(0.4,1.5,abs(px.y)));\ncross*=1.0-smoothstep(r*0.72,r*0.74,d);\nCOLOR=vec4(vec3(0.02),clamp(max(outside,max(ring,cross)),0.0,1.0));\n}\n"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	mask.material = material
	scope_layer.add_child(mask)
	scope_layer.visible = false

func _make_flash() -> void:
	flash = MeshInstance3D.new()
	flash.name = "SniperMuzzleFlash"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.10
	mesh.radial_segments = 8
	mesh.rings = 4
	flash.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.69, 0.24)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = mat
	flash.position = Vector3(0, 0.03, -0.82)
	add_child(flash)
	flash.visible = false
