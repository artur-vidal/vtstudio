@tool
extends "res://front-end/components/botao/button.gd"

@export_file("*.tscn") var popup: String = "res://front-end/components/popups/amigos/amigos.tscn"


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	SceneChanger.open_popup(popup)
