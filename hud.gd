extends CanvasLayer

const FPS_REFRESH_SECONDS: float = 0.4
const HIT_DURATION: float = 0.16

@onready var fps_label: Label = $FpsLabel
@onready var hit_marker: Label = $HitMarker

var fps_refresh_timer: float = 0.0
var hit_timer: float = 0.0
var stance_readout: Label
var health_readout: Label
var damage_overlay: ColorRect
var damage_strength: float = 0.0
var death_panel: Control

func _ready() -> void:
	hit_marker.visible = false
	_make_player_hud()

func _process(delta: float) -> void:
	fps_refresh_timer -= delta
	if fps_refresh_timer <= 0.0:
		fps_refresh_timer = FPS_REFRESH_SECONDS
		var frames: int = Engine.get_frames_per_second()
		fps_label.text = "FPS: %d | %.1f ms" % [frames, 1000.0 / float(maxi(frames, 1))]

	damage_strength = maxf(0.0, damage_strength - delta * 1.65)
	damage_overlay.color = Color(0.75, 0.035, 0.025, damage_strength)
	if hit_timer > 0.0:
		hit_timer -= delta
		if hit_timer <= 0.0:
			hit_marker.visible = false

func show_hit_marker() -> void:
	hit_timer = HIT_DURATION
	hit_marker.visible = true

func _make_player_hud() -> void:
	health_readout = Label.new()
	health_readout.name = "HealthDisplay"
	health_readout.position = Vector2(12.0, 42.0)
	health_readout.text = "VIDA 100 / 100"
	health_readout.add_theme_font_size_override("font_size", 20)
	health_readout.add_theme_color_override("font_color", Color(0.95, 0.94, 0.85))
	add_child(health_readout)
	stance_readout = Label.new()
	stance_readout.name = "PlayerStance"
	stance_readout.position = Vector2(12.0, 70.0)
	stance_readout.add_theme_color_override("font_color", Color(0.78, 0.91, 0.79))
	stance_readout.add_theme_font_size_override("font_size", 15)
	stance_readout.text = "EM PE  |  SHIFT PARA CORRER"
	add_child(stance_readout)

	damage_overlay = ColorRect.new()
	damage_overlay.name = "DamageFlash"
	damage_overlay.color = Color(0.75, 0.035, 0.025, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_overlay)
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	death_panel = Control.new()
	death_panel.name = "DeathPanel"
	death_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(death_panel)
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.visible = false

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.025, 0.92)
	death_panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	death_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	var title: Label = Label.new()
	title.text = "VOCE MORREU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)
	var info: Label = Label.new()
	info.text = "Pressione Enter ou clique para reiniciar"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(info)
	var button: Button = Button.new()
	button.text = "REINICIAR PARTIDA"
	button.custom_minimum_size = Vector2(310, 52)
	button.pressed.connect(_restart_game)
	column.add_child(button)

func _restart_game() -> void:
	get_tree().reload_current_scene()

func show_player_health(current_health: int, maximum: int) -> void:
	health_readout.text = "VIDA %d / %d" % [current_health, maximum]
	var ratio: float = float(current_health) / float(maxi(maximum, 1))
	health_readout.add_theme_color_override("font_color",
		Color(1.0, 0.34, 0.30) if ratio <= 0.25 else Color(0.95, 0.94, 0.85))

func show_player_damage(amount: int) -> void:
	if amount > 0:
		damage_strength = minf(0.35, damage_strength + 0.14)

func show_player_death() -> void:
	death_panel.visible = true
	damage_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_player_stance(posture: String, movement_note: String) -> void:
	if stance_readout != null:
		stance_readout.text = posture + "  |  " + movement_note
