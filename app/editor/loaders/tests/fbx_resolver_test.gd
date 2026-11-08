extends Node
## Teste de fumaça do FbxTextureResolver. Rode esta cena (F6).
##
## O PikminExport.fbx pede uma textura (Pikmin01_EyeShape.psd) cujo caminho aponta para uma
## pasta do Maya de outra pessoa. Este teste copia o FBX para user://fbx_fixture/ e roda dois
## cenários:
##   - sem a textura por perto: o carregador AVISA que ela falta e o Godot não carrega imagem;
##   - com um PNG de mesmo nome numa SUBPASTA: o resolvedor a encontra e o Godot a CARREGA.
## Tudo acontece em user://, então nada é criado dentro do projeto.
##
## O teste confere se o Godot carrega a IMAGEM (state.get_images()), e não se ela aparece num
## material: essa textura do Pikmin é uma máscara dos olhos, que o importador de FBX do Godot
## não liga a nenhum slot de material, então o modelo fica igual com ou sem ela.

const SOURCE_FBX: String = 'res://assets/models/temporary/PikminExport.fbx'
const TEXTURE_NAME: String = 'Pikmin01_EyeShape'
const DIRECTORY: String = 'user://fbx_fixture'

## Texto do resultado (também aparece na tela)
var report: String = ''
var all_passed: bool = false


func _ready() -> void:
	var results := {
		'sem a textura (deve avisar)': _check_without_texture(),
		'com a textura numa subpasta (deve carregar a imagem)': _check_with_texture(),
	}

	var lines := PackedStringArray()
	var passed := 0
	for scenario in results:
		var problem: String = results[scenario]
		if problem.is_empty():
			passed += 1
			lines.append('OK     %s' % scenario)
		else:
			lines.append('FALHA  %s: %s' % [scenario, problem])
	all_passed = passed == results.size()
	lines.append('')
	lines.append('%d de %d cenários corretos' % [passed, results.size()])
	report = char(10).join(lines)
	print(report)

	var label := Label.new()
	label.text = report
	label.position = Vector2(16, 16)
	add_child(label)


func _check_without_texture() -> String:
	var fbx_path := _prepare(DIRECTORY.path_join('sem_textura'), false)
	var loader := ModelLoader.new()
	var model := loader.load_file(fbx_path)
	if model == null:
		return 'o modelo não carregou (%s)' % loader.error
	model.free()
	if loader.warnings.size() != 1 or not loader.warnings[0].contains(TEXTURE_NAME):
		return 'esperava 1 aviso sobre %s, veio: %s' % [TEXTURE_NAME, loader.warnings]
	var images := _loaded_image_count(fbx_path)
	if images != 0:
		return 'não devia carregar imagem, mas carregou %d' % images
	return ''


func _check_with_texture() -> String:
	var fbx_path := _prepare(DIRECTORY.path_join('com_textura'), true)
	var loader := ModelLoader.new()
	var model := loader.load_file(fbx_path)
	if model == null:
		return 'o modelo não carregou (%s)' % loader.error
	model.free()
	if not loader.warnings.is_empty():
		return 'não devia haver avisos, veio: %s' % loader.warnings
	var images := _loaded_image_count(fbx_path)
	if images != 1:
		return 'esperava 1 imagem carregada pelo Godot, veio %d' % images
	return ''


## Copia o FBX para `directory`; com `with_texture`, cria o PNG numa subpasta 'textures'
func _prepare(directory: String, with_texture: bool) -> String:
	var textures_directory := directory.path_join('textures')
	DirAccess.make_dir_recursive_absolute(textures_directory)

	var fbx_path := directory.path_join('PikminExport.fbx')
	var file := FileAccess.open(fbx_path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(SOURCE_FBX))
	file.close()

	var png_path := textures_directory.path_join(TEXTURE_NAME + '.png')
	if with_texture:
		var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.MAGENTA)
		image.save_png(png_path)
	elif FileAccess.file_exists(png_path):
		DirAccess.remove_absolute(png_path)
	return fbx_path


## Quantas imagens o Godot conseguiu carregar ao ler o FBX já corrigido pelo resolvedor
## (-1 se o FBX nem foi lido)
func _loaded_image_count(fbx_path: String) -> int:
	var resolver := FbxTextureResolver.new()
	var bytes := resolver.resolve(FileAccess.get_file_as_bytes(fbx_path), fbx_path)
	var document := FBXDocument.new()
	var state := FBXState.new()
	if document.append_from_buffer(bytes, fbx_path, state) != OK:
		return -1
	var count := 0
	for image in state.get_images():
		if image != null:
			count += 1
	return count
