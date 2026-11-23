extends Control
## Mantém a miniatura fora da cena durante a janela de desfazer.

const PALETTE = preload('res://front-end/pallete.tres')
const BUTTON = preload('res://front-end/components/botao/Botao.tscn')
const FONT = preload('res://assets/fonts/Outfit/static/Outfit-Regular.ttf')
const ANIMATION_DURATION := 0.3
const MIN_SCALE := 0.0001

var miniature: MapObject
var original_parent: Node
var original_index: int
var original_transform: Transform3D
var _original_process_mode: ProcessMode
var _original_pickable: bool
var _original_collision_layer: int
var _original_collision_mask: int
var _animation: Tween
var _timer: Timer
var _restoring := false
var _scale_factor := 1.0
var _panel: PanelContainer
var _toast_animation: Tween
var _closing := false


func capture(target: MapObject) -> void:
	miniature = target
	original_parent = target.get_parent()
	original_index = target.get_index()
	original_transform = target.transform
	_original_process_mode = target.process_mode
	_original_pickable = target.input_ray_pickable
	_original_collision_layer = target.collision_layer
	_original_collision_mask = target.collision_mask
	target._on_mouse_exited()
	target._end_drag()
	target.add_to_group('miniature_removing')
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.input_ray_pickable = false
	target.collision_layer = 0
	target.collision_mask = 0


func _ready() -> void:
	# O container posiciona este espaço; só o painel interno se move.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.colors[8]
	style.border_color = PALETTE.colors[3]
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override('panel', style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override('separation', 16)
	_panel.add_child(row)
	var label := Label.new()
	label.text = 'Minatura removida.'
	label.add_theme_font_override('font', FONT)
	label.add_theme_font_size_override('font_size', 16)
	label.add_theme_color_override('font_color', PALETTE.colors[10])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var undo := BUTTON.instantiate() as Button
	undo.text = 'Desfazer?'
	undo.set('cor', 'Dourado')
	undo.focus_mode = Control.FOCUS_NONE
	undo.pressed.connect(restore)
	row.add_child(undo)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 5.0
	_timer.timeout.connect(_dismiss)
	add_child(_timer)
	_timer.start()
	_animation = create_tween()
	_animation.tween_method(_apply_scale, 1.0, MIN_SCALE, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_animation.tween_callback(_detach)
	custom_minimum_size = _panel.get_combined_minimum_size()
	resized.connect(func() -> void: _panel.size = size)
	_panel.size = custom_minimum_size
	_panel.position.x = -custom_minimum_size.x - 32.0
	_toast_animation = create_tween()
	_toast_animation.tween_property(_panel, 'position:x', 0.0, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _dismiss() -> void:
	if _closing:
		return
	_closing = true
	_timer.stop()
	_toast_animation.kill()
	(_panel.get_child(0).get_child(1) as Button).disabled = true
	_toast_animation = create_tween().set_parallel(true)
	_toast_animation.tween_property(_panel, 'position:y', 32.0, ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_toast_animation.tween_property(_panel, 'modulate:a', 0.0, ANIMATION_DURATION)
	_toast_animation.chain().tween_callback(queue_free)


func _apply_scale(factor: float) -> void:
	_scale_factor = maxf(factor, MIN_SCALE)
	if is_instance_valid(miniature):
		miniature.transform = Transform3D(original_transform.basis.scaled(Vector3.ONE * _scale_factor), original_transform.origin)


func _detach() -> void:
	if is_instance_valid(miniature) and miniature.get_parent() != null:
		miniature.get_parent().remove_child(miniature)


func restore() -> void:
	if is_queued_for_deletion() or _restoring or _closing:
		return
	if is_instance_valid(original_parent) and not original_parent.is_queued_for_deletion() and is_instance_valid(miniature):
		_restoring = true
		_timer.stop()
		_dismiss()
		_animation.kill()
		if miniature.get_parent() == null:
			original_parent.add_child(miniature)
			original_parent.move_child(miniature, mini(original_index, original_parent.get_child_count() - 1))
		_animation = create_tween()
		_animation.tween_method(_apply_scale, _scale_factor, 1.0, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_animation.tween_callback(_finish_restore)
		return
	_dismiss()


func _finish_restore() -> void:
	if is_instance_valid(miniature):
		miniature.transform = original_transform
		miniature.process_mode = _original_process_mode
		miniature.input_ray_pickable = _original_pickable
		miniature.collision_layer = _original_collision_layer
		miniature.collision_mask = _original_collision_mask
		miniature.remove_from_group('miniature_removing')
	miniature = null


func _exit_tree() -> void:
	if _toast_animation != null:
		_toast_animation.kill()
	if _animation != null:
		_animation.kill()
	if _restoring:
		_finish_restore()
	if is_instance_valid(miniature):
		miniature.free()
		miniature = null
