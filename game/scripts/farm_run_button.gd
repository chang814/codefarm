extends Button
class_name FarmRunButton
const FarmIcon := preload("res://scripts/farm_icons.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")

enum Mode { LOOP, ONCE }

var mode: Mode = Mode.LOOP:
	set(value):
		mode = value
		queue_redraw()

var active := false:
	set(value):
		active = value
		queue_redraw()

# Soft sage / matcha greens.
const FILL := Color(0.50, 0.69, 0.54, 1)
const FILL_HOVER := Color(0.56, 0.75, 0.60, 1)
const FILL_ACTIVE := Color(0.92, 0.66, 0.50, 1)
const FILL_ONCE := Color(0.865, 0.900, 0.810, 1)
const FILL_ONCE_HOVER := Color(0.815, 0.870, 0.765, 1)
const ICON := Color(1.0, 0.99, 0.95, 1)
const ICON_ONCE := Color(0.33, 0.50, 0.40, 1)
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
	tooltip_text = "运行" if mode == Mode.LOOP else "单步"
	FarmMotion.bind_hover(self)
	queue_redraw()


func set_active(on: bool) -> void:
	active = on


func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


func _process(_dt: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	var bg: Color
	if mode == Mode.LOOP:
		bg = FILL.lerp(FILL_HOVER, float(get_meta("_fm_over", 0.0)))
		if active:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
			bg = FILL_ACTIVE.lerp(FILL_HOVER, pulse * 0.45)
	else:
		bg = FILL_ONCE.lerp(FILL_ONCE_HOVER, float(get_meta("_fm_over", 0.0)))
		if active:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
			bg = FILL_ONCE_HOVER.lerp(FILL_HOVER, pulse * 0.40)
	if button_pressed:
		bg = bg.darkened(0.08)
	_fill_round(r, bg, RADIUS)
	var icon := Rect2(Vector2(7, 7), size - Vector2(14, 14))
	if active:
		FarmIcon.draw_kind(self, FarmIcon.Kind.STOP, icon, ICON, 2.1)
	elif mode == Mode.LOOP:
		FarmIcon.draw_kind(self, FarmIcon.Kind.PLAY, icon, ICON, 2.1)
	else:
		FarmIcon.draw_kind(self, FarmIcon.Kind.PLAY_ONCE, icon, ICON_ONCE, 2.15)


func _fill_round(r: Rect2, color: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(round(radius)))
	sb.draw(get_canvas_item(), r)
