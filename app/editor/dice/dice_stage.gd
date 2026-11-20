extends Node3D
## Physics throws followed by a short, deterministic settling animation.
## The result RNG is separate from cosmetic motion, so frame rate cannot affect rolls.
signal settled

const Assets = preload("res://editor/dice/dice_assets.gd")
const Palette = preload("res://editor/dice/dice_palette.gd")
var bodies: Array[RigidBody3D] = []
var targets: Array[Transform3D] = []
var camera: Camera3D
var motion_rng := RandomNumberGenerator.new()
var rolling := false
var elapsed := 0.0
var settle_tween: Tween
var aspect := 1.5
const FREE_FALL_TIME := 0.55
const LANDING_TIME := 1.45

func _ready() -> void:
	motion_rng.randomize()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 15.0
	camera.position = Vector3(0, 24, 0)
	camera.rotation.x = -PI / 2.0
	add_child(camera)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.background_color = Palette.color(8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Palette.color(6)
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -25, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0))

func _box(dimensions: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	add_child(body)

func set_aspect(value: float) -> void:
	aspect = maxf(0.35, value)
	if camera:
		_reflow()

func _reflow() -> void:
	if bodies.is_empty():
		camera.size = 15.0
		return
	var columns := clampi(ceili(sqrt(bodies.size() * maxf(aspect, 0.7))), 1, 14)
	var rows := ceili(float(bodies.size()) / columns)
	var upper_rows := ceili(rows / 2.0)
	var lower_rows := rows - upper_rows
	# Separate bands leave the central 40% and bottom action area unobstructed.
	var height := maxf(12, ((upper_rows - 1) * 1.85 + 1.84) / 0.25)
	height = maxf(height, ((lower_rows - 1) * 1.85 + 1.84) / 0.2)
	camera.size = maxf(height, (columns * 1.85 + 1.0) / aspect)
	var gap := camera.size * 0.2 + 0.92
	for i in targets.size():
		var row := i / columns
		var z := -(gap + (upper_rows - 1 - row) * 1.85) if row < upper_rows else gap + (row - upper_rows) * 1.85
		targets[i].origin.x = (i % columns - (columns - 1) * 0.5) * 1.85
		targets[i].origin.z = z
		if not rolling and bodies[i].freeze:
			bodies[i].transform = targets[i]

func clear() -> void:
	rolling = false
	if settle_tween:
		settle_tween.kill()
	for body in bodies:
		body.queue_free()
	bodies.clear()
	targets.clear()

func throw_result(result: Dictionary) -> void:
	clear()
	var index := 0
	for group: Dictionary in result.groups:
		var data: Dictionary = Assets.get_die(group.sides)
		for value: int in group.values:
			var body := RigidBody3D.new()
			body.mass = 0.7
			# Each die has a landing lane: collide with the tray, never stack on another die.
			body.collision_layer = 2
			body.collision_mask = 1
			body.linear_damp = 0.65
			body.angular_damp = 0.9
			body.continuous_cd = true
			body.physics_material_override = PhysicsMaterial.new()
			body.physics_material_override.bounce = 0.38
			body.physics_material_override.friction = 0.8
			var visual := MeshInstance3D.new()
			visual.mesh = data.mesh
			body.add_child(visual)
			var collision := CollisionShape3D.new()
			collision.shape = data.shape
			body.add_child(collision)
			add_child(body)
			body.position.y = 4.0 + (index % 5) * 0.3
			body.rotation = Vector3(motion_rng.randf() * TAU, motion_rng.randf() * TAU, motion_rng.randf() * TAU)
			body.linear_velocity = Vector3(motion_rng.randf_range(-0.1, 0.1), -2, motion_rng.randf_range(-0.1, 0.1))
			body.angular_velocity = Vector3(motion_rng.randf_range(-10, 10), motion_rng.randf_range(-10, 10), motion_rng.randf_range(-10, 10))
			body.set_meta("sides", group.sides)
			body.set_meta("value", value)
			var target_basis := face_basis(data, value)
			var min_y := 0.0
			for point: Vector3 in (data.shape as ConvexPolygonShape3D).points:
				min_y = minf(min_y, (target_basis * point).y)
			targets.append(Transform3D(target_basis, Vector3(0, -min_y + 0.015, 0)))
			bodies.append(body)
			index += 1
	rolling = true
	_reflow()
	for i in bodies.size():
		bodies[i].position.x = targets[i].origin.x
		bodies[i].position.z = targets[i].origin.z
	elapsed = 0

static func face_basis(data: Dictionary, value: int) -> Basis:
	for face: Dictionary in data.faces:
		if face.value == value:
			var normal: Vector3 = face.normal
			var up := Vector3.DOWN if data.get("read_bottom", false) else Vector3.UP
			var orientation := Basis(Quaternion(normal.normalized(), up))
			if face.has("up") and not data.get("read_bottom", false):
				var glyph_up: Vector3 = orientation * face.up
				var angle := glyph_up.signed_angle_to(Vector3.FORWARD, Vector3.UP)
				orientation = Basis(Vector3.UP, angle) * orientation
			if data.get("read_bottom", false):
				# Presentation angle for the tetrahedron: expose the upper apex and
				# its front face instead of looking directly along the apex axis.
				orientation = Basis(Vector3.RIGHT, deg_to_rad(-45)) * orientation
			return orientation
	return Basis.IDENTITY

## Read back the actual visible face, independently of the sampled value.
static func read_face(data: Dictionary, orientation: Basis) -> int:
	var direction := Vector3.DOWN if data.get("read_bottom", false) else Vector3.UP
	var best := -INF
	var result := 0
	for face: Dictionary in data.faces:
		var score: float = (orientation * face.normal).dot(direction)
		if score > best:
			best = score
			result = face.value
	return result

static func contact_height(shape: ConvexPolygonShape3D, orientation: Basis) -> float:
	var lowest := INF
	for point: Vector3 in shape.points:
		lowest = minf(lowest, (orientation * point).y)
	return -lowest + 0.015

func _physics_process(delta: float) -> void:
	if not rolling:
		return
	elapsed += delta
	if elapsed < FREE_FALL_TIME:
		return
	rolling = false
	settle_tween = create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for i in bodies.size():
		var body := bodies[i]
		body.freeze = true
		body.collision_mask = 0
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		var start := body.transform
		var target_index := i
		settle_tween.tween_method(func(weight: float): _land_die(target_index, start, weight), 0.0, 1.0, LANDING_TIME)
	settle_tween.chain().tween_callback(_finish_landing)

func _land_die(index: int, start: Transform3D, progress: float) -> void:
	var target := targets[index]
	var body := bodies[index]
	var data: Dictionary = Assets.get_die(body.get_meta("sides"))
	# Finish orienting while airborne. There is no late face swap after resting.
	var turn := smoothstep(0.0, 0.62, progress)
	var orientation := Basis(start.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), turn))
	var travel := smoothstep(0.0, 0.65, progress)
	var position_on_tray := start.origin.lerp(target.origin, travel)
	var clearance := maxf(0.0, start.origin.y - contact_height(data.shape, start.basis))
	if progress < 0.72:
		clearance *= 1.0 - pow(progress / 0.72, 2.0)
	else:
		# A small final bounce keeps the chosen face and returns exactly to the floor.
		clearance = sin(PI * (progress - 0.72) / 0.28) * 0.16
	position_on_tray.y = contact_height(data.shape, orientation) + maxf(0, clearance)
	body.transform = Transform3D(orientation, position_on_tray)

func _finish_landing() -> void:
	for i in bodies.size():
		var body := bodies[i]
		body.transform = targets[i]
		var data: Dictionary = Assets.get_die(body.get_meta("sides"))
		assert(read_face(data, body.basis) == body.get_meta("value"), "Visible face must match the roll before revealing it")
	settled.emit()
