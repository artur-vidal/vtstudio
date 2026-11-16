class_name ImageLoader
extends RefCounted
## Carrega imagens do sistema de arquivos em tempo de execução. Lê os formatos que o
## Image.load_from_file do Godot suporta e, além deles, GIF (animado ou não) via GifDecoder.
##
## Seguro para rodar em outra thread: só cria Images, nunca texturas. Enquanto roda,
## `get_progress()` pode ser consultado de outra thread.

## Formatos lidos pelo próprio Godot
const NATIVE_EXTENSIONS: PackedStringArray = ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'tga', 'svg', 'exr', 'hdr', 'dds', 'ktx']
const GIF_EXTENSION: String = 'gif'

## Mensagem do último erro. Fica vazia quando o carregamento dá certo.
var error: String = ''

var _decoder: GifDecoder = null
var _native_progress: float = 0.0


static func supported_extensions() -> PackedStringArray:
	return NATIVE_EXTENSIONS + PackedStringArray([GIF_EXTENSION])


static func is_supported(path: String) -> bool:
	return path.get_extension().to_lower() in supported_extensions()


## Progresso do carregamento, de 0.0 a 1.0. Só imagens GIF têm etapas intermediárias;
## as demais vão direto de 0 a 1.
func get_progress() -> float:
	if _decoder != null:
		return _decoder.progress
	return _native_progress


## Devolve a imagem (um quadro, ou vários no caso de GIF animado) ou null se falhar.
func load_file(path: String) -> MiniatureImage:
	error = ''
	_decoder = null
	_native_progress = 0.0
	if not is_supported(path):
		error = 'Formato não suportado: .%s' % path.get_extension()
		return null

	var result: MiniatureImage
	if path.get_extension().to_lower() == GIF_EXTENSION:
		result = _load_gif(path)
	else:
		result = _load_native(path)

	# Mipmaps evitam serrilhado com a miniatura longe da câmera. Em GIF animado ficam de
	# fora: multiplicam o tempo e a memória por todos os quadros e quase não aparecem.
	if result != null and not result.is_animated():
		for frame in result.frames:
			_prepare(frame)
	_native_progress = 1.0
	return result


func _load_native(path: String) -> MiniatureImage:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		error = 'Não foi possível ler a imagem'
		return null

	var result := MiniatureImage.new()
	result.frames.append(image)
	result.delays.append(0.0)
	result.size = image.get_size()
	return result


func _load_gif(path: String) -> MiniatureImage:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		error = 'Não foi possível ler o arquivo: %s' % error_string(FileAccess.get_open_error())
		return null

	_decoder = GifDecoder.new()
	var result := _decoder.decode(bytes)
	if result == null:
		error = _decoder.error
	return result


func _prepare(image: Image) -> void:
	if not image.is_compressed() and not image.has_mipmaps():
		image.generate_mipmaps()
