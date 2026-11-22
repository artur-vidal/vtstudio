extends Sprite2D


func _ready() -> void:
	visible = not SceneChanger.historico.is_empty()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_rect().has_point(to_local(get_global_mouse_position())):
			SceneChanger.voltar()
