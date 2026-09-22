@tool
extends Button

@export_enum("Small", "Medium", "Large") var tamanho := "Small":
	set(value):
		tamanho = value
		_aplicar_tamanho()

@export_enum("Dourado", "Vermelho", "Cinza-Outline", "Vermelho-Outline", "Dourado-Outline") var cor := "Dourado":
	set(value):
		cor = value
		_aplicar_cor()

func _ready() -> void:
	_aplicar_tamanho()
	_aplicar_cor()

func _aplicar_tamanho() -> void:
	var tamanhos := {
		"Small": Vector2(96, 42),
		"Medium": Vector2(144, 42),
		"Large": Vector2(144, 60),
	}
	custom_minimum_size = tamanhos[tamanho]
	size = tamanhos[tamanho]

func _aplicar_cor() -> void:
	var temas := {
		"Dourado": preload("res://components/themes/ButtonDourado.tres"),
		"Vermelho": preload("res://components/themes/ButtonVermelho.tres"),
		"Cinza-Outline": preload("res://components/themes/ButttonCinza-Outline.tres"),
		"Vermelho-Outline": preload("res://components/themes/ButtonVermelho-Outline.tres"),
		"Dourado-Outline": preload("res://components/themes/ButtonDourado-Outline.tres"),
	}
	theme = temas[cor]
