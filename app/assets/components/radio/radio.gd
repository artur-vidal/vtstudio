@tool
extends CheckBox

@export var texto : String = "Option":
	set(value):
		texto = value
		text = texto

const TEMAS := {
	"Small": preload("res://components/themes/radio/RadioSmall.tres"),
	"Large": preload("res://components/themes/radio/RadioLarge.tres")
}

@export_enum("Small", "Large") var tamanho := "Small":
	set(value):
		tamanho = value
		_aplicar_tamanho()

func _ready() -> void:
	_aplicar_tamanho()

func _aplicar_tamanho() -> void:
	theme = TEMAS[tamanho]
