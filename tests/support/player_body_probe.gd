extends RefCounted

# Diagnostic only. No gameplay imports this script, and no asset is rewritten.
# Godot Skeleton3D uploads global_pose * inverse_bind for each Skin bind.
# MeshInstance3D applies that palette in mesh-local space before its world transform.
# CPU prediction is NOT proof of rasterization, occlusion or shader deformation.
static func geometry(piece: MeshInstance3D, camera: Camera3D, frame: Node3D) -> Dictionary:
	var result: Dictionary = {"path": str(piece.get_path()), "errors": [], "points": PackedVector3Array()}
	var errors: Array = result["errors"]
	result["local_transform"] = str(piece.transform)
	result["world_transform"] = str(piece.global_transform)
	result["static_aabb"] = str(piece.get_aabb())
	result["visible_in_tree"] = piece.is_visible_in_tree()
	result["layers"] = piece.layers
	result["camera_mask"] = camera.cull_mask
	result["skeleton_path"] = str(piece.skeleton)
	result["transparency"] = piece.transparency
	result["visibility_range"] = [piece.visibility_range_begin, piece.visibility_range_end]
	result["custom_aabb"] = str(piece.custom_aabb)
	result["extra_cull_margin"] = piece.extra_cull_margin
	if piece.mesh == null:
		errors.append("mesh missing")
		return result
	var skeleton: Skeleton3D = piece.get_node_or_null(piece.skeleton) as Skeleton3D
	var reference: SkinReference = piece.get_skin_reference()
	var skin: Skin = piece.skin
	if reference != null:
		skin = reference.get_skin()
	if skeleton == null or skin == null or reference == null:
		errors.append("unresolved Skeleton3D, Skin or registered SkinReference")
		return result
	result["resolved_skeleton"] = str(skeleton.get_path())
	result["skeleton_world"] = str(skeleton.global_transform)
	result["show_rest_only"] = skeleton.show_rest_only
	result["binds"] = []
	var palette: Array[Transform3D] = []
	for bind_index in range(skin.get_bind_count()):
		var bind_name: StringName = skin.get_bind_name(bind_index)
		var bone_index: int = skeleton.find_bone(bind_name) if not bind_name.is_empty() else skin.get_bind_bone(bind_index)
		if bone_index < 0 or bone_index >= skeleton.get_bone_count():
			errors.append("invalid bind %d: %s / %d" % [bind_index, bind_name, bone_index])
			return result
		var bind_pose: Transform3D = skin.get_bind_pose(bind_index)
		var pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
		if skeleton.show_rest_only:
			pose = skeleton.get_bone_global_rest(bone_index)
		palette.append(pose * bind_pose)
		result["binds"].append({"slot": bind_index, "bone": bone_index,
			"name": str(skeleton.get_bone_name(bone_index)), "inverse_bind": str(bind_pose),
			"rest": str(skeleton.get_bone_global_rest(bone_index)), "pose": str(pose)})
	if palette.is_empty():
		errors.append("empty bind palette")
		return result
	for blend in range(piece.get_blend_shape_count()):
		if absf(piece.get_blend_shape_value(blend)) > 0.00001:
			errors.append("active blendshape: CPU prediction unsupported")
	var points: PackedVector3Array = PackedVector3Array()
	var low: Vector3 = Vector3(INF, INF, INF)
	var high: Vector3 = Vector3(-INF, -INF, -INF)
	var in_frustum: int = 0
	var left_in: int = 0
	var right_in: int = 0
	var screen_min: Vector2 = Vector2(INF, INF)
	var screen_max: Vector2 = Vector2(-INF, -INF)
	var near_clipped: int = 0
	var surfaces: Array = []
	for surface in range(piece.mesh.get_surface_count()):
		var arrays: Array = piece.mesh.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
			errors.append("surface %d lacks vertices/skin arrays" % surface)
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = 8 if (piece.mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
		if joints.size() != vertices.size() * influences or weights.size() != joints.size():
			errors.append("surface %d malformed skin arrays" % surface)
			continue
		var material: Material = piece.get_active_material(surface)
		var material_info: Dictionary = {"surface": surface, "vertices": vertices.size(), "influences": influences}
		if material != null:
			material_info["class"] = material.get_class()
			material_info["resource"] = material.resource_path
			if material is BaseMaterial3D:
				material_info["albedo"] = str(material.albedo_color)
				material_info["cull_mode"] = material.cull_mode
				material_info["transparency"] = material.transparency
			elif material is ShaderMaterial:
				errors.append("custom shader: vertex displacement not covered")
		surfaces.append(material_info)
		for vertex_index in range(vertices.size()):
			var source: Vector3 = vertices[vertex_index]
			var deformed: Vector3 = Vector3.ZERO
			var weight_sum: float = 0.0
			for influence in range(influences):
				var offset: int = vertex_index * influences + influence
				var weight: float = weights[offset]
				if not is_finite(weight) or weight < 0.0:
					errors.append("invalid skin weight")
					return result
				if weight == 0.0:
					continue
				var slot: int = joints[offset]
				if slot < 0 or slot >= palette.size():
					errors.append("vertex references invalid bind slot")
					return result
				deformed += (palette[slot] * source) * weight
				weight_sum += weight
			if absf(weight_sum - 1.0) > 0.01:
				errors.append("weights do not sum to 1: %.6f" % weight_sum)
				return result
			var world_point: Vector3 = piece.to_global(deformed)
			if not world_point.is_finite():
				errors.append("non-finite deformed vertex")
				return result
			points.append(world_point)
			var local_point: Vector3 = frame.to_local(world_point)
			low = low.min(local_point)
			high = high.max(local_point)
			if -camera.to_local(world_point).z < camera.near:
				near_clipped += 1
			if camera.is_position_in_frustum(world_point):
				in_frustum += 1
				if local_point.x < 0.0:
					left_in += 1
				else:
					right_in += 1
				var screen: Vector2 = camera.unproject_position(world_point)
				screen_min = screen_min.min(screen)
				screen_max = screen_max.max(screen)
	result["surfaces"] = surfaces
	result["points"] = points
	result["vertices"] = points.size()
	result["in_frustum"] = in_frustum
	result["left_in_frustum"] = left_in
	result["right_in_frustum"] = right_in
	result["near_clipped"] = near_clipped
	if not points.is_empty():
		result["bounds"] = AABB(low, high - low)
		result["bounds_in_player"] = str(result["bounds"])
	if in_frustum > 0:
		var view_size: Vector2 = camera.get_viewport().get_visible_rect().size
		result["screen_min"] = str(screen_min / view_size)
		result["screen_max"] = str(screen_max / view_size)
		result["screen_area_ratio"] = ((screen_max.x - screen_min.x) * (screen_max.y - screen_min.y)) / (view_size.x * view_size.y)
	return result

static func hierarchy(node: Node) -> Array:
	var rows: Array = []
	if node is Node3D:
		rows.append({"path": str(node.get_path()), "type": node.get_class(),
			"local": str(node.transform), "world": str(node.global_transform),
			"visible": node.is_visible_in_tree()})
	for child in node.get_children():
		rows.append_array(hierarchy(child))
	return rows

static func serializable(measurement: Dictionary) -> Dictionary:
	var result: Dictionary = measurement.duplicate()
	result.erase("points")
	result.erase("bounds")
	return result

static func forward_hits(piece: MeshInstance3D, points: PackedVector3Array, camera: Camera3D) -> int:
	# Uses deformed triangles, not an AABB. Does not test material alpha/backface culling.
	var hits: int = 0
	var base: int = 0
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_basis.z.normalized()
	for surface in range(piece.mesh.get_surface_count()):
		var arrays: Array = piece.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if piece.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			base += vertices.size()
			continue
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for vertex in range(vertices.size()):
				indices.append(vertex)
		for index in range(0, indices.size() - 2, 3):
			var a: int = base + indices[index]
			var b: int = base + indices[index + 1]
			var c: int = base + indices[index + 2]
			if mini(a, mini(b, c)) < 0 or maxi(a, maxi(b, c)) >= points.size():
				continue
			var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, points[a], points[b], points[c])
			if hit is Vector3:
				var depth: float = -camera.to_local(hit).z
				if depth >= camera.near and depth <= camera.far:
					hits += 1
		base += vertices.size()
	return hits
