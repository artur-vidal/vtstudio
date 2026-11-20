extends RefCounted
## Shared palette: the project's resource remains the single source of colors.
const SOURCE = preload("res://front-end/pallete.tres")

static func color(index: int) -> Color:
	return SOURCE.colors[clampi(index, 0, SOURCE.colors.size() - 1)]
