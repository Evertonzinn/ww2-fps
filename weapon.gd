class_name WeaponController
extends Node3D

const MAGAZINE_SIZE: int = 5
const STARTING_RESERVE: int = 30
const MAX_RANGE: float = 90.0
const SHOT_INTERVAL: float = 0.55
const RELOAD_DURATION: float = 1.8
const BOLT_CYCLE_DURATION: float = 0.80
const BoltVisualRig = preload("res://weapon_bolt.gd")
const CASE_EJECTION_DURATION: float = 0.38
const HIP_POSITION: Vector3 = Vector3(0.30, -0.28, -0.56)
const AIM_POSITION: Vector3 = Vector3(0.0, -0.15, -0.48)
const HIP_FOV: float = 75.0
const AIM_FOV: float = 55.0

# Arquivo de asset instalado localmente; a v0.5 continua funcional sem ele.
# Escolha lee_enfield_1k.glb para reduzir o uso de VRAM na GT 730.
const RIFLE_3D_PATH: String = "res://assets/weapons/lee_enfield/lee_enfield_2k.glb"

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
var reload_timer: float = 0.0
var reloading: bool = false
var pending_shot: bool = false
var recoil: float = 0.0
var recoil_pitch: float = 0.0
var muzzle_timer: float = 0.0
var walk_cycle: float = 0.0
var bolt_cycle_timer: float = 0.0
var auto_reload_pending: bool = false
var case_ejection_pending: bool = false
var case_ejection_timer: float = 0.0
var case_visual: MeshInstance3D
var rifle_instance: Node3D
var active_texture_size: int = 2
var bolt_visual_rig: BoltVisualRig

func _ready() -> void:
	bolt_visual_rig = BoltVisualRig.new()
	position = HIP_POSITION
	muzzle_flash.visible = false
	# Quando o GLB estiver presente, troca somente o visual do rifle.
	# Raycast, ADS, carregador, dano e HUD permanecem inalterados.
	if not _equip_real_rifle():
		_build_rifle_details()
		_build_stock_mesh()
	_create_cartridge_case()
	shot_audio.stream = _create_placeholder_sound(true)
	reload_audio.stream = _create_placeholder_sound(false)
	_update_hud()

func request_fire() -> void:
	pending_shot = true

func request_reload() -> void:
	if reloading or magazine == MAGAZINE_SIZE or reserve_ammo <= 0:
		return
	# Nao iniciar recarga no meio do ciclo de extracao do estojo.
	if bolt_cycle_timer > 0.0:
		auto_reload_pending = true
		return
	auto_reload_pending = false
	reloading = true
	reload_timer = RELOAD_DURATION
	reload_audio.play()
	_update_hud()

func _physics_process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	bolt_cycle_timer = maxf(0.0, bolt_cycle_timer - delta)
	if auto_reload_pending and bolt_cycle_timer <= 0.0:
		auto_reload_pending = false
		request_reload()

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
		if not reloading and shot_cooldown <= 0.0 and bolt_cycle_timer <= 0.0 and magazine > 0:
			_fire_hitscan()

func _process(delta: float) -> void:
	var aiming: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var moving: bool = player_body.is_on_floor() and Vector2(player_body.velocity.x, player_body.velocity.z).length_squared() > 0.8

	if moving:
		var running: bool = Input.is_key_pressed(KEY_SHIFT)
		walk_cycle += delta * (12.0 if running else 8.0)

	var bob_scale: float = 0.35 if aiming else 1.0
	var bob_x: float = sin(walk_cycle) * 0.014 * bob_scale if moving else 0.0
	var bob_y: float = abs(cos(walk_cycle)) * 0.010 * bob_scale if moving else 0.0

	var target_pos: Vector3 = AIM_POSITION if aiming else HIP_POSITION
	var cycle_progress: float = 1.0 - bolt_cycle_timer / BOLT_CYCLE_DURATION
	var bolt_pull: float = sin(cycle_progress * PI) * 0.038 if bolt_cycle_timer > 0.0 else 0.0
	target_pos += Vector3(bob_x + bolt_pull * 0.45, bob_y, recoil + bolt_pull)
	if reloading:
		target_pos = HIP_POSITION + Vector3(0.08, -0.22, 0.04)

	position = position.lerp(target_pos, minf(1.0, delta * 12.0))
	rotation.x = lerpf(rotation.x, -0.32 if reloading else recoil_pitch, minf(1.0, delta * 13.0))
	var cycle_roll: float = sin(cycle_progress * PI) * 0.065 if bolt_cycle_timer > 0.0 else 0.0
	rotation.z = lerpf(rotation.z, (sin(walk_cycle) * 0.018 if moving else 0.0) + cycle_roll, minf(1.0, delta * 8.0))
	view_camera.fov = lerpf(view_camera.fov, AIM_FOV if aiming else HIP_FOV, minf(1.0, delta * 10.0))
	recoil = move_toward(recoil, 0.0, delta * 0.75)
	recoil_pitch = move_toward(recoil_pitch, 0.0, delta * 2.2)

	if muzzle_timer > 0.0:
		muzzle_timer -= delta
		if muzzle_timer <= 0.0:
			muzzle_flash.visible = false

	# O estojo sai somente durante a abertura do ferrolho, nao no instante do tiro.
	if case_ejection_pending and bolt_cycle_timer > 0.0 and cycle_progress >= 0.37:
		case_ejection_pending = false
		case_ejection_timer = CASE_EJECTION_DURATION
	if case_visual != null:
		_update_cartridge_case(delta)
	if bolt_visual_rig != null and rifle_instance != null:
		bolt_visual_rig.animate(cycle_progress if bolt_cycle_timer > 0.0 else 1.0)
	crosshair.visible = not aiming

func _fire_hitscan() -> void:
	magazine -= 1
	shot_cooldown = SHOT_INTERVAL
	bolt_cycle_timer = BOLT_CYCLE_DURATION
	case_ejection_timer = 0.0
	case_ejection_pending = true
	if case_visual != null:
		case_visual.visible = false
	recoil = 0.10
	recoil_pitch = 0.14
	muzzle_timer = 0.07
	muzzle_flash.visible = true
	shot_audio.play()
	_update_hud()

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

	# A recarga inicia apos o ultimo disparo, sem exigir R.
	# Se nao houver municao na reserva, o HUD informa carregador vazio.
	if magazine == 0 and reserve_ammo > 0:
		auto_reload_pending = true
		_update_hud()

func _update_hud() -> void:
	ammo_label.text = "%d / %d" % [magazine, reserve_ammo]
	if reloading:
		ammo_label.text += "  RECARREGANDO..."
	elif auto_reload_pending:
		ammo_label.text += "  OPERANDO FERROLHO..."
	elif magazine == 0 and reserve_ammo == 0:
		ammo_label.text += "  SEM MUNICAO"

# Efeito sonoro sintetizado apenas como placeholder; sem dependencia de arquivos/licencas.
func _create_placeholder_sound(is_shot: bool) -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.19 if is_shot else 0.09
	var sample_count: int = int(float(rate) * duration)
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(sample_count * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1944 if is_shot else 1945

	for i in range(sample_count):
		var progress: float = float(i) / float(sample_count)
		var envelope: float = pow(1.0 - progress, 4.0 if is_shot else 5.0)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var tone: float = sin(float(i) * TAU * (110.0 if is_shot else 450.0) / float(rate))
		var sample: float = clampf((noise * 0.80 + tone * 0.20) * envelope * 0.72, -1.0, 1.0)
		var encoded: int = int(sample * 32767.0) & 0xffff
		raw[i * 2] = encoded & 0xff
		raw[i * 2 + 1] = (encoded >> 8) & 0xff

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = raw
	return stream


func _build_rifle_details() -> void:
	# Detalhes simples com material proprio; podem ser trocados por um GLB.
	var stock_wood: StandardMaterial3D = StandardMaterial3D.new()
	stock_wood.albedo_color = Color(0.30, 0.17, 0.085)
	stock_wood.roughness = 0.86
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.19, 0.20, 0.19)
	steel.metallic = 0.42
	steel.roughness = 0.63

	_weapon_box("WoodHandguard", Vector3(0, 0.015, -0.60), Vector3(0.125, 0.10, 0.39), stock_wood)
	_weapon_box("FrontBand", Vector3(0, 0.018, -0.81), Vector3(0.15, 0.115, 0.058), steel)
	_weapon_box("ReceiverTop", Vector3(0, 0.075, -0.35), Vector3(0.11, 0.035, 0.27), steel)
	_weapon_box("TriggerPlate", Vector3(0, -0.13, -0.20), Vector3(0.085, 0.035, 0.18), steel)
	_weapon_box("ButtPlate", Vector3(0, -0.07, 0.49), Vector3(0.17, 0.15, 0.035), steel)

func _weapon_box(node_name: String, local_position: Vector3, dimensions: Vector3, surface: Material) -> void:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = node_name
	var shape: BoxMesh = BoxMesh.new()
	shape.size = dimensions
	visual.mesh = shape
	visual.material_override = surface
	visual.position = local_position
	add_child(visual)


func _build_stock_mesh() -> void:
	# Geometria tapered: a coronha deixa de ser um bloco uniforme.
	# O node Stock original permanece na cena como fallback de editor.
	$Stock.visible = false
	var profiles: Array[Vector4] = [
		Vector4(-0.39, 0.055, -0.060, 0.046),
		Vector4(-0.23, 0.058, -0.075, 0.052),
		Vector4(-0.08, 0.061, -0.079, 0.050),
		Vector4(0.08, 0.073, -0.092, 0.060),
		Vector4(0.29, 0.098, -0.110, 0.076),
		Vector4(0.47, 0.104, -0.102, 0.089)
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for profile_index in range(profiles.size() - 1):
		var first: Vector4 = profiles[profile_index]
		var second: Vector4 = profiles[profile_index + 1]
		for face in range(4):
			var next_corner: int = (face + 1) % 4
			var a: Vector3 = _stock_corner(first, face)
			var b: Vector3 = _stock_corner(first, next_corner)
			var c: Vector3 = _stock_corner(second, next_corner)
			var d: Vector3 = _stock_corner(second, face)
			_stock_triangle(st, a, b, c)
			_stock_triangle(st, a, c, d)
	_stock_triangle(st, _stock_corner(profiles[0], 0), _stock_corner(profiles[0], 2), _stock_corner(profiles[0], 1))
	_stock_triangle(st, _stock_corner(profiles[0], 0), _stock_corner(profiles[0], 3), _stock_corner(profiles[0], 2))
	st.generate_normals()
	var sculpted_stock := MeshInstance3D.new()
	sculpted_stock.name = "SculptedStock"
	sculpted_stock.mesh = st.commit()
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.18, 0.085)
	wood.roughness = 0.88
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	sculpted_stock.material_override = wood
	add_child(sculpted_stock)

func _stock_corner(profile: Vector4, corner: int) -> Vector3:
	var half_width: float = profile.y
	var center_y: float = profile.z
	var half_height: float = profile.w
	var x: float = -half_width if corner == 0 or corner == 3 else half_width
	var y: float = center_y - half_height if corner == 0 or corner == 1 else center_y + half_height
	return Vector3(x, y, profile.x)

func _stock_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.set_uv(Vector2(0, 0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(1, 0))
	surface.add_vertex(b)
	surface.set_uv(Vector2(0.5, 1))
	surface.add_vertex(c)

func _equip_real_rifle(texture_size: int = 2) -> bool:
	var model_path: String = "res://assets/weapons/lee_enfield/lee_enfield_%dk.glb" % texture_size
	if not ResourceLoader.exists(model_path):
		return false

	var imported_scene: PackedScene = ResourceLoader.load(model_path) as PackedScene
	if imported_scene == null:
		push_warning("Lee-Enfield: modelo 3D invalido. Mantendo rifle anterior.")
		return false

	var replacement: Node3D = imported_scene.instantiate() as Node3D
	if replacement == null:
		push_warning("Lee-Enfield: o GLB nao tem raiz Node3D. Mantendo rifle anterior.")
		return false

	# O arquivo distribuido ja esta normalizado para cerca de 1,11 m.
	# Eixo da boca do cano: -Z, alinhado com a camera do FPS.
	# Nao escalar novamente, pois o glTF original tinha escala de exportacao 100x.
	if bolt_visual_rig != null:
		bolt_visual_rig.reset()
	replacement.name = "LeeEnfield3D"
	add_child(replacement)
	replacement.position = Vector3(0.0, 0.085, -0.55)
	if rifle_instance != null:
		rifle_instance.queue_free()
	rifle_instance = replacement
	active_texture_size = texture_size
	if bolt_visual_rig != null:
		bolt_visual_rig.bind_to(rifle_instance)

	# Oculta somente malhas antigas. Audio e muzzle flash continuam ativos.
	for child in get_children():
		if child is MeshInstance3D and child != muzzle_flash:
			(child as MeshInstance3D).visible = false

	muzzle_flash.position = Vector3(0.0, 0.085, -1.13)
	return true

# Troca 1K/2K sem interferir no controlador de dano e sem alterar o asset original.
func set_texture_quality(high_quality: bool) -> bool:
	var requested_size: int = 2 if high_quality else 1
	if rifle_instance != null and active_texture_size == requested_size:
		return true
	return _equip_real_rifle(requested_size)

# Feedback de ejeção de estojo e ciclo visual do ferrolho.
# O GLB não possui animações e seus nomes não indicam qual malha é o ferrolho:
# preservamos todas as 44 malhas para não mover uma peça errada.
func _create_cartridge_case() -> void:
	case_visual = MeshInstance3D.new()
	case_visual.name = "CartridgeEjection"
	var case_mesh: CylinderMesh = CylinderMesh.new()
	case_mesh.top_radius = 0.013
	case_mesh.bottom_radius = 0.013
	case_mesh.height = 0.065
	case_mesh.radial_segments = 8
	case_visual.mesh = case_mesh
	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = Color(0.64, 0.44, 0.12)
	brass.metallic = 0.52
	brass.roughness = 0.42
	case_visual.material_override = brass
	case_visual.visible = false
	add_child(case_visual)

func _update_cartridge_case(delta: float) -> void:
	if case_ejection_timer <= 0.0:
		case_visual.visible = false
		return
	case_ejection_timer = maxf(0.0, case_ejection_timer - delta)
	var progress: float = 1.0 - case_ejection_timer / CASE_EJECTION_DURATION
	case_visual.position = Vector3(0.13 + progress * 0.22, 0.13 + sin(progress * PI) * 0.16, -0.31 + progress * 0.13)
	case_visual.rotation.z = progress * PI * 2.0
	case_visual.visible = case_ejection_timer > 0.0
