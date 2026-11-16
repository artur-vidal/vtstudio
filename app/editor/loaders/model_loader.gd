class_name ModelLoader
extends RefCounted
## Carrega modelos 3D (GLB, glTF e FBX) do sistema de arquivos em tempo de execução,
## sem depender do importador do editor. Funciona também em projetos exportados.
##
## Uso:
##   var loader := ModelLoader.new()
##   var model := loader.load_file('C:/modelos/personagem.glb')
##   if model == null:
##       push_warning(loader.error)
##   for warning in loader.warnings:
##       print(warning)

const GLTF_EXTENSIONS: PackedStringArray = ['glb', 'gltf']
const FBX_EXTENSIONS: PackedStringArray = ['fbx']

## Mensagem do último erro. Fica vazia quando o carregamento dá certo.
var error: String = ''
## Avisos de um carregamento que deu certo (ex.: textura de um FBX não encontrada)
var warnings: PackedStringArray = PackedStringArray()


static func supported_extensions() -> PackedStringArray:
	return GLTF_EXTENSIONS + FBX_EXTENSIONS


static func is_supported(path: String) -> bool:
	return path.get_extension().to_lower() in supported_extensions()


## Devolve a raiz do modelo (ainda fora da árvore de cena) ou null se falhar.
## O chamador é dono do nó devolvido.
func load_file(path: String) -> Node3D:
	error = ''
	warnings = PackedStringArray()
	if not is_supported(path):
		error = 'Formato não suportado: .%s' % path.get_extension()
		return null

	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		error = 'Não foi possível ler o arquivo: %s' % error_string(FileAccess.get_open_error())
		return null

	# FBXDocument/FBXState têm a mesma API do glTF; só mudam as classes
	var is_fbx := path.get_extension().to_lower() in FBX_EXTENSIONS
	var document: GLTFDocument = FBXDocument.new() if is_fbx else GLTFDocument.new()
	var state: GLTFState = FBXState.new() if is_fbx else GLTFState.new()

	# O FBX guarda caminhos absolutos da máquina de quem o criou: corrige antes de ler
	if is_fbx:
		var resolver := FbxTextureResolver.new()
		bytes = resolver.resolve(bytes, path)
		warnings = resolver.warnings

	# Buffers e texturas externos (.gltf + .bin/.png) são procurados na pasta do arquivo.
	# O Godot trata o 2º argumento como um caminho de ARQUIVO e tira o último nome para
	# achar a pasta; por isso passamos o caminho do arquivo, e não o da pasta.
	var status := document.append_from_buffer(bytes, path, state)
	if status != OK:
		error = 'Falha ao interpretar o modelo: %s' % error_string(status)
		return null

	var root := document.generate_scene(state) as Node3D
	if root == null:
		error = 'O arquivo não contém uma cena 3D'
		return null

	root.name = path.get_file().get_basename().validate_node_name()
	return root
