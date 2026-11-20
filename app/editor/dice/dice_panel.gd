extends Control
## Selection only; the owner renders dice and reveals the resulting roll.
signal roll_requested(groups: Array)
signal close_requested

const Palette = preload("res://editor/dice/dice_palette.gd")
const BUTTON = preload("res://front-end/components/botao/Botao.tscn")
const DROPDOWN = preload("res://front-end/components/dropdown/Dropdown.tscn")
const FONT = preload("res://assets/fonts/Outfit/static/Outfit-Regular.ttf")
const SIDES = [4, 6, 8, 10, 12, 20]
const Rules = preload("res://editor/dice/dice_roll.gd")
const MAX_DICE = Rules.MAX_DICE
var rows: Dictionary = {}
var rolling := false
var roll_button: Button
var reset_button: Button
var close_button: Button
var summary: Label
var status: Label

func _ready() -> void:
	custom_minimum_size = Vector2(320, 240)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 22
	ui_theme.set_color("font_color", "Label", Palette.color(10))
	theme = ui_theme
	var shell := PanelContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_stylebox_override("panel", _style(Palette.color(8), 18, 12))
	add_child(shell)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	shell.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := _label("Rolagem de dados", 30, Palette.color(6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(title)
	var intro := _label("Combine os dados. Deixe a sorte jogar.", 20, Palette.color(4))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var explanation := _label("Soma: conta todos os valores.\nMaior: conta apenas o melhor de cada conjunto.", 18, Palette.color(10))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)
	for sides: int in SIDES:
		_add_row(content, sides)
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	summary = _label("", 22, Palette.color(6))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(summary)
	status = _label("", 18, Palette.color(4))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status)
	roll_button = _button("Rolar dados", "Dourado")
	roll_button.name = "RollButton"
	footer.add_child(roll_button)
	roll_button.pressed.connect(_request_roll)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 10)
	footer.add_child(secondary)
	reset_button = _button("Limpar", "Branco-Outline")
	reset_button.name = "ResetButton"
	secondary.add_child(reset_button)
	reset_button.pressed.connect(reset_selection)
	close_button = _button("Fechar", "Branco-Outline")
	close_button.name = "CloseButton"
	secondary.add_child(close_button)
	close_button.pressed.connect(func(): close_requested.emit())
	_refresh()

func _add_row(parent: Control, sides: int) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _style(Palette.color(9), 10, 10))
	parent.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var badge := _label("D%d" % sides, 26, Palette.color(3))
	badge.custom_minimum_size.x = 44
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var count := SpinBox.new()
	count.name = "CountD%d" % sides
	count.min_value = 0
	count.max_value = Rules.MAX_PER_GROUP
	count.step = 1
	count.value = 0
	count.custom_minimum_size = Vector2(82, 48)
	count.tooltip_text = "Quantidade de d%d (0 a %d)" % [sides, Rules.MAX_PER_GROUP]
	count.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.get_line_edit().expand_to_text_length = false
	count.get_line_edit().add_theme_constant_override("minimum_character_width", 2)
	count.get_line_edit().add_theme_color_override("font_color", Palette.color(10))
	count.get_line_edit().add_theme_stylebox_override("normal", _style(Palette.color(8), 7, 6))
	row.add_child(count)
	var mode: OptionButton = DROPDOWN.instantiate()
	mode.name = "ModeD%d" % sides
	mode.add_theme_font_size_override("font_size", 22)
	mode.get_popup().add_theme_font_size_override("font_size", 22)
	mode.clear()
	mode.add_item("Soma")
	mode.add_item("Maior")
	mode.selected = 0
	mode.custom_minimum_size = Vector2(108, 48)
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode.tooltip_text = "Como combinar os dados deste conjunto"
	row.add_child(mode)
	rows[sides] = {"count": count, "mode": mode}
	count.value_changed.connect(func(_value): _refresh())
	mode.item_selected.connect(func(_index): _refresh())

func get_roll_groups() -> Array:
	var groups: Array = []
	for sides: int in SIDES:
		var count := int(rows[sides].count.value)
		if count > 0:
			groups.append({"sides": sides, "count": count,
				"mode": "sum" if rows[sides].mode.selected == 0 else "highest"})
	return groups

func set_rolling(value: bool) -> void:
	rolling = value
	for row: Dictionary in rows.values():
		row.count.editable = not value
		row.mode.disabled = value
	if is_instance_valid(reset_button):
		reset_button.disabled = value
		_refresh()

func reset_selection() -> void:
	if rolling:
		return
	for row: Dictionary in rows.values():
		row.count.value = 0
		row.mode.selected = 0
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(summary):
		return
	var total := 0
	var parts := PackedStringArray()
	for group: Dictionary in get_roll_groups():
		total += group.count
		parts.append("%dd%d%s" % [group.count, group.sides, " ↑" if group.mode == "highest" else ""])
	summary.text = " + ".join(parts) if total > 0 else "Escolha seus dados"
	status.text = "%d / %d dados · até %d por tipo" % [total, MAX_DICE, Rules.MAX_PER_GROUP]
	if total > MAX_DICE:
		status.text = "Limite de %d dados. Reduza uma quantidade." % MAX_DICE
	elif total == 0:
		status.text = "Adicione pelo menos um dado para rolar."
	roll_button.disabled = rolling or total == 0 or total > MAX_DICE
	roll_button.text = "Rolando…" if rolling else ("Selecione seus dados" if total == 0 else "Rolar %d dado%s" % [total, "s" if total != 1 else ""])
	roll_button.add_theme_color_override("font_disabled_color", Palette.color(10))

func _request_roll() -> void:
	# Commit a manually typed quantity before evaluating the selection.
	for row: Dictionary in rows.values():
		if row.count.get_line_edit().has_focus():
			row.count.apply()
	_refresh()
	if not roll_button.disabled:
		roll_requested.emit(get_roll_groups())

func _button(caption: String, color_name: String) -> Button:
	var button: Button = BUTTON.instantiate()
	button.set("cor", color_name)
	button.text = caption
	# Godot 4.7 uses -1 for unconstrained; zero collapses the control.
	button.custom_maximum_size = Vector2(-1, -1)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_FILL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	return button

func _label(text_value: String, font_size: int, color_value: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color_value)
	return label

func _style(color_value: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color_value
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style
