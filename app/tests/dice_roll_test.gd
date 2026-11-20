extends SceneTree

const Rules = preload("res://editor/dice/dice_roll.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	OS.set_environment("BREAKPOINT_RUNTIME_PORT", "0")
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func group(sides: int, count: int, mode: String = "sum") -> Dictionary:
	return {"sides": sides, "count": count, "mode": mode}


func _run() -> void:
	for invalid in [[], [null], [1], [{}], [{"sides": 6, "count": 1}],
		[group(3, 1)], [group(100, 1)], [group(6, -1)], [group(6, 51)],
		[group(6, 0)], [group(6, 1, "max")],
		[{"sides": 6.0, "count": 1, "mode": "sum"}],
		[{"sides": 6, "count": 1.0, "mode": "sum"}],
		[{"sides": 6, "count": true, "mode": "sum"}],
		[{"sides": 6, "count": 1, "mode": null}],
		[group(4, 50), group(6, 50), group(8, 1)]]:
		check(not Rules.validate(invalid).is_empty(), "Accepted invalid input: %s" % str(invalid))
		var rejected := Rules.roll(invalid, RandomNumberGenerator.new())
		check(not rejected.error.is_empty() and rejected.groups.is_empty(), "Invalid roll returned a partial result")
	check(Rules.validate([group(4, 50), group(20, 50)]).is_empty(), "Rejected maximum 100 dice")
	var maximum_roll := Rules.roll([group(6, 50), group(20, 50, "highest")], RandomNumberGenerator.new())
	check(maximum_roll.error.is_empty() and maximum_roll.groups[0].values.size() == 50 and maximum_roll.groups[1].values.size() == 50, "Maximum roll must sample all 100 dice")
	check(not Rules.roll([group(6, 1)], null).error.is_empty(), "Accepted null RNG")
	for sides in Rules.SIDES:
		for mode in ["sum", "highest"]:
			var config := [group(sides, 2, mode)]
			var minimum := Rules.evaluate(config, [[1, 1]])
			check(minimum.total == (2 if mode == "sum" else 1), "Wrong minimum")
			check(not minimum.special, "Minimum marked special")
			var maximum := Rules.evaluate(config, [[sides, sides]])
			check(maximum.total == (2 * sides if mode == "sum" else sides), "Wrong maximum")
			check(maximum.special, "Maximum not marked special")
			var almost := Rules.evaluate([group(sides, 3, "highest")], [[1, sides - 1, 2]])
			check(almost.total == sides - 1 and not almost.special, "Highest special requires exact maximum")
	check(not Rules.evaluate([group(10, 2)], [[8, 8]]).special, "Exactly 80% must not celebrate")
	check(Rules.evaluate([group(10, 2)], [[8, 9]]).special, "Above 80% must celebrate")
	check(not Rules.evaluate([group(10, 2)], [[8, 7]]).special, "Below 80% must not celebrate")
	var configs := [group(6, 3), group(20, 2, "highest"), group(4, 0), group(6, 1, "highest")]
	var samples := [[2, 3, 5], [4, 20], [], [3]]
	var mixed := Rules.evaluate(configs, samples)
	check(mixed.total == 33 and mixed.special, "Mixed total should sum each group's aggregate")
	check(mixed.groups.size() == 3 and not mixed.groups[0].special and mixed.groups[1].special, "Group celebrations/zero filtering incorrect")
	check(configs[0].count == 3 and samples[0] == [2, 3, 5], "Evaluation mutated inputs")
	mixed.groups[0].values[0] = 6
	check(samples[0][0] == 2, "Results alias input values")
	for samples_invalid in [[], [[1]], [[1, 7]], [[0, 6]], [[1.0, 2]], [[true, 2]], [null], ["12"], [[1, 2], []]]:
		var invalid := Rules.evaluate([group(6, 2)], samples_invalid)
		check(not invalid.error.is_empty() and invalid.groups.is_empty(), "Accepted invalid samples: %s" % str(samples_invalid))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118
	for sides in Rules.SIDES:
		var counts: Array[int] = []
		counts.resize(sides)
		counts.fill(0)
		for sample in 2000:
			var result := Rules.roll([group(sides, 10)], rng)
			check(result.error.is_empty(), "Valid random roll failed")
			var sum := 0
			for value in result.groups[0].values:
				check(value >= 1 and value <= sides, "Random result out of bounds")
				counts[value - 1] += 1
				sum += value
			check(sum == result.total, "Random sum inconsistent")
		# Broad smoke bound with fixed seed: catches missing or badly weighted faces.
		var expected: float = 20000.0 / sides
		for count in counts:
			check(absf(count - expected) < expected * 0.18, "Face distribution is grossly uneven for d%d: %s" % [sides, counts])
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 42
	second.seed = 42
	check(Rules.roll(configs, first) == Rules.roll(configs, second), "Equal RNG seeds must reproduce results")
	print("Dice rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
