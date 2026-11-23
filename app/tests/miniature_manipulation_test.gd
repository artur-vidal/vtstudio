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
	# Use the configured T binding through the real input path.
	var scale_key := InputEventKey.new()
	scale_key.physical_keycode = KEY_T
	scale_key.keycode = KEY_T
	scale_key.pressed = true
	Input.parse_input_event(scale_key)
	Input.flush_buffered_events()
	check(Input.is_action_pressed('scale_miniature'), 'T is not bound to scale_miniature')
	object.scale = Vector3(1.0, 2.0, 0.5)
	object._begin_drag(camera, object.global_position)
	check(object._drag_mode == MapObject.DragMode.SCALE, 'Holding T before capture did not enter scale mode')
	before = object.global_position
	var initial_scale := object.scale
	var initial_rotation := object.rotation
	var scale_motion := InputEventMouseMotion.new()
	scale_motion.relative = Vector2(100, -50)
	scale_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	object._input(scale_motion)
	check(object.scale.is_equal_approx(initial_scale * exp(50 * object.scale_sensitivity)), 'Scaling did not enlarge all axes proportionally')
	check(object.global_position.is_equal_approx(before) and object.rotation.is_equal_approx(initial_rotation), 'Scaling moved or rotated the miniature')
	scale_motion.relative = Vector2(-100, 50)
	object._input(scale_motion)
	check(object.scale.is_equal_approx(initial_scale), 'Opposite drag did not restore scale')
	object._apply_drag_motion(Vector2(0, 100000))
	check(is_equal_approx(object.scale.y, MapObject.MIN_SCALE) and object.scale.x > 0.0, 'Scale minimum was not positive and bounded')
	object._apply_drag_motion(Vector2(0, -100000))
	check(object.scale.is_finite() and is_equal_approx(object.scale.y, MapObject.MAX_SCALE), 'Scale maximum was not finite and bounded')
	Input.action_press('scale_miniature')
	object._update_drag_mode()
	check(object._drag_mode == MapObject.DragMode.SCALE, 'Scale mode did not use the action')
	Input.action_release('scale_miniature')
	scale_key = scale_key.duplicate()
	scale_key.pressed = false
	Input.parse_input_event(scale_key)
	Input.flush_buffered_events()
	object._update_drag_mode()
	check(object._drag_mode == MapObject.DragMode.MOVE and object.global_position.is_equal_approx(before), 'Releasing T did not restore movement without jumping')
	object._end_drag()
	var released_scale := object.scale
	scale_motion.relative = Vector2(0, -50)
	object._input(scale_motion)
	check(object.scale.is_equal_approx(released_scale), 'Mouse motion scaled an unheld miniature')
	object.scale = Vector3.ONE
	# Camera travel must carry both the grabbed point and the unsnapped target.
	object.snap_size = 1.0
	object._begin_drag(camera, object.global_position + Vector3(0.3, 1.0, 0.2))
	object._drag_target += Vector3(0.2, 0.0, 0.3)
	var residual := object._drag_target - object.global_position
	var orientation := object.global_basis
	for mode in [MapObject.DragMode.MOVE, MapObject.DragMode.ELEVATE, MapObject.DragMode.ROTATE, MapObject.DragMode.SCALE]:
		object._set_drag_mode(mode)
		residual = object._drag_target - object.global_position
		before = object.global_position
		camera.position.y += 10.0
		object._follow_drag_camera()
		check(object.global_position.is_equal_approx(before), 'Vertical camera travel moved the miniature')
		var hit := object.to_global(object._drag_local_hit)
		var held_in_view := camera.to_local(hit)
		camera.position += Vector3(20.0, 3.0, -15.0)
		camera.rotation += Vector3(-0.1, 0.4, 0.2)
		var expected := before + camera.to_global(held_in_view) - hit
		expected.y = before.y
		object._follow_drag_camera()
		check(object.global_position.is_equal_approx(expected), 'Camera travel did not follow the XZ drag plane')
		check(object.global_basis.is_equal_approx(orientation), 'Camera travel rotated the miniature')
		check((object._drag_target - object.global_position).is_equal_approx(residual), 'Camera travel lost the drag target residual')
	# Release before the next process frame must consume the final camera move.
	before = object.global_position
	camera.position += Vector3(2.0, 1.0, 3.0)
	object._end_drag()
	check(object.global_position.is_equal_approx(before + Vector3(2.0, 0.0, 3.0)), 'Release lost the final horizontal camera movement')
	before = object.global_position
	camera.position += Vector3(10.0, 0.0, 0.0)
	object._process(0.1)
	check(object.global_position.is_equal_approx(before), 'Released miniature kept following the camera')
	object.snap_size = 0.0
	camera.rotation = Vector3.ZERO
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
	Input.action_press('scale_miniature')
	object._update_drag_mode()
	check(object._drag_mode == MapObject.DragMode.SCALE, 'Scale action did not take priority over R and Shift')
	Input.action_release('scale_miniature')
	object._update_drag_mode()
	check(object._drag_mode == MapObject.DragMode.ROTATE, 'Releasing scale action did not restore rotation')
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
