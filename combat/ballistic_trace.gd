extends RefCounted

# Deterministic exterior ballistics: one ray per short trajectory segment.
# No per-frame projectile Node, network dependency or physics body allocation.
# The muzzle axis is the camera's -Z; the bullet drops under gravity.
const SEGMENT_LENGTH_M: float = 4.0

static func point_at(origin: Vector3, direction: Vector3, distance_m: float,
		muzzle_speed_mps: float, gravity_mps2: float) -> Vector3:
	if muzzle_speed_mps <= 0.0:
		return origin
	var seconds: float = distance_m / muzzle_speed_mps
	return origin + direction.normalized() * distance_m + (
		Vector3.DOWN * (0.5 * maxf(0.0, gravity_mps2) * seconds * seconds))

static func trace(space: PhysicsDirectSpaceState3D, origin: Vector3,
		direction: Vector3, max_range_m: float, muzzle_speed_mps: float,
		gravity_mps2: float, excluded: Array[RID]) -> Dictionary:
	if space == null or direction.length_squared() < 0.000001 or (
			max_range_m <= 0.0 or muzzle_speed_mps <= 0.0):
		return {}
	var path: Vector3 = direction.normalized()
	var segments: int = maxi(1, ceili(max_range_m / SEGMENT_LENGTH_M))
	var previous: Vector3 = origin
	for i in range(1, segments + 1):
		var distance_m: float = minf(max_range_m, float(i) * SEGMENT_LENGTH_M)
		var next_point: Vector3 = point_at(
			origin, path, distance_m, muzzle_speed_mps, gravity_mps2)
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			previous, next_point)
		ray.exclude = excluded
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty():
			hit["distance_m"] = distance_m
			return hit
		previous = next_point
	return {}
