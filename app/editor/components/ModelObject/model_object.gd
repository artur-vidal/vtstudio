class_name ModelObject
extends MapObject
## Miniatura de um modelo 3D carregado em tempo de execução. Herda o arrasto do MapObject.
##
## O modelo é escalado para caber em `target_size` e posicionado com o centro da base
## na origem do objeto. A colisão é uma caixa (AABB) que cobre o modelo inteiro.
## Ao passar o mouse ou arrastar, o modelo ganha um outline (veja OutlineStyle).

## Maior dimensão do modelo depois de escalado, em unidades do mundo
@export var target_size: float = 2.0

## Raiz do modelo carregado (filha de um pivot interno)
var model: Node3D

var _geometries: Array[GeometryInstance3D] = []
var _outline_material: ShaderMaterial


## Monta o objeto a partir do modelo carregado. Pode ser chamado antes de entrar na
## árvore. Devolve false se o modelo não tem geometria; nesse caso, descarte o objeto.
func setup(model_root: Node3D) -> bool:
	var pivot := Node3D.new()
	pivot.name = 'Visual'
	add_child(pivot)
	pivot.add_child(model_root)
	model = model_root

	var parts: Array[AABB] = []
	_collect_bounds(model_root, Transform3D.IDENTITY, parts)
	if parts.is_empty():
		return false

	var bounds := parts[0]
	for part in parts:
		bounds = bounds.merge(part)

	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest <= 0.0001:
		return false

	var factor := target_size / largest
	var center := bounds.get_center()
	pivot.scale = Vector3.ONE * factor
	# Centro da base na origem do objeto: o modelo fica "de pé" sobre o chão
	pivot.position = Vector3(-center.x, -bounds.position.y, -center.z) * factor

	var shape := BoxShape3D.new()
	shape.size = bounds.size * factor
	var collision := CollisionShape3D.new()
	collision.name = 'CollisionShape3D'
	collision.shape = shape
	collision.position = Vector3(0.0, shape.size.y / 2.0, 0.0)
	add_child(collision)

	_collect_geometries(model_root)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OutlineStyle.HULL_SHADER
	return true


## Mostra o outline (como overlay de cada malha) enquanto há hover ou arrasto
func _on_visual_state_changed(state: VisualState) -> void:
	if _outline_material == null:
		return
	var overlay: Material = null
	if state != VisualState.IDLE:
		_outline_material.set_shader_parameter('outline_color', OutlineStyle.color_for(state))
		_outline_material.set_shader_parameter('width', OutlineStyle.width_for(state))
		overlay = _outline_material
	for geometry in _geometries:
		geometry.material_overlay = overlay


## Junta as caixas de todas as malhas, no espaço do pai do modelo. Não usa
## global_transform porque o modelo ainda pode estar fora da árvore.
func _collect_bounds(node: Node, parent_transform: Transform3D, out: Array[AABB]) -> void:
	var current := parent_transform
	if node is Node3D:
		current = parent_transform * (node as Node3D).transform
	if node is GeometryInstance3D:
		var local := (node as GeometryInstance3D).get_aabb()
		if local.size != Vector3.ZERO:
			out.append(current * local)
	for child in node.get_children():
		_collect_bounds(child, current, out)


func _collect_geometries(node: Node) -> void:
	if node is GeometryInstance3D:
		_geometries.append(node as GeometryInstance3D)
	for child in node.get_children():
		_collect_geometries(child)
