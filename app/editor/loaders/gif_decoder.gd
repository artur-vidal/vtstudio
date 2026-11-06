class_name GifDecoder
extends RefCounted
## Decodificador de GIF (87a e 89a, estático ou animado) em GDScript puro.
## O Godot não lê GIF nativamente. Este decodificador devolve os quadros já compostos
## (transparência e método de descarte aplicados), todos do tamanho da tela lógica do
## GIF, como Images RGBA8.
##
## É lento para GIFs grandes (GDScript), então chame-o fora da thread principal.
## A contagem de repetições (NETSCAPE) é ignorada: quem reproduz decide se faz loop.

const MAX_CODES: int = 4096
## Navegadores tratam atrasos de 0 ou 1 centésimo como 100 ms; seguimos o mesmo costume
const DEFAULT_DELAY: float = 0.1

## Mensagem do último erro. Fica vazia quando a decodificação dá certo.
var error: String = ''

var _data: PackedByteArray = PackedByteArray()
var _pos: int = 0
var _width: int = 0
var _height: int = 0
var _canvas: PackedByteArray = PackedByteArray()


func decode(bytes: PackedByteArray) -> MiniatureImage:
	error = ''
	_data = bytes
	_pos = 0

	if bytes.size() < 13 or bytes.slice(0, 3).get_string_from_ascii() != 'GIF':
		error = 'Arquivo GIF inválido'
		return null

	_pos = 6
	_width = _u16()
	_height = _u16()
	var packed := _u8()
	_pos += 2 # cor de fundo e proporção do pixel
	if _width == 0 or _height == 0:
		error = 'GIF com dimensões inválidas'
		return null

	var global_palette := PackedByteArray()
	if (packed & 0x80) != 0:
		global_palette = _read_palette(1 << ((packed & 0x07) + 1))

	var result := MiniatureImage.new()
	result.size = Vector2i(_width, _height)
	_canvas = PackedByteArray()
	_canvas.resize(_width * _height * 4) # zerado = transparente

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
			if not _decode_frame(result, global_palette, delay, disposal, transparent_index):
				break
			delay = DEFAULT_DELAY
			disposal = 0
			transparent_index = -1
		else:
			error = 'Bloco desconhecido no GIF'
			break

	# Um GIF cortado no meio ainda rende os quadros que deram certo
	if result.frames.is_empty():
		if error.is_empty():
			error = 'O GIF não tem quadros'
		return null
	error = ''
	return result


func _decode_frame(result: MiniatureImage, global_palette: PackedByteArray, delay: float,
		disposal: int, transparent_index: int) -> bool:
	var left := _u16()
	var top := _u16()
	var w := _u16()
	var h := _u16()
	var packed := _u8()
	var interlaced := (packed & 0x40) != 0

	var palette := global_palette
	if (packed & 0x80) != 0:
		palette = _read_palette(1 << ((packed & 0x07) + 1))
	if palette.is_empty():
		error = 'GIF sem paleta de cores'
		return false

	var min_code_size := _u8()
	if min_code_size < 2 or min_code_size > 8:
		error = 'GIF com dados corrompidos'
		return false
	var indices := _lzw_decode(_read_sub_blocks(), min_code_size, w * h)

	# "Restaurar ao anterior" precisa do estado da tela antes de pintar este quadro
	var before := PackedByteArray()
	if disposal == 3:
		before = _canvas.duplicate()

	_paint(indices, palette, left, top, w, h, interlaced, transparent_index)
	result.frames.append(Image.create_from_data(_width, _height, false, Image.FORMAT_RGBA8, _canvas.duplicate()))
	result.delays.append(delay)

	if disposal == 2:
		_clear_rect(left, top, w, h)
	elif disposal == 3:
		_canvas = before
	return true


## Descomprime os dados LZW de um quadro. Devolve um índice de paleta por pixel.
func _lzw_decode(data: PackedByteArray, min_code_size: int, pixel_count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(pixel_count)

	var clear_code := 1 << min_code_size
	var end_code := clear_code + 1
	var next_code := end_code + 1
	var code_size := min_code_size + 1
	var code_mask := (1 << code_size) - 1

	# Tabela de códigos: cada entrada = (código anterior, último byte)
	var prefix := PackedInt32Array()
	prefix.resize(MAX_CODES)
	var suffix := PackedByteArray()
	suffix.resize(MAX_CODES)
	var stack := PackedByteArray()
	stack.resize(MAX_CODES + 1)
	for i in clear_code:
		suffix[i] = i

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
			first = code
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


## Pinta os índices do quadro sobre a tela, respeitando entrelaçamento e transparência
func _paint(indices: PackedByteArray, palette: PackedByteArray, left: int, top: int,
		w: int, h: int, interlaced: bool, transparent_index: int) -> void:
	var rows := _interlaced_rows(h) if interlaced else PackedInt32Array()
	var palette_size := palette.size()
	for row in h:
		var y := top + (rows[row] if interlaced else row)
		if y < 0 or y >= _height:
			continue
		var src := row * w
		for x in w:
			var canvas_x := left + x
			if canvas_x >= _width:
				break
			var index := indices[src + x]
			if index == transparent_index:
				continue
			var p := index * 3
			if p + 2 >= palette_size:
				continue
			var o := (y * _width + canvas_x) * 4
			_canvas[o] = palette[p]
			_canvas[o + 1] = palette[p + 1]
			_canvas[o + 2] = palette[p + 2]
			_canvas[o + 3] = 255


## Para cada linha lida do arquivo, a linha real da imagem (GIF entrelaçado, 4 passadas)
func _interlaced_rows(h: int) -> PackedInt32Array:
	var rows := PackedInt32Array()
	for start_and_step in [[0, 8], [4, 8], [2, 4], [1, 2]]:
		var y: int = start_and_step[0]
		while y < h:
			rows.append(y)
			y += start_and_step[1]
	return rows


## Método de descarte 2: apaga a área do quadro (volta a ser transparente)
func _clear_rect(left: int, top: int, w: int, h: int) -> void:
	var x0 := maxi(left, 0)
	var x1 := mini(left + w, _width)
	for y in range(maxi(top, 0), mini(top + h, _height)):
		for o in range((y * _width + x0) * 4, (y * _width + x1) * 4):
			_canvas[o] = 0


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
