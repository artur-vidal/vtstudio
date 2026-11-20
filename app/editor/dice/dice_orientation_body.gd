extends RigidBody3D
## Native flight and impacts first; progressively steer angular velocity near rest.
## Gravity, position, restitution and contact response remain engine-owned.
var landing_basis := Basis.IDENTITY
var orientation_time := 0.0
var guidance_delay := 0.9
var aligned := false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	orientation_time += state.step
	if aligned:
		state.angular_velocity = Vector3.ZERO
		return
	if orientation_time < guidance_delay:
		return
	var current := state.transform.basis.get_rotation_quaternion()
	var target := landing_basis.get_rotation_quaternion()
	var error := (target * current.inverse()).normalized()
	if error.w < 0:
		error = -error
	var angle := error.get_angle()
	var strength := smoothstep(guidance_delay, guidance_delay + 1.1, orientation_time)
	if angle < 0.08 and strength >= 0.99:
		state.angular_velocity = Vector3.ZERO
		aligned = true
		lock_rotation = true
		return
	aligned = false
	var desired := Vector3.ZERO
	if angle > 0.0001:
		desired = error.get_axis() * minf(angle * 10.0, 7.0)
	# Bound acceleration so guidance blends into the tumble, rather than snapping.
	state.angular_velocity = desired if strength >= 0.99 else state.angular_velocity.move_toward(desired, lerpf(2.0, 85.0, strength) * state.step)
