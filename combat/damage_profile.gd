extends RefCounted

# Damage policy is shared by all hit zones. Keep enemy health authoritative.
# Default enemy has 100 HP; unarmoured chest is lethal to sniper rounds.
# Lee-Enfield damage is unchanged and remains on each authored hit zone.
static func sniper_damage(region: String) -> int:
	match region:
		"Cabeca":
			return 150
		"Torax":
			return 120
		"Abdomen":
			return 82
		"Braco":
			return 35
		"Perna":
			return 48
		_:
			return 90
