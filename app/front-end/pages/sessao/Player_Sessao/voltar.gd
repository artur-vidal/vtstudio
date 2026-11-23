extends TextureButton

@export_file("*.tscn") var popup_anterior: String = ""
@export var ocultar_sem_historico: bool = false


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if ocultar_sem_historico and popup_anterior == "":
		visible = not SceneChanger.historico.is_empty()


func _on_pressed() -> void:
	if popup_anterior != "":
		SceneChanger.open_popup(popup_anterior)
	else:
		SceneChanger.close_popup()
		SceneChanger.voltar()
