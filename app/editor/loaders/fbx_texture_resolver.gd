class_name FbxTextureResolver
extends RefCounted
## O FBX guarda o caminho ABSOLUTO das texturas na máquina de quem o criou (ex.:
## C:/Users/fulano/textura.psd). Em outro computador o Godot não as encontra e o modelo
## aparece sem textura. Este resolvedor procura as texturas pelo nome, ao lado do arquivo
## (e em subpastas), e reescreve o caminho dentro dos bytes do FBX antes de o Godot lê-lo.
##
## O caminho novo tem SEMPRE o mesmo tamanho em bytes do antigo (completado com './'),
## então nenhum deslocamento do formato muda e o arquivo continua válido. Funciona com
## FBX binário e em texto. O que não for encontrado vira um aviso em `warnings`.

## Formatos que o Godot lê em tempo de execução, por ordem de preferência
const LOADABLE_EXTENSIONS: PackedStringArray = ['png', 'jpg', 'jpeg', 'webp', 'tga', 'bmp', 'dds', 'exr', 'hdr', 'ktx', 'svg']
## Extensões procuradas dentro do FBX, as mais longas primeiro. Inclui as que o Godot não
## lê (psd, tif, gif): nesses casos procuramos uma versão em formato legível.
const SCAN_EXTENSIONS: PackedStringArray = ['jpeg', 'tiff', 'webp', 'png', 'jpg', 'tga', 'bmp', 'dds', 'exr', 'hdr', 'ktx', 'svg', 'psd', 'tif', 'gif']
const MAX_PATH_LENGTH: int = 520
## Quantas pastas abaixo da do modelo são vasculhadas
const MAX_DEPTH: int = 3
## Limite de arquivos indexados, para não travar com o FBX numa pasta enorme
const MAX_INDEXED_FILES: int = 5000

## Avisos para mostrar ao usuário (texturas que não foram encontradas)
var warnings: PackedStringArray = PackedStringArray()

# nome sem extensão, em minúsculas -> caminhos (relativos à pasta do modelo) de imagens legíveis
var _index: Dictionary = {}
var _indexed_files: int = 0
var _reported: Dictionary = {}


## Devolve os bytes do FBX com os caminhos das texturas corrigidos
func resolve(bytes: PackedByteArray, model_path: String) -> PackedByteArray:
	warnings = PackedStringArray()
	_index.clear()
	_reported.clear()
	_indexed_files = 0
	var base_dir := model_path.get_base_dir()
	_index_directory(base_dir, '', 0)

	var is_binary := bytes.slice(0, 18).get_string_from_ascii() == 'Kaydara FBX Binary'
	var patched := bytes.duplicate()
	var from := 0
	while from < patched.size():
		var dot := patched.find(46, from) # 46 = '.'
		if dot == -1:
			break
		from = dot + 1
		var extension := _extension_at(patched, dot + 1)
		if extension.is_empty():
			continue
		var end := dot + 1 + extension.length()
		var span := _string_span(patched, end, is_binary)
		if span.x < 0:
			continue
		_patch(patched, span.x, span.y, base_dir)
	return patched


## Extensão de textura que começa em `pos` (sem diferenciar maiúsculas), ou ''
func _extension_at(bytes: PackedByteArray, pos: int) -> String:
	for extension in SCAN_EXTENSIONS:
		var length := extension.length()
		if pos + length > bytes.size():
			continue
		var matches := true
		for i in length:
			if (bytes[pos + i] | 0x20) != extension.unicode_at(i):
				matches = false
				break
		if matches:
			return extension
	return ''


## Onde começa e quanto mede (em bytes) o texto do caminho que termina em `end`.
## Devolve (-1, -1) se esse trecho não é um caminho guardado no FBX.
func _string_span(bytes: PackedByteArray, end: int, is_binary: bool) -> Vector2i:
	if is_binary:
		# Cada string do FBX binário vem precedida do próprio tamanho (4 bytes)
		for length in range(4, mini(end - 4, MAX_PATH_LENGTH) + 1):
			var start := end - length
			if _u32(bytes, start - 4) == length and _is_text(bytes, start, end):
				return Vector2i(start, length)
	elif end < bytes.size() and bytes[end] == 34:
		# FBX em texto: o caminho vem entre aspas
		var start := end - 1
		while start >= 0 and end - start <= MAX_PATH_LENGTH and bytes[start] >= 32:
			if bytes[start] == 34:
				return Vector2i(start + 1, end - start - 1)
			start -= 1
	return Vector2i(-1, -1)


func _patch(patched: PackedByteArray, start: int, length: int, base_dir: String) -> void:
	var original := patched.slice(start, start + length).get_string_from_utf8()
	var normalized := original.replace('\\', '/')
	var file_name := normalized.get_file()
	var extension := file_name.get_extension().to_lower()

	# Se o Godot já acha a textura onde o FBX diz que ela está, não há o que corrigir
	if LOADABLE_EXTENSIONS.has(extension) \
			and (FileAccess.file_exists(original) or FileAccess.file_exists(base_dir.path_join(normalized))):
		return

	var found := _find(file_name.get_basename().to_lower(), extension)
	var replacement := _pad(found, length) if not found.is_empty() else ''
	if replacement.is_empty():
		_report(file_name)
		return

	var new_bytes := replacement.to_utf8_buffer()
	for i in length:
		patched[start + i] = new_bytes[i]


## Procura uma imagem legível com esse nome. Prefere a mesma extensão e depois a ordem
## de LOADABLE_EXTENSIONS (assim "corpo.psd" é substituído por "corpo.png", se existir).
func _find(stem: String, extension: String) -> String:
	var candidates: Array = _index.get(stem, [])
	var best := ''
	var best_rank := 1000
	for candidate: String in candidates:
		var candidate_extension := candidate.get_extension().to_lower()
		var rank := LOADABLE_EXTENSIONS.find(candidate_extension)
		if candidate_extension == extension:
			rank = -1
		if rank < best_rank:
			best_rank = rank
			best = candidate
	return best


## Completa o caminho com './' até ter exatamente `length` bytes. Devolve '' se não couber.
func _pad(relative_path: String, length: int) -> String:
	var padding := length - relative_path.to_utf8_buffer().size()
	if padding < 0:
		return ''
	if padding == 0:
		return relative_path
	if padding % 2 == 0:
		return './'.repeat(int(padding / 2.0)) + relative_path
	if padding < 3:
		return ''
	# Tamanho ímpar: um trecho './/' (3 bytes) e o resto em pares './'
	return './'.repeat(int((padding - 3) / 2.0)) + './/' + relative_path


func _report(file_name: String) -> void:
	var key := file_name.to_lower()
	if _reported.has(key):
		return
	_reported[key] = true
	warnings.append('Textura "%s" não encontrada. Coloque uma versão PNG ou JPG dela na mesma pasta do arquivo .fbx.' % file_name)


func _index_directory(base_dir: String, relative: String, depth: int) -> void:
	var directory := base_dir if relative.is_empty() else base_dir.path_join(relative)
	var dir := DirAccess.open(directory)
	if dir == null:
		return

	for file_name in dir.get_files():
		if _indexed_files >= MAX_INDEXED_FILES:
			return
		var extension := file_name.get_extension().to_lower()
		if not LOADABLE_EXTENSIONS.has(extension):
			continue
		_indexed_files += 1
		var stem := file_name.get_basename().to_lower()
		if not _index.has(stem):
			_index[stem] = []
		_index[stem].append(file_name if relative.is_empty() else relative.path_join(file_name))

	if depth >= MAX_DEPTH:
		return
	for sub_directory in dir.get_directories():
		if sub_directory.begins_with('.'):
			continue
		_index_directory(base_dir, sub_directory if relative.is_empty() else relative.path_join(sub_directory), depth + 1)


func _u32(bytes: PackedByteArray, at: int) -> int:
	if at < 0 or at + 3 >= bytes.size():
		return -1
	return bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16) | (bytes[at + 3] << 24)


func _is_text(bytes: PackedByteArray, start: int, end: int) -> bool:
	for i in range(start, end):
		if bytes[i] < 32 or bytes[i] == 127:
			return false
	return true
