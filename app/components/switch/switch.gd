@tool
extends CheckButton

const TEMAS := {
	"Small": preload("res://components/themes/switch/Switch_Small.tres"),
	"Large": preload("res://components/themes/switch/Switch_Large.tres")
}

@export_enum("Small", "Large") var tamanho := "Small":
	set(value):
		tamanho = value
		_aplicar_tamanho()


func _ready() -> void:
	_aplicar_tamanho()


func _aplicar_tamanho() -> void:
	theme = TEMAS[tamanho]
