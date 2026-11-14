extends ScrollContainer
## Capture on press, activate nodes on release only after ruling out a drag.
signal node_clicked(id: String)
signal zoom_changed(value: float)
const DRAG_THRESHOLD := 6.0
var blocking_control: Control
var _held := false
var _dragging := false
var _origin := Vector2.ZERO
var _scroll_origin := Vector2.ZERO
var _candidate := ""
var canvas: Control
var extent: Control
var canvas_size := Vector2.ZERO
var zoom := 1.0
var _velocity := Vector2.ZERO
var _last_motion_usec := 0
var _scroll_position := Vector2.ZERO

func configure(content: Control, wrapper: Control, dimensions: Vector2) -> void:
	canvas = content
	extent = wrapper
	canvas_size = dimensions
	canvas.size = canvas_size
	extent.custom_minimum_size = canvas_size
	extent.resized.connect(_center_canvas)
	resized.connect(_center_canvas)

func _center_canvas() -> void:
	if canvas:
		var available := size.x - get_v_scroll_bar().size.x
		canvas.position.x = maxf(0.0, (available - canvas_size.x * zoom) * 0.5)

func zoom_about(value: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	if canvas == null:
		return
	_cancel_drag()
	if anchor.x < 0.0:
		anchor = size * 0.5
	var location := (Vector2(scroll_horizontal, scroll_vertical) + anchor - canvas.position) / zoom
	zoom = clampf(value, 0.18, 1.5)
	canvas.scale = Vector2.ONE * zoom
	extent.custom_minimum_size = canvas_size * zoom
	_center_canvas()
	# Container ranges update on the next layout pass.
	_apply_zoom_scroll.call_deferred(location * zoom + canvas.position - anchor)
	zoom_changed.emit(zoom)

func _apply_zoom_scroll(value: Vector2) -> void:
	scroll_horizontal = int(value.x)
	scroll_vertical = int(value.y)

func fit_all() -> void:
	zoom_about(minf((size.x - 20.0) / canvas_size.x, (size.y - 20.0) / canvas_size.y), Vector2.ZERO)
	_apply_zoom_scroll.call_deferred(Vector2.ZERO)


func _cancel_drag() -> void:
	_held = false
	_dragging = false
	_candidate = ""
	_velocity = Vector2.ZERO
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_drag()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_cancel_drag()
		return
	if _held:
		return
	if _velocity.length() > 2.0:
		# Integrate subpixel motion independently from integer scroll bars.
		_scroll_position += _velocity * (1.0 - exp(-delta * 14.0)) / 14.0
		scroll_horizontal = int(_scroll_position.x)
		scroll_vertical = int(_scroll_position.y)
		_scroll_position.x = clampf(_scroll_position.x, 0, maxf(0, get_h_scroll_bar().max_value - get_h_scroll_bar().page))
		_scroll_position.y = clampf(_scroll_position.y, 0, maxf(0, get_v_scroll_bar().max_value - get_v_scroll_bar().page))
		_velocity *= exp(-delta * 14.0)
	else:
		_velocity = Vector2.ZERO

func _inside_content(point: Vector2) -> bool:
	if not get_global_rect().has_point(point):
		return false
	if is_instance_valid(blocking_control) and blocking_control.is_visible_in_tree() and blocking_control.get_global_rect().has_point(point):
		return false
	for bar in [get_h_scroll_bar(), get_v_scroll_bar()]:
		if bar.visible and bar.get_global_rect().has_point(point):
			return false
	return true

func _node_at(point: Vector2) -> String:
	for card in find_children("Skill_*", "Control", true, false):
		if card.has_meta("skill_id") and card.get_global_rect().has_point(point):
			return str(card.get_meta("skill_id"))
	return ""

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_cancel_drag()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_drag()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _inside_content(event.position):
		zoom_about(zoom * (1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1), event.position - global_position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _inside_content(event.position):
				return
			_cancel_drag()
			_last_motion_usec = Time.get_ticks_usec()
			_held = true
			_dragging = false
			_origin = event.position
			_scroll_origin = Vector2(scroll_horizontal, scroll_vertical)
			_candidate = _node_at(event.position)
			get_viewport().set_input_as_handled()
		elif _held:
			var chosen := _candidate
			var click: bool = not _dragging and event.position.distance_to(_origin) < DRAG_THRESHOLD and _inside_content(event.position) and _node_at(event.position) == chosen
			var glide := _velocity if _dragging and Time.get_ticks_usec() - _last_motion_usec < 100000 else Vector2.ZERO
			_cancel_drag()
			_velocity = glide
			_scroll_position = Vector2(scroll_horizontal, scroll_vertical)
			get_viewport().set_input_as_handled()
			if click and chosen != "":
				node_clicked.emit(chosen)
	elif event is InputEventMouseMotion and _held:
		var movement: Vector2 = event.position - _origin
		if movement.length() >= DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			var before := Vector2(scroll_horizontal, scroll_vertical)
			scroll_horizontal = int(_scroll_origin.x - movement.x)
			scroll_vertical = int(_scroll_origin.y - movement.y)
			var now := Time.get_ticks_usec()
			var dt := maxf(float(now - _last_motion_usec) / 1000000.0, 1.0 / 120.0)
			_velocity = ((Vector2(scroll_horizontal, scroll_vertical) - before) / dt).limit_length(1600.0)
			_last_motion_usec = now
		get_viewport().set_input_as_handled()
