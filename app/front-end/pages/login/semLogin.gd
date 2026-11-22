extends Label

@export_file("*.tscn") var destino: String = "res://front-end/pages/entrar_sessao/entrar_sessao.tscn"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if destino != "" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SceneChanger.load_scene(destino)
