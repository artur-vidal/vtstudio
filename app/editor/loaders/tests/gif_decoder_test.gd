extends Node
## Teste de fumaça do GifDecoder. Rode esta cena (F6).
##
## Decodifica GIFs gerados com o Pillow (cobrindo LZW com códigos de até 12 bits, quadros
## parciais com deslocamento, transparência com descarte 2 e entrelaçamento) e compara cada
## quadro (SHA-256, ignorando o RGB de pixels totalmente transparentes), o tamanho e os
## atrasos com o resultado esperado, calculado pelo próprio Pillow.
##
## Também grava os GIFs em user://gif_fixtures/ para testar o carregamento pela interface.

const FIXTURES: Dictionary = {
	'noise': {
		'size': [32, 32],
		'delays': [0.05, 0.1, 0.2],
		'hashes': [
			'386ca95a2d7b93d011b84bfd9d5dc272c86d81db1cf83abad772ed6df81fcb47',
			'19446d5e6744ed9a552c2f74fdd41173c7dcea610c2ebb27ae0033f0dc39cf6c',
			'bbca1e625ab3cf10a2f57a3d76a3e3bb4c92addbff7b8a39cb010f8a5116ae39',
		],
		'b64': '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',
	},
	'partial': {
		'size': [40, 30],
		'delays': [0.1, 0.1, 0.1],
		'hashes': [
			'ec8d50813ff28954fe9f4f4d7d6eefab76ba6060b79b042853dba2066bcc06bc',
			'a5df374612467ff545eaf2c1a6164708d527d606aea66cae5ff5b2ba4a61d954',
			'b08a9bbd4a791216360aa8f9f6cdc1aa69358bd55a45a8926d28dec57ede1b1f',
		],
		'b64': 'R0lGODlhKAAeAIIAAOfu52Fe818w5JtILhXK51AHIB4SYXsP7SH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAKAAeAAAI/wALHBgwgMABAAEOEDAQgECBgggDMFwYAAAAggAOGNgYoGCBhgUAMBQwoGLGAyQHCuC4cQAAAgQurqyYMmYBigE6uiwgUABKAwIEECA4gKSBAxIjvhxgYKFCAQFSNsTY8KhLAEILQNV6QKvFrjERInUINWFIATwTJj24MWLOhQWOHkD6MuHFhAoB3CSJdu6AuEMNEBT8MGhXhASgzg18VODHly9vYrW6VIDYAB8JPs2I1ePKkht9DhTpuKTOiZIfd216EDRWrqI7PoUpOLFBphUNWGSIVPHGoXPRNu6oO7HFoi4dPkQ6lqlIoERJauVJNGrRqhKh6+6Y9qHar3w7Bv8lQBMp5qMG4v49vrKreqh6Jf6FGRUoT6CCtxqsGLKgQ6ZQWZVUTgVpdNF2MDnEW27t+SSSRgs5ZFCCx02mW1zxMaWQSwmRlBtSO231k0LpCSWVhEMNRZRFLy1kUUfkWSdQV3/1lNNAENqHVmLpmZWTXDFN1RBY0nWn0JEPCYZZSHERBlRQCcXkklAiNYSZlY8FqJlA6fEUG2lVHhRSdnzZx1RTMSnUUFCciSneQwPgKBRQE2r00UC6FdXURRkJBKCOtmFlWVH64dXQgSWNdlRWFO33UYDMPViQXUVFGNdUuN1kEJc5QRWUURkRiFV255W5GmnJPXQTUoSRJ9RQWmGKVFJKXWK2H0olJaZVRf9ppZhI4+lm1EEzAbreZMw1aZBGDJ134Usb3dRRQs6BuFBJcRmVU1R2paiXYhqhlVyfDqE0EEQ1ErsiSAv1NdKkBZEEU2aJxasWXS2OpCKVbBpI7JIHJablhrfl5RJKXmmUV6dFQavXfisNJZpejU2JkoMHBmgQQxfRp2FAACH5BAEKAAgALAwABQAKAAoAgufu52Fe818w5JtILhXK51AHIB4SYXsP7QhYAA0AMFCggAAAAwgcEEAAAAEDBgQcKDDgwACHAw4GWDhgQAACDAuA3GgggMcABSAaAEmgo4CUIi8SCCDwwAECFAk8XGiyZEcDAwoEMAkgAIACEyMqBHAgIAAh+QQBCgAIACwZABIADQAKAILn7udhXvNfMOSbSC4VyudQByAeEmF7D+0IZQALECggwACAAwIAACCw8MAAhAcCRCxw4ECBhQYKHjAwgICBgR03VjwAYIBAAwYvCghgIGIAAAJIAqC4EWTFACZJDkApYIBJAQVwDlgJIADBmgQeJsSJMGnLogYlGq0o0OTAjQEBADs=',
	},
	'transparent': {
		'size': [32, 32],
		'delays': [0.1, 0.1, 0.1, 0.1],
		'hashes': [
			'bc088347e9453ea85f6c45d663e1fd75c1bde5c91f16a97488de1dc04d910b4a',
			'b8adedbcc3ad2371ed6f7d225d01761106f3282d1cc5f10f23b4126211c1c880',
			'8f5443a68c3088a6aa4c77752004f44aa7acbae146737572767c00a2c8c38cb8',
			'1ab306f727b29a23fa196d56ef750417cfa79a17f69effadde9852ef1b9a2c5e',
		],
		'b64': 'R0lGODlhIAAgAIEAAAAAAP8AAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQJCgAAACwAAAAAIAAgAAAITQABCBxIsKDBgwgTKlzIsKHDhwwDSJwoESJCihQtHsQ4UaNBjhU9EgQZQORIkCYHkkwpcCXLlzBjypxJs6bNmzhz6tzJs6fPn0CDJgwIACH5BAkKAAAALAgACAAIAAgAgQAAAP8AAAAAAAAAAAgPAAMIHEiwoMGDCBMqTBgQACH5BAkKAAAALAwADAAIAAgAgQAAAP8AAAAAAAAAAAgPAAMIHEiwoMGDCBMqTBgQACH5BAkKAAAALBAAEAAIAAgAgQAAAP8AAAAAAAAAAAgPAAMIHEiwoMGDCBMqTBgQADs=',
	},
	'interlaced': {
		'size': [20, 20],
		'delays': [0.1],
		'hashes': [
			'852fe7589bd680b37b9cf24a10741fa5cfd4d87a2ada8470ead9be802e2ab5bf',
		],
		'b64': 'R0lGODdhFAAUAIUAANLe2NLMz67Yw8bAw9KuwK6urpDYtHLYpYTAopCun3KukFTYljbYh0jAhBLeeBLMbxLAaVSugTauchKuYNKWtNKEq66Qn9Jyoq5ykJCQkHKQgZBygXJyclSQcjaQY0hyXRKWVBKESxJyQtJaltJIja5UgdI2hK42cpBUcnJUY5A2Y3I2VNIeeNIMb64YY8YAY5AYVHIYRYQAQlRUVDZURVQ2RTY2NhJaNhJILRI2JFQYNjYYJ0gAJBIeGBIMDxIACSwAAAAAFAAUAEAI/wB/CPzBo2BBGQgRunjBsEWLGxBpSJxBMUUKFBhLlBjBcQSEjxAkNBipQAGCkwUKDFgZIECOlzls2KhBc8UKFThP6DTBMwSInx48dBiqQUOGoxaSUljqo4fTHTt0SI0RA4ZVF1hZaMXBFcfEihczliBBloSIsyE+qP3Aoe2GtxgwXJhbYYLdCRIkRNhbMoHflAUICH7goDADBgsSHzhgoLGAxwAi+5jsAyqPqTFkXF3osIXTHlCjYrYKI6tWFjBlzqx5M+cJniZI4IB44+sMixhRaNzI8exZGmvbcni7Ia7cuSGShwj6gahRpBYqSK/wE0RQoc6PZlC6lMLdvCL5miD8q1IwgQfoHxxuoPgAAscCBrQMUNjBYcTtGxuAHBlAQAA7',
	},
}

## Texto do resultado (também aparece na tela)
var report: String = ''
var all_passed: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute('user://gif_fixtures')
	var lines := PackedStringArray()
	var passed := 0
	for fixture_name in FIXTURES:
		var fixture: Dictionary = FIXTURES[fixture_name]
		var bytes := Marshalls.base64_to_raw(fixture['b64'])
		_save_fixture(fixture_name, bytes)
		var problem := _check(bytes, fixture)
		if problem.is_empty():
			passed += 1
			lines.append('OK     %s' % fixture_name)
		else:
			lines.append('FALHA  %s: %s' % [fixture_name, problem])

	all_passed = passed == FIXTURES.size()
	lines.append('')
	lines.append('%d de %d GIFs corretos' % [passed, FIXTURES.size()])
	report = char(10).join(lines)
	print(report)

	var label := Label.new()
	label.text = report
	label.position = Vector2(16, 16)
	add_child(label)


## Devolve uma descrição do problema, ou texto vazio se o GIF decodificou como esperado
func _check(bytes: PackedByteArray, fixture: Dictionary) -> String:
	var decoder := GifDecoder.new()
	var result := decoder.decode(bytes)
	if result == null:
		return 'não decodificou (%s)' % decoder.error

	var size: Array = fixture['size']
	if result.size != Vector2i(size[0], size[1]):
		return 'tamanho %s, esperado %s' % [result.size, size]

	var hashes: Array = fixture['hashes']
	var delays: Array = fixture['delays']
	if result.frames.size() != hashes.size():
		return '%d quadros, esperado %d' % [result.frames.size(), hashes.size()]

	for i in hashes.size():
		if _frame_hash(result.frames[i]) != hashes[i]:
			return 'o quadro %d é diferente do esperado' % i
		if not is_equal_approx(result.delays[i], float(delays[i])):
			return 'atraso do quadro %d é %s, esperado %s' % [i, result.delays[i], delays[i]]
	return ''


## SHA-256 do RGBA do quadro, ignorando o RGB de pixels totalmente transparentes
func _frame_hash(frame: Image) -> String:
	var data := frame.get_data()
	for i in range(0, data.size(), 4):
		if data[i + 3] == 0:
			data[i] = 0
			data[i + 1] = 0
			data[i + 2] = 0
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _save_fixture(fixture_name: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open('user://gif_fixtures/%s.gif' % fixture_name, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
