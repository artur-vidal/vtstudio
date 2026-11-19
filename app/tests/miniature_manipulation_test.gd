extends SceneTree

var failures := 0


func _initialize() -> void:
	OS.set_environment('BREAKPOINT_RUNTIME_PORT', '0')
	call_deferred('_run')


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 2, 6)
	var object := MapObject.new()
	root.add_child(object)
	object._begin_drag(camera, Vector3(0, 1, 0))
	object._apply_drag_motion(Vector2(100, 0))
	check(object.position.x > 0.0 and object.position.is_finite(), 'Horizontal screen motion did not move right')
	check(is_zero_approx(object.position.y), 'Ground drag changed elevation')
	var before := object.position
	object._apply_drag_motion(Vector2(0, -100))
	check(object.position.z < before.z and is_equal_approx(object.position.y, before.y), 'Forward drag was not on XZ')
	object._set_drag_mode(MapObject.DragMode.ELEVATE)
	before = object.position
	object._apply_drag_motion(Vector2(400, -100))
	check(object.position.y > before.y and is_equal_approx(object.position.x, before.x) and is_equal_approx(object.position.z, before.z), 'Shift movement was not restricted to height')
	object._set_drag_mode(MapObject.DragMode.ROTATE)
	before = object.position
	object._apply_drag_motion(Vector2(100, 200))
	check(object.position.is_equal_approx(before), 'Rotation translated the object')
	check(is_equal_approx(object.rotation.y, -100 * object.rotation_sensitivity), 'Horizontal mouse did not rotate around Y')
	check(object._rotation_indicator.visible, 'Rotation indicator was not shown')
	# Cross +/- PI: the sector must keep the short continuous signed sweep.
	object.rotation.y = 3.0
	object._set_drag_mode(MapObject.DragMode.MOVE)
	object._set_drag_mode(MapObject.DragMode.ROTATE)
	object._apply_drag_motion(Vector2(-50, 0))
	check(is_equal_approx(object._rotation_angle - object._rotation_start_yaw, 0.5), 'Rotation sweep jumped at PI')
	object._set_drag_mode(MapObject.DragMode.MOVE)
	check(not object._rotation_indicator.visible and object.position.is_equal_approx(before), 'Switching modes moved the object or left indicator visible')
	object._end_drag()
	check(not object._dragging and not object.is_in_group('miniature_dragging'), 'Release did not clear capture')
	# Horizon and top-down views must remain finite, with no grazing-plane jump.
	for pitch in [0.0, -0.0001, -PI / 2.0]:
		camera.rotation.x = pitch
		camera.position = Vector3(0, 0.01, 0.01)
		object.position = Vector3.ZERO
		object._begin_drag(camera, Vector3.ZERO)
		object._apply_drag_motion(Vector2(20, 20))
		check(object.position.is_finite() and object.position.length() < 1.0, 'Close/horizon camera caused a drag jump')
		var settled := object.position
		object._process(1.0)
		check(object.position.is_equal_approx(settled), 'Object moved without mouse input')
		object._end_drag()
	# Real input polling: R wins over Shift; releasing R enters height mode.
	object._begin_drag(camera, Vector3.ZERO)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key = InputEventKey.new()
	key.physical_keycode = KEY_R
	key.keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	object._update_drag_mode()
	check(object._drag_mode == MapObject.DragMode.ROTATE, 'R did not take priority over Shift')
	key = InputEventKey.new()
	key.physical_keycode = KEY_R
	key.keycode = KEY_R
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	object._update_drag_mode()
	check(object._drag_mode == MapObject.DragMode.ELEVATE, 'Releasing R did not restore Shift mode')
	key = InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.keycode = KEY_SHIFT
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	object._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not object._dragging, 'Losing focus did not end capture')
	object.free()
	camera.free()
	print('Miniature manipulation failures: ', failures)
	quit(1 if failures else 0)
