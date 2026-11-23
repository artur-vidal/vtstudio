extends Control
## Modal de importação. A janela recebe os arquivos externos via files_dropped.
signal browse_requested

const PALETTE = preload('res://front-end/pallete.tres')
const BUTTON_THEME = preload('res://front-end/components/themes/button/ButtonDourado.tres')
const FONT = preload('res://assets/fonts/Outfit/static/Outfit-Regular.ttf')

var _shade: ColorRect
var _card: PanelContainer
var _tween: Tween
var _closing := false
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_font_override('font', FONT)
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.gui_input.connect(_on_backdrop_input)
	_card = PanelContainer.new()
	add_child(_card)
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.colors[8]
	style.border_color = PALETTE.colors[3]
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_card.add_theme_stylebox_override('panel', style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override('separation', 22)
	_card.add_child(box)
	var title := _label('Arraste seus arquivos', 28, PALETTE.colors[3])
	box.add_child(title)
	_hint = _label('Modelos 3D, imagens e GIFs', 16, PALETTE.colors[10])
	box.add_child(_hint)
	var formats := VBoxContainer.new()
	formats.add_theme_constant_override('separation', 14)
	box.add_child(formats)
	_add_format_group(formats, 'MODELOS 3D', PackedStringArray(['FBX', 'GLB', 'glTF']))
	_add_format_group(formats, 'IMAGENS E ANIMAÇÕES', ImageLoader.supported_extensions())
	var browse := Button.new()
	browse.text = 'Escolher arquivos'
	browse.theme = BUTTON_THEME
	browse.custom_minimum_size.y = 42
	browse.pressed.connect(func() -> void: browse_requested.emit())
	box.add_child(browse)
	var cancel := Button.new()
	cancel.text = 'Cancelar'
	cancel.flat = true
	cancel.theme = preload('res://front-end/components/themes/button/ButtonBranco-Outline.tres')
	cancel.add_theme_color_override('font_color', PALETTE.colors[6])
	for state in ['font_hover_color', 'font_pressed_color', 'font_hover_pressed_color', 'font_focus_color']:
		cancel.add_theme_color_override(state, PALETTE.colors[10])
	var cancel_hover := StyleBoxFlat.new()
	cancel_hover.bg_color = PALETTE.colors[9]
	cancel_hover.set_corner_radius_all(6)
	cancel.add_theme_stylebox_override('hover', cancel_hover)
	cancel.add_theme_stylebox_override('pressed', cancel_hover)
	cancel.custom_minimum_size.y = 42
	cancel.pressed.connect(dismiss)
	box.add_child(cancel)
	resized.connect(_layout_card)
	hide()


func _add_format_group(parent: Control, caption: String, extensions: PackedStringArray) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override('separation', 8)
	parent.add_child(group)
	var heading := _label(caption, 12, PALETTE.colors[6])
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	group.add_child(heading)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override('h_separation', 6)
	chips.add_theme_constant_override('v_separation', 6)
	group.add_child(chips)
	for extension in extensions:
		var chip := Label.new()
		chip.text = extension if extension == 'glTF' else extension.to_upper()
		chip.add_theme_font_size_override('font_size', 13)
		chip.add_theme_color_override('font_color', PALETTE.colors[10])
		var background := StyleBoxFlat.new()
		background.bg_color = PALETTE.colors[9]
		background.set_corner_radius_all(5)
		background.content_margin_left = 9
		background.content_margin_right = 9
		background.content_margin_top = 5
		background.content_margin_bottom = 5
		chip.add_theme_stylebox_override('normal', background)
		chips.add_child(chip)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override('font_size', font_size)
	label.add_theme_color_override('font_color', color)
	return label


func _layout_card() -> void:
	_card.size = Vector2(minf(520.0, maxf(240.0, size.x - 32.0)), 0.0)
	_card.position = (size - _card.size) / 2.0


func present() -> void:
	if visible:
		return
	_closing = false
	_hint.text = 'Modelos 3D, imagens e GIFs'
	show()
	add_to_group('editor_import_modal')
	_layout_card()
	# Containers precisam de um quadro para recalcular a altura com o texto quebrado.
	await get_tree().process_frame
	if _closing or not visible:
		return
	_layout_card()
	var target := _card.position
	_card.position.y = -_card.size.y
	_shade.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_card, 'position', target, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_shade, 'modulate:a', 1.0, 0.25)


func dismiss() -> void:
	if not visible:
		return
	if _closing:
		await _tween.finished
		return
	_closing = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_card, 'position:y', -_card.size.y, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_shade, 'modulate:a', 0.0, 0.24)
	await _tween.finished
	hide()
	remove_from_group('editor_import_modal')
	_closing = false


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed('ui_cancel'):
		get_viewport().set_input_as_handled()
		dismiss()


func show_unsupported() -> void:
	_hint.text = 'Formato não suportado. Arraste um dos formatos abaixo.'


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()
