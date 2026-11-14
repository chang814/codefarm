extends PanelContainer
class_name FarmWindow
const FarmChromeButton := preload("res://scripts/farm_chrome_button.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")

## Draggable, minimizable, maximizable floating window with a themed title bar.

signal close_requested
signal minimize_changed(is_minimized: bool)
signal maximize_changed(is_maximized: bool)

const TITLE_H := 52.0
const HANDLE := 16.0
const MARGIN := 10.0

var title_text: String = "窗口":
	set(value):
		title_text = value
		if title_label:
			title_label.text = value

var content: Control
var title_label: Label
var tools_left: HBoxContainer
var title_bar: PanelContainer
var body: Control
var min_button: FarmChromeButton
var max_button: FarmChromeButton
var close_button: FarmChromeButton
var resize_handle: Control

var minimized := false
var maximized := false
var _dragging := false
var _drag_off := Vector2.ZERO
var _resizing := false
var _resize_origin := Vector2.ZERO
var _resize_size := Vector2.ZERO
var _restore_rect := Rect2()
var _chip_pos := Vector2.ZERO
var min_window_size := Vector2(280, 140)
var max_top_margin := 86.0
var max_bottom_margin := 10.0
var _make_button: Callable
var _move_tween: Tween
var _changing_state := false

func setup(title: String, button_factory: Callable, panel_style: StyleBox, bar_style: StyleBox, apply_font: Callable) -> void:
	title_text = title
	_make_button = button_factory
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	title_bar = PanelContainer.new()
	title_bar.custom_minimum_size = Vector2(0, TITLE_H)
	title_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_bar.add_theme_stylebox_override("panel", bar_style)
	title_bar.gui_input.connect(_on_title_input)
	vbox.add_child(title_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_bar.add_child(row)

	tools_left = HBoxContainer.new()
	tools_left.name = "TitleTools"
	tools_left.add_theme_constant_override("separation", 2)
	tools_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tools_left)

	title_label = Label.new()
	title_label.text = title_text
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply_font.call(title_label, 21)
	row.add_child(title_label)

	min_button = _chrome_button(FarmChromeButton.Action.MINIMIZE, "最小化")
	max_button = _chrome_button(FarmChromeButton.Action.MAXIMIZE, "全屏")
	close_button = _chrome_button(FarmChromeButton.Action.CLOSE, "关闭")
	min_button.pressed.connect(toggle_minimize)
	max_button.pressed.connect(toggle_maximize)
	close_button.pressed.connect(_on_close)
	row.add_child(min_button)
	row.add_child(max_button)
	row.add_child(close_button)

	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	vbox.add_child(body)

	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_top = 10
	content.offset_right = -14
	content.offset_bottom = -22
	body.add_child(content)

	# Must live under `body` (a Control), not as a sibling of the VBox on this
	# PanelContainer. PanelContainer fits every direct child to the full rect,
	# which made the handle cover the whole window, steal all clicks, and show
	# a resize cursor everywhere. The grip itself is a transparent hit target
	# with a faint L-shaped cue — never a solid color block.
	resize_handle = Control.new()
	resize_handle.name = "ResizeHandle"
	resize_handle.custom_minimum_size = Vector2(HANDLE, HANDLE)
	resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	resize_handle.gui_input.connect(_on_resize_input)
	resize_handle.draw.connect(_draw_resize_handle)
	resize_handle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	resize_handle.anchor_left = 1.0
	resize_handle.anchor_top = 1.0
	resize_handle.anchor_right = 1.0
	resize_handle.anchor_bottom = 1.0
	resize_handle.offset_left = -HANDLE
	resize_handle.offset_top = -HANDLE
	resize_handle.offset_right = 0
	resize_handle.offset_bottom = 0
	body.add_child(resize_handle)
	resize_handle.z_index = 1

	_restore_rect = Rect2(position, size)
	get_viewport().size_changed.connect(_on_viewport_changed)



func _chrome_button(action: FarmChromeButton.Action, tip: String) -> FarmChromeButton:
	var btn := FarmChromeButton.new()
	btn.action = action
	btn.tooltip_text = tip
	btn.custom_minimum_size = Vector2(40, 40)
	return btn


func _on_close() -> void:
	dismiss()


func set_minimized(on: bool, instant: bool = false) -> void:
	if minimized == on:
		return
	_set_minimized_state(on, instant)


func toggle_minimize() -> void:
	_set_minimized_state(not minimized, false)


func _set_minimized_state(on: bool, instant: bool) -> void:
	_end_pointer_gesture()
	_changing_state = true
	var was_maximized := maximized
	if maximized and on:
		maximized = false
		max_button.tooltip_text = "全屏"
		max_button.set_maximize_state(false)
		maximize_changed.emit(false)
	var target: Rect2
	if not on:
		minimized = false
		min_button.tooltip_text = "最小化"
		target = _restore_rect
		body.visible = true
		resize_handle.visible = true
	else:
		if not minimized and not was_maximized:
			# An interrupted restore still owns its destination, not this frame.
			if not _move_active():
				_restore_rect = Rect2(position, size)
		minimized = true
		min_button.tooltip_text = "还原"
		target = _min_rect()
		body.visible = false
		resize_handle.visible = false
	_changing_state = false
	if instant:
		_apply_rect(target)
	else:
		_tween_to(target)
	minimize_changed.emit(minimized)


func toggle_maximize() -> void:
	_end_pointer_gesture()
	_changing_state = true
	var was_minimized := minimized
	if minimized:
		minimized = false
		min_button.tooltip_text = "最小化"
		body.visible = true
		resize_handle.visible = true
		minimize_changed.emit(false)
	if maximized:
		maximized = false
		max_button.tooltip_text = "全屏"
		max_button.set_maximize_state(false)
	else:
		if not was_minimized and not _move_active():
			_restore_rect = Rect2(position, size)
		maximized = true
		max_button.tooltip_text = "还原"
		max_button.set_maximize_state(true)
	# Listeners adjust docking margins before the target is calculated. They
	# must never snap geometry or cancel this transition in the middle.
	maximize_changed.emit(maximized)
	_changing_state = false
	_tween_to(_max_rect() if maximized else _restore_rect)


func reveal(at: Rect2 = Rect2()) -> void:
	var first := not visible or is_closing()
	if first:
		FarmMotion.open_popup(self)
		if maximized:
			_changing_state = true
			maximize_changed.emit(true)
			_changing_state = false
			_tween_to(_max_rect())
	if minimized:
		toggle_minimize()
	if at != Rect2():
		_restore_rect = at
		if not maximized and not minimized:
			_tween_to(at)


func dismiss() -> void:
	_end_pointer_gesture()
	if not maximized and not minimized:
		_restore_rect = current_restore_rect()
	_kill_move_tween()
	close_requested.emit()
	FarmMotion.close_popup(self)


func is_closing() -> bool:
	return bool(get_meta("_fm_closing", false))


func refresh_max_rect() -> void:
	if maximized and not _changing_state:
		_tween_to(_max_rect())


func current_restore_rect() -> Rect2:
	if maximized or minimized or _move_active():
		return _restore_rect
	return Rect2(position, size)


func _max_rect() -> Rect2:
	var vp := _viewport_size()
	var bottom := maxf(MARGIN, max_bottom_margin)
	return Rect2(Vector2(MARGIN, max_top_margin), Vector2(vp.x - MARGIN * 2.0, vp.y - max_top_margin - bottom))


func _min_rect() -> Rect2:
	var vp := _viewport_size()
	var chip := Vector2(maxf(220.0, _restore_rect.size.x * 0.55), TITLE_H + 8.0)
	return Rect2(Vector2(_restore_rect.position.x, vp.y - chip.y - MARGIN), chip)


func _on_viewport_changed() -> void:
	_end_pointer_gesture()
	var target := _max_rect() if maximized else (_min_rect() if minimized else current_restore_rect())
	# Resize is driven by the OS; fit immediately, discarding the old target.
	_apply_rect(target)
	if not maximized and not minimized:
		_restore_rect = Rect2(position, size)


func _viewport_size() -> Vector2:
	var parent := get_parent() as Control
	if parent:
		return parent.size
	return get_viewport().get_visible_rect().size


func _clamp_rect(rect: Rect2) -> Rect2:
	var vp := _viewport_size()
	var minimum := Vector2(220, TITLE_H + 8.0) if minimized else min_window_size
	minimum = minimum.max(get_combined_minimum_size())
	rect.size.x = clampf(rect.size.x, minf(minimum.x, vp.x - MARGIN * 2.0), maxf(1, vp.x - MARGIN * 2.0))
	rect.size.y = clampf(rect.size.y, minf(minimum.y, vp.y - MARGIN * 2.0), maxf(1, vp.y - MARGIN * 2.0))
	rect.position.x = clampf(rect.position.x, MARGIN, maxf(MARGIN, vp.x - rect.size.x - MARGIN))
	rect.position.y = clampf(rect.position.y, MARGIN, maxf(MARGIN, vp.y - rect.size.y - MARGIN))
	return rect


func _kill_move_tween() -> void:
	if _move_tween and is_instance_valid(_move_tween) and _move_tween.is_running():
		_move_tween.kill()
	_move_tween = null


func _move_active() -> bool:
	return _move_tween != null and is_instance_valid(_move_tween) and _move_tween.is_running()


func _apply_rect(rect: Rect2, clamp_it: bool = true) -> void:
	_kill_move_tween()
	if clamp_it:
		rect = _clamp_rect(rect)
	custom_minimum_size = Vector2(0, 0)
	size = rect.size
	position = rect.position


func _tween_to(rect: Rect2) -> void:
	rect = _clamp_rect(rect)
	_kill_move_tween()
	var start := Rect2(position, size)
	# A single center/extent interpolation keeps all edges on the same clock.
	# Resize first, then position: container minimums cannot kick the title bar.
	_move_tween = create_tween()
	_move_tween.tween_method(func(t: float) -> void:
		size = start.size.lerp(rect.size, t)
		position = start.get_center().lerp(rect.get_center(), t) - size * 0.5,
		0.0, 1.0, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(func() -> void:
		size = rect.size
		position = rect.position
	)


func _end_pointer_gesture() -> void:
	_dragging = false
	_resizing = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_pointer_gesture()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_end_pointer_gesture()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_end_pointer_gesture()


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if maximized:
				return
			_kill_move_tween()
			_dragging = true
			_drag_off = event.global_position - global_position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging and not maximized:
		var motion := event as InputEventMouseMotion
		var parent := get_parent() as Control
		var local := motion.global_position - _drag_off
		if parent:
			local = local - parent.global_position
		_apply_rect(Rect2(local, size))
		if not minimized:
			_restore_rect = Rect2(position, size)


func _draw_resize_handle() -> void:
	if resize_handle == null:
		return
	var s := resize_handle.size
	var color := Color(0.82, 0.68, 0.44, 0.22)
	var w := 2.0
	var length := minf(s.x, s.y) * 0.58
	var origin := Vector2(s.x - 3.5, s.y - 3.5)
	resize_handle.draw_line(origin + Vector2(-length, 0.0), origin, color, w, true)
	resize_handle.draw_line(origin + Vector2(0.0, -length), origin, color, w, true)
	resize_handle.draw_circle(origin, w * 0.55, color)


func _on_resize_input(event: InputEvent) -> void:
	if minimized or maximized:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_kill_move_tween()
			_resizing = true
			_resize_origin = event.global_position
			_resize_size = size
		else:
			_resizing = false
			_restore_rect = Rect2(position, size)
	elif event is InputEventMouseMotion and _resizing:
		var motion := event as InputEventMouseMotion
		var delta: Vector2 = motion.global_position - _resize_origin
		_apply_rect(Rect2(position, _resize_size + delta))
		_restore_rect = Rect2(position, size)
