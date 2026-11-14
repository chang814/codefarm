extends Button
class_name FarmChromeButton
const FarmIcon := preload("res://scripts/farm_icons.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")

enum Action { MINIMIZE, MAXIMIZE, RESTORE, CLOSE }

var action: Action = Action.MINIMIZE:
	set(value):
		action = value
		queue_redraw()

const CREAM := Color(0.88, 0.84, 0.76, 0.95)
const BOX := Color(0.38, 0.42, 0.38, 0.62)
const BOX_HOVER := Color(0.48, 0.52, 0.47, 0.82)
const CLOSE_HOVER := Color(0.82, 0.48, 0.44, 0.90)
const RADIUS := 8.0


func _ready() -> void:
	set_meta("_fm_custom_draw", true)
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(40, 40)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	add_theme_stylebox_override("normal", _empty())
	add_theme_stylebox_override("hover", _empty())
	add_theme_stylebox_override("pressed", _empty())
	add_theme_stylebox_override("focus", _empty())
	add_theme_stylebox_override("disabled", _empty())
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	FarmMotion.bind_hover(self)
	queue_redraw()


func set_kind(k: Action) -> void:
	action = k


func set_maximize_state(maximized: bool) -> void:
	action = Action.RESTORE if maximized else Action.MAXIMIZE


func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


func _draw() -> void:
	var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	var bg := BOX.lerp(CLOSE_HOVER if action == Action.CLOSE else BOX_HOVER, float(get_meta("_fm_over", 0.0)))
	if button_pressed:
		bg = bg.darkened(0.10)
	_fill_round(r, bg, RADIUS)
	var icon := Rect2(Vector2(8, 8), size - Vector2(16, 16))
	var col := CREAM
	var w := 2.1
	match action:
		Action.MINIMIZE:
			FarmIcon.draw_kind(self, FarmIcon.Kind.MINIMIZE, icon, col, w)
		Action.MAXIMIZE:
			FarmIcon.draw_kind(self, FarmIcon.Kind.MAXIMIZE, icon, col, w)
		Action.RESTORE:
			FarmIcon.draw_kind(self, FarmIcon.Kind.RESTORE, icon, col, w)
		Action.CLOSE:
			FarmIcon.draw_kind(self, FarmIcon.Kind.CLOSE, icon, col, w)


func _fill_round(r: Rect2, color: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(round(radius)))
	sb.draw(get_canvas_item(), r)
