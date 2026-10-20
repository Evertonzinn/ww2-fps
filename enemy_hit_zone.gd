extends StaticBody3D

# Existing weapons raycast StaticBody3D and call take_damage(1).
@export var region: String = "Torax"
@export_range(1, 200, 1) var damage_per_hit: int = 40

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	var enemy: Node = get_parent()
	if enemy != null and enemy.has_method("receive_zone_damage"):
		enemy.call("receive_zone_damage", amount * damage_per_hit, region)
