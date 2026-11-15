extends Control
class_name FarmErrorMarkup

## Token underline with explanations docked outside the editable text rectangle.

const APPEAR := 0.18
const DISMISS := 0.15
const RISE := 7.0
const CORAL := Color(0.84, 0.44, 0.38, 1)
const AMBER := Color(0.80, 0.58, 0.24, 1)

var editor: CodeEdit
var _font: Font
var _font_mono: Font
var _line := -1
var _col0 := 0
var _col1 := 0
var _message := ""
var _kind := ""
var _shown_source := ""
var _amt := 0.0
var _target := 0.0
var _latch := false

var _bubble: PanelContainer
var _label: RichTextLabel
var _dock: Control


func set_diagnostic_dock(dock: Control) -> void:
	_dock = dock
	_bubble.reparent(dock)
	_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bubble.custom_minimum_size.x = 0


func set_editor(edit: CodeEdit, font: Font = null, mono: Font = null) -> void:
	editor = edit
	_font = font
	_font_mono = mono
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _bubble == null:
		_make_bubble()
	if editor:
		if editor.get_v_scroll_bar() and not editor.get_v_scroll_bar().value_changed.is_connected(_on_scroll):
			editor.get_v_scroll_bar().value_changed.connect(_on_scroll)
		if editor.get_h_scroll_bar() and not editor.get_h_scroll_bar().value_changed.is_connected(_on_scroll):
			editor.get_h_scroll_bar().value_changed.connect(_on_scroll)


func _on_scroll(_value: float) -> void:
	queue_redraw()
	_place_bubble()


func is_showing() -> bool:
	return _target > 0.0 or _amt > 0.02


func shown_line_1() -> int:
	return _line + 1 if _line >= 0 else 0


func shown_source() -> String:
	return _shown_source


func show_diagnostic(line_1: int, col_start: int, col_end: int, message: String, suggestion: String, kind: String) -> void:
	if line_1 <= 0:
		line_1 = 1
	_line = line_1 - 1
	_col0 = maxi(col_start - 1, 0)
	_col1 = maxi(col_end - 1, _col0 + 1)
	_kind = kind
	var text := message.strip_edges()
	# One short sentence: drop the "第 N 行：" prefix in the bubble.
	var prefix := "第 %d 行：" % line_1
	if text.begins_with(prefix):
		text = text.substr(prefix.length())
	var action := suggestion.strip_edges()
	if action.is_empty():
		match kind:
			"missing_semicolon": action = "在上一条语句末尾补上分号 ;，再点运行。"
			"unclosed": action = "检查这一行及前面的括号、引号是否成对闭合。"
			"locked_syntax": action = "打开技能树，查看并解锁这项语法后再运行。"
			"outside_main": action = "把农场操作放进 int main() 的大括号内。"
			"typo": action = "检查下划线标出的名称，也可以从代码补全中选择。"
			_: action = "先检查标出的名称、参数和上一行，再重新运行。"
	if kind == "typo":
		for candidate in ["can_harvest", "get_entity_type", "get_ground_type", "do_a_flip", "harvest", "move", "plant", "till"]:
			if suggestion.contains(candidate):
				action = "把下划线标出的名称改为 %s，再点运行。" % candidate
				break
	var category: String = {"typo": "检查拼写", "missing_semicolon": "缺少分号", "unclosed": "检查配对", "locked_syntax": "尚未解锁", "outside_main": "调整位置"}.get(kind, "检查代码")
	_message = "第 %d 行 · 第 %d 列  |  %s\n%s" % [line_1, maxi(col_start, 1), category, text]
	if text.find(action) < 0:
		_message += "\n建议：" + action

	if editor and _line >= 0 and _line < editor.get_line_count():
		_shown_source = editor.get_line(_line)
	_apply_label()
	_target = 1.0
	if not _latch:
		_amt = 0.0
	_latch = true
	_bubble.visible = true
	if _dock:
		_dock.visible = true
	_place_bubble()
	queue_redraw()


func dismiss() -> void:
	_target = 0.0
	_latch = false
	queue_redraw()


func clear() -> void:
	_target = 0.0
	_amt = 0.0
	_latch = false
	_line = -1
	_shown_source = ""
	if _bubble:
		_bubble.visible = false
	if _dock:
		_dock.visible = false
	queue_redraw()


func _process(delta: float) -> void:
	if is_equal_approx(_amt, _target) and _target == 0.0 and (_bubble == null or not _bubble.visible):
		return
	var speed := (1.0 / APPEAR) if _target > _amt else (1.0 / DISMISS)
	_amt = move_toward(_amt, _target, delta * speed)
	if _amt <= 0.001 and _target == 0.0:
		_amt = 0.0
		if _bubble:
			_bubble.visible = false
		if _dock:
			_dock.visible = false
	_place_bubble()
	queue_redraw()


func _make_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.name = "ErrorBubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = false
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(0, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		_label.add_theme_font_override("normal_font", _font)
	if _font_mono:
		_label.add_theme_font_override("mono_font", _font_mono)
	_label.add_theme_font_size_override("normal_font_size", 16)
	_label.add_theme_font_size_override("mono_font_size", 16)
	_label.add_theme_constant_override("line_separation", 6)
	_label.add_theme_color_override("default_color", Color(0.31, 0.29, 0.25, 1))
	_bubble.add_child(_label)


func _stroke() -> Color:
	return AMBER if _kind == "locked_syntax" else CORAL


func _apply_label() -> void:
	if _label == null:
		return
	var stroke := _stroke()
	var bg := Color(0.995, 0.975, 0.945, 0.99)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(stroke.r, stroke.g, stroke.b, 0.36)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0.36, 0.28, 0.17, 0.20)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	_bubble.add_theme_stylebox_override("panel", sb)
	_label.text = _message


func _token_rect() -> Rect2:
	if editor == null or _line < 0 or _line >= editor.get_line_count():
		return Rect2()
	# The line may have been shortened since the error was reported. Asking the
	# editor for a column past the end logs an engine error on every redraw.
	var line_len := editor.get_line(_line).length()
	var first_col := clampi(_col0, 0, line_len)
	var a: Rect2 = editor.get_rect_at_line_column(_line, first_col)
	if a.size.x < 0.0 and a.size.y < 0.0:
		return Rect2()
	var last_col := clampi(maxi(_col1, first_col + 1), 0, line_len)
	var b: Rect2 = editor.get_rect_at_line_column(_line, last_col)
	var x := minf(a.position.x, b.position.x)
	var w := absf(b.position.x - a.position.x)
	if w < 6.0:
		w = 8.0
	var height := maxf(editor.get_line_height(), a.size.y)
	# Sit just under the glyphs, not on the next line.
	var y := a.position.y + height * 0.72
	return Rect2(Vector2(x, y), Vector2(w, 3.0))


func _place_bubble() -> void:
	if _bubble == null or editor == null:
		return
	if _dock:
		_bubble.modulate.a = clampf(_amt, 0.0, 1.0)
		return
	var underline := _token_rect()
	if underline.size.x <= 0.0:
		return
	_bubble.reset_size()
	var sz := _bubble.get_combined_minimum_size()
	if sz.x < 240:
		sz.x = 240
	if sz.x > 400:
		sz.x = 400
	_bubble.size = sz
	var rise := (1.0 - _amt) * RISE
	var line_height := float(editor.get_line_height())
	var line_top := underline.position.y - line_height * 0.72
	# Park the bubble above the error line so the word stays visible.
	var pos := Vector2(underline.position.x - 8.0, line_top - sz.y - 8.0 - rise)
	var area := get_size()
	pos.x = clampf(pos.x, 8.0, maxf(8.0, area.x - sz.x - 8.0))
	if pos.y < 6.0:
		# Not enough room above: put it just below the underline.
		pos.y = underline.position.y + 8.0 + rise
	pos.y = clampf(pos.y, 6.0, maxf(6.0, area.y - sz.y - 6.0))
	_bubble.position = pos
	_bubble.modulate = Color(1, 1, 1, clampf(_amt, 0.0, 1.0))


func _draw() -> void:
	if editor == null or _line < 0 or _amt <= 0.01:
		return
	var r := _token_rect()
	if r.size.x <= 0.0:
		return
	var col := _stroke()
	col.a = 0.85 * _amt
	var y := r.position.y - 1.0
	var x := r.position.x
	var pts: Array[Vector2] = []
	var w := r.size.x + 2.0
	var i := 0.0
	while i <= w:
		var yy := y + sin(i * 0.85) * 1.5
		pts.append(Vector2(x + i, yy))
		i += 1.5
	if pts.size() >= 2:
		draw_polyline(PackedVector2Array(pts), col, 1.35, true)
