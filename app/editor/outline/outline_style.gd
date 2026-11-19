class_name OutlineStyle
extends RefCounted
## Aparência do outline das miniaturas (modelos 3D e imagens): uma cor e uma espessura
## para o mouse em cima (hover) e outras para o arrasto. Ajuste tudo aqui.

const HOVER_COLOR: Color = Color(1.0, 0.8, 0.1)
const DRAG_COLOR: Color = Color(1.0, 0.35, 0.05)
## Espessuras em unidades do mundo
const HOVER_WIDTH: float = 0.07
const DRAG_WIDTH: float = 0.11
## Modelos 3D: espessura constante em pixels, independente do zoom/escala.
const MODEL_HOVER_PIXELS: float = 2.0
const MODEL_DRAG_PIXELS: float = 3.0

## Casco invertido, para modelos 3D
const HULL_SHADER: Shader = preload('res://editor/outline/outline_hull.gdshader')
const MASK_SHADER: Shader = preload('res://editor/outline/outline_mask.gdshader')
## Borda pelo canal alfa, para imagens (billboards)
const SPRITE_SHADER: Shader = preload('res://editor/outline/outline_sprite.gdshader')


static func color_for(state: MapObject.VisualState) -> Color:
	return DRAG_COLOR if state == MapObject.VisualState.DRAG else HOVER_COLOR


static func width_for(state: MapObject.VisualState) -> float:
	return DRAG_WIDTH if state == MapObject.VisualState.DRAG else HOVER_WIDTH


static func model_width_for(state: MapObject.VisualState) -> float:
	return MODEL_DRAG_PIXELS if state == MapObject.VisualState.DRAG else MODEL_HOVER_PIXELS
