extends Node3D

@export var pan_speed: float = 12.0
@export var vertical_speed: float = 10.0
@export var orbit_sensitivity: float = 0.005
@export var zoom_step: float = 1.5

@export var min_distance: float = 3.0
@export var max_distance: float = 40.0
@export var min_eixo_rotation: float = deg_to_rad(-80.0)
@export var max_eixo_rotation: float = deg_to_rad(-15.0)

@export_group("Movimento")
@export var acceleration: float = 60.0   # unidades/s². Menor = demora mais para chegar na velocidade máxima
@export var deceleration: float = 30.0   # unidades/s². Menor = desliza mais ao soltar a tecla

@export_group("Suavização")
@export var orbit_smoothing: float = 12.0  # maior = mais responsivo, menor = mais suave
@export var roll_smoothing: float = 8.0
@export var zoom_smoothing: float = 8.0

@onready var eixo: Node3D = $Eixo
@onready var camera: Camera3D = $Eixo/Camera3D

var camera_z: float = 0.0
var distance: float = 20.0

var target_yaw: float = 0.0
var target_pitch: float = 0.0

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	target_yaw = rotation.y
	target_pitch = eixo.rotation.x
	camera.position.z = distance

func _process(delta: float) -> void:
	var real_delta := delta  # usado nas suavizações, sem o efeito do cam_slow
	var speed_scale := 1.0

	if Input.is_action_pressed("cam_slow"):
		speed_scale = 0.1
		delta /= 10

	# Velocidade alvo (horizontal + vertical)
	var input := Input.get_vector("cam_left", "cam_right", "cam_forwards", "cam_backwards")
	var target_velocity := basis * Vector3(input.x, 0.0, input.y) * pan_speed

	if Input.is_action_pressed("cam_raise"):
		target_velocity.y = vertical_speed
	elif Input.is_action_pressed("cam_lower"):
		target_velocity.y = -vertical_speed

	target_velocity *= speed_scale

	# Rampa de aceleração ao mover, rampa de frenagem ao soltar
	var rate := acceleration if target_velocity.length_squared() > 0.0001 else deceleration
	velocity = velocity.move_toward(target_velocity, rate * real_delta)
	position += velocity * real_delta

	if Input.is_action_pressed("cam_roll_left"):
		camera_z += 2.0 * delta
	elif Input.is_action_pressed("cam_roll_right"):
		camera_z -= 2.0 * delta

	if Input.is_action_pressed("cam_reset"):
		camera_z = 0.0

	# Suavização independente de framerate
	rotation.y = lerp_angle(rotation.y, target_yaw, _smooth(orbit_smoothing, real_delta))
	eixo.rotation.x = lerpf(eixo.rotation.x, target_pitch, _smooth(orbit_smoothing, real_delta))
	eixo.rotation.z = lerp_angle(eixo.rotation.z, camera_z, _smooth(roll_smoothing, real_delta))
	camera.position.z = lerpf(camera.position.z, distance, _smooth(zoom_smoothing, real_delta))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_zoom_in"):
		distance = clampf(distance - zoom_step, min_distance, max_distance)
	elif event.is_action_pressed("cam_zoom_out"):
		distance = clampf(distance + zoom_step, min_distance, max_distance)

	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		# Compensa o roll: converte o movimento da tela para o referencial do eixo
		var rel: Vector2 = event.relative.rotated(-eixo.rotation.z)

		target_yaw -= rel.x * orbit_sensitivity
		target_pitch = clampf(
			target_pitch - rel.y * orbit_sensitivity,
			min_eixo_rotation,
			max_eixo_rotation
		)

# Converte uma "velocidade" em fator de lerp estável com qualquer FPS
func _smooth(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)
