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

# Dedicated sniper damage path. Ordinary Lee-Enfield hits still call
# take_damage(1) and preserve their established regional damage.
# A scoped rifle round through an unarmoured torso is lethal with
# 100HP; limb hits remain survivable. No generic damage multiplier.
func take_sniper_damage() -> void:
	var damage: int = 0
	match region:
		"Cabeca":
			damage = 150
		"Torax":
			damage = 120
		"Abdomen":
			damage = 82
		"Braco":
			damage = 35
		"Perna":
			damage = 48
		_:
			damage = 90
	var enemy: Node = get_parent()
	if enemy != null and enemy.has_method("receive_zone_damage"):
		enemy.call("receive_zone_damage", damage, region)
