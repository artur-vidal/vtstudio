extends RigidBody3D
## Integrate the isolated tray contact using the full rotated convex geometry.
## A swept vertical contact prevents fast, spinning dice from crossing the floor.
var points := PackedVector3Array()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	var velocity := state.linear_velocity + state.total_gravity * dt
	velocity *= exp(-linear_damp * dt)
	var spin := state.angular_velocity * exp(-angular_damp * dt)
	var pose := state.transform
	if spin.length() > 0.0001:
		pose.basis = (Basis(spin.normalized(), spin.length() * dt) * pose.basis).orthonormalized()
	pose.origin += velocity * dt
	var support := 0.0
	for point: Vector3 in points:
		support = maxf(support, -(pose.basis * point).y)
	if pose.origin.y < support + 0.015:
		pose.origin.y = support + 0.015
		if velocity.y < 0:
			velocity.y = -velocity.y * 0.38
		spin *= 0.82
	state.transform = pose
	state.linear_velocity = velocity
	state.angular_velocity = spin
