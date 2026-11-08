extends Node
## Teste do cursor do mouse e do estado visual dos MapObjects. Rode esta cena (F6).
##
## Não usa o mouse de verdade: chama os handlers de "mouse entrou/saiu" diretamente, na ordem
## em que causavam o bug do cursor (ao ir de um objeto para o vizinho, o "entrou" do novo pode
## chegar ANTES do "saiu" do antigo) e confere o cursor e o estado visual a cada passo.
##
## O Godot só aplica o cursor padrão no frame seguinte, então o teste espera dois frames antes
## de ler o cursor. O resultado fica em `report` quando `finished` for true.

## Texto do resultado (também aparece na tela)
var report: String = ''
var all_passed: bool = false
var finished: bool = false

var _problems: PackedStringArray = PackedStringArray()


func _ready() -> void:
	# Câmera olhando para baixo: o arrasto precisa de um raio que cruze o plano do objeto
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 5.0, 0.0)
	camera.rotation.x = -PI / 2.0
	add_child(camera)
	camera.make_current()

	var a := _make_object()
	var b := _make_object()

	# 1. Mouse entra em A
	a._on_mouse_entered()
	await _expect_cursor('mouse entra em A', Input.CURSOR_POINTING_HAND)
	_expect_state('A em hover', a, MapObject.VisualState.HOVER)

	# 2. Vai de A para B, com o "entrou" de B ANTES do "saiu" de A (a ordem que quebrava)
	b._on_mouse_entered()
	a._on_mouse_exited()
	await _expect_cursor('vai de A para B (entrou antes de sair)', Input.CURSOR_POINTING_HAND)
	_expect_state('A sem hover', a, MapObject.VisualState.IDLE)
	_expect_state('B em hover', b, MapObject.VisualState.HOVER)

	# 3. Sai de B
	b._on_mouse_exited()
	await _expect_cursor('mouse sai de B', Input.CURSOR_ARROW)

	# 4. Objeto removido enquanto estava em hover
	a._on_mouse_entered()
	await _expect_cursor('A em hover de novo', Input.CURSOR_POINTING_HAND)
	a.free()
	await _expect_cursor('objeto removido em hover', Input.CURSOR_ARROW)

	# 5. Arrasto: o cursor de arrastar vence o de hover, e o outro objeto não mostra hover
	var c := _make_object()
	c._on_mouse_entered()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	c._on_input_event(camera, press, Vector3.ZERO, Vector3.UP, 0)
	await _expect_cursor('arrastando C', Input.CURSOR_DRAG)
	_expect_state('C arrastado', c, MapObject.VisualState.DRAG)

	b._on_mouse_entered()
	await _expect_cursor('arrastando C com o mouse sobre B', Input.CURSOR_DRAG)
	_expect_state('B sem hover durante o arrasto de C', b, MapObject.VisualState.IDLE)

	# 6. Solta o arrasto em cima de B: B passa a mostrar hover e o cursor vira mão
	c._end_drag()
	await _expect_cursor('arrasto solto sobre B', Input.CURSOR_POINTING_HAND)
	_expect_state('B em hover depois do arrasto', b, MapObject.VisualState.HOVER)

	# 7. Tudo fora: seta
	b._on_mouse_exited()
	c._on_mouse_exited()
	await _expect_cursor('nenhum objeto com mouse', Input.CURSOR_ARROW)

	all_passed = _problems.is_empty()
	report = 'OK: o cursor e o estado visual seguiram o esperado em todos os passos' if all_passed \
			else char(10).join(_problems)
	print(report)
	var label := Label.new()
	label.text = report
	label.position = Vector2(16, 16)
	add_child(label)
	finished = true


func _make_object() -> MapObject:
	var object := MapObject.new()
	add_child(object)
	return object


func _expect_cursor(step: String, expected: Input.CursorShape) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var actual := Input.get_current_cursor_shape()
	if actual != expected:
		_problems.append('FALHA em "%s": cursor %d, esperado %d' % [step, actual, expected])


func _expect_state(step: String, object: MapObject, expected: MapObject.VisualState) -> void:
	if object.visual_state() != expected:
		_problems.append('FALHA em "%s": estado %d, esperado %d' % [step, object.visual_state(), expected])
