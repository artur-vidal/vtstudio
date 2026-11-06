class_name ImageLoader
extends RefCounted
## Carrega imagens do sistema de arquivos em tempo de execução. Lê os formatos que o
## Image.load_from_file do Godot suporta e, além deles, GIF (animado ou não) via GifDecoder.
##
## Seguro para rodar em outra thread: só cria Images, nunca texturas.

## Formatos lidos pelo próprio Godot
const NATIVE_EXTENSIONS: PackedStringArray = ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'tga', 'svg', 'exr', 'hdr', 'dds', 'ktx']
const GIF_EXTENSION: String = 'gif'

## Mensagem do último erro. Fica vazia quando o carregamento dá certo.
var error: String = ''


static func supported_extensions() -> PackedStringArray:
	return NATIVE_EXTENSIONS + PackedStringArray([GIF_EXTENSION])


static func is_supported(path: String) -> bool:
	return path.get_extension().to_lower() in supported_extensions()


## Devolve a imagem (um quadro, ou vários no caso de GIF animado) ou null se falhar.
func load_file(path: String) -> MiniatureImage:
	error = ''
	if not is_supported(path):
		error = 'Formato não suportado: .%s' % path.get_extension()
		return null

	var result: MiniatureImage
	if path.get_extension().to_lower() == GIF_EXTENSION:
		result = _load_gif(path)
	else:
		result = _load_native(path)

	if result != null:
		for frame in result.frames:
			_prepare(frame)
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

	var decoder := GifDecoder.new()
	var result := decoder.decode(bytes)
	if result == null:
		error = decoder.error
	return result


## Mipmaps evitam serrilhado quando a miniatura fica longe da câmera
func _prepare(image: Image) -> void:
	if not image.is_compressed() and not image.has_mipmaps():
		image.generate_mipmaps()
