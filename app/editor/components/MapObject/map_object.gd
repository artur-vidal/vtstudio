class_name MapObject
extends StaticBody3D

## Estado visual do objeto. Usado pelo outline das miniaturas.
enum VisualState { IDLE, HOVER, DRAG }

## Emitido quando o estado visual muda (nada, mouse em cima ou arrastando)
signal visual_state_changed(state: VisualState)

## 0 = sem snap. Ex.: 1.0 alinha o objeto a uma grade de 1 unidade.
@export var snap_size: float = 0.0

var _hovering: bool = false
var _dragging: bool = false
var _visual_state: VisualState = VisualState.IDLE

enum DragMode { MOVE, ROTATE, ELEVATE }

## Radians por pixel horizontal ao girar com R.
@export var rotation_sensitivity: float = 0.01
## Compensa o encurtamento aparente dos eixos sem explodir no horizonte.
@export_range(1.0, 8.0, 0.25) var max_drag_angle_compensation: float = 4.0

var _drag_mode: DragMode = DragMode.MOVE
var _drag_target := Vector3.ZERO
var _drag_units_per_pixel: float = 0.01
var _drag_height_compensation: float = 1.0
var _drag_camera: Camera3D
var _drag_local_hit := Vector3.ZERO
var _rotation_start_yaw: float = 0.0
var _rotation_angle: float = 0.0
var _rotation_radius: float = 1.0
var _rotation_indicator: MiniatureRotationIndicator


func _ready() -> void:
	input_ray_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	set_process(false)


func visual_state() -> VisualState:
	return _visual_state


func _on_visual_state_changed(_state: VisualState) -> void:
	pass


func _on_mouse_entered() -> void:
	_hovering = true
	_refresh_visual_state()


func _on_mouse_exited() -> void:
	_hovering = false
	_refresh_visual_state()


func _on_input_event(camera: Node, event: InputEvent, hit_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if _dragging or not camera is Camera3D:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Apenas uma miniatura pode capturar o mesmo clique (objetos sobrepostos).
		if not get_tree().get_nodes_in_group('miniature_dragging').is_empty():
			return
		_begin_drag(camera as Camera3D, hit_position)


func _begin_drag(camera: Camera3D, hit_position: Vector3) -> void:
	_dragging = true
	_drag_target = global_position
	_drag_mode = DragMode.MOVE
	_drag_camera = camera
	_drag_local_hit = to_local(hit_position)
	_update_drag_projection(camera, hit_position)
	add_to_group('miniature_dragging')
	set_process(true)
	_update_drag_mode()
	_refresh_visual_state()


## Escala da projeção atual, sem interseção com um plano rasante.
func _update_drag_projection(camera: Camera3D, hit_position: Vector3) -> void:
	var depth := maxf(2.0, (hit_position - camera.global_position).dot(-camera.global_basis.z))
	var pixel := get_viewport().get_mouse_position()
	_drag_units_per_pixel = camera.project_position(pixel, depth).distance_to(camera.project_position(pixel + Vector2.RIGHT, depth))
	_drag_height_compensation = _axis_compensation(Vector3.UP, camera)


func _axis_compensation(axis: Vector3, camera: Camera3D) -> float:
	var projected_length := Vector2(axis.dot(camera.global_basis.x), axis.dot(camera.global_basis.y)).length()
	return 1.0 / maxf(projected_length, 1.0 / maxf(1.0, max_drag_angle_compensation))


# Solta em qualquer ponto da tela; o modo depende das teclas durante a captura.
func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
	elif event is InputEventMouseMotion:
		# O mesmo gesto não deve arrastar a peça e girar a câmera.
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			return
		_update_drag_mode()
		_apply_drag_motion(event.relative)
	elif event is InputEventKey:
		_update_drag_mode()


func _process(_delta: float) -> void:
	if not _dragging:
		return
	_update_drag_mode()
	_update_rotation_indicator()


func _update_drag_mode() -> void:
	var next_mode := DragMode.MOVE
	if Input.is_physical_key_pressed(KEY_R):
		next_mode = DragMode.ROTATE
	elif Input.is_physical_key_pressed(KEY_SHIFT):
		next_mode = DragMode.ELEVATE
	_set_drag_mode(next_mode)


func _set_drag_mode(mode: DragMode) -> void:
	if mode == _drag_mode:
		return
	_drag_mode = mode
	# Reancora ao trocar de modo: o snap não acumula um deslocamento invisível.
	_drag_target = global_position
	if mode == DragMode.ROTATE:
		_rotation_start_yaw = global_rotation.y
		_rotation_angle = _rotation_start_yaw
		_rotation_radius = _get_rotation_radius()
		if _rotation_indicator == null:
			_rotation_indicator = MiniatureRotationIndicator.new()
			add_child(_rotation_indicator)
		_rotation_indicator.visible = true
		_update_rotation_indicator()
	elif _rotation_indicator != null:
		_rotation_indicator.visible = false


func _apply_drag_motion(pixels: Vector2) -> void:
	if _drag_mode == DragMode.ROTATE:
		var angle := -pixels.x * rotation_sensitivity
		global_rotate(Vector3.UP, angle)
		_rotation_angle += angle
		_update_rotation_indicator()
		return
	if not is_instance_valid(_drag_camera):
		return
	var hit_position := to_global(_drag_local_hit)
	_update_drag_projection(_drag_camera, hit_position)
	if _drag_mode == DragMode.ELEVATE:
		_drag_target.y -= pixels.y * _drag_units_per_pixel * _drag_height_compensation
		var height := snappedf(_drag_target.y, snap_size) if snap_size > 0.0 else _drag_target.y
		global_position.y = height
		return
	_drag_target += _screen_delta_to_ground(pixels, hit_position)
	var target := _drag_target
	if snap_size > 0.0:
		target.x = snappedf(target.x, snap_size)
		target.z = snappedf(target.z, snap_size)
	global_position = Vector3(target.x, global_position.y, target.z)


## Inverte a projeção local dos eixos X/Z, incluindo perspectiva, roll e
## posição do ponto agarrado na tela. A inversa é limitada nas direções que
## ficam quase invisíveis: reduz suavemente a resposta em vez de inverter
## arbitrariamente o eixo ou gerar um deslocamento enorme no horizonte.
func _screen_delta_to_ground(pixels: Vector2, point: Vector3) -> Vector3:
	var depth := (point - _drag_camera.global_position).dot(-_drag_camera.global_basis.z)
	if depth <= _drag_camera.near:
		return Vector3.ZERO
	var step := maxf(0.0001, depth * 0.001)
	var x := (_drag_camera.unproject_position(point + Vector3.RIGHT * step) - _drag_camera.unproject_position(point - Vector3.RIGHT * step)) / (2.0 * step)
	var z := (_drag_camera.unproject_position(point + Vector3.BACK * step) - _drag_camera.unproject_position(point - Vector3.BACK * step)) / (2.0 * step)
	# Autovetores de J*J^T: limita os dois ganhos sem introduzir viés de direção.
	var a := x.x * x.x + z.x * z.x
	var b := x.x * x.y + z.x * z.y
	var d := x.y * x.y + z.y * z.y
	var gap := sqrt(maxf(0.0, (a - d) * (a - d) + 4.0 * b * b))
	var high := maxf(0.0, (a + d + gap) * 0.5)
	var low := maxf(0.0, (a + d - gap) * 0.5)
	var axis := Vector2(b, high - a)
	if axis.length_squared() < 0.000001:
		axis = Vector2.RIGHT if a >= d else Vector2.DOWN
	else:
		axis = axis.normalized()
	var other := Vector2(-axis.y, axis.x)
	var max_gain := _drag_units_per_pixel * maxf(1.0, max_drag_angle_compensation)
	var minimum := 1.0 / maxf(max_gain * max_gain, 0.00000001)
	var solved := axis * pixels.dot(axis) / maxf(high, minimum) + other * pixels.dot(other) / maxf(low, minimum)
	var delta := Vector3(x.dot(solved), 0.0, z.dot(solved))
	return delta.limit_length(pixels.length() * max_gain)


func _update_rotation_indicator() -> void:
	if _rotation_indicator != null and _rotation_indicator.visible:
		_rotation_indicator.show_angle(global_position, _rotation_start_yaw, _rotation_angle, _rotation_radius)


func _get_rotation_radius() -> float:
	return 1.0


func _end_drag() -> void:
	_dragging = false
	remove_from_group('miniature_dragging')
	set_process(false)
	if _rotation_indicator != null:
		_rotation_indicator.visible = false
	_refresh_visual_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _dragging:
		_end_drag()


func _refresh_visual_state() -> void:
	var state := VisualState.IDLE
	if _dragging:
		state = VisualState.DRAG
	elif _hovering:
		state = VisualState.HOVER
	if state == _visual_state:
		return
	_visual_state = state
	_on_visual_state_changed(state)
	visual_state_changed.emit(state)
