class_name MiniatureLoaderUI
extends CanvasLayer
## Interface para escolher modelos 3D e imagens do sistema de arquivos, com o jogo rodando.
##
## Esta interface não cria nada: só emite `files_chosen`. Na cena, ligue:
##   - files_chosen             -> MiniatureSpawner.spawn_files
##   - MiniatureSpawner.miniature_spawned -> show_loaded
##   - MiniatureSpawner.spawn_failed      -> show_failed

## Emitido quando o usuário escolhe (ou arrasta para a janela) arquivos suportados
signal files_chosen(paths: PackedStringArray)

@export var button_text: String = 'Carregar miniatura...'
## Aceita também arquivos arrastados para a janela do jogo
@export var accept_dropped_files: bool = true
## Segundos até a mensagem de status sumir
@export var message_duration: float = 5.0

var _message: Label
var _dialog: FileDialog
var _message_serial: int = 0


func _ready() -> void:
	_build_ui()
	if accept_dropped_files:
		get_window().files_dropped.connect(_on_files_dropped)


func show_loaded(miniature: MapObject, _path: String) -> void:
	_show_message('Miniatura criada: %s' % miniature.name)


func show_failed(path: String, message: String) -> void:
	_show_message('Falha ao carregar %s: %s' % [path.get_file(), message])


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ['left', 'top', 'right', 'bottom']:
		margin.add_theme_constant_override('margin_' + side, 12)
	add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	var button := Button.new()
	button.text = button_text
	button.pressed.connect(_open_dialog)
	box.add_child(button)

	_message = Label.new()
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.visible = false
	box.add_child(_message)

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = 'Escolher modelos 3D ou imagens'
	_dialog.add_filter(_pattern(ModelLoader.supported_extensions() + ImageLoader.supported_extensions()), 'Modelos 3D e imagens')
	_dialog.add_filter(_pattern(ModelLoader.supported_extensions()), 'Modelos 3D')
	_dialog.add_filter(_pattern(ImageLoader.supported_extensions()), 'Imagens')
	_dialog.files_selected.connect(_on_files_selected)
	add_child(_dialog)


func _open_dialog() -> void:
	_dialog.popup_centered_ratio(0.7)


func _on_files_selected(paths: PackedStringArray) -> void:
	_choose(paths)


func _on_files_dropped(paths: PackedStringArray) -> void:
	var supported := PackedStringArray()
	for path in paths:
		if ModelLoader.is_supported(path) or ImageLoader.is_supported(path):
			supported.append(path)
	if supported.is_empty():
		_show_message('Nenhum arquivo suportado foi solto na janela')
		return
	_choose(supported)


func _choose(paths: PackedStringArray) -> void:
	_show_message('Carregando %d arquivo(s)...' % paths.size())
	files_chosen.emit(paths)


## Filtro do FileDialog, ex.: '*.glb, *.gltf'
func _pattern(extensions: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for extension in extensions:
		parts.append('*.%s' % extension)
	return ', '.join(parts)


## Mostra a mensagem e a esconde depois de `message_duration`, a menos que outra a substitua
func _show_message(text: String) -> void:
	_message_serial += 1
	var serial := _message_serial
	_message.text = text
	_message.visible = true
	await get_tree().create_timer(message_duration).timeout
	if serial == _message_serial:
		_message.visible = false
