extends Control
## Shared sliding selection for modal navigation. Container lays out buttons;
## the independent selection surface follows them without shifting hit targets.
const Motion := preload("res://scripts/farm_motion.gd")
var options := [["skill", "技能树"], ["settings", "设置"], ["log", "日志"]]
var selected := ""
var buttons: Dictionary = {}
var indicator: Panel
var row: HBoxContainer
signal chosen(id: String)

func _ready() -> void:
	custom_minimum_size = Vector2(300, 40)
	mouse_filter = Control.MOUSE_FILTER_PASS
	indicator = Panel.new()
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.43, 0.54, 0.44, 0.8)
	style.set_corner_radius_all(9)
	indicator.add_theme_stylebox_override("panel", style)
	add_child(indicator)
	row = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for spec in options:
		var button := Button.new()
		button.text = spec[1]
		button.custom_minimum_size = Vector2(94, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color(0.84, 0.88, 0.73, 0.7)
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(9)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_font_size_override("font_size", 17)
		var id: String = spec[0]
		button.pressed.connect(func() -> void: chosen.emit(id))
		row.add_child(button)
		Motion.bind_hover(button, 1.015, 0.97)
		buttons[id] = button
	resized.connect(func() -> void: call_deferred("select", selected, false))
	call_deferred("select", selected, false)

func select(id: String, animate: bool = true) -> void:
	selected = id
	if not buttons.has(id):
		if indicator:
			indicator.visible = false
		return
	indicator.visible = true
	var button: Button = buttons[id]
	Motion.stop(indicator, "_selection")
	if animate:
		var tween := indicator.create_tween().set_parallel(true)
		indicator.set_meta("_selection", tween)
		tween.tween_property(indicator, "position", button.position, 0.26).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(indicator, "size", button.size, 0.26).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		indicator.position = button.position
		indicator.size = button.size
	for key in buttons:
		var tint := Color(0.96, 0.94, 0.85) if key == id else Color(0.73, 0.78, 0.72)
		buttons[key].add_theme_color_override("font_color", tint)
