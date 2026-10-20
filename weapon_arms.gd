class_name FirstPersonArms
extends Node3D

# Low-poly visual placeholders for a first-person shooter, Godot Compatibility.
# Attached to Weapon, so existing ADS, sway and recoil drive all parts together.
# No armature or licensed asset modifications; this can later be replaced by a rigged GLB.

const RIGHT_ELBOW: Vector3 = Vector3(0.32, -0.48, 0.58)
const RIGHT_GRIP: Vector3 = Vector3(0.115, -0.155, 0.19)
const LEFT_ELBOW: Vector3 = Vector3(-0.32, -0.46, 0.14)
const LEFT_SUPPORT: Vector3 = Vector3(-0.082, -0.132, -0.73)
const LEFT_BOLT: Vector3 = Vector3(-0.092, 0.045, -0.47)
const LEFT_CHARGER_OFFSET: Vector3 = Vector3(-0.062, 0.069, 0.014)
const HAND_SPEED: float = 13.0

var right_hand: Node3D
var left_hand: Node3D
var right_sleeve: MeshInstance3D
var left_sleeve: MeshInstance3D

func _ready() -> void:
	var fabric: StandardMaterial3D = StandardMaterial3D.new()
	fabric.albedo_color = Color(0.32, 0.35, 0.23)
	fabric.roughness = 0.96
	var cuff: StandardMaterial3D = StandardMaterial3D.new()
	cuff.albedo_color = Color(0.25, 0.26, 0.19)
	cuff.roughness = 0.95
	var leather: StandardMaterial3D = StandardMaterial3D.new()
	leather.albedo_color = Color(0.39, 0.30, 0.22)
	leather.roughness = 0.89

	right_sleeve = _make_sleeve("RightSleeve", fabric)
	left_sleeve = _make_sleeve("LeftSleeve", fabric)

	right_hand = _make_gloved_hand("RightHand", leather, cuff)
	right_hand.position = RIGHT_GRIP
	right_hand.rotation.z = -0.20

	left_hand = _make_gloved_hand("LeftHand", leather, cuff)
	left_hand.position = LEFT_SUPPORT
	left_hand.rotation.z = 0.12

	_align_sleeve(right_sleeve, RIGHT_ELBOW, RIGHT_GRIP)
	_align_sleeve(left_sleeve, LEFT_ELBOW, LEFT_SUPPORT)

func update_pose(in_reload: bool, phase: int, charger_position: Vector3, delta: float) -> void:
	if left_hand == null:
		return
	var target: Vector3 = LEFT_SUPPORT
	var roll: float = 0.12
	if in_reload:
		match phase:
			1:
				# Reach for bolt while action opens.
				target = LEFT_BOLT
				roll = -0.20
			2:
				# Hand accompanies the charger, including downward pressure.
				target = charger_position + LEFT_CHARGER_OFFSET
				roll = -0.32
			3:
				# Stay at the action while the bolt is closing.
				target = LEFT_BOLT
				roll = -0.18
	left_hand.position = left_hand.position.lerp(target, minf(1.0, delta * HAND_SPEED))
	left_hand.rotation.z = lerpf(left_hand.rotation.z, roll, minf(1.0, delta * 11.0))
	_align_sleeve(left_sleeve, LEFT_ELBOW, left_hand.position)

func _make_sleeve(node_name: String, cloth: Material) -> MeshInstance3D:
	var sleeve: MeshInstance3D = MeshInstance3D.new()
	sleeve.name = node_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.043
	mesh.bottom_radius = 0.062
	mesh.height = 1.0
	mesh.radial_segments = 10
	sleeve.mesh = mesh
	sleeve.material_override = cloth
	add_child(sleeve)
	return sleeve

func _make_gloved_hand(node_name: String, glove: Material, cuff: Material) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = node_name
	add_child(root)

	var palm: SphereMesh = SphereMesh.new()
	palm.radius = 0.043
	palm.height = 0.086
	palm.radial_segments = 12
	palm.rings = 6
	var palm_visual: MeshInstance3D = MeshInstance3D.new()
	palm_visual.name = "GlovedPalm"
	palm_visual.mesh = palm
	palm_visual.material_override = glove
	palm_visual.scale = Vector3(1.16, 0.84, 1.15)
	root.add_child(palm_visual)

	var wrist: CylinderMesh = CylinderMesh.new()
	wrist.top_radius = 0.041
	wrist.bottom_radius = 0.048
	wrist.height = 0.065
	wrist.radial_segments = 10
	var cuff_visual: MeshInstance3D = MeshInstance3D.new()
	cuff_visual.name = "Cuff"
	cuff_visual.mesh = wrist
	cuff_visual.material_override = cuff
	cuff_visual.position = Vector3(0.0, -0.057, 0.015)
	root.add_child(cuff_visual)

	# Four distinct digits provide a readable grip without heavy skinned meshes.
	var finger_shape: CapsuleMesh = CapsuleMesh.new()
	finger_shape.radius = 0.010
	finger_shape.height = 0.062
	finger_shape.radial_segments = 8
	finger_shape.rings = 3
	for i in range(4):
		var finger: MeshInstance3D = MeshInstance3D.new()
		finger.name = "Finger%d" % i
		finger.mesh = finger_shape
		finger.material_override = glove
		finger.position = Vector3(-0.028 + float(i) * 0.019, -0.015, -0.050)
		finger.rotation.x = PI * 0.42
		root.add_child(finger)

	var thumb_shape: CapsuleMesh = CapsuleMesh.new()
	thumb_shape.radius = 0.015
	thumb_shape.height = 0.070
	thumb_shape.radial_segments = 8
	thumb_shape.rings = 3
	var thumb: MeshInstance3D = MeshInstance3D.new()
	thumb.name = "Thumb"
	thumb.mesh = thumb_shape
	thumb.material_override = glove
	thumb.position = Vector3(0.051, -0.008, 0.003)
	thumb.rotation.z = -0.90
	root.add_child(thumb)
	return root

func _align_sleeve(sleeve: MeshInstance3D, elbow: Vector3, wrist: Vector3) -> void:
	var direction: Vector3 = wrist - elbow
	var length: float = direction.length()
	if length <= 0.001:
		return
	sleeve.position = (elbow + wrist) * 0.5
	sleeve.quaternion = Quaternion(Vector3.UP, direction / length)
	sleeve.scale = Vector3(1.0, length, 1.0)
