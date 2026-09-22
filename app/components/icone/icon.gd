@tool
extends PanelContainer

@export var textura: Texture2D:
	set(value):
		textura = value
		_aplicar_textura()

@export_enum("Small", "Medium", "Large") var tamanho := "Small":
	set(value):
		tamanho = value
		_aplicar_tamanho()

@export_enum("Vermelho", "Dourado", "Vermelho-Outline", "Dourado-Outline", "Cinza-Outline") var cor := "Vermelho":
	set(value):
		cor = value
		_aplicar_cor()

@onready var texture_rect: TextureRect = $TextureRect

func _ready() -> void:
	_aplicar_textura()
	_aplicar_tamanho()
	_aplicar_cor()

func _aplicar_textura() -> void:
	if texture_rect:
		texture_rect.texture = textura

func _aplicar_tamanho() -> void:
	var tamanhos := {
		"Small": Vector2(48, 48),
		"Medium": Vector2(64, 64),
		"Large": Vector2(80, 80),
	}
	custom_minimum_size = tamanhos[tamanho]
	size = tamanhos[tamanho]
	if texture_rect:
		texture_rect.custom_minimum_size = tamanhos[tamanho]
		texture_rect.size = tamanhos[tamanho]

func _aplicar_cor() -> void:
	var temas := {
		"Vermelho": preload("res://components/themes/IconeVermelho.tres"),
		"Dourado": preload("res://components/themes/IconeDourado.tres"),
		"Vermelho-Outline": preload("res://components/themes/IconeVermelho-Outline.tres"),
		"Dourado-Outline": preload("res://components/themes/IconeDourado-Outline.tres"),
		"Cinza-Outline": preload("res://components/themes/IconeCinza-Outline.tres"),
	}
	theme = temas[cor]
