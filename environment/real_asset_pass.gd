extends RefCounted

# Optional licensed glTF visual adapter. The physical bodies, hitboxes,
# tactical cover and rifle sockets remain unchanged. If import or geometry
# validation fails, do not hide the existing proven placeholder meshes.
const ASSET_ROOT: String = "res://assets/remaster_imported/"

static func populate(world: Node3D) -> void:
	var houses: int = 0
	houses += int(_replace_visual(world.get_node_or_null("LeftHouseA") as Node3D,
		"environment/french_house", Vector3(5.50, 4.65, 5.70), -2.35))
	houses += int(_replace_visual(world.get_node_or_null("RightHouseA") as Node3D,
		"environment/stone_house", Vector3(5.50, 4.65, 5.70), -2.35))
	# Two other houses remain unique until more historical façades are installed.
	var trees: int = 0
	trees += int(_replace_visual(world.get_node_or_null("TreeWest") as Node3D,
		"environment/beech_tree", Vector3(4.0, 6.5, 4.0), 0.0))
	trees += int(_replace_visual(world.get_node_or_null("TreeEast") as Node3D,
		"environment/realistic_tree", Vector3(4.0, 6.5, 4.0), 0.0))
	print("WW2 REAL ASSETS: houses=%d trees=%d (fallbacks preserved)" % [houses, trees])

static func _replace_visual(existing: Node3D, relative: String, dimensions: Vector3,
		base_y: float) -> bool:
	if existing == null or existing.has_node("WW2RealVisual"):
		return false
	var packed: PackedScene = _get_model(relative)
	if packed == null:
		return false
	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		return false
	var holder: Node3D = Node3D.new()
	holder.name = "WW2RealVisual"
	existing.add_child(holder)
	holder.add_child(instance)
	var bounds: AABB = _mesh_bounds(holder)
	if bounds.size.x < 0.01 or bounds.size.y < 0.01 or bounds.size.z < 0.01:
		holder.queue_free()
		push_warning("WW2 real asset rejected; empty visual bounds: " + relative)
		return false
	var scale: float = minf(
		dimensions.x / bounds.size.x,
		minf(dimensions.y / bounds.size.y, dimensions.z / bounds.size.z))
	if not is_finite(scale) or scale <= 0.000001 or scale > 10000.0:
		holder.queue_free()
		push_warning("WW2 real asset rejected; invalid source scale: " + relative)
		return false
	# Normalize source FBX/glTF coordinates while keeping the authored
	# StaticBody3D collider at precisely its original transform.
	holder.scale = Vector3.ONE * scale
	var center: Vector3 = bounds.get_center()
	holder.position = Vector3(-center.x * scale,
		base_y - bounds.position.y * scale, -center.z * scale)
	# Hide only the direct old procedural meshes once replacement is valid.
	# Do not hide collision shapes, sockets or other scene dependencies.
	for child in existing.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	return true

static func install_enemy_rifle(gun: Node3D) -> bool:
	if gun == null or gun.has_node("WW2RealGun"):
		return false
	var packed: PackedScene = _get_model("weapons/kar98k")
	if packed == null:
		return false
	var model: Node3D = packed.instantiate() as Node3D
	if model == null:
		return false
	var mount: Node3D = Node3D.new()
	mount.name = "WW2RealGun"
	gun.add_child(mount)
	mount.add_child(model)
	var bounds: AABB = _mesh_bounds(mount)
	var major: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if major < 0.01:
		mount.queue_free()
		return false
	# Rotate the model's longest dimension along the weapon's -Z axis.
	# Source-facing direction can still need an artist-calibrated adjustment.
	if bounds.size.y >= bounds.size.x and bounds.size.y >= bounds.size.z:
		mount.rotation.x = -PI * 0.5
	elif bounds.size.x >= bounds.size.y and bounds.size.x >= bounds.size.z:
		mount.rotation.y = PI * 0.5
	# Fit the real rifle to the existing one-metre weapon socket.
	var scale: float = 1.05 / major
	if not is_finite(scale) or scale <= 0.000001 or scale > 10000.0:
		mount.queue_free()
		return false
	model.scale = Vector3.ONE * scale
	# Keep rifle centered near the existing firing and support grip markers.
	var center: Vector3 = bounds.get_center()
	model.position = -center * scale
	# The pivot remains attached to EnemyCombat's animated rifle mount.
	for child in gun.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	return true

static func _get_model(relative: String) -> PackedScene:
	var path: String = ASSET_ROOT + relative + "/scene.gltf"
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as PackedScene

static func _mesh_bounds(root: Node3D) -> AABB:
	var have: bool = false
	var bounds: AABB = AABB()
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = item as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var box: AABB = mesh.get_aabb()
		for corner in range(8):
			var position: Vector3 = root.to_local(mesh.to_global(box.get_endpoint(corner)))
			if not position.is_finite():
				continue
			if not have:
				bounds = AABB(position, Vector3.ZERO)
				have = true
			else:
				bounds = bounds.expand(position)
	return bounds
