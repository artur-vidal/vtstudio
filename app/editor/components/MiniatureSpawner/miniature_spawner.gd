class_name MiniatureSpawner
extends Node
## Cria miniaturas (MapObject) a partir de arquivos do sistema de arquivos, em tempo de execução.
##
## - Modelos 3D (GLB, glTF, FBX) viram um ModelObject.
## - Imagens (PNG, JPG, GIF...) viram um BillboardObject.
##
## As miniaturas são apoiadas no chão, no centro da tela. Modelos são carregados na hora;
## imagens, em outra thread (GIFs grandes demoram), e aparecem quando ficam prontas.

## Emitido quando uma miniatura foi criada e adicionada à cena
signal miniature_spawned(miniature: MapObject, path: String)
## Emitido quando um arquivo não pôde virar miniatura
signal spawn_failed(path: String, message: String)
## Emitido quando a miniatura foi criada, mas com um problema (ex.: textura de FBX não encontrada)
signal spawn_warning(path: String, message: String)
## Progresso (0.0 a 1.0) de uma imagem que está sendo carregada em segundo plano
signal load_progress(path: String, fraction: float)

## Onde as miniaturas são adicionadas. Se vazio, usa o pai deste nó.
@export var container_path: NodePath
## Altura (Y) do chão, onde as miniaturas são apoiadas
@export var ground_height: float = 0.0
## Maior dimensão de um modelo 3D depois de escalado, em unidades do mundo
@export var model_size: float = 2.0
## Qualidade das miniaturas externas; o original nunca é sobrescrito.
@export var optimize_models: bool = true
@export_range(1000, 2000000, 1000) var model_triangle_budget: int = 100000
## Altura de uma miniatura de imagem, em unidades do mundo
@export var image_height: float = 2.0
## Distância entre miniaturas criadas de uma vez (vários arquivos escolhidos juntos)
@export var batch_spacing: float = 3.0
## Distância máxima da câmera até o ponto de criação (evita criar no horizonte)
@export var max_spawn_distance: float = 30.0

var _jobs: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)


## Espera as imagens que ainda estão carregando, para não destruir uma Thread em execução
func _exit_tree() -> void:
	for job in _jobs:
		(job['thread'] as Thread).wait_to_finish()
	_jobs.clear()


static func supported_extensions() -> PackedStringArray:
	return ModelLoader.supported_extensions() + ImageLoader.supported_extensions()


static func is_supported(path: String) -> bool:
	return ModelLoader.is_supported(path) or ImageLoader.is_supported(path)


## Cria uma miniatura para cada arquivo, lado a lado diante da câmera.
func spawn_files(paths: PackedStringArray) -> void:
	var origin := _spawn_origin()
	var right := _camera_right()
	for i in paths.size():
		var offset := (i - (paths.size() - 1) / 2.0) * batch_spacing
		spawn_file(paths[i], origin + right * offset)


## Cria uma miniatura para um arquivo. Sem `point`, usa o centro da tela, no chão.
func spawn_file(path: String, point: Vector3 = Vector3.INF) -> void:
	if point == Vector3.INF:
		point = _spawn_origin()

	if ModelLoader.is_supported(path):
		_spawn_model(path, point)
	elif ImageLoader.is_supported(path):
		_spawn_image(path, point)
	else:
		spawn_failed.emit(path, 'Formato não suportado: .%s' % path.get_extension())


func _spawn_model(path: String, point: Vector3) -> void:
	var loader := ModelLoader.new()
	var model := loader.load_file(path)
	if model == null:
		spawn_failed.emit(path, loader.error)
		return

	var miniature := ModelObject.new()
	miniature.target_size = model_size
	miniature.optimize_geometry = optimize_models
	miniature.triangle_budget = model_triangle_budget
	if not miniature.setup(model):
		miniature.free()
		spawn_failed.emit(path, 'O modelo não tem geometria visível')
		return
	_place(miniature, path, point)
	for warning in loader.warnings:
		spawn_warning.emit(path, warning)
	for warning in miniature.optimization_warnings:
		spawn_warning.emit(path, warning)


## A leitura e a decodificação vão para uma Thread própria; o objeto é montado em _process.
## (Thread e não WorkerThreadPool: o decodificador de GIF usa o pool para trabalhar em
## paralelo e esperaria por ele de dentro dele.)
func _spawn_image(path: String, point: Vector3) -> void:
	var thread := Thread.new()
	var job: Dictionary = {
		'path': path,
		'point': point,
		'loader': ImageLoader.new(),
		'image': null,
		'thread': thread,
		'last_progress': 0.0,
	}
	thread.start(func() -> void: job['image'] = job['loader'].load_file(path))
	_jobs.append(job)
	load_progress.emit(path, 0.0)
	set_process(true)


func _process(_delta: float) -> void:
	for i in range(_jobs.size() - 1, -1, -1):
		var job := _jobs[i]
		var thread: Thread = job['thread']
		var path: String = job['path']

		if thread.is_alive():
			var fraction: float = (job['loader'] as ImageLoader).get_progress()
			if not is_equal_approx(fraction, job['last_progress']):
				job['last_progress'] = fraction
				load_progress.emit(path, fraction)
			continue

		thread.wait_to_finish()
		_jobs.remove_at(i)
		_finish_image(job)
	if _jobs.is_empty():
		set_process(false)


func _finish_image(job: Dictionary) -> void:
	var path: String = job['path']
	var image: MiniatureImage = job['image']
	if image == null:
		spawn_failed.emit(path, (job['loader'] as ImageLoader).error)
		return

	var miniature := BillboardObject.new()
	miniature.world_height = image_height
	if not miniature.setup(image):
		miniature.free()
		spawn_failed.emit(path, 'A imagem não tem conteúdo utilizável')
		return
	_place(miniature, path, job['point'])


func _place(miniature: MapObject, path: String, point: Vector3) -> void:
	var container: Node = null
	if not container_path.is_empty():
		container = get_node_or_null(container_path)
	if container == null:
		container = get_parent()

	miniature.name = path.get_file().get_basename().validate_node_name()
	container.add_child(miniature)
	miniature.global_position = point
	if miniature is BillboardObject:
		_face_camera(miniature)
	miniature_spawned.emit(miniature, path)


## Orientação inicial apenas: usa a câmera atual ao concluir a carga, sem billboard.
## O Sprite3D aponta para +Z. Gira só em Y para manter a imagem em pé no chão.
func _face_camera(miniature: MapObject) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var direction := camera.global_position - miniature.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		return
	miniature.global_rotation = Vector3(0.0, atan2(direction.x, direction.z), 0.0)


## Ponto no chão diante do centro da tela, a no máximo `max_spawn_distance` da câmera
func _spawn_origin() -> Vector3:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return Vector3(0.0, ground_height, 0.0)

	var screen_center := viewport.get_visible_rect().size / 2.0
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_direction := camera.project_ray_normal(screen_center)
	var hit: Variant = Plane(Vector3.UP, ground_height).intersects_ray(ray_origin, ray_direction)
	var point: Vector3 = hit if hit != null else ray_origin + ray_direction * max_spawn_distance

	var flat := Vector2(point.x - ray_origin.x, point.z - ray_origin.z)
	if flat.length() > max_spawn_distance:
		flat = flat.normalized() * max_spawn_distance
	point.x = ray_origin.x + flat.x
	point.z = ray_origin.z + flat.y
	point.y = ground_height
	return point


func _camera_right() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.RIGHT
	var right := camera.global_basis.x
	right.y = 0.0
	return right.normalized() if right.length() > 0.001 else Vector3.RIGHT
