extends StaticBody3D

@export_range(1, 20, 1) var hit_points: int = 3

@onready var mesh: MeshInstance3D = $MeshInstance3D

func take_damage(amount: int) -> void:
	hit_points = maxi(0, hit_points - amount)
	if hit_points == 0:
		queue_free()
		return

	if mesh.material_override is StandardMaterial3D:
		var material_copy := mesh.material_override.duplicate() as StandardMaterial3D
		material_copy.albedo_color = Color(1.0, 0.70, 0.10) if hit_points == 1 else Color(1.0, 0.35, 0.10)
		mesh.material_override = material_copy
