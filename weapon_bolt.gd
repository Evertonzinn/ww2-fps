extends RefCounted

# Mesh names come from the license-compatible Lee-Enfield GLB supplied by the user.
# Candidate parts on top of the action, measured in the actual model bounds.
# Do not affect the stock, barrel, firing logic or bullets.
const CANDIDATES = [
	"Cube009Low",
	"Cube010Low",
	"Circle001Low"
]
const BOLT_TRAVEL_METERS: float = 0.075

var model: Node3D
var parts: Array[MeshInstance3D] = []
var rest_positions: Array[Vector3] = []

func bind_to(model_root: Node3D) -> void:
	reset()
	model = model_root
	_collect_nodes(model)
	if parts.is_empty():
		push_warning("Lee-Enfield: bolt candidates not found. Viewmodel-only animation remains enabled.")
	else:
		print("Lee-Enfield: visual bolt cycle bound to %d candidate meshes." % parts.size())

func reset() -> void:
	for i in range(parts.size()):
		if is_instance_valid(parts[i]):
			parts[i].position = rest_positions[i]
	parts.clear()
	rest_positions.clear()
	model = null

func animate(progress: float) -> void:
	if model == null or not is_instance_valid(model):
		return

	var normalized_progress: float = clampf(progress, 0.0, 1.0)
	var travel: float = 0.0
	if normalized_progress >= 0.18 and normalized_progress < 0.53:
		travel = (normalized_progress - 0.18) / 0.35
	elif normalized_progress >= 0.53 and normalized_progress < 0.84:
		travel = 1.0 - (normalized_progress - 0.53) / 0.31
	travel = clampf(travel, 0.0, 1.0) * BOLT_TRAVEL_METERS

	# Translate in rifle world axis; imported glTF hierarchy contains 100x source nodes.
	# Convert meters back into each mesh's parent space, avoiding transform assumptions.
	var direction: Vector3 = model.global_transform.basis.z.normalized() * travel
	for i in range(parts.size()):
		var part: MeshInstance3D = parts[i]
		if not is_instance_valid(part):
			continue
		var parent_node: Node3D = part.get_parent() as Node3D
		if parent_node == null:
			continue
		part.position = rest_positions[i] + parent_node.global_transform.basis.inverse() * direction

func _collect_nodes(container: Node) -> void:
	for child in container.get_children():
		if child is MeshInstance3D and _is_bolt_candidate(String(child.name)):
			var mesh: MeshInstance3D = child as MeshInstance3D
			parts.append(mesh)
			rest_positions.append(mesh.position)
		_collect_nodes(child)

func _is_bolt_candidate(node_name: String) -> bool:
	var normalized: String = node_name.replace(".", "").replace("_", "").replace("-", "").to_lower()
	for candidate in CANDIDATES:
		if normalized.begins_with(candidate.to_lower()):
			return true
	return false
