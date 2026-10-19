extends CanvasLayer

const FPS_REFRESH_SECONDS: float = 0.4
const HIT_DURATION: float = 0.16

@onready var fps_label: Label = $FpsLabel
@onready var hit_marker: Label = $HitMarker

var fps_refresh_timer: float = 0.0
var hit_timer: float = 0.0

func _ready() -> void:
	hit_marker.visible = false

func _process(delta: float) -> void:
	fps_refresh_timer -= delta
	if fps_refresh_timer <= 0.0:
		fps_refresh_timer = FPS_REFRESH_SECONDS
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if hit_timer > 0.0:
		hit_timer -= delta
		if hit_timer <= 0.0:
			hit_marker.visible = false

func show_hit_marker() -> void:
	hit_timer = HIT_DURATION
	hit_marker.visible = true
