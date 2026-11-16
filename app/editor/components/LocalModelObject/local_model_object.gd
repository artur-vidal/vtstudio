class_name LocalModelObject
extends ModelObject
## Variante do ModelObject para assets locais (res://) carregados com preload().
##
## Aceita uma PackedScene (.glb, .gltf, .tscn) definida pelo Inspector ou por código.
## A escala pode seguir `target_size` (FIT_TO_SIZE) ou o tamanho original do arquivo
## (NATIVE), e ainda receber um multiplicador por eixo.

enum ScaleMode {
	## A maior dimensão do modelo vira `target_size`
	FIT_TO_SIZE,
	## Mantém o tamanho original do arquivo. `target_size` é ignorado
	NATIVE,
}

## Cena do modelo. Pode ser definida no Inspector ou antes de entrar na árvore.
@export var scene: PackedScene

@export var scale_mode: ScaleMode = ScaleMode.FIT_TO_SIZE

## Multiplicador aplicado depois do modo de escala, por eixo.
## (1, 1, 1) não altera nada. Valores não uniformes esticam o modelo.
@export var scale_multiplier: Vector3 = Vector3.ONE


## Cria o objeto já configurado a partir de uma cena preloaded.
## Devolve null se a cena for inválida ou não tiver geometria.
static func create(
	model_scene: PackedScene,
	size: float = 2.0,
	multiplier: Vector3 = Vector3.ONE,
	mode: ScaleMode = ScaleMode.FIT_TO_SIZE
) -> LocalModelObject:
	var object := LocalModelObject.new()
	object.target_size = size
	object.scale_multiplier = multiplier
	object.scale_mode = mode
	if not object.setup_from_scene(model_scene):
		object.free()
		return null
	return object


## Instancia a cena e monta o objeto. Devolve false se algo der errado.
func setup_from_scene(model_scene: PackedScene) -> bool:
	if model_scene == null:
		push_warning('LocalModelObject: cena nula.')
		return false
	var root := model_scene.instantiate() as Node3D
	if root == null:
		push_warning('LocalModelObject: a raiz da cena não é um Node3D.')
		return false

	if scale_mode == ScaleMode.NATIVE:
		# O fator do pai é target_size / maior dimensão. Com target_size igual
		# à maior dimensão, o fator vira 1 e o modelo fica no tamanho original.
		var largest := _largest_dimension(root)
		if largest > 0.0001:
			target_size = largest

	if not setup(root):
		root.free()
		return false

	_apply_scale_multiplier()
	scene = model_scene
	return true


func _ready() -> void:
	# Se a cena veio do Inspector e o setup ainda não rodou, monta agora.
	# Precisa acontecer antes do _ready do pai, que pode depender da colisão.
	if scene != null and model == null:
		if not setup_from_scene(scene):
			queue_free()
			return
	super._ready()


func _largest_dimension(root: Node3D) -> float:
	var parts: Array[AABB] = []
	_collect_bounds(root, Transform3D.IDENTITY, parts)
	if parts.is_empty():
		return 0.0
	var bounds := parts[0]
	for part in parts:
		bounds = bounds.merge(part)
	return maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))


## Escala visual e colisão juntas, mantendo o centro da base na origem
func _apply_scale_multiplier() -> void:
	var m := Vector3(
		maxf(absf(scale_multiplier.x), 0.001),
		maxf(absf(scale_multiplier.y), 0.001),
		maxf(absf(scale_multiplier.z), 0.001)
	)
	if m.is_equal_approx(Vector3.ONE):
		return

	var pivot := model.get_parent() as Node3D
	pivot.scale *= m
	# A posição do pivot é proporcional ao fator de escala, então escala junto
	pivot.position *= m

	var collision := get_node('CollisionShape3D') as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size *= m
	collision.position.y = shape.size.y / 2.0
