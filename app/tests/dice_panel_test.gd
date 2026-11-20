extends SceneTree
## Headless UI behavior and narrow layout checks; no display or input server required.
const DicePanelScript = preload("res://editor/dice/dice_panel.gd")
var failures: Array[String] = []
var requests: Array = []

func _initialize() -> void:
	OS.set_environment("BREAKPOINT_RUNTIME_PORT", "0")
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var panel := DicePanelScript.new()
	root.add_child(panel)
	panel.size = Vector2(320, 400)
	panel.roll_requested.connect(func(groups): requests.append(groups))
	await process_frame
	await process_frame
	_check(panel.get_roll_groups().is_empty() and panel.roll_button.disabled, "First opening must have no selected dice")
	_check(panel.roll_button.text == "Selecione seus dados", "Empty button should invite selection")
	_check(panel.roll_button.get_theme_color("font_disabled_color").r > 0.98, "Empty button text must be white")
	_check(panel.size.x <= 320, "Narrow layout should not expand beyond 320px")
	for button: Button in [panel.roll_button, panel.reset_button, panel.close_button]:
		_check(button.size.x >= 96 and button.size.y >= 42,
			"%s must have a visible, clickable rectangle, got %s" % [button.name, button.size])
		_check(button.get_global_rect().end.x <= panel.get_global_rect().end.x,
			"%s must fit within the narrow panel width: %s vs %s" % [button.name, button.get_global_rect(), panel.get_global_rect()])
	panel.rows[6].count.value = 2
	panel._request_roll()
	_check(requests.size() == 1, "Valid roll should emit one request")
	panel.reset_selection()
	_check(panel.get_roll_groups().is_empty() and panel.roll_button.disabled, "Empty selection must disable roll")
	panel._request_roll()
	_check(requests.size() == 1, "Empty selection must not emit")
	panel.rows[4].count.value = 3
	panel.rows[20].count.value = 2
	panel.rows[20].mode.select(1)
	_check(panel.get_roll_groups() == [{"sides": 4, "count": 3, "mode": "sum"}, {"sides": 20, "count": 2, "mode": "highest"}], "Mixed modes must survive selection")
	panel.set_rolling(true)
	_check(panel.roll_button.disabled and panel.reset_button.disabled, "Rolling must lock actions")
	for row: Dictionary in panel.rows.values():
		_check(not row.count.editable and row.mode.disabled, "Rolling must lock every row")
	panel._request_roll()
	_check(requests.size() == 1, "Rolling must not emit a repeated request")
	panel.set_rolling(false)
	panel.reset_selection()
	for sides in [6, 20]:
		panel.rows[sides].count.value = 50
	_check(not panel.roll_button.disabled, "Exactly 100 dice must be allowed")
	_check(panel.rows[6].count.value == 50 and panel.rows[20].count.value == 50, "Each quantity control must allow 50 dice")
	panel.rows[10].count.value = 1
	_check(panel.roll_button.disabled, "101 dice must be rejected")
	panel._request_roll()
	_check(requests.size() == 1, "Over-limit request must not emit")
	panel.rows[10].count.value = 0
	panel._request_roll()
	_check(requests.size() == 2, "Valid 100-dice selection must emit")
	panel.rows[6].count.value = 51
	_check(panel.rows[6].count.value == 50, "Quantity control must clamp values above 50")
	panel.reset_selection()
	for row: Dictionary in panel.rows.values():
		_check(row.count.value == 0 and row.mode.selected == 0, "Reset must clear quantities and modes")
	panel.queue_free()
	await process_frame
	print("Dice panel: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
