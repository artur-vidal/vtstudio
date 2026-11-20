extends SceneTree
## Checks the entire flight, including the first floor contact, not only final poses.
const Stage = preload("res://editor/dice/dice_stage.gd")
const Rules = preload("res://editor/dice/dice_roll.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	OS.set_environment("BREAKPOINT_RUNTIME_PORT", "0")
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var stage := Stage.new()
	viewport.add_child(stage)
	var groups: Array = []
	var values: Array = []
	for sides in [4, 6, 8, 10, 12, 20]:
		groups.append({"sides": sides, "count": sides, "mode": "sum"})
		values.append(range(1, sides + 1))
	var result := Rules.evaluate(groups, values)
	var scenario := 0
	for test_aspect in [0.45, 1.7, 0.45, 1.7]:
		if scenario == 2:
			var d6: Array = []
			var d20: Array = []
			for i in 50:
				d6.append(i % 6 + 1)
				d20.append(i % 20 + 1)
			result = Rules.evaluate([{"sides": 6, "count": 50, "mode": "sum"}, {"sides": 20, "count": 50, "mode": "highest"}], [d6, d20])
		scenario += 1
		stage.set_aspect(test_aspect)
		stage.motion_rng.seed = 8412
		stage.throw_result(result)
		var landed := [false]
		stage.settled.connect(func(): landed[0] = true, CONNECT_ONE_SHOT)
		var frames := 0
		while not landed[0] and frames < 240:
			await physics_frame
			frames += 1
			for body: RigidBody3D in stage.bodies:
				var data: Dictionary = stage.Assets.get_die(body.get_meta("sides"))
				var clearance := body.position.y - stage.contact_height(data.shape, body.basis)
				check(clearance >= -0.002, "Die penetrated the floor during flight: %s frozen=%s" % [clearance, body.freeze])
				if body.freeze and clearance < 0.025 and stage.elapsed > stage.FREE_FALL_TIME:
					check(stage.read_face(data, body.basis) == body.get_meta("value"), "First floor contact showed another result")
			if frames % 15 == 0:
				for i in stage.bodies.size():
					for j in range(i + 1, stage.bodies.size()):
						check(stage.bodies[i].position.distance_to(stage.bodies[j].position) > 1.64, "Dice overlap or stack")
		check(landed[0], "Landing failed to finish")
		for body: RigidBody3D in stage.bodies:
			var data: Dictionary = stage.Assets.get_die(body.get_meta("sides"))
			check(absf(body.position.y - stage.contact_height(data.shape, body.basis)) < 0.002, "Die did not reach floor")
			check(stage.read_face(data, body.basis) == body.get_meta("value"), "Final value differs from visible face")
		stage.clear()
		await process_frame
	viewport.queue_free()
	await process_frame
	print("Dice landing: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
