extends SceneTree
## Run: godot --headless --path app --script res://tests/model_optimizer_test.gd

var failures := 0


func _initialize() -> void:
	# Testes usam uma porta efêmera, sem disputar a sessão debug do editor.
	OS.set_environment('BREAKPOINT_RUNTIME_PORT', '0')
	call_deferred('_run')


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	var material := StandardMaterial3D.new()
	source.surface_set_material(0, material)
	source.surface_set_name(0, 'surface')
	var original_count := ModelOptimizer.triangle_count(source)
	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.mesh = source
	root.add_child(instance)
	var optimizer := ModelOptimizer.new()
	var report := optimizer.optimize(root, 1000)
	check(report.after < report.before, 'Dense plane was not simplified')
	check(ModelOptimizer.triangle_count(source) == original_count, 'Source mesh mutated')
	check(instance.mesh.surface_get_material(0) == material, 'Material lost')
	check(instance.mesh.surface_get_name(0) == 'surface', 'Surface name lost')
	check(instance.mesh.get_aabb() == source.get_aabb(), 'Bounds changed')
	var optimized_count: int = report.after
	instance.mesh = source
	report = optimizer.optimize(root, 1000)
	check(report.cache_hits == 1, 'Disk cache not reused')
	check(report.after == optimized_count, 'Cache changed output')
	var replacement := StandardMaterial3D.new()
	source.surface_set_material(0, replacement)
	instance.mesh = source
	optimizer.optimize(root, 1000)
	check(instance.mesh.surface_get_material(0) == replacement, 'Cache retained stale material')
	# Skin must remain intact even when its mesh is otherwise eligible.
	instance.mesh = source
	instance.skin = Skin.new()
	report = optimizer.optimize(root, 1000)
	check(report.skipped == 1 and instance.mesh == source, 'Skinned mesh changed')
	instance.skin = null
	# Shared meshes count once per rendered instance toward the object budget.
	var second := MeshInstance3D.new()
	second.mesh = source
	root.add_child(second)
	instance.mesh = source
	report = optimizer.optimize(root, 1000)
	check(report.before == original_count * 2, 'Instance budget accounting wrong')
	check(instance.mesh == second.mesh, 'Shared geometry duplicated')
	root.free()
	var unindexed := ArrayMesh.new()
	var triangle: Array = []
	triangle.resize(Mesh.ARRAY_MAX)
	triangle[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	unindexed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, triangle)
	root = Node3D.new()
	instance = MeshInstance3D.new()
	instance.mesh = unindexed
	root.add_child(instance)
	report = optimizer.optimize(root)
	check(report.after == 1, 'Unindexed triangle lost')
	root.free()
	# Compaction must retain vertices used only by a coarse LOD, and preserve
	# packed custom attributes and tangent stride alongside the UV channels.
	var attributes: Array = []
	attributes.resize(Mesh.ARRAY_MAX)
	attributes[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK])
	attributes[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP, Vector2.ONE])
	attributes[Mesh.ARRAY_CUSTOM0] = PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7])
	attributes[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1])
	attributes[Mesh.ARRAY_INDEX] = PackedInt32Array([2, 0, 1])
	var lods := {1.0: PackedInt32Array([3, 1, 0])}
	optimizer._compact(attributes, lods)
	check(attributes[Mesh.ARRAY_TEX_UV][0] == Vector2.UP, 'UV remap corrupted')
	check(attributes[Mesh.ARRAY_CUSTOM0] == PackedByteArray([4, 5, 0, 1, 2, 3, 6, 7]), 'Custom channel corrupted')
	check(attributes[Mesh.ARRAY_TANGENT].slice(0, 4) == PackedFloat32Array([0, 0, 1, 1]), 'Tangent stride corrupted')
	check(lods[1.0] == PackedInt32Array([3, 2, 1]), 'LOD index remap corrupted')
	# Blend shapes and non-triangle primitives must not be rebuilt.
	var special := ArrayMesh.new()
	special.add_blend_shape('expression')
	var base_arrays := plane.get_mesh_arrays()
	var shape_arrays: Array = []
	shape_arrays.resize(Mesh.ARRAY_MAX)
	for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT]:
		shape_arrays[channel] = base_arrays[channel]
	special.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base_arrays, [shape_arrays])
	root = Node3D.new()
	instance = MeshInstance3D.new()
	instance.mesh = special
	root.add_child(instance)
	report = optimizer.optimize(root, 1000)
	check(report.skipped == 1 and instance.mesh == special, 'Blend shapes changed')
	root.free()
	for path in [
		'res://editor/example_assets/warlord-the-last-conqueror/source/WARLORD.glb',
		'res://editor/example_assets/prisoner_in_stripes.glb',
	]:
		var scene := load(path) as PackedScene
		var model := scene.instantiate() as Node3D
		report = optimizer.optimize(model)
		print(path, ': ', report)
		check(report.after < report.before, 'Example model was not reduced: ' + path)
		var local := LocalModelObject.new()
		check(local.setup_from_scene(scene), 'Local model setup failed')
		check(local.optimization_report.after < local.optimization_report.before, 'Local setup bypassed optimization')
		local.free()
		var original := LocalModelObject.new()
		original.optimize_geometry = false
		check(original.setup_from_scene(scene), 'Original mode setup failed')
		check(original.optimization_report.is_empty(), 'Original mode optimized geometry')
		original.free()
		model.free()
		# External-file path must receive the same optimization through ModelObject.
		var loader := ModelLoader.new()
		var external := loader.load_file(ProjectSettings.globalize_path(path))
		check(external != null, 'External load failed: ' + loader.error)
		if external != null:
			var object := ModelObject.new()
			check(object.setup(external), 'External setup failed')
			print('external: ', object.optimization_report)
			check(object.optimization_report.after < object.optimization_report.before, 'External setup bypassed optimization')
			object.free()
	print('Model optimizer failures: ', failures)
	quit(1 if failures else 0)
