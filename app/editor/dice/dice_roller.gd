extends CanvasLayer
## Self-contained screen-space dice tray, usable over any editor scene.
signal roll_completed(result: Dictionary)

const DicePanel = preload("res://editor/dice/dice_panel.gd")
const Stage = preload("res://editor/dice/dice_stage.gd")
const Rules = preload("res://editor/dice/dice_roll.gd")
const Palette = preload("res://editor/dice/dice_palette.gd")
const ButtonScene = preload("res://front-end/components/botao/Botao.tscn")
## Cor do botão de dados no canto superior direito, usando os temas do front-end.
@export_enum('Vermelho', 'Dourado', 'Cinza-Outline', 'Vermelho-Outline', 'Dourado-Outline', 'Branco-Outline') var launcher_color: String = 'Vermelho':
	set(value):
		launcher_color = value
		if is_instance_valid(launcher):
			launcher.set('cor', value)
var rng := RandomNumberGenerator.new()
var screen: Control
var panel: Control
var stage: Node3D
var viewport: SubViewport
var viewport_container: SubViewportContainer
var result_box: VBoxContainer
var result_number: Label
var result_title: Label
var breakdown: Label
var status: Label
var actions: HBoxContainer
var launcher: Button
var last_result: Dictionary = {}
var last_groups: Array = []
var busy := false
var result_tween: Tween
var suspended: Dictionary = {}
var sparks: Array[Control] = []
var panel_tween: Tween
var screen_tween: Tween
var reveal_tween: Tween
var closing := false
const RESULT_PAUSE := 1.0

func _ready() -> void:
	layer = 20
	rng.randomize()
	launcher = _button('', launcher_color)
	launcher.icon = preload('res://assets/images/dadinho.png')
	launcher.expand_icon = true
	launcher.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	launcher.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	launcher.add_theme_constant_override('icon_max_width', 30)
	launcher.tooltip_text = 'Rolar dados'
	launcher.focus_mode = Control.FOCUS_NONE
	launcher.pressed.connect(open)
	add_child(launcher)
	launcher.custom_minimum_size = Vector2(48, 48)
	launcher.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	launcher.offset_left = -60
	launcher.offset_right = -12
	launcher.offset_top = 12
	launcher.offset_bottom = 60
	screen = Control.new()
	screen.name = "DiceScreen"
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.42)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container = SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(viewport_container)
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport_container.add_child(viewport)
	stage = Stage.new()
	viewport.add_child(stage)
	stage.settled.connect(_settled)
	status = _label("SUA PRÓXIMA JOGADA", 22)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.offset_top = 25
	status.offset_bottom = 55
	result_box = VBoxContainer.new()
	result_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_box.add_theme_constant_override("separation", 0)
	screen.add_child(result_box)
	result_title = _label("RESULTADO", 26)
	result_number = _label("0", 108)
	result_number.add_theme_font_override("font", preload("res://assets/fonts/Outfit/static/Outfit-SemiBold.ttf"))
	breakdown = _label("", 22)
	breakdown.mouse_filter = Control.MOUSE_FILTER_PASS
	breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Label in [result_title, result_number, breakdown]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_box.add_child(label)
	actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	screen.add_child(actions)
	var again := _button("Rolar de novo", "Dourado")
	again.pressed.connect(func(): _roll(last_groups))
	actions.add_child(again)
	var edit := _button("Editar", "Dourado-Outline")
	edit.pressed.connect(_edit)
	actions.add_child(edit)
	var close_button := _button("Fechar", "Cinza-Outline")
	close_button.pressed.connect(close)
	actions.add_child(close_button)
	panel = DicePanel.new()
	panel.name = "DicePanel"
	screen.add_child(panel)
	panel.roll_requested.connect(_roll)
	panel.close_requested.connect(close)
	screen.resized.connect(_layout)
	_layout()
	screen.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	result_box.hide()
	actions.hide()

func _button(caption: String, color: String) -> Button:
	var button := ButtonScene.instantiate() as Button
	button.set("cor", color)
	button.text = caption
	button.custom_maximum_size = Vector2(-1, -1)
	button.add_theme_font_override("font", preload("res://assets/fonts/Outfit/static/Outfit-Medium.ttf"))
	button.add_theme_font_size_override("font_size", 20)
	if color.ends_with("Outline"):
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Palette.color(6))
	return button

func _label(caption: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", preload("res://assets/fonts/Outfit/static/Outfit-Medium.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.color(6))
	return label

func _layout() -> void:
	var available := screen.size
	if not panel_tween or not panel_tween.is_running():
		panel.position = Vector2(24 if available.x > 600 else 12, 70)
	panel.size = Vector2(minf(460, available.x - 24), maxf(100, available.y - 90))
	var result_width := minf(980, available.x - 32)
	result_box.position = Vector2((available.x - result_width) * 0.5, available.y * 0.5 - 165)
	result_box.size = Vector2(result_width, 300)
	result_box.pivot_offset = result_box.size / 2
	var actions_width := minf(600, available.x - 24)
	actions.position = Vector2((available.x - actions_width) * 0.5, available.y - 76)
	actions.size = Vector2(actions_width, 48)
	stage.set_aspect(available.x / maxf(available.y, 1))

func open() -> void:
	if screen.visible or not get_tree().get_nodes_in_group('editor_import_modal').is_empty():
		return
	_suspend_editor(get_tree().current_scene)
	screen.show()
	screen.modulate.a = 0
	if screen_tween:
		screen_tween.kill()
	screen_tween = create_tween()
	screen_tween.tween_property(screen, "modulate:a", 1.0, 0.3)
	launcher.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_edit()

func close() -> void:
	if closing or not screen.visible:
		return
	closing = true
	stage.clear()
	busy = false
	_clear_effects()
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	panel.set_rolling(true)
	if panel_tween:
		panel_tween.kill()
	if screen_tween:
		screen_tween.kill()
	screen_tween = create_tween().set_parallel(true)
	screen_tween.tween_property(screen, "modulate:a", 0.0, 0.25)
	screen_tween.tween_property(panel, "position:x", -panel.size.x - 24, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	screen_tween.chain().tween_callback(_finish_close)

func _finish_close() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	screen.hide()
	closing = false
	launcher.show()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for node: Node in suspended:
		if is_instance_valid(node):
			node.process_mode = suspended[node]
	suspended.clear()
	launcher.release_focus()

func _suspend_editor(node: Node) -> void:
	if node == null or node == self:
		return
	# Polling camera/miniature scripts must not react to UI keys and pointer input.
	if node is Camera3D or node is CollisionObject3D or node.name == "NavigationCamera" or node.name == "MiniatureSpawner":
		suspended[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		return
	for child in node.get_children():
		_suspend_editor(child)

func _edit() -> void:
	if closing:
		return
	stage.clear()
	_clear_effects()
	result_box.hide()
	actions.hide()
	panel.show()
	panel.set_rolling(false)
	status.text = "SUA PRÓXIMA JOGADA"
	_layout()
	if panel_tween:
		panel_tween.kill()
	panel.position.x = -panel.size.x - 24
	panel.modulate.a = 0
	panel_tween = create_tween().set_parallel(true)
	panel_tween.tween_property(panel, "position:x", 24.0 if screen.size.x > 600 else 12.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(panel, "modulate:a", 1.0, 0.24)

func _roll(groups: Array) -> void:
	if busy or closing:
		return
	var result: Dictionary = Rules.roll(groups, rng)
	if not result.get("error", "").is_empty():
		status.text = result.error
		return
	busy = true
	last_groups = groups.duplicate(true)
	last_result = result
	_clear_effects()
	panel.set_rolling(true)
	if panel_tween:
		panel_tween.kill()
	panel_tween = create_tween().set_parallel(true)
	panel_tween.tween_property(panel, "position:x", -panel.size.x - 24, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(panel, "modulate:a", 0.0, 0.24)
	panel_tween.chain().tween_callback(panel.hide)
	result_box.hide()
	actions.hide()
	status.text = "QUE A SORTE ESTEJA COM VOCÊ"
	stage.throw_result(result)

func _settled() -> void:
	status.text = "DADOS NA MESA · CONFIRA SUA JOGADA"
	reveal_tween = create_tween()
	reveal_tween.tween_interval(RESULT_PAUSE)
	reveal_tween.tween_callback(_reveal_result)

func _reveal_result() -> void:
	busy = false
	status.text = "DADOS NA MESA"
	result_title.text = "JOGADA INCRÍVEL!" if last_result.special else "RESULTADO TOTAL"
	result_title.add_theme_color_override("font_color", Palette.color(3) if last_result.special else Palette.color(6))
	var lines := PackedStringArray()
	var detailed_lines := PackedStringArray()
	for group: Dictionary in last_result.groups:
		var values := PackedStringArray()
		for value: int in group.values:
			values.append(str(value))
		var detail := "%dd%d · %s [%s] = %d%s" % [group.count, group.sides, "soma" if group.mode == "sum" else "maior", ", ".join(values), group.total, " ★" if group.special else ""]
		detailed_lines.append(detail)
		lines.append(detail if group.count <= 6 else "%dd%d · %s = %d%s" % [group.count, group.sides, "soma" if group.mode == "sum" else "maior", group.total, " ★" if group.special else ""])
	breakdown.text = "\n".join(lines)
	breakdown.tooltip_text = "\n".join(detailed_lines)
	result_number.text = str(last_result.total)
	result_box.show()
	result_box.modulate.a = 0
	result_box.scale = Vector2.ONE * 0.8
	result_tween = create_tween().set_parallel(true)
	result_tween.tween_property(result_box, "modulate:a", 1.0, 0.25)
	result_tween.tween_property(result_box, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	result_tween.tween_method(func(v: float): result_number.text = str(roundi(v)), 0.0, float(last_result.total), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	actions.show()
	actions.get_child(0).grab_focus()
	if last_result.special:
		_celebrate()
	roll_completed.emit(last_result)

func _celebrate() -> void:
	for i in 32:
		var spark := ColorRect.new()
		spark.color = Palette.color(3 if i % 2 else 0)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.size = Vector2(5, 10)
		spark.position = screen.size * 0.5
		screen.add_child(spark)
		sparks.append(spark)
		var angle := TAU * i / 32.0
		var end := spark.position + Vector2(cos(angle), sin(angle)) * minf(screen.size.x * 0.42, 310)
		var tween := spark.create_tween().set_parallel(true)
		tween.tween_property(spark, "position", end, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "rotation", angle + PI, 1.1)
		tween.tween_property(spark, "modulate:a", 0.0, 0.65).set_delay(0.45)
		tween.chain().tween_callback(spark.queue_free)

func _clear_effects() -> void:
	if reveal_tween:
		reveal_tween.kill()
	if result_tween:
		result_tween.kill()
	for spark in sparks:
		if is_instance_valid(spark):
			spark.queue_free()
	sparks.clear()

func _input(event: InputEvent) -> void:
	if screen.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	for node: Node in suspended:
		if is_instance_valid(node):
			node.process_mode = suspended[node]
