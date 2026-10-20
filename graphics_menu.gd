class_name GraphicsSettingsMenu
extends CanvasLayer

# As resolucoes representam dimensoes reais da janela em modo janela.
# Tela cheia usa a resolucao nativa do monitor (nao faz upscale magico para 4K).
const SETTINGS_FILE: String = "user://ww2_graphics.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var is_open: bool = false
var overlay: ColorRect
var resolution_option: OptionButton
var mode_option: OptionButton
var quality_option: OptionButton
var texture_option: OptionButton
var vsync_toggle: CheckBox
var status_label: Label
var chosen_resolution: int = 0
var chosen_mode: int = 0
var chosen_quality: int = 0
var chosen_texture: int = 0
var chosen_vsync: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_menu()
	_load_settings()
	_sync_controls()
	overlay.visible = false
	# Adiar ate os scripts do mundo e da arma finalizarem seus _ready.
	call_deferred("_apply_settings")

func open_menu() -> void:
	if is_open:
		return
	is_open = true
	overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func close_menu() -> void:
	if not is_open:
		return
	overlay.visible = false
	is_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()

func _create_menu() -> void:
	overlay = ColorRect.new()
	overlay.name = "DarkOverlay"
	overlay.color = Color(0.035, 0.045, 0.055, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 24)
	padding.add_theme_constant_override("margin_right", 24)
	padding.add_theme_constant_override("margin_top", 20)
	padding.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(padding)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	padding.add_child(column)

	var title := Label.new()
	title.text = "WW2 FPS — Configuracoes graficas"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	resolution_option = _option_row(column, "Resolucao", [
		"Atual (nao alterar)", "1280 x 720", "1920 x 1080",
		"2560 x 1440 (QHD)", "3840 x 2160 (4K)"
	])
	mode_option = _option_row(column, "Janela", ["Janela", "Tela cheia (nativa)"])
	quality_option = _option_row(column, "Graficos", ["Eco", "Equilibrado", "Alto", "Ultra"])
	texture_option = _option_row(column, "Textura do rifle", ["1K (economia de VRAM)", "2K (mais detalhes)"])
	vsync_toggle = CheckBox.new()
	vsync_toggle.text = "Sincronizacao vertical (V-Sync)"
	column.add_child(vsync_toggle)

	var info := Label.new()
	info.text = "4K depende do monitor e da GPU. Textura 2K nao torna o jogo 4K."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)

	var apply_button := Button.new()
	apply_button.text = "Aplicar e salvar"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_save_and_apply)
	row.add_child(apply_button)

	var resume_button := Button.new()
	resume_button.text = "Voltar ao jogo"
	resume_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_button.pressed.connect(close_menu)
	row.add_child(resume_button)

func _option_row(column: VBoxContainer, caption: String, options: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(caption_label)
	var select := OptionButton.new()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label_text in options:
		select.add_item(label_text)
	row.add_child(select)
	return select

func _sync_controls() -> void:
	resolution_option.select(chosen_resolution)
	mode_option.select(chosen_mode)
	quality_option.select(chosen_quality)
	texture_option.select(chosen_texture)
	vsync_toggle.button_pressed = chosen_vsync

func _save_and_apply() -> void:
	chosen_resolution = resolution_option.selected
	chosen_mode = mode_option.selected
	chosen_quality = quality_option.selected
	chosen_texture = texture_option.selected
	chosen_vsync = vsync_toggle.button_pressed
	_apply_settings()
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "resolution", chosen_resolution)
	cfg.set_value("graphics", "mode", chosen_mode)
	cfg.set_value("graphics", "quality", chosen_quality)
	cfg.set_value("graphics", "texture", chosen_texture)
	cfg.set_value("graphics", "vsync", chosen_vsync)
	var result: Error = cfg.save(SETTINGS_FILE)
	if result != OK:
		status_label.text += " | Nao foi possivel salvar configuracoes."

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	chosen_resolution = clampi(int(cfg.get_value("graphics", "resolution", 0)), 0, RESOLUTIONS.size() - 1)
	chosen_mode = clampi(int(cfg.get_value("graphics", "mode", 0)), 0, 1)
	chosen_quality = clampi(int(cfg.get_value("graphics", "quality", 0)), 0, 3)
	chosen_texture = clampi(int(cfg.get_value("graphics", "texture", 0)), 0, 1)
	chosen_vsync = bool(cfg.get_value("graphics", "vsync", true))

func _apply_settings() -> void:
	if chosen_mode == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var wanted_size: Vector2i = RESOLUTIONS[chosen_resolution]
		if wanted_size != Vector2i.ZERO:
			var monitor_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
			if wanted_size.x <= monitor_size.x and wanted_size.y <= monitor_size.y:
				DisplayServer.window_set_size(wanted_size)
				status_label.text = "Resolucao aplicada."
			else:
				status_label.text = "Resolucao maior que o monitor. Tamanho atual preservado."
		else:
			status_label.text = "Resolucao atual preservada."
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		status_label.text = "Tela cheia na resolucao nativa do monitor."

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if chosen_vsync else DisplayServer.VSYNC_DISABLED)

	var viewport: Viewport = get_tree().root
	match chosen_quality:
		0, 1:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		2:
			viewport.msaa_3d = Viewport.MSAA_2X
		3:
			viewport.msaa_3d = Viewport.MSAA_4X

	var sun: DirectionalLight3D = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = chosen_quality >= 2

	var weapon: WeaponController = get_parent().get_node_or_null("Player/Head/Camera3D/Weapon") as WeaponController
	if weapon != null:
		var use_2k: bool = chosen_texture == 1
		if not weapon.set_texture_quality(use_2k):
			status_label.text += " | Asset da qualidade escolhida nao encontrado."
