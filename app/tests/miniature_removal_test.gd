extends SceneTree

const REMOVAL = preload('res://editor/components/MiniatureSpawner/miniature_removal.gd')
var failures := 0


func _initialize() -> void:
	OS.set_environment('BREAKPOINT_RUNTIME_PORT', '0')
	call_deferred('_run')


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	for code in [KEY_BACKSPACE, KEY_DELETE]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = true
		check(key.is_action_pressed('remove_miniature'), 'Missing removal key binding')
	var parent := Node3D.new()
	root.add_child(parent)
	var controller := REMOVAL.new()
	root.add_child(controller)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var hovered := MapObject.new()
	var collision := CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	hovered.add_child(collision)
	parent.add_child(hovered)
	var mouse := root.get_mouse_position()
	hovered.position = camera.project_ray_origin(mouse) + camera.project_ray_normal(mouse) * 5.0
	await physics_frame
	await process_frame
	var remove := InputEventKey.new()
	remove.physical_keycode = KEY_DELETE
	remove.pressed = true
	remove.echo = true
	controller._unhandled_input(remove)
	check(hovered.is_inside_tree(), 'Key repeat removed miniature')
	remove.echo = false
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	controller._unhandled_input(remove)
	check(hovered.is_inside_tree(), 'Typing removed miniature')
	field.free()
	controller._unhandled_input(remove)
	await create_timer(0.4).timeout
	check(not hovered.is_inside_tree(), 'Shortcut did not remove miniature under mouse')
	if not hovered.is_inside_tree():
		controller._toasts.get_child(0).restore()
	await create_timer(0.4).timeout
	hovered.free()
	camera.free()
	var first := MapObject.new()
	var second := MapObject.new()
	parent.add_child(first)
	parent.add_child(second)
	first.position = Vector3(2, 3, 4)
	first.rotation = Vector3(0.2, 0.7, 0.1)
	first.scale = Vector3(2, 3, 2)
	var original := first.transform
	first._on_mouse_entered()
	controller.remove_miniature(first)
	check(first.is_inside_tree() and not first.input_ray_pickable, 'Removal did not animate or disable picking')
	controller.remove_miniature(first)
	check(controller._toasts.get_child_count() == 1, 'Animating miniature removed twice')
	await create_timer(0.15).timeout
	check(not first.transform.is_equal_approx(original), 'Removal did not animate scale')
	await create_timer(0.25).timeout
	check(not first.is_inside_tree(), 'Removed miniature remains in scene')
	check(first.visual_state() == MapObject.VisualState.IDLE, 'Removal left hover active')
	controller.remove_miniature(second)
	check(controller._toasts.get_child_count() == 2, 'Successive removals lost undo')
	var toast: Control = controller._toasts.get_child(0)
	var undo := toast._panel.get_child(0).get_child(1) as Button
	undo.pressed.emit()
	check(first.is_inside_tree() and first.scale.length() < original.basis.get_scale().length(), 'Undo did not start small')
	await create_timer(0.4).timeout
	check(first.get_parent() == parent and first.get_index() == 0, 'Undo did not restore parent/order')
	check(first.transform.is_equal_approx(original), 'Undo changed transform')
	check(first.input_ray_pickable and first.collision_layer == 1 and not first.is_in_group('miniature_removing'), 'Undo did not restore interaction')
	var second_toast: Control = controller._toasts.get_child(0)
	check(not second_toast._restoring, 'Undo affected another removal')
	await create_timer(5.2).timeout
	check(not is_instance_valid(second), 'Expired removal did not free miniature')
	check(controller._toasts.get_child_count() == 0, 'Toast did not expire after five seconds')
	controller.remove_miniature(first)
	await create_timer(0.1).timeout
	controller._toasts.get_child(0).restore()
	await create_timer(0.4).timeout
	check(first.is_inside_tree() and first.transform.is_equal_approx(original), 'Undo during removal did not restore miniature')
	controller.remove_miniature(first)
	controller.free()
	check(not is_instance_valid(first), 'Closing scene leaked pending miniature')
	parent.free()
	print('Miniature removal failures: ', failures)
	quit(1 if failures else 0)
