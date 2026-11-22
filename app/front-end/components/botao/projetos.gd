extends "res://front-end/components/botao/button.gd"

const DESTINO := "res://front-end/pages/projetos/projetos.tscn"

func _ready() -> void:
	disabled = (get_tree().current_scene.scene_file_path == DESTINO)

func _on_pressed() -> void:
	SceneChanger.load_scene(DESTINO)
