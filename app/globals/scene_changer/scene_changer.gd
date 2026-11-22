extends Node

signal progress_changed(progress)
signal load_finished

var loading_screen: PackedScene = preload("uid://b27qm5kt2fm23")
var loaded_resource: PackedScene
var scene_path: String
var cena_atual: String = ""
var historico: Array[String] = []
var progress: Array = []
var _popup_layer: CanvasLayer


func _ready() -> void:
	set_process(false)


func load_scene(new_scene_path: String, registrar: bool = true) -> void:
	close_popup()

	if registrar:
		var origem: String = cena_atual
		if origem == "" and get_tree().current_scene:
			origem = get_tree().current_scene.scene_file_path
		if origem != "" and origem != new_scene_path:
			historico.append(origem)

	scene_path = new_scene_path
	cena_atual = new_scene_path

	var new_load_screen = loading_screen.instantiate()
	add_child(new_load_screen)
	progress_changed.connect(new_load_screen._on_progress_changed)
	load_finished.connect(new_load_screen._on_load_finished)

	await new_load_screen.loading_screen_ready

	start_load()


func voltar() -> void:
	if historico.is_empty():
		return
	var destino: String = historico.pop_back()
	load_scene(destino, false)


func start_load() -> void:
	var state = ResourceLoader.load_threaded_request(scene_path, "", true)
	if state == OK:
		set_process(true)


func _process(_delta: float) -> void:
	var load_state = ResourceLoader.load_threaded_get_status(scene_path, progress)
	match load_state:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			set_process(false)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_changed.emit(progress[0])
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_changed.emit(1.0)
			loaded_resource = ResourceLoader.load_threaded_get(scene_path)
			set_process(false)
			get_tree().change_scene_to_packed(loaded_resource)
			load_finished.emit()


func open_popup(path: String) -> Control:
	close_popup()

	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 100
	add_child(_popup_layer)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	fundo.gui_input.connect(_on_fundo_input)
	_popup_layer.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(centro)

	var popup: Control = load(path).instantiate()
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	centro.add_child(popup)
	return popup


func close_popup() -> void:
	if is_instance_valid(_popup_layer):
		_popup_layer.queue_free()
	_popup_layer = null


func notificar(texto: String, duracao: float = 2.0) -> void:
	var camada := CanvasLayer.new()
	camada.layer = 110
	add_child(camada)

	var painel := PanelContainer.new()
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.modulate.a = 0.0

	var label := Label.new()
	label.text = texto
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(label)
	camada.add_child(painel)

	await get_tree().process_frame

	var tela := get_viewport().get_visible_rect().size
	var y_final := tela.y - painel.size.y - 32.0
	painel.position = Vector2((tela.x - painel.size.x) / 2.0, tela.y)
	painel.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(painel, "position:y", y_final, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duracao)
	tween.tween_property(painel, "position:y", tela.y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(camada.queue_free)


func _on_fundo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_popup()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_popup_layer):
		close_popup()
		get_viewport().set_input_as_handled()
