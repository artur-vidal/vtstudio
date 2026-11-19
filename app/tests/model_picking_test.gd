extends SceneTree
## godot --headless --path app --script res://tests/model_picking_test.gd

var failures := 0


func _initialize() -> void:
	OS.set_environment('BREAKPOINT_RUNTIME_PORT', '0')
	call_deferred('_run')


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _assembly() -> Node3D:
	var model := Node3D.new()
	# Separate cubes: their combined AABB incorrectly fills the center gap.
	for x in [-2.0, 2.0]:
		var part := MeshInstance3D.new()
		part.mesh = BoxMesh.new()
		part.position.x = x
		model.add_child(part)
	return model


func _hit(object: ModelObject, local_point: Vector3, reverse: bool = false) -> bool:
	var center := object.to_global(local_point)
	var axis := object.global_basis.z.normalized() * (10.0 if not reverse else -10.0)
	var query := PhysicsRayQueryParameters3D.create(center + axis, center - axis)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == object


func _run() -> void:
	for multiplier in [Vector3.ONE, Vector3(2.0, 3.0, 0.5)]:
		var object := LocalModelObject.new()
		object.optimize_geometry = false
		object.target_size = 5.0
		object.scale_multiplier = multiplier
		check(object.setup(_assembly()), 'Setup failed')
		object._apply_scale_multiplier()
		object.position = Vector3(7.0, -2.0, 3.0)
		object.rotation.y = 0.7
		root.add_child(object)
		await physics_frame
		await physics_frame
		check(not _hit(object, Vector3(0.0, 0.5, 0.0) * multiplier), 'Empty AABB gap remained pickable')
		check(_hit(object, Vector3(2.0, 0.5, 0.0) * multiplier), 'Visible right mesh was not pickable')
		check(_hit(object, Vector3(-2.0, 0.5, 0.0) * multiplier), 'Visible left mesh was not pickable')
		check(_hit(object, Vector3(2.0, 0.5, 0.0) * multiplier, true), 'Back face was not pickable')
		check(not _hit(object, Vector3(2.0, 1.5, 0.0) * multiplier), 'Space above mesh remained pickable')
		object.free()
	print('Model picking failures: ', failures)
	quit(1 if failures else 0)
