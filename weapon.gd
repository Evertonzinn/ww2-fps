class_name WeaponController
extends Node3D

# Lee-Enfield No.4: 10-round magazine, normally recharged with 5-round chargers.
const MAGAZINE_SIZE: int = 10
const STARTING_RESERVE: int = 30
const CHARGER_SIZE: int = 5
const MAX_RANGE: float = 90.0
const SHOT_INTERVAL: float = 0.55
const ACTION_DURATION: float = 0.86
const OPEN_DURATION: float = 0.43
const CLOSE_DURATION: float = 0.48
const CHARGER_DURATION: float = 1.18
const HIP_POSITION: Vector3 = Vector3(0.30, -0.28, -0.56)
const AIM_POSITION: Vector3 = Vector3(0.0, -0.15, -0.48)
const HIP_FOV: float = 75.0
const AIM_FOV: float = 55.0

const MODEL_DIRECTORY: String = "res://assets/weapons/lee_enfield/"
const ReloadEffects = preload("res://weapon_reload_fx.gd")

@onready var view_camera: Camera3D = get_parent() as Camera3D
@onready var player_body: CharacterBody3D = view_camera.get_parent().get_parent() as CharacterBody3D
@onready var hud: CanvasLayer = get_tree().current_scene.get_node("HUD") as CanvasLayer
@onready var ammo_label: Label = hud.get_node("AmmoLabel") as Label
@onready var crosshair: Label = hud.get_node("Crosshair") as Label
@onready var muzzle_flash: MeshInstance3D = $MuzzleFlash
@onready var shot_audio: AudioStreamPlayer = $ShotAudio
@onready var reload_audio: AudioStreamPlayer = $ReloadAudio

var magazine: int = MAGAZINE_SIZE
var reserve_ammo: int = STARTING_RESERVE
var shot_cooldown: float = 0.0
var bolt_timer: float = 0.0
var eject_at_remaining: float = 0.0
var pending_ejection: bool = false
var pending_reload: bool = false
var bolt_open: bool = false
var reloading: bool = false
var reload_phase: int = 0  # 0=idle, 1=opening, 2=charger, 3=closing
var segment_timer: float = 0.0
var clip_rounds: int = 0
var pending_shot: bool = false
var recoil: float = 0.0
var recoil_pitch: float = 0.0
var muzzle_timer: float = 0.0
var walk_cycle: float = 0.0
var rifle_instance: Node3D
var active_texture_size: int = 2
var bolt_player: AnimationPlayer
var action_clip: StringName = &""
var open_clip: StringName = &""
var close_clip: StringName = &""
var reload_fx: RifleReloadFx

func _ready() -> void:
	position = HIP_POSITION
	muzzle_flash.visible = false
	reload_fx = ReloadEffects.new() as RifleReloadFx
	reload_fx.name = "ReloadFx"
	add_child(reload_fx)
	# Without a GLB, the scene's original procedural meshes remain visible.
	_equip_real_rifle(2)
	shot_audio.stream = _placeholder_sound(true)
	reload_audio.stream = _placeholder_sound(false)
	_update_hud()

func request_fire() -> void:
	pending_shot = true

func request_reload() -> void:
	if reloading or pending_reload or magazine >= MAGAZINE_SIZE or reserve_ammo <= 0:
		return
	if bolt_timer > 0.0:
		pending_reload = true
		_update_hud()
	else:
		_start_reload()

func _physics_process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	bolt_timer = maxf(0.0, bolt_timer - delta)

	if pending_ejection and bolt_timer <= eject_at_remaining:
		pending_ejection = false
		reload_fx.eject_case(global_transform, player_body)

	if reloading:
		match reload_phase:
			1: # Open the action before feeding chargers.
				if bolt_timer <= 0.0:
					_hold_clip_end(open_clip)
					bolt_open = true
					_start_charger()
			2: # Insert up to five cartridges per charger.
				segment_timer -= delta
				if segment_timer <= 0.0:
					magazine += clip_rounds
					reserve_ammo -= clip_rounds
					reload_fx.hide_charger()
					_update_hud()
					if magazine < MAGAZINE_SIZE and reserve_ammo > 0:
						_start_charger()
					else:
						_start_close()
			3: # Close and lock the action before enabling fire.
				if bolt_timer <= 0.0:
					_hold_clip_end(close_clip)
					reload_phase = 0
					reloading = false
					bolt_open = false
					_update_hud()
	elif pending_reload and bolt_timer <= 0.0:
		pending_reload = false
		_start_reload()

	if pending_shot:
		pending_shot = false
		if not reloading and not pending_reload and shot_cooldown <= 0.0 and bolt_timer <= 0.0 and magazine > 0:
			_fire_hitscan()

func _process(delta: float) -> void:
	var aiming: bool = not reloading and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var moving: bool = player_body.is_on_floor() and Vector2(player_body.velocity.x, player_body.velocity.z).length_squared() > 0.8
	if moving:
		walk_cycle += delta * (12.0 if Input.is_key_pressed(KEY_SHIFT) else 8.0)
	var bob_scale: float = 0.35 if aiming else 1.0
	var bob_x: float = sin(walk_cycle) * 0.014 * bob_scale if moving else 0.0
	var bob_y: float = abs(cos(walk_cycle)) * 0.010 * bob_scale if moving else 0.0
	var destination: Vector3 = AIM_POSITION if aiming else HIP_POSITION
	destination += Vector3(bob_x, bob_y, recoil)
	if reloading:
		destination = HIP_POSITION + Vector3(0.08, -0.12, 0.04)
	position = position.lerp(destination, minf(1.0, delta * 12.0))
	rotation.x = lerpf(rotation.x, -0.20 if reloading else recoil_pitch, minf(1.0, delta * 13.0))
	rotation.z = lerpf(rotation.z, sin(walk_cycle) * 0.018 if moving else 0.0, minf(1.0, delta * 8.0))
	view_camera.fov = lerpf(view_camera.fov, AIM_FOV if aiming else HIP_FOV, minf(1.0, delta * 10.0))
	recoil = move_toward(recoil, 0.0, delta * 0.75)
	recoil_pitch = move_toward(recoil_pitch, 0.0, delta * 2.2)
	muzzle_timer = maxf(0.0, muzzle_timer - delta)
	muzzle_flash.visible = muzzle_timer > 0.0
	crosshair.visible = not aiming
	if reloading and reload_phase == 2:
		reload_fx.animate_charger(1.0 - segment_timer / CHARGER_DURATION)

func _fire_hitscan() -> void:
	magazine -= 1
	shot_cooldown = SHOT_INTERVAL
	recoil = 0.10
	recoil_pitch = 0.14
	muzzle_timer = 0.07
	shot_audio.play()

	var auto_reload: bool = magazine == 0 and reserve_ammo > 0
	if auto_reload and bolt_player != null and open_clip != &"":
		_play_clip(open_clip, OPEN_DURATION)
		eject_at_remaining = 0.21
		bolt_open = true
	elif bolt_player != null and action_clip != &"":
		_play_clip(action_clip, ACTION_DURATION)
		eject_at_remaining = 0.44
		bolt_open = false
	else:
		bolt_timer = 0.0
		eject_at_remaining = 0.0
		bolt_open = false
	pending_ejection = true

	var origin: Vector3 = view_camera.global_position
	var destination: Vector3 = origin - view_camera.global_transform.basis.z * MAX_RANGE
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, destination)
	query.exclude = [player_body.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit.get("collider")
		if target != null and target.has_method("take_damage"):
			target.call("take_damage", 1)
			hud.call("show_hit_marker")

	if auto_reload:
		pending_reload = true
	_update_hud()

func _start_reload() -> void:
	if reloading or magazine >= MAGAZINE_SIZE or reserve_ammo <= 0:
		return
	pending_reload = false
	reloading = true
	reload_audio.play()
	if bolt_player != null and open_clip != &"" and not bolt_open:
		reload_phase = 1
		_play_clip(open_clip, OPEN_DURATION)
	else:
		_start_charger()
	_update_hud()

func _start_charger() -> void:
	clip_rounds = mini(CHARGER_SIZE, mini(MAGAZINE_SIZE - magazine, reserve_ammo))
	if clip_rounds <= 0:
		_start_close()
		return
	reload_phase = 2
	segment_timer = CHARGER_DURATION
	reload_fx.show_charger(clip_rounds)
	_update_hud()

func _start_close() -> void:
	reload_fx.hide_charger()
	if bolt_player != null and close_clip != &"":
		reload_phase = 3
		_play_clip(close_clip, CLOSE_DURATION)
	else:
		reload_phase = 0
		reloading = false
		bolt_open = false
		_update_hud()

func _play_clip(clip: StringName, duration: float) -> void:
	bolt_timer = duration
	bolt_player.play(clip)

func _hold_clip_end(clip: StringName) -> void:
	if bolt_player == null or clip == &"":
		return
	var animation: Animation = bolt_player.get_animation(clip)
	bolt_player.stop(true)
	if animation != null:
		bolt_player.seek(animation.length, true)

func _update_hud() -> void:
	ammo_label.text = "%d / %d" % [magazine, reserve_ammo]
	if reloading:
		if reload_phase == 1:
			ammo_label.text += "  ABRINDO FERROLHO..."
		elif reload_phase == 2:
			ammo_label.text += "  INSERINDO CLIP..."
		else:
			ammo_label.text += "  FECHANDO FERROLHO..."
	elif pending_reload:
		ammo_label.text += "  AGUARDANDO FERROLHO..."
	elif magazine == 0 and reserve_ammo == 0:
		ammo_label.text += "  SEM MUNICAO"

func set_texture_quality(high_quality: bool) -> bool:
	if reloading or pending_reload or bolt_timer > 0.0:
		return false
	var size: int = 2 if high_quality else 1
	if rifle_instance != null and active_texture_size == size:
		return true
	return _equip_real_rifle(size)

func _equip_real_rifle(size: int) -> bool:
	var sources: Array[String] = [
		MODEL_DIRECTORY + "lee_enfield_charger_%dk.glb" % size,
		MODEL_DIRECTORY + "lee_enfield_rigged_once_%dk.glb" % size,
		MODEL_DIRECTORY + "lee_enfield_rigged_%dk.glb" % size,
		MODEL_DIRECTORY + "lee_enfield_%dk.glb" % size
	]
	var chosen: String = ""
	for path in sources:
		if ResourceLoader.exists(path):
			chosen = path
			break
	if chosen.is_empty():
		return false
	var scene: PackedScene = ResourceLoader.load(chosen) as PackedScene
	if scene == null:
		return false
	var replacement: Node3D = scene.instantiate() as Node3D
	if replacement == null:
		return false
	replacement.name = "LeeEnfield3D"
	add_child(replacement)
	replacement.position = Vector3(0.0, 0.085, -0.55)
	if rifle_instance != null:
		rifle_instance.queue_free()
	rifle_instance = replacement
	active_texture_size = size
	_bind_animations()
	for child in get_children():
		if child is MeshInstance3D and child != muzzle_flash:
			(child as MeshInstance3D).visible = false
	muzzle_flash.position = Vector3(0.0, 0.085, -1.13)
	return true

func _bind_animations() -> void:
	bolt_player = null
	action_clip = &""
	open_clip = &""
	close_clip = &""
	if rifle_instance == null:
		return
	var candidates: Array[Node] = rifle_instance.find_children("*", "AnimationPlayer", true, false)
	for node in candidates:
		var player: AnimationPlayer = node as AnimationPlayer
		if player == null:
			continue
		for entry in player.get_animation_list():
			var clip_name: String = String(entry)
			var animation: Animation = player.get_animation(entry)
			if animation == null:
				continue
			if clip_name.ends_with("BoltAction_Once") or clip_name.ends_with("BoltCycle"):
				action_clip = StringName(entry)
			elif clip_name.ends_with("BoltOpen_Once"):
				open_clip = StringName(entry)
			elif clip_name.ends_with("BoltClose_Once"):
				close_clip = StringName(entry)
			else:
				continue
			animation.loop_mode = Animation.LOOP_NONE
			bolt_player = player
		if bolt_player != null:
			bolt_player.stop(true)
			print("Lee-Enfield: action=", action_clip, " open=", open_clip, " close=", close_clip)
			return

func _placeholder_sound(is_shot: bool) -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.19 if is_shot else 0.09
	var count: int = int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 1944 if is_shot else 1945
	for i in range(count):
		var p: float = float(i) / float(count)
		var envelope: float = pow(1.0 - p, 4.0 if is_shot else 5.0)
		var noise: float = random.randf_range(-1.0, 1.0)
		var tone: float = sin(float(i) * TAU * (110.0 if is_shot else 450.0) / float(rate))
		var sample: float = clampf((noise * 0.8 + tone * 0.2) * envelope * 0.72, -1.0, 1.0)
		var encoded: int = int(sample * 32767.0) & 0xffff
		data[i * 2] = encoded & 0xff
		data[i * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
