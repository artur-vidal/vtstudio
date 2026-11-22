extends "res://front-end/components/botao/button.gd"



func _on_pressed() -> void:
	SceneChanger.load_scene("res://front-end/pages/sessao/Player_Sessao/PlayerSessao.tscn")
