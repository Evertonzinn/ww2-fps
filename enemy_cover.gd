extends RefCounted

# Tactical cover placement using actual scene collision objects. No NavMesh.
# Returns empty Dictionary when no cover satisfies the line-of-sight test.
const COVER_NAMES: PackedStringArray = PackedStringArray([
	"SandbagLeft", "SandbagRight",
	"SupplyCrateA", "SupplyCrateB",
	"BarrelLeft", "BarrelRight"
])
const MAX_TRAVEL: float = 13.0

static func find_cover(world: Node3D, enemy: CollisionObject3D,
		player: CollisionObject3D) -> Dictionary:
	var physics: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var player_point: Vector3 = player.global_position + Vector3.UP * 0.55
	var best: Dictionary = {}
	var best_score: float = INF
	var excluded: Array[RID] = [enemy.get_rid(), player.get_rid()]
	for child in enemy.get_children():
		if child is CollisionObject3D:
			excluded.append((child as CollisionObject3D).get_rid())
	for name in COVER_NAMES:
		var obstacle: StaticBody3D = world.get_node_or_null(String(name)) as StaticBody3D
		if obstacle == null:
			continue
		var collider: CollisionShape3D = obstacle.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collider == null or not collider.shape is BoxShape3D:
			continue
		var half: Vector3 = (collider.shape as BoxShape3D).size * 0.5
		var away: Vector3 = obstacle.global_position - player.global_position
		away.y = 0.0
		if away.length_squared() < 0.01:
			continue
		away = away.normalized()
		# Distance from box centre to its back edge along the away vector.
		var along_x: float = half.x / maxf(0.001, absf(away.x))
		var along_z: float = half.z / maxf(0.001, absf(away.z))
		var edge: float = minf(along_x, along_z)
		var location: Vector3 = obstacle.global_position + away * (edge + 0.65)
		location.y = 0.0
		var travel: float = enemy.global_position.distance_to(location)
		if travel > MAX_TRAVEL or travel < 0.7:
			continue
		# The crouched character is protected only if a real collider
		# intercepts the player's head-to-cover shot line.
		var shot_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			player_point, location + Vector3.UP * 0.84)
		shot_query.exclude = excluded
		var shield: Dictionary = physics.intersect_ray(shot_query)
		if shield.is_empty() or shield.get("collider") != obstacle:
			continue
		# A direct path is preferred, not a route through the solid prop.
		var path_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			enemy.global_position + Vector3.UP * 0.65,
			location + Vector3.UP * 0.65)
		path_query.exclude = excluded
		if not physics.intersect_ray(path_query).is_empty():
			continue
		var score: float = travel + location.distance_to(player.global_position) * 0.09
		if score < best_score:
			best_score = score
			best = {"point":location,"obstacle":obstacle.name}
	return best
