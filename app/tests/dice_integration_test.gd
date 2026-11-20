extends SceneTree
## Real scene/physics lifecycle checks. Run headless; visual review remains separate.

var failures := 0
var checks := 0
var completions := 0


func _initialize() -> void:
	OS.set_environment("BREAKPOINT_RUNTIME_PORT", "0")
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func wait_for_roll(roller: Node) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while roller.busy and Time.get_ticks_msec() < deadline:
		await physics_frame
	check(not roller.busy, "Roll did not settle within eight seconds")
	await create_timer(0.7).timeout


func check_rest(roller: Node) -> void:
	var stage: Node3D = roller.stage
	var expected_count := 0
	for group in roller.last_result.groups:
		expected_count += group.count
	check(stage.bodies.size() == expected_count, "Visual count differs from sampled dice count")
	for index in stage.bodies.size():
		var body: RigidBody3D = stage.bodies[index]
		var data: Dictionary = stage.Assets.get_die(body.get_meta("sides"))
		check(body.freeze, "Settled body is not frozen")
		check(body.transform.is_equal_approx(stage.targets[index]), "Body missed target transform")
		var lowest := INF
		for vertex: Vector3 in data.shape.points:
			lowest = minf(lowest, (body.transform * vertex).y)
		check(absf(lowest - 0.015) < 0.002, "Die floats above or intersects tray: %s" % lowest)
		var found := false
		for face in data.faces:
			if face.value == body.get_meta("value"):
				found = true
				var up := Basis(Vector3.RIGHT, deg_to_rad(-45)) * Vector3.DOWN if data.get("read_bottom", false) else Vector3.UP
				check((body.basis * face.normal).normalized().dot(up) > 0.9999, "Visible landing face disagrees with sampled value")
		check(found, "Result has no mapped face")
		check(stage.read_face(data, body.basis) == body.get_meta("value"), "Read-back face does not match the result")
	check(roller.result_number.text == str(roller.last_result.total), "Animated number missed exact final total")
	check(roller.result_box.visible and roller.actions.visible and not roller.panel.visible, "Completion screen visibility is wrong")
	for button: Button in roller.actions.get_children():
		check(button.size.x >= 90 and button.size.y >= 40, "Result action is too small or invisible: %s %s" % [button.text, button.size])


func check_framing(roller: Node, dimensions: Vector2i) -> void:
	# Use a real viewport rectangle so Camera3D.unproject_position exercises the
	# same projection as rendering; this is stronger than comparing camera.size.
	roller.viewport_container.stretch = false
	roller.viewport.size = dimensions
	roller.stage.set_aspect(float(dimensions.x) / dimensions.y)
	await process_frame
	check_rest(roller)
	# Bottom 10% belongs to the reroll/edit/close controls.
	var frame := Rect2(Vector2.ZERO, Vector2(dimensions.x, dimensions.y * 0.9))
	var corridor := Rect2(0, dimensions.y * 0.3, dimensions.x, dimensions.y * 0.4)
	for body: RigidBody3D in roller.stage.bodies:
		var mesh: Mesh = body.get_child(0).mesh
		var clipped := false
		var obscured := false
		for surface in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var projected: Vector2 = roller.stage.camera.unproject_position(body.global_transform * vertex)
				clipped = clipped or not frame.has_point(projected)
				obscured = obscured or corridor.has_point(projected)
		check(not clipped, "Die geometry clipped after resize to %s: d%s" % [dimensions, body.get_meta("sides")])
		check(not obscured, "Die geometry overlaps central result corridor at %s: d%s" % [dimensions, body.get_meta("sides")])


func _run() -> void:
	var scene := Node.new()
	scene.name = "DiceIntegrationHost"
	root.add_child(scene)
	current_scene = scene
	var original_camera := Camera3D.new()
	original_camera.name = "CameraUnderTest"
	original_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(original_camera)
	var packed := load("res://editor/dice/DiceRoller.tscn") as PackedScene
	check(packed != null, "DiceRoller scene failed to load")
	if packed == null:
		quit(1)
		return
	var roller = packed.instantiate()
	scene.add_child(roller)
	roller.roll_completed.connect(func(_result): completions += 1)
	await process_frame
	check(not roller.screen.visible and roller.launcher.visible, "Roller should start closed")
	check(roller.launcher.size.x >= 90 and roller.launcher.size.y >= 40, "Launcher is too small or invisible")
	roller.launcher.pressed.emit()
	await create_timer(0.4).timeout
	check(roller.screen.visible and roller.panel.visible, "Launcher did not open selection")
	check(original_camera.process_mode == Node.PROCESS_MODE_DISABLED, "Editor input was not suspended")
	check(roller.panel.get_roll_groups().is_empty(), "First opening must be empty")
	roller.panel.rows[6].count.value = 2
	roller.panel.roll_button.pressed.emit()
	check(roller.busy and roller.stage.bodies.size() == 2, "Default roll did not spawn two dice")
	var first_result: Dictionary = roller.last_result.duplicate(true)
	roller._roll([{"sides": 20, "count": 1, "mode": "highest"}])
	check(roller.last_result == first_result, "Second roll replaced active roll")
	await roller.stage.settled
	check(roller.busy and not roller.result_box.visible, "Results must stay hidden during post-settlement pause")
	await create_timer(0.8).timeout
	check(roller.busy and not roller.result_box.visible and completions == 0, "Result revealed before the 1-second pause elapsed")
	await wait_for_roll(roller)
	check(completions == 1, "Completion emitted wrong number of times")
	check_rest(roller)
	roller._edit()
	roller.panel.reset_selection()
	check(roller.panel.roll_button.disabled, "Empty selection can roll")
	for sides in [4, 6, 8, 10, 12, 20]:
		roller.panel.rows[sides].count.value = 20
	check(roller.panel.roll_button.disabled, "120 dice bypassed UI limit")
	for sides in [4, 6, 8, 10, 12, 20]:
		roller.panel.rows[sides].count.value = 5
		roller.panel.rows[sides].mode.selected = 1 if sides in [6, 10, 20] else 0
	roller.panel._refresh()
	check(not roller.panel.roll_button.disabled, "30 dice rejected")
	roller.panel.roll_button.pressed.emit()
	check(roller.stage.bodies.size() == 30, "Maximum mixed roll did not spawn 30 dice")
	await wait_for_roll(roller)
	check(completions == 2, "Mixed roll did not complete exactly once")
	check_rest(roller)
	await check_framing(roller, Vector2i(450, 1000))
	await check_framing(roller, Vector2i(1700, 1000))
	roller.viewport_container.stretch = true
	for sides in [4, 6, 8, 10, 12, 20]:
		var data: Dictionary = roller.stage.Assets.get_die(sides)
		check(data.faces.size() == sides, "Wrong number of mapped faces for d%d" % sides)
		var seen: Array[int] = []
		for face in data.faces:
			seen.append(face.value)
			var basis: Basis = roller.stage.face_basis(data, face.value)
			var up := Basis(Vector3.RIGHT, deg_to_rad(-45)) * Vector3.DOWN if data.get("read_bottom", false) else Vector3.UP
			check((basis * face.normal).normalized().dot(up) > 0.9999, "Face alignment failed for d%d value%d" % [sides, face.value])
			if sides != 4:
				check((basis * face.up).normalized().dot(Vector3.FORWARD) > 0.9999, "Numeral is not upright for d%d value%d" % [sides, face.value])
		seen.sort()
		check(seen == range(1, sides + 1), "Face mapping is not a bijection for d%d" % sides)
	roller._roll([{"sides": 6, "count": 50, "mode": "sum"}, {"sides": 20, "count": 50, "mode": "highest"}])
	check(roller.stage.bodies.size() == 100, "Maximum roll did not spawn 100 dice")
	for body: RigidBody3D in roller.stage.bodies:
		check(body.position.y < 15.0, "Spawn height grows beyond tray for large rolls")
	await wait_for_roll(roller)
	check(completions == 3, "100-dice roll did not complete exactly once")
	check_rest(roller)
	await check_framing(roller, Vector2i(450, 1000))
	await check_framing(roller, Vector2i(1700, 1000))
	roller.viewport_container.stretch = true
	roller._roll(roller.last_groups)
	await create_timer(0.15).timeout
	roller.close()
	await create_timer(0.35).timeout
	check(not roller.busy and roller.stage.bodies.is_empty(), "Closing did not clear throw")
	check(original_camera.process_mode == Node.PROCESS_MODE_ALWAYS, "Closing failed to restore editor processing")
	check(root.gui_get_focus_owner() == null, "Closing must release UI keyboard focus")
	await create_timer(3.5).timeout
	check(completions == 3 and not roller.screen.visible, "Canceled roll completed after close")
	roller.open()
	await create_timer(0.4).timeout
	roller._roll([{"sides": 6, "count": 1, "mode": "sum"}])
	await roller.stage.settled
	check(roller.busy and not roller.result_box.visible, "Expected cancellable reveal pause")
	roller.close()
	await create_timer(2.3).timeout
	check(completions == 3 and not roller.screen.visible and not roller.busy, "Canceled reveal pause fired after closing")
	check(root.gui_get_focus_owner() == null, "Cancel during reveal must release UI focus")
	roller.open()
	await create_timer(0.4).timeout
	check(roller.panel.visible and not roller.panel.rolling, "Reopening did not reset UI state")
	roller.queue_free()
	await process_frame
	check(original_camera.process_mode == Node.PROCESS_MODE_ALWAYS, "Freeing open roller failed to restore editor")
	current_scene = null
	scene.queue_free()
	await process_frame
	print("Dice integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
