class_name BillboardObject
extends MapObject
## Miniatura de imagem (inclusive GIF animado): um quadro que gira só em torno do eixo Y
## para sempre encarar a câmera. Herda o arrasto e o estado visual do MapObject.
##
## O visual é um Sprite3D com billboard fixo no Y. A caixa de colisão gira em torno do Y
## a cada quadro de física, seguindo a MESMA regra do billboard (veja billboard_normal),
## para continuar cobrindo a imagem. Ao passar o mouse ou arrastar, a imagem ganha um
## outline que segue o formato dela.

## Altura da imagem no mundo, em unidades. A largura segue a proporção original.
@export var world_height: float = 2.0
## Espessura da caixa de colisão. Pode ser fina, pois ela sempre fica de frente para a câmera.
@export var collision_thickness: float = 0.1

var _sprite: Sprite3D
var _collision: CollisionShape3D
var _timer: Timer
var _outline: MeshInstance3D
var _outline_material: ShaderMaterial
var _images: Array[Image] = []
# Texturas são criadas só quando o quadro é mostrado pela primeira vez. Em GIFs grandes,
# enviar todos os quadros para a GPU de uma vez travaria o jogo ao criar a miniatura.
var _textures: Array[ImageTexture] = []
var _delays: PackedFloat32Array = PackedFloat32Array()
var _frame: int = 0
var _world_size: Vector2 = Vector2.ONE


## Direção horizontal para onde a imagem aponta, IGUAL à do Sprite3D com BILLBOARD_FIXED_Y:
## a projeção horizontal do vetor "para trás" da câmera. A imagem fica em pé no mundo e o
## plano dela é perpendicular a essa direção, onde quer que o objeto esteja na tela.
## Dois erros já aconteceram aqui, e a shader do outline (outline_sprite.gdshader) usa a
## mesma conta:
##  - apontar para a POSIÇÃO da câmera desalinha tudo que está fora do centro da tela;
##  - usar o vetor "direita" da câmera faz o plano rolar junto com o roll (Q/E), enquanto a
##    imagem continua em pé. O "para trás" não muda com o roll.
static func billboard_normal(camera: Camera3D) -> Vector3:
	var back := camera.global_basis.z
	back.y = 0.0
	if back.length() < 0.0001:
		return Vector3.BACK # câmera olhando reto para baixo: sem direção horizontal
	return back.normalized()


## Monta o objeto a partir da imagem carregada. Pode ser chamado antes de entrar na
## árvore. Devolve false se a imagem não tem quadros utilizáveis.
func setup(image: MiniatureImage) -> bool:
	_images = image.frames
	if _images.is_empty() or _images[0].get_height() <= 0:
		return false
	_delays = image.delays
	_textures.resize(_images.size())

	var first := _texture(0)
	var pixel_size := world_height / first.get_height()
	_world_size = Vector2(first.get_width() * pixel_size, world_height)

	_sprite = Sprite3D.new()
	_sprite.name = 'Imagem'
	_sprite.texture = first
	_sprite.pixel_size = pixel_size
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Base da imagem na origem do objeto: ela fica "de pé" sobre o chão
	_sprite.position = Vector3(0.0, world_height / 2.0, 0.0)
	add_child(_sprite)

	var shape := BoxShape3D.new()
	shape.size = Vector3(_world_size.x, world_height, collision_thickness)
	_collision = CollisionShape3D.new()
	_collision.name = 'CollisionShape3D'
	_collision.shape = shape
	_collision.position = Vector3(0.0, world_height / 2.0, 0.0)
	add_child(_collision)

	_build_outline(first)

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


## A colisão é atualizada na física, que é quem usa a caixa para achar o objeto sob o mouse
func _physics_process(_delta: float) -> void:
	if _collision == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var normal := billboard_normal(camera)
	_collision.rotation.y = atan2(normal.x, normal.z) - global_rotation.y


func _on_visual_state_changed(state: VisualState) -> void:
	if _outline == null:
		return
	_outline.visible = state != VisualState.IDLE
	if _outline.visible:
		var width := OutlineStyle.width_for(state)
		_outline_material.set_shader_parameter('outline_color', OutlineStyle.color_for(state))
		_outline_material.set_shader_parameter('width_uv', Vector2(width / _world_size.x, width / _world_size.y))


func _texture(index: int) -> ImageTexture:
	var texture := _textures[index]
	if texture == null:
		texture = ImageTexture.create_from_image(_images[index])
		_textures[index] = texture
	return texture


## Quad um pouco maior que a imagem, com uma shader que desenha só a borda. Fica
## escondido enquanto não há hover nem arrasto.
func _build_outline(texture: Texture2D) -> void:
	var margin := OutlineStyle.DRAG_WIDTH + 0.03
	var quad := QuadMesh.new()
	quad.size = _world_size + Vector2.ONE * margin * 2.0

	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OutlineStyle.SPRITE_SHADER
	_outline_material.set_shader_parameter('tex', texture)
	_outline_material.set_shader_parameter('uv_scale', quad.size / _world_size)

	_outline = MeshInstance3D.new()
	_outline.name = 'Outline'
	_outline.mesh = quad
	_outline.material_override = _outline_material
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.position = Vector3(0.0, world_height / 2.0, 0.0)
	_outline.visible = false
	add_child(_outline)


func _next_frame() -> void:
	_frame = (_frame + 1) % _textures.size()
	var texture := _texture(_frame)
	_sprite.texture = texture
	_outline_material.set_shader_parameter('tex', texture)
	_timer.start(maxf(_delays[_frame], 0.02))
