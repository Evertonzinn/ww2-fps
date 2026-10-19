extends RefCounted

# Independent bolt mechanism prototype, not a modification of the licensed GLB.
# Source asset has no animation, skeleton or semantically named bolt group.
const COVER_NAMES = ["Cube008Low", "Cube009Low", "Cube010Low", "Circle001Low"]
const LOCATION = Vector3(-0.011, 0.082, -0.079)
const TRAVEL: float = 0.086
const LIFT_RAD: float = 0.93

var model: Node3D
var covered: Array[MeshInstance3D] = []
var prior_visibility: Array[bool] = []
var assembly: Node3D
var slider: Node3D
var rotator: Node3D

func bind_to(root: Node3D) -> void:
	reset()
	model = root
	_collect(root)
	if covered.size() != COVER_NAMES.size():
		push_warning("Lee-Enfield: visual bolt needs all four covers (found %d). Fallback active." % covered.size())
		covered.clear()
		model = null
		return
	var parent_weapon := root.get_parent() as Node3D
	if parent_weapon == null:
		covered.clear()
		model = null
		return
	for part in covered:
		prior_visibility.append(part.visible)
		part.visible = false
	assembly = Node3D.new()
	assembly.name = "BoltAssemblyVisual"
	parent_weapon.add_child(assembly)
	assembly.position = root.position + LOCATION

	slider = Node3D.new()
	slider.name = "BoltSlide"
	assembly.add_child(slider)
	rotator = Node3D.new()
	rotator.name = "BoltLockRotation"
	slider.add_child(rotator)

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.23, 0.24, 0.24)
	steel.metallic = 0.62
	steel.roughness = 0.45
	_cylinder("BoltBody", Vector3(0, 0, -0.015), 0.011, 0.142, Vector3(PI * 0.5, 0, 0), steel)
	_cylinder("RearCollar", Vector3(0, 0, 0.054), 0.014, 0.020, Vector3(PI * 0.5, 0, 0), steel)
	_cylinder("HandleStem", Vector3(0.028, -0.001, 0.044), 0.006, 0.056, Vector3(0, 0, PI * 0.5), steel)
	_cylinder("HandleBend", Vector3(0.052, -0.012, 0.044), 0.006, 0.028, Vector3(0, 0, -0.25), steel)
	var knob := MeshInstance3D.new()
	knob.name = "BoltKnob"
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024
	sphere.radial_segments = 12
	sphere.rings = 6
	knob.mesh = sphere
	knob.material_override = steel
	knob.position = Vector3(0.061, -0.021, 0.044)
	rotator.add_child(knob)
	animate(1.0)
	print("Lee-Enfield: BoltAssemblyVisual: bolt body, handle and knob created.")

func reset() -> void:
	for i in range(covered.size()):
		if i < prior_visibility.size() and is_instance_valid(covered[i]):
			covered[i].visible = prior_visibility[i]
	covered.clear()
	prior_visibility.clear()
	if assembly != null and is_instance_valid(assembly):
		assembly.queue_free()
	assembly = null
	slider = null
	rotator = null
	model = null

func animate(progress: float) -> void:
	if slider == null or rotator == null or not is_instance_valid(slider):
		return
	var p: float = clampf(progress, 0.0, 1.0)
	var lift: float = 0.0
	var pull: float = 0.0
	# Unlock / extract / feed / lock
	if p < 0.21:
		lift = _ease(p / 0.21)
	elif p < 0.51:
		lift = 1.0
		pull = _ease((p - 0.21) / 0.30)
	elif p < 0.80:
		lift = 1.0
		pull = 1.0 - _ease((p - 0.51) / 0.29)
	else:
		lift = 1.0 - _ease((p - 0.80) / 0.20)
	slider.position.z = pull * TRAVEL
	rotator.rotation.z = lift * LIFT_RAD

func _ease(t: float) -> float:
	var v: float = clampf(t, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)

func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and _matches(String(child.name)):
			covered.append(child as MeshInstance3D)
		_collect(child)

func _matches(name: String) -> bool:
	var normalized: String = name.replace(".", "").replace("_", "").replace("-", "").to_lower()
	for expected in COVER_NAMES:
		if normalized.begins_with(expected.to_lower()):
			return true
	return false

func _cylinder(name: String, location: Vector3, radius: float, length: float, angles: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = location
	visual.rotation = angles
	rotator.add_child(visual)
