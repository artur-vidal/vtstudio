@tool
extends "res://front-end/components/botao/button.gd"

@export var mensagem: String = "Sessão Hospedada"
@export var duracao: float = 2.0

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	SceneChanger.notificar(mensagem, duracao)
