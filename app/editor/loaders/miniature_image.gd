class_name MiniatureImage
extends RefCounted
## Imagem carregada em tempo de execução: um quadro (PNG, JPG...) ou vários (GIF).
## Guarda só Images, que podem ser criadas em outra thread; as texturas
## (ImageTexture) são geradas sob demanda na thread principal.

## Quadros já compostos, todos com o mesmo tamanho
var frames: Array[Image] = []
## Duração de cada quadro, em segundos (mesmo índice de `frames`)
var delays: PackedFloat32Array = PackedFloat32Array()
var size: Vector2i = Vector2i.ZERO


func is_animated() -> bool:
	return frames.size() > 1


func make_textures() -> Array[ImageTexture]:
	var textures: Array[ImageTexture] = []
	for frame in frames:
		textures.append(ImageTexture.create_from_image(frame))
	return textures
