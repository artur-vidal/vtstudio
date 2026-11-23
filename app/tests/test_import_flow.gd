extends SceneTree
## Execute: godot --headless --path app --script res://tests/test_import_flow.gd

func _initialize() -> void:
	call_deferred('_run')

func _run() -> void:
	var ui := MiniatureLoaderUI.new()
	root.add_child(ui)
	var card: Control = ui._drop_card
	card.present()
	await create_timer(0.4).timeout
	assert(card.visible)
	assert(card.is_in_group('editor_import_modal'))
	assert(card._card.position.y >= 0.0)
	var selected: Array = []
	ui.files_chosen.connect(func(paths: PackedStringArray) -> void: selected.append(paths))
	ui._on_files_dropped(PackedStringArray(['invalid.txt']))
	assert(selected.is_empty())
	assert(card.visible)
	ui._on_files_dropped(PackedStringArray(['model.GLB', 'image.PNG', 'invalid.txt']))
	await create_timer(0.4).timeout
	assert(not card.visible)
	assert(not card.is_in_group('editor_import_modal'))
	assert(selected.size() == 1 and selected[0].size() == 2)
	card.present()
	await create_timer(0.4).timeout
	await card.dismiss()
	assert(not card.visible)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(10, 10, 10)
	camera.rotation_degrees.x = -45
	camera.make_current()
	var spawner := MiniatureSpawner.new()
	world.add_child(spawner)
	var first := spawner._spawn_origin()
	camera.position.x += 7.0
	var second := spawner._spawn_origin()
	assert(is_equal_approx(second.x - first.x, 7.0))
	assert(is_equal_approx(second.y, spawner.ground_height))
	var image_data := MiniatureImage.new()
	var frame := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	frame.fill(Color.WHITE)
	image_data.frames = [frame, frame.duplicate()]
	image_data.delays = PackedFloat32Array([0.1, 0.1])
	var miniature := BillboardObject.new()
	assert(miniature.setup(image_data))
	world.add_child(miniature)
	miniature._set_drag_mode(MapObject.DragMode.ROTATE)
	miniature._apply_drag_motion(Vector2(50, 0))
	assert(is_equal_approx(miniature.global_rotation.y, -0.5))
	assert(miniature._sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED)
	var facing := miniature._sprite.global_basis
	camera.rotation.y += 1.0
	await physics_frame
	assert(miniature._sprite.global_basis.is_equal_approx(facing))
	assert(miniature._collision.global_basis.is_equal_approx(facing))
	assert(miniature._outline.global_basis.is_equal_approx(facing))
	miniature._next_frame()
	assert(miniature._sprite.texture == miniature._outline_material.get_shader_parameter('tex'))
	# A câmera muda enquanto o arquivo está sendo decodificado. A orientação deve
	# usar sua posição ao finalizar, inclusive antes de emitir miniature_spawned.
	var imported: Array[MapObject] = []
	spawner.miniature_spawned.connect(func(item: MapObject, _path: String) -> void:
		var toward_camera := camera.global_position - item.global_position
		toward_camera.y = 0.0
		assert(item.global_basis.z.normalized().is_equal_approx(toward_camera.normalized()))
		imported.append(item)
	)
	var static_image := MiniatureImage.new()
	static_image.frames = [frame]
	for data: MiniatureImage in [static_image, image_data]:
		var job := {'path': 'image.gif' if data.is_animated() else 'image.png', 'image': data, 'point': Vector3(3, 0, -4)}
		camera.position = Vector3(-12, 8, 6)
		spawner._finish_image(job)
		var item := imported.back() as BillboardObject
		var initial_basis := item.global_basis
		camera.position = Vector3(10, 8, -12)
		await physics_frame
		assert(item.global_basis.is_equal_approx(initial_basis))
		assert(item._collision.global_basis.is_equal_approx(initial_basis))
		assert(item._outline.global_basis.is_equal_approx(initial_basis))
		item._set_drag_mode(MapObject.DragMode.ROTATE)
		item._apply_drag_motion(Vector2(30, 0))
		assert(not item.global_basis.is_equal_approx(initial_basis))
	assert(imported.size() == 2)
	ui.show_progress('sample.png', 0.5)
	assert(is_equal_approx(ui._progress_rows['sample.png'].bar.value, 0.5))
	ui.show_failed('sample.png', 'Teste de aviso')
	assert(ui._progress_rows.is_empty())
	assert(ui._warnings.visible)
	var dice := preload('res://editor/dice/dice_roller.gd').new()
	root.add_child(dice)
	await process_frame
	assert(dice.launcher.text.is_empty() and dice.launcher.icon != null)
	assert(is_equal_approx(dice.launcher.get_rect().end.x, root.get_visible_rect().size.x - 12.0))
	assert(is_equal_approx(dice.launcher.position.y, 12.0))
	dice.queue_free()
	print('PASS: modal, animation, filtering, selection, reopening, camera-relative placement')
	print('PASS: image rotation, fixed collision and outline, GIF frames, progress and warnings')
	ui.queue_free()
	world.queue_free()
	await process_frame
	quit()
