extends Button

@export_file("*.tscn") var popup: String = "res://front-end/components/popups/amigos/amigos.tscn"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	SceneChanger.open_popup(popup)
