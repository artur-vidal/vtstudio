extends SceneTree
## Generates a visual atlas audit: each caption is the expected upward value.
const Assets = preload("res://editor/dice/dice_assets.gd")
const Stage = preload("res://editor/dice/dice_stage.gd")

func _initialize() -> void:
	OS.set_environment("BREAKPOINT_RUNTIME_PORT", "0")
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1600, 1400)
	root.size = Vector2i(1600, 1400)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 23
	camera.position = Vector3(0, 30, 0)
	camera.rotation.x = -PI / 2
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-75, 15, 0)
	light.light_energy = 1.5
	world.add_child(light)
	var ui := CanvasLayer.new()
	root.add_child(ui)
	var row := 0
	for sides in [4, 6, 8, 10, 12, 20]:
		var data: Dictionary = Assets.get_die(sides)
		for value in range(1, sides + 1):
			var mesh := MeshInstance3D.new()
			mesh.mesh = data.mesh
			mesh.basis = Stage.face_basis(data, value)
			mesh.position = Vector3(((value - 1) % 10 - 4.5) * 2.3, 0, (row + (value - 1) / 10 - 3.5) * 2.7)
			world.add_child(mesh)
			var caption := Label.new()
			caption.text = "d%d → %d" % [sides, value]
			caption.add_theme_font_size_override("font_size", 22)
			ui.add_child(caption)
			caption.position = camera.unproject_position(mesh.position) + Vector2(-40, 48)
		row += ceili(sides / 10.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var destination := OS.get_environment("DICE_AUDIT_IMAGE")
	if destination.is_empty():
		destination = "user://dice_face_audit.png"
	root.get_texture().get_image().save_png(destination)
	print(destination)
	quit()
