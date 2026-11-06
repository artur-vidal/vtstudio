class_name BillboardObject
extends MapObject
## Miniatura de imagem (inclusive GIF animado): um quadro que gira só em torno do eixo Y
## para sempre encarar a câmera. Herda o arrasto do MapObject.
##
## O visual é um Sprite3D com billboard fixo no Y. A caixa de colisão gira em torno do Y
## a cada quadro de física, acompanhando a câmera, para continuar cobrindo a imagem
## (uma caixa parada deixaria de cobri-la quando a câmera desse a volta).

## Altura da imagem no mundo, em unidades. A largura segue a proporção original.
@export var world_height: float = 2.0
## Espessura da caixa de colisão. Pode ser fina, pois ela sempre fica de frente para a câmera.
@export var collision_thickness: float = 0.1

var _sprite: Sprite3D
var _collision: CollisionShape3D
var _timer: Timer
var _textures: Array[ImageTexture] = []
var _delays: PackedFloat32Array = PackedFloat32Array()
var _frame: int = 0


## Monta o objeto a partir da imagem carregada. Pode ser chamado antes de entrar na
## árvore. Devolve false se a imagem não tem quadros utilizáveis.
func setup(image: MiniatureImage) -> bool:
	_textures = image.make_textures()
	if _textures.is_empty() or _textures[0].get_height() <= 0:
		return false
	_delays = image.delays

	var texture_size := _textures[0].get_size()
	var pixel_size := world_height / texture_size.y
	var width := texture_size.x * pixel_size

	_sprite = Sprite3D.new()
	_sprite.name = 'Imagem'
	_sprite.texture = _textures[0]
	_sprite.pixel_size = pixel_size
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Base da imagem na origem do objeto: ela fica "de pé" sobre o chão
	_sprite.position = Vector3(0.0, world_height / 2.0, 0.0)
	add_child(_sprite)

	var shape := BoxShape3D.new()
	shape.size = Vector3(width, world_height, collision_thickness)
	_collision = CollisionShape3D.new()
	_collision.name = 'CollisionShape3D'
	_collision.shape = shape
	_collision.position = Vector3(0.0, world_height / 2.0, 0.0)
	add_child(_collision)

	if image.is_animated():
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_next_frame)
		add_child(_timer)
	return true


func _ready() -> void:
	super()
	if _timer != null:
		_timer.start(maxf(_delays[0], 0.02))


## A colisão é atualizada na física (e não no _process, que o MapObject liga e desliga
## durante o arrasto), já que é a física que usa a caixa para detectar o mouse.
func _physics_process(_delta: float) -> void:
	if _collision == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_camera := camera.global_position - global_position
	_collision.rotation.y = atan2(to_camera.x, to_camera.z) - global_rotation.y


func _next_frame() -> void:
	_frame = (_frame + 1) % _textures.size()
	_sprite.texture = _textures[_frame]
	_timer.start(maxf(_delays[_frame], 0.02))
