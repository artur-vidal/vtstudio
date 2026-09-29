extends VBoxContainer

@export var button_group: ButtonGroup

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button_group.pressed.connect(_on_opcao_selecionada)

func _on_opcao_selecionada(botao: BaseButton) -> void:
	print("Selecionado: " + botao.text)
