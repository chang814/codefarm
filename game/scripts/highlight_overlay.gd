extends Control

## Draws a finer execution highlight over a CodeEdit: a slim gold tick,
## a soft wash, a left-to-right rounded progress fill, and a fading previous line.

const WASH := Color(0.86, 0.70, 0.38, 0.16)
const FILL := Color(0.86, 0.70, 0.38, 0.22)
const TICK := Color(0.90, 0.72, 0.36, 0.95)
const FADE_SPEED := 4.2
const GUIDE := Color(0.78, 0.62, 0.38, 0.14)
const GUIDE_ACTIVE := Color(0.82, 0.68, 0.44, 0.32)

var editor: CodeEdit
var current_line: int = -1
var progress: float = 0.0
var _prev_line: int = -1
var _prev_alpha: float = 0.0

func set_editor(edit: CodeEdit) -> void:
	editor = edit
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if editor != null:
		if not editor.caret_changed.is_connected(queue_redraw):
			editor.caret_changed.connect(queue_redraw)
		if editor.get_v_scroll_bar() and not editor.get_v_scroll_bar().value_changed.is_connected(_on_scroll):
			editor.get_v_scroll_bar().value_changed.connect(_on_scroll)
		if editor.get_h_scroll_bar() and not editor.get_h_scroll_bar().value_changed.is_connected(_on_scroll):
			editor.get_h_scroll_bar().value_changed.connect(_on_scroll)

func _on_scroll(_value: float) -> void:
	queue_redraw()

func set_current_line(line: int) -> void:
	if line == current_line:
		return
	if current_line >= 0:
		_prev_line = current_line
		_prev_alpha = 1.0
	current_line = line
	queue_redraw()

func clear_line() -> void:
	if current_line >= 0:
		_prev_line = current_line
		_prev_alpha = 1.0
	current_line = -1
	progress = 0.0
	queue_redraw()

func set_progress(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if absf(next - progress) > 0.001:
		progress = next
		queue_redraw()

func _process(delta: float) -> void:
	if _prev_alpha > 0.0:
		_prev_alpha = maxf(0.0, _prev_alpha - delta * FADE_SPEED)
		if _prev_alpha == 0.0:
			_prev_line = -1
		queue_redraw()
	elif current_line >= 0:
		queue_redraw()

func _draw() -> void:
	if editor == null:
		return
	_draw_indent_guides()
	if _prev_line >= 0 and _prev_alpha > 0.0:
		_draw_wash(_prev_line, WASH * Color(1, 1, 1, _prev_alpha))
	if current_line >= 0:
		_draw_wash(current_line, WASH)
		_draw_fill(current_line, progress)
		_draw_tick(current_line)

func _line_rect(line: int) -> Rect2:
	if line < 0 or line >= editor.get_line_count():
		return Rect2()
	var glyph := editor.get_rect_at_line_column(line, 0)
	if glyph.size.x < 0.0 and glyph.size.y < 0.0:
		return Rect2()
	var height := maxf(editor.get_line_height(), glyph.size.y)
	var left := float(editor.get_total_gutter_width())
	var top := glyph.position.y
	if glyph.position.y < -height or glyph.position.y > size.y:
		return Rect2()
	var width := maxf(8.0, size.x - left - 10.0)
	return Rect2(left, top, width, height)

func _draw_wash(line: int, color: Color) -> void:
	var rect := _line_rect(line)
	if rect.size.y <= 0.0:
		return
	_draw_round_rect(rect, color, 5.0)

func _draw_fill(line: int, amount: float) -> void:
	if amount <= 0.001:
		return
	var rect := _line_rect(line)
	if rect.size.y <= 0.0:
		return
	rect.size.x *= clampf(amount, 0.0, 1.0)
	_draw_round_rect(rect, FILL, 5.0)

func _draw_tick(line: int) -> void:
	var rect := _line_rect(line)
	if rect.size.y <= 0.0:
		return
	var tick := Rect2(rect.position.x - 3.0, rect.position.y + 3.0, 3.0, rect.size.y - 6.0)
	_draw_round_rect(tick, TICK, 1.5)

func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(0)
	draw_style_box(sb, rect)


func _draw_indent_guides() -> void:
	var count := editor.get_line_count()
	if count <= 0:
		return
	var step: int = editor.indent_size if editor.indent_size > 0 else 4
	var first := maxi(0, editor.get_first_visible_line())
	var last := mini(count - 1, editor.get_last_full_visible_line() + 2)
	var caret_col := 0
	if current_line >= 0:
		caret_col = editor.get_indent_level(current_line)
	else:
		caret_col = editor.get_indent_level(editor.get_caret_line())
	var active_stop := (caret_col / step) * step
	for line in range(first, last + 1):
		var indent := _block_indent(line, step)
		if indent < step:
			continue
		var height := float(editor.get_line_height())
		var base := editor.get_rect_at_line_column(line, 0)
		if base.size.y < 0.0 and base.size.x < 0.0:
			continue
		var top := base.position.y
		if top + height < 0.0 or top > size.y:
			continue
		var stops := indent / step
		for i in range(1, stops + 1):
			var col := i * step
			var glyph := editor.get_rect_at_line_column(line, mini(col, editor.get_line(line).length()))
			var x := glyph.position.x
			# If the line is shorter than this column, estimate from column 0 + char width.
			if col > editor.get_line(line).length() or glyph.size.x < 0.0:
				var unit := editor.get_rect_at_line_column(line, 0)
				var font := editor.get_theme_font("font")
				var fs := editor.get_theme_font_size("font_size")
				var cw := 8.0
				if font:
					cw = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					if cw <= 0.0:
						cw = 8.0
				x = unit.position.x + cw * float(col)
			var color := GUIDE_ACTIVE if col == active_stop and active_stop > 0 else GUIDE
			draw_line(Vector2(x + 0.5, top + 1.0), Vector2(x + 0.5, top + height - 1.0), color, 1.0)

func _block_indent(line: int, step: int) -> int:
	var raw := editor.get_first_non_whitespace_column(line)
	var text := editor.get_line(line)
	if text.strip_edges().is_empty():
		var ahead := raw
		for j in range(line + 1, mini(editor.get_line_count(), line + 8)):
			if not editor.get_line(j).strip_edges().is_empty():
				ahead = editor.get_first_non_whitespace_column(j)
				break
		var behind := raw
		for j in range(line - 1, maxi(-1, line - 8), -1):
			if j >= 0 and not editor.get_line(j).strip_edges().is_empty():
				behind = editor.get_first_non_whitespace_column(j)
				break
		return maxi(ahead, behind)
	return raw

