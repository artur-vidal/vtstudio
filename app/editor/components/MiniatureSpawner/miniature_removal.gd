extends CanvasLayer
## Só trata atalhos que não foram consumidos pela interface (como campos de texto).

const TOAST = preload('res://front-end/components/popups/notificacao/miniature_removal_toast.gd')
var _toasts: VBoxContainer


func _ready() -> void:
	layer = 10
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ['left', 'top', 'right', 'bottom']:
		margin.add_theme_constant_override('margin_' + side, 16)
	add_child(margin)
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override('separation', 8)
	margin.add_child(_toasts)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed('remove_miniature') or event.is_echo():
		return
	var viewport := get_viewport()
	if viewport.gui_get_hovered_control() != null:
		return
	var focus := viewport.gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var camera := viewport.get_camera_3d()
	if camera == null:
		return
	var mouse := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(mouse) * camera.far)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var target := hit.get('collider') as MapObject
	if target == null:
		return
	viewport.set_input_as_handled()
	remove_miniature(target)


func remove_miniature(target: MapObject) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		return
	if target.is_in_group('miniature_removing'):
		return
	var toast := TOAST.new()
	toast.capture(target)
	_toasts.add_child(toast)
