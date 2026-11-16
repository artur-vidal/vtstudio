class_name MiniatureLoaderUI
extends CanvasLayer
## Interface para escolher modelos 3D e imagens do sistema de arquivos, com o jogo rodando.
##
## Esta interface não cria nada: só emite `files_chosen`. Na cena, ligue:
##   - files_chosen                        -> MiniatureSpawner.spawn_files
##   - MiniatureSpawner.miniature_spawned  -> show_loaded
##   - MiniatureSpawner.spawn_failed       -> show_failed
##   - MiniatureSpawner.spawn_warning      -> show_warning
##   - MiniatureSpawner.load_progress      -> show_progress

## Emitido quando o usuário escolhe (ou arrasta para a janela) arquivos suportados
signal files_chosen(paths: PackedStringArray)

@export var button_text: String = 'Carregar miniatura...'
## Aceita também arquivos arrastados para a janela do jogo
@export var accept_dropped_files: bool = true
## Segundos até a mensagem de status sumir
@export var message_duration: float = 5.0
## Avisos e falhas pedem uma ação do usuário, então ficam mais tempo na tela
@export var warning_duration: float = 12.0
## Quantos avisos aparecem ao mesmo tempo (os mais antigos saem primeiro)
@export var max_warning_lines: int = 6
## Largura das mensagens, em pixels. O texto que passa disso quebra em mais linhas.
@export var message_width: float = 520.0

var _status: Label
var _warnings: Label
var _progress_box: VBoxContainer
var _dialog: FileDialog
var _status_serial: int = 0
var _warning_serial: int = 0
var _warning_lines: PackedStringArray = PackedStringArray()
## caminho do arquivo -> { 'row': HBoxContainer, 'bar': ProgressBar }
var _progress_rows: Dictionary = {}


func _ready() -> void:
	_build_ui()
	if accept_dropped_files:
		get_window().files_dropped.connect(_on_files_dropped)


func show_loaded(miniature: MapObject, path: String) -> void:
	_remove_progress(path)
	_show_status('Miniatura criada: %s' % miniature.name)


func show_failed(path: String, message: String) -> void:
	_remove_progress(path)
	_add_warning('Falha ao carregar %s: %s' % [path.get_file(), message])


func show_warning(path: String, message: String) -> void:
	_add_warning('Aviso em %s: %s' % [path.get_file(), message])


## Mostra (ou atualiza) a barra de progresso de um arquivo; some quando ele termina
func show_progress(path: String, fraction: float) -> void:
	if not _progress_rows.has(path):
		_progress_rows[path] = _create_progress_row(path)
	var bar: ProgressBar = _progress_rows[path]['bar']
	bar.value = fraction


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
	# Sem foco: senão, depois do primeiro clique, espaço e Enter acionariam o botão de novo
	button.focus_mode = Control.FOCUS_NONE
	# Largura natural do texto, em vez de esticar até a largura das mensagens
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(_open_dialog)
	box.add_child(button)

	_progress_box = VBoxContainer.new()
	_progress_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_progress_box)

	_status = _create_label()
	box.add_child(_status)
	_warnings = _create_label()
	_warnings.add_theme_color_override('font_color', Color(1.0, 0.8, 0.3))
	box.add_child(_warnings)

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


## Rótulo que quebra linha, escondido até ter o que mostrar
func _create_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(message_width, 0.0)
	label.visible = false
	return label


func _create_progress_row(path: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = path.get_file()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.custom_minimum_size = Vector2(180, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	_progress_box.add_child(row)
	return {'row': row, 'bar': bar}


func _remove_progress(path: String) -> void:
	if not _progress_rows.has(path):
		return
	(_progress_rows[path]['row'] as Control).queue_free()
	_progress_rows.erase(path)


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
		_show_status('Nenhum arquivo suportado foi solto na janela')
		return
	_choose(supported)


func _choose(paths: PackedStringArray) -> void:
	_show_status('Carregando %d arquivo(s)...' % paths.size())
	files_chosen.emit(paths)


## Filtro do FileDialog, ex.: '*.glb, *.gltf'
func _pattern(extensions: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for extension in extensions:
		parts.append('*.%s' % extension)
	return ', '.join(parts)


## Mensagem de status: uma só, a mais recente substitui a anterior
func _show_status(text: String) -> void:
	_status_serial += 1
	var serial := _status_serial
	_status.text = text
	_status.visible = true
	await get_tree().create_timer(message_duration).timeout
	if serial == _status_serial:
		_status.visible = false


## Avisos e falhas se ACUMULAM (um FBX pode faltar várias texturas) e não são apagados por
## mensagens de status. Somem juntos depois de `warning_duration` sem novidades.
func _add_warning(text: String) -> void:
	_warning_lines.append(text)
	while _warning_lines.size() > max_warning_lines:
		_warning_lines.remove_at(0)
	_warning_serial += 1
	var serial := _warning_serial
	_warnings.text = '\n'.join(_warning_lines)
	_warnings.visible = true
	await get_tree().create_timer(warning_duration).timeout
	if serial == _warning_serial:
		_warning_lines.clear()
		_warnings.visible = false
