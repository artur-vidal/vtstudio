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
	var scene := load('res://editor/components/NavigationCamera/NavigationCamera.tscn') as PackedScene
	var rig = scene.instantiate()
	root.add_child(rig)
	rig.set_process(false)
	var eye: Vector3 = rig.camera.global_position
	rig.target_yaw = 1.2
	rig.target_pitch = -0.7
	rig.camera_z = 0.5
	for frame in 120:
		rig._apply_view_rotation(1.0 / 60.0)
		check(rig.camera.global_position.distance_to(eye) < 0.0001, 'Look rotation moved camera away from its eye')
	check(absf(rig.rotation.y - 1.2) < 0.001, 'View yaw did not converge')
	check(absf(rig.eixo.rotation.x + 0.7) < 0.001, 'View pitch did not converge')
	var forward: Vector3 = -rig.camera.global_basis.z
	rig.distance = 6.0
	rig._process(0.1)
	var zoom_delta: Vector3 = rig.camera.global_position - eye
	check(zoom_delta.dot(forward) > 0.0 and zoom_delta.cross(forward).length() < 0.001, 'Zoom stopped moving along view direction')
	rig.free()
	# A fixed mouse displacement should have similar apparent size at common
	# pitches, including roll. The old mapping shrank it by sin(pitch).
	var camera := Camera3D.new()
	root.add_child(camera)
	var object := MapObject.new()
	root.add_child(object)
	for degrees in [15.0, 30.0, 60.0, 80.0]:
		var pitch := deg_to_rad(degrees)
		camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * 10.0
		camera.look_at(Vector3.ZERO)
		camera.rotate_object_local(Vector3.BACK, 0.5)
		object.global_position = Vector3.ZERO
		object._begin_drag(camera, Vector3.ZERO)
		var before := camera.unproject_position(object.global_position)
		var screen_forward := (camera.unproject_position(Vector3.FORWARD * 0.01) - before).normalized()
		object._apply_drag_motion(screen_forward * 10.0)
		var visible_pixels := camera.unproject_position(object.global_position).distance_to(before)
		check(absf(visible_pixels - 10.0) < 1.2, 'Ground drag is too slow at %s degrees: %s px' % [degrees, visible_pixels])
		object._end_drag()
	# Keep ONE capture while the camera moves around the miniature. Old frozen
	# axes reverse the motion after a half-turn and fail on an upward view.
	object.global_position = Vector3.ZERO
	object._begin_drag(camera, object.global_position)
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		for degrees in [-30.0, 20.0, 45.0, 80.0]:
			for roll in [0.0, 1.1]:
				var held_height := object.global_position.y
				var held_in_view := camera.to_local(object.global_position)
				var pitch := deg_to_rad(degrees)
				camera.position = object.global_position + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 10.0
				camera.look_at(object.global_position)
				camera.rotate_object_local(Vector3.BACK, roll)
				var expected := camera.to_global(held_in_view)
				expected.y = held_height
				object._process(0.1)
				check(object.global_position.is_equal_approx(expected), 'Held miniature did not follow camera rotation on XZ')
				for pixels in [Vector2(3, 0), Vector2(0, 3), Vector2(-3, -3)]:
					var before := camera.unproject_position(object.global_position)
					object._apply_drag_motion(pixels)
					var projected := camera.unproject_position(object.global_position) - before
					check(projected.normalized().dot(pixels.normalized()) > 0.99, 'Drag direction disagreed with current view: yaw=%s pitch=%s roll=%s mouse=%s actual=%s' % [yaw, degrees, roll, pixels, projected])
	# Off-center perspective and zoom changes also need a fresh projection.
	camera.position = object.global_position + Vector3(6.0, 8.0, 10.0)
	camera.look_at(object.global_position + Vector3(3.0, 2.0, 0.0))
	for zoom in [1.0, 0.5]:
		camera.position = object.global_position + (camera.position - object.global_position) * zoom
		object._process(0.1)
		var before := camera.unproject_position(object.global_position)
		var pixels := Vector2(3.0, -3.0)
		object._apply_drag_motion(pixels)
		var projected := camera.unproject_position(object.global_position) - before
		check(projected.normalized().dot(pixels.normalized()) > 0.99, 'Off-center/zoomed drag direction disagreed with mouse')
	# Looking with RMB must not also translate the held miniature.
	var stationary := object.global_position
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20, 15)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	object._input(motion)
	check(object.global_position.is_equal_approx(stationary), 'Camera-look gesture also moved the miniature')
	object._end_drag()
	object.free()
	camera.free()
	print('Camera navigation failures: ', failures)
	quit(1 if failures else 0)
