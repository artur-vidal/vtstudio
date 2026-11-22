@tool
extends "res://front-end/components/icone/icon.gd"

@export_file("*.tscn") var popup: String = "res://front-end/components/popups/perfil/perfil.tscn"

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for filho in find_children("*", "Control", true, false):
		filho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if popup != "" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SceneChanger.open_popup(popup)

func _on_botao_premium_pressed() -> void:
	pass # Replace with function body.


func _on_botao_dourado_2_pressed() -> void:
	pass # Replace with function body.
