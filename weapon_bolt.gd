extends RefCounted

# Receptora: agrupamento EXPERIMENTAL para o GLB de Talamander.
# Inspecao de bounding boxes no GLB 2K: Cube.008, Cube.009, Cube.010
# e Circle.001 proximas ao topo da acao. Os nomes ainda nao certificam
# uma divisao mecanicamente exata. Caso falte uma malha, nao animar parcialmente.
const PART_NAMES = [
	"Cube008Low",
	"Cube009Low",
	"Cube010Low",
	"Circle001Low"
]

const PIVOT: Vector3 = Vector3(-0.011, 0.076, -0.055)
const BOLT_TRAVEL: float = 0.084
const OPEN_ANGLE_RAD: float = 0.65

var model: Node3D
var parts: Array[MeshInstance3D] = []
var at_rest: Array[Transform3D] = []
var valid: bool = false

func bind_to(model_root: Node3D) -> void:
	reset()
	model = model_root
	_collect(model_root)
	if parts.size() != PART_NAMES.size():
		push_warning("Lee-Enfield: encontradas %d/%d malhas candidatas. Ferrolho 3D desativado; feedback do viewmodel mantido." % [parts.size(), PART_NAMES.size()])
		reset()
		return

	# Os transforms sao relativos a raiz do modelo: acompanham a camera
	# em movimento e nao dependem do scale nos intermediarios glTF.
	for part in parts:
		at_rest.append(model.global_transform.affine_inverse() * part.global_transform)
	valid = true
	print("Lee-Enfield: ciclo experimental do ferrolho ativo; %d partes: " % parts.size(), PART_NAMES)

func reset() -> void:
	if valid and model != null and is_instance_valid(model):
		for i in range(parts.size()):
			if is_instance_valid(parts[i]):
				parts[i].global_transform = model.global_transform * at_rest[i]
	parts.clear()
	at_rest.clear()
	model = null
	valid = false

func animate(progress: float) -> void:
	if not valid or model == null or not is_instance_valid(model):
		return

	var p: float = clampf(progress, 0.0, 1.0)
	var lift: float = 0.0
	var pull: float = 0.0

	# 1. Levantar, 2. Recuar, 3. Avancar, 4. Travar.
	if p < 0.20:
		lift = _smooth(p / 0.20)
	elif p < 0.48:
		lift = 1.0
		pull = _smooth((p - 0.20) / 0.28)
	elif p < 0.76:
		lift = 1.0
		pull = 1.0 - _smooth((p - 0.48) / 0.28)
	else:
		lift = 1.0 - _smooth((p - 0.76) / 0.24)

	# Transform em metros no eixo local do GLB (Z positivo: direcao da coronha).
	# O pivô deslocado permite rotacao em torno do eixo longitudinal do ferrolho.
	var to_pivot := Transform3D(Basis.IDENTITY, PIVOT)
	var from_pivot := Transform3D(Basis.IDENTITY, -PIVOT)
	var rotation := Transform3D(Basis(Vector3(0.0, 0.0, 1.0), lift * OPEN_ANGLE_RAD), Vector3.ZERO)
	var motion := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, pull * BOLT_TRAVEL))
	var movement: Transform3D = motion * to_pivot * rotation * from_pivot

	for i in range(parts.size()):
		if is_instance_valid(parts[i]):
			parts[i].global_transform = model.global_transform * movement * at_rest[i]

func _smooth(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _collect(parent: Node) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D and _is_candidate(String(child.name)):
			parts.append(child as MeshInstance3D)
		_collect(child)

func _is_candidate(name: String) -> bool:
	var cleaned: String = name.replace(".", "").replace("_", "").replace("-", "").to_lower()
	for expected in PART_NAMES:
		if cleaned.begins_with(expected.to_lower()):
			return true
	return false
