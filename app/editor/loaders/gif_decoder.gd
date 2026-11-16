class_name GifDecoder
extends RefCounted
## Decodificador de GIF (87a e 89a, estático ou animado) em GDScript puro.
## O Godot não lê GIF nativamente. Este decodificador devolve os quadros já compostos
## (transparência e método de descarte aplicados), todos do tamanho da tela lógica do
## GIF, como Images RGBA8.
##
## Para ser rápido:
##  - cada quadro é descomprimido em paralelo (WorkerThreadPool), usando todos os núcleos;
##  - a descompressão LZW já grava a cor final do pixel, sem um laço extra de pintura;
##  - a composição dos quadros usa as operações nativas de Image.
##
## `decode` bloqueia até terminar, então chame-o fora da thread principal em GIFs grandes.
## `progress` pode ser lido de outra thread enquanto isso.
## A contagem de repetições (NETSCAPE) é ignorada: quem reproduz decide se faz loop.

const MAX_CODES: int = 4096
## Navegadores tratam atrasos de 0 ou 1 centésimo como 100 ms; seguimos o mesmo costume
const DEFAULT_DELAY: float = 0.1
## Como o progresso se divide: leitura do arquivo, descompressão e composição
const PROGRESS_AFTER_PARSE: float = 0.02
const PROGRESS_AFTER_DECODE: float = 0.92

## Mensagem do último erro. Fica vazia quando a decodificação dá certo.
var error: String = ''
## Progresso da decodificação, de 0.0 a 1.0
var progress: float = 0.0

var _data: PackedByteArray = PackedByteArray()
var _pos: int = 0
var _width: int = 0
var _height: int = 0
## Um dicionário por quadro (posição, paleta, dados comprimidos...)
var _frames: Array[Dictionary] = []
## Retângulo já descomprimido de cada quadro, preenchido pelas tarefas em paralelo
var _tiles: Array[Image] = []
var _mutex: Mutex = Mutex.new()


func decode(bytes: PackedByteArray) -> MiniatureImage:
	error = ''
	progress = 0.0
	_frames.clear()
	_tiles.clear()
	if not _parse(bytes):
		return null
	progress = PROGRESS_AFTER_PARSE

	_tiles.resize(_frames.size())
	var group := WorkerThreadPool.add_group_task(_decode_tile, _frames.size(), -1, false, 'Decodificando GIF')
	while not WorkerThreadPool.is_group_task_completed(group):
		var done := WorkerThreadPool.get_group_processed_element_count(group)
		progress = lerpf(PROGRESS_AFTER_PARSE, PROGRESS_AFTER_DECODE, float(done) / _frames.size())
		OS.delay_msec(10)
	WorkerThreadPool.wait_for_group_task_completion(group)

	var result := _compose()
	_frames.clear()
	_tiles.clear()
	return result


## Lê só a estrutura do arquivo, guardando os dados comprimidos de cada quadro
func _parse(bytes: PackedByteArray) -> bool:
	_data = bytes
	_pos = 0

	if bytes.size() < 13 or bytes.slice(0, 3).get_string_from_ascii() != 'GIF':
		error = 'Arquivo GIF inválido'
		return false

	_pos = 6
	_width = _u16()
	_height = _u16()
	var packed := _u8()
	_pos += 2 # cor de fundo e proporção do pixel
	if _width == 0 or _height == 0:
		error = 'GIF com dimensões inválidas'
		return false

	var global_palette := PackedByteArray()
	if (packed & 0x80) != 0:
		global_palette = _read_palette(1 << ((packed & 0x07) + 1))

	# Dados do Graphic Control Extension, que valem só para o próximo quadro
	var delay := DEFAULT_DELAY
	var disposal := 0
	var transparent_index := -1

	while _pos < _data.size():
		var block := _u8()
		if block == 0x3B: # fim do arquivo
			break
		elif block == 0x21: # extensão
			var label := _u8()
			if label == 0xF9:
				_u8() # tamanho do bloco, sempre 4
				var flags := _u8()
				disposal = (flags >> 2) & 0x07
				var centiseconds := _u16()
				delay = (centiseconds / 100.0) if centiseconds > 1 else DEFAULT_DELAY
				var transparent_value := _u8()
				transparent_index = transparent_value if (flags & 0x01) != 0 else -1
			_skip_sub_blocks()
		elif block == 0x2C: # quadro
			var frame := _read_frame(global_palette, delay, disposal, transparent_index)
			if frame.is_empty():
				break
			_frames.append(frame)
			delay = DEFAULT_DELAY
			disposal = 0
			transparent_index = -1
		else:
			error = 'Bloco desconhecido no GIF'
			break

	# Um GIF cortado no meio ainda rende os quadros que deram certo
	if _frames.is_empty():
		if error.is_empty():
			error = 'O GIF não tem quadros'
		return false
	error = ''
	return true


func _read_frame(global_palette: PackedByteArray, delay: float, disposal: int, transparent_index: int) -> Dictionary:
	var left := _u16()
	var top := _u16()
	var w := _u16()
	var h := _u16()
	var packed := _u8()

	var palette := global_palette
	if (packed & 0x80) != 0:
		palette = _read_palette(1 << ((packed & 0x07) + 1))
	if palette.is_empty():
		error = 'GIF sem paleta de cores'
		return {}

	var min_code_size := _u8()
	if min_code_size < 2 or min_code_size > 8:
		error = 'GIF com dados corrompidos'
		return {}

	return {
		'left': left,
		'top': top,
		'w': w,
		'h': h,
		'interlaced': (packed & 0x40) != 0,
		'min_code': min_code_size,
		'palette': palette,
		'transparent': transparent_index,
		'disposal': disposal,
		'delay': delay,
		'data': _read_sub_blocks(),
	}


## Roda em paralelo, uma vez por quadro: descomprime o quadro numa Image do tamanho do
## retângulo dele. Só lê `_frames`; o resultado vai para `_tiles` sob o mutex.
func _decode_tile(index: int) -> void:
	var frame := _frames[index]
	var w: int = frame['w']
	var h: int = frame['h']
	var tile: Image = null
	if w > 0 and h > 0:
		var roots := _root_colors(frame['palette'], frame['transparent'])
		var colors := _lzw_decode(frame['data'], frame['min_code'], w * h, roots)
		if frame['interlaced']:
			colors = _deinterlace(colors, w, h)
		tile = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, colors.to_byte_array())
	_mutex.lock()
	_tiles[index] = tile
	_mutex.unlock()


## Cor de cada índice da paleta, já no formato do pixel RGBA8 (R no byte menos
## significativo). O índice transparente vira 0 (alfa 0), o que dispensa um teste por pixel.
func _root_colors(palette: PackedByteArray, transparent_index: int) -> PackedInt32Array:
	var count := int(palette.size() / 3.0)
	var colors := PackedInt32Array()
	colors.resize(count)
	for i in count:
		var p := i * 3
		colors[i] = palette[p] | (palette[p + 1] << 8) | (palette[p + 2] << 16) | (255 << 24)
	if transparent_index >= 0 and transparent_index < count:
		colors[transparent_index] = 0
	return colors


## Descomprime os dados LZW de um quadro. Devolve uma COR por pixel (e não o índice da
## paleta): a tabela de códigos já guarda cores, então não é preciso pintar depois.
func _lzw_decode(data: PackedByteArray, min_code_size: int, pixel_count: int, root_colors: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(pixel_count)

	var clear_code := 1 << min_code_size
	var end_code := clear_code + 1
	var next_code := end_code + 1
	var code_size := min_code_size + 1
	var code_mask := (1 << code_size) - 1

	# Tabela de códigos: cada entrada = (código anterior, cor do último pixel)
	var prefix := PackedInt32Array()
	prefix.resize(MAX_CODES)
	var suffix := PackedInt32Array()
	suffix.resize(MAX_CODES)
	var stack := PackedInt32Array()
	stack.resize(MAX_CODES + 1)
	var root_count := root_colors.size()
	for i in clear_code:
		suffix[i] = root_colors[i] if i < root_count else 0

	var bits := 0
	var bit_count := 0
	var pos := 0
	var out_pos := 0
	var previous := -1
	var first := 0
	var data_size := data.size()

	while out_pos < pixel_count:
		while bit_count < code_size and pos < data_size:
			bits |= data[pos] << bit_count
			bit_count += 8
			pos += 1
		if bit_count < code_size:
			break # acabaram os dados
		var code := bits & code_mask
		bits >>= code_size
		bit_count -= code_size

		if code == clear_code:
			next_code = end_code + 1
			code_size = min_code_size + 1
			code_mask = (1 << code_size) - 1
			previous = -1
			continue
		if code == end_code:
			break

		if previous == -1:
			if code >= clear_code:
				break # dados corrompidos
			out[out_pos] = suffix[code]
			out_pos += 1
			previous = code
			first = suffix[code]
			continue
		if code > next_code:
			break # dados corrompidos

		# Monta a sequência de trás para frente na pilha
		var current := code
		var length := 0
		if code == next_code:
			# Caso especial: o código ainda não existe na tabela
			stack[length] = first
			length += 1
			current = previous
		while current >= clear_code:
			stack[length] = suffix[current]
			length += 1
			current = prefix[current]
		first = suffix[current]
		stack[length] = first
		length += 1

		if next_code < MAX_CODES:
			prefix[next_code] = previous
			suffix[next_code] = first
			next_code += 1
			if next_code > code_mask and code_size < 12:
				code_size += 1
				code_mask = (1 << code_size) - 1
		previous = code

		while length > 0 and out_pos < pixel_count:
			length -= 1
			out[out_pos] = stack[length]
			out_pos += 1
	return out


## Reordena as linhas de um quadro entrelaçado (as linhas vêm em 4 passadas)
func _deinterlace(colors: PackedInt32Array, w: int, h: int) -> PackedInt32Array:
	var stored_row_of := PackedInt32Array() # linha real da imagem -> linha lida no arquivo
	stored_row_of.resize(h)
	var stored := 0
	for start_and_step in [[0, 8], [4, 8], [2, 4], [1, 2]]:
		var y: int = start_and_step[0]
		while y < h:
			stored_row_of[y] = stored
			stored += 1
			y += start_and_step[1]

	var out := PackedInt32Array()
	for y in h:
		var from := stored_row_of[y] * w
		out.append_array(colors.slice(from, from + w))
	return out


## Junta os retângulos sobre uma tela do tamanho do GIF, respeitando o método de descarte.
## blend_rect com alfa 0 não altera o que já está na tela (é assim que o índice
## transparente "deixa passar" o quadro anterior).
func _compose() -> MiniatureImage:
	var result := MiniatureImage.new()
	result.size = Vector2i(_width, _height)
	var canvas := Image.create_empty(_width, _height, false, Image.FORMAT_RGBA8)
	var total := _frames.size()

	for i in total:
		var tile := _tiles[i]
		if tile == null:
			break
		var frame := _frames[i]
		var origin := Vector2i(frame['left'], frame['top'])
		var disposal: int = frame['disposal']

		# "Restaurar ao anterior" precisa do estado da tela antes de pintar este quadro
		var before := PackedByteArray()
		if disposal == 3:
			before = canvas.get_data()

		canvas.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), origin)
		result.frames.append(Image.create_from_data(_width, _height, false, Image.FORMAT_RGBA8, canvas.get_data()))
		result.delays.append(frame['delay'])

		if disposal == 2:
			canvas.fill_rect(Rect2i(origin, tile.get_size()), Color(0, 0, 0, 0))
		elif disposal == 3:
			canvas = Image.create_from_data(_width, _height, false, Image.FORMAT_RGBA8, before)
		progress = lerpf(PROGRESS_AFTER_DECODE, 1.0, float(i + 1) / total)

	if result.frames.is_empty():
		error = 'Não foi possível decodificar os quadros do GIF'
		return null
	return result


func _read_palette(color_count: int) -> PackedByteArray:
	var palette := _data.slice(_pos, _pos + color_count * 3)
	_pos += color_count * 3
	return palette


## Junta os sub-blocos de dados (tamanho + bytes, terminado por tamanho 0)
func _read_sub_blocks() -> PackedByteArray:
	var out := PackedByteArray()
	while _pos < _data.size():
		var size := _u8()
		if size == 0:
			break
		out.append_array(_data.slice(_pos, _pos + size))
		_pos += size
	return out


func _skip_sub_blocks() -> void:
	while _pos < _data.size():
		var size := _u8()
		if size == 0:
			break
		_pos += size


## Leituras seguras: depois do fim do arquivo devolvem 0 em vez de dar erro
func _u8() -> int:
	var value := 0
	if _pos < _data.size():
		value = _data[_pos]
	_pos += 1
	return value


func _u16() -> int:
	var low := _u8()
	var high := _u8()
	return low | (high << 8)
