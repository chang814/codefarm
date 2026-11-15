extends Node
## Editing help for the code window: Shift+wheel / Ctrl+0 font zoom with a
## fading percent badge, indent-aware Backspace, C++ syntax colors, and
## completion that only offers what the player has unlocked.
##
## Side effects that belong to the game (save, stop a running program, clear
## an error) are left to main through the `edited` and `clicked` signals.

const FarmPalette := preload("res://scripts/farm_palette.gd")

## The player changed the text.
signal edited
## Left press inside the editor (main stops a running program here).
signal clicked(position: Vector2)

const FONT_SIZE_MIN := 12
const FONT_SIZE_MAX := 32

var editor: CodeEdit
var host: CodefarmHost
## Redrawn when the font size changes (the execution highlight overlay).
var overlay: Control
var highlighter: CodeHighlighter

var font_size: int = 20
var font_size_default: int = 20
var _font_display: float = 18.0
var _font_zoom_accum: float = 0.0
var _font_tween: Tween
var _font_badge_tween: Tween
var _font_anchor_line: int = -1
var _font_anchor_y: float = 0.0
var _badge: Label
var _pending_paren_adjust: bool = false
var _completion_prefix: String = ""


func setup(code_edit: CodeEdit, sim_host: CodefarmHost) -> void:
	editor = code_edit
	host = sim_host


## The percent label in the editor corner; double-click resets the size.
func attach_font_badge(badge: Label) -> void:
	_badge = badge
	_badge.gui_input.connect(_on_badge_input)


# --- Font size (Shift+wheel, Ctrl+0, settings) -------------------------------

func apply_font_size() -> void:
	if editor == null:
		return
	var px := int(round(_font_display))
	editor.add_theme_font_size_override("font_size", px)
	editor.add_theme_constant_override("line_spacing", 6 if px < 19 else 8)
	editor.add_theme_font_size_override("completion_font_size", maxi(14, px - 2))
	if overlay:
		overlay.queue_redraw()
	_keep_font_anchor()


func _font_percent() -> int:
	return int(round(100.0 * float(font_size) / float(font_size_default)))


func _show_font_badge() -> void:
	if _badge == null:
		return
	_badge.text = "%d%%" % _font_percent()
	_badge.visible = true
	_badge.modulate = Color(1, 1, 1, 1)
	if _font_badge_tween and is_instance_valid(_font_badge_tween):
		_font_badge_tween.kill()
	_font_badge_tween = create_tween()
	_font_badge_tween.tween_interval(0.7)
	_font_badge_tween.tween_property(_badge, "modulate:a", 0.0, 0.28)
	_font_badge_tween.tween_callback(func() -> void:
		if _badge:
			_badge.visible = false
			_badge.modulate = Color(1, 1, 1, 1)
	)


func _on_badge_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		reset_font()
		get_viewport().set_input_as_handled()


func reset_font() -> void:
	set_font_size(font_size_default, true)


func set_font_size(size: int, animate: bool, anchor: bool = true) -> void:
	size = clampi(size, FONT_SIZE_MIN, FONT_SIZE_MAX)
	if anchor and editor:
		var local := editor.get_local_mouse_position()
		var lc: Vector2i = editor.get_line_column_at_pos(local, true)
		_font_anchor_line = lc.y
		_font_anchor_y = local.y
	else:
		_font_anchor_line = -1
	font_size = size
	if _font_tween and is_instance_valid(_font_tween):
		_font_tween.kill()
	if not animate:
		_font_display = float(size)
		apply_font_size()
		_show_font_badge()
		return
	_font_tween = create_tween()
	_font_tween.tween_method(_tick_font_display, _font_display, float(size), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_font_badge()


func _tick_font_display(value: float) -> void:
	_font_display = value
	apply_font_size()


func _keep_font_anchor() -> void:
	if editor == null or _font_anchor_line < 0:
		return
	var after: Vector2 = editor.get_pos_at_line_column(_font_anchor_line, 0)
	var delta: float = after.y - _font_anchor_y
	if absf(delta) < 0.5:
		return
	var line_h := float(editor.get_line_height())
	if line_h <= 0.1:
		return
	editor.scroll_vertical = editor.scroll_vertical + delta / line_h


func _handle_font_zoom(event: InputEventMouseButton) -> void:
	var notch := event.factor if event.factor != 0.0 else 1.0
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		notch = -notch
	elif event.button_index != MOUSE_BUTTON_WHEEL_UP:
		return
	_font_zoom_accum += notch
	if absf(_font_zoom_accum) < 0.85:
		return
	var steps := int(_font_zoom_accum)
	if steps == 0:
		steps = 1 if _font_zoom_accum > 0.0 else -1
	_font_zoom_accum -= float(steps)
	set_font_size(font_size + steps, true, true)

# --- Input -------------------------------------------------------------------

func gui_input(event: InputEvent) -> void:
	if editor == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			if mb.shift_pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				if mb.pressed:
					_handle_font_zoom(mb)
				editor.accept_event()
				var vp := editor.get_viewport()
				if vp:
					vp.set_input_as_handled()
				return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(mb.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and (event.keycode == KEY_0 or event.keycode == KEY_KP_0):
			reset_font()
			editor.accept_event()
			var vp2 := editor.get_viewport()
			if vp2:
				vp2.set_input_as_handled()
			return
		if editor.editable and event.keycode == KEY_BACKSPACE and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			if not editor.has_selection() and _try_smart_backspace():
				editor.accept_event()
				var vp3 := editor.get_viewport()
				if vp3:
					vp3.set_input_as_handled()


func _try_smart_backspace() -> bool:
	var line_i := editor.get_caret_line()
	var col := editor.get_caret_column()
	if col <= 0:
		return false
	var line := editor.get_line(line_i)
	var prefix := line.substr(0, col)
	if prefix.is_empty():
		return false
	for i in prefix.length():
		var ch := prefix[i]
		if ch != " " and ch != "\t":
			return false
	var step: int = editor.indent_size if editor.indent_size > 0 else 4
	var remove := col % step
	if remove == 0:
		remove = step
	remove = mini(remove, col)
	editor.begin_complex_operation()
	editor.select(line_i, col - remove, line_i, col)
	editor.delete_selection()
	editor.end_complex_operation()
	return true

# --- Syntax highlighting -----------------------------------------------------

## Syntax colors for the editor; `extra_views` (hint code panes) get copies.
func setup_highlighter(extra_views: Array) -> void:
	var hl := CodeHighlighter.new()
	hl.number_color = FarmPalette.SYN_NUMBER
	hl.symbol_color = FarmPalette.SYN_SYMBOL
	hl.function_color = FarmPalette.SYN_FUNC
	hl.member_variable_color = FarmPalette.SYN_IDENT
	for word in ["while", "if", "else", "for", "return", "using", "namespace", "switch", "case", "break", "default", "continue", "do"]:
		hl.add_keyword_color(word, FarmPalette.SYN_KEYWORD)
	for word in ["int", "void", "enum", "class", "struct", "bool", "double", "float", "char", "string", "auto", "const", "constexpr", "include",
			"Dir", "Entity", "Ground", "Item", "Cost", "Measure", "Companion", "Hat", "Unlock"]:
		hl.add_keyword_color(word, FarmPalette.SYN_TYPE)
	hl.add_keyword_color("true", FarmPalette.SYN_ENUM)
	hl.add_keyword_color("false", FarmPalette.SYN_ENUM)
	hl.add_keyword_color("std", FarmPalette.SYN_STD)
	for word in ["East", "West", "North", "South", "Grass", "Bush", "None", "Grassland", "Soil",
			"Tree", "Carrot", "Sunflower", "Pumpkin", "DeadPumpkin", "Cactus", "Treasure", "Hedge", "Apple",
			"Hay", "Wood", "Water", "Fertilizer", "WeirdSubstance", "Gold", "Bone", "Power",
			"DinosaurHat", "StrawHat", "TopHat", "Pumpkins"]:
		hl.add_keyword_color(word, FarmPalette.SYN_ENUM)
	hl.add_color_region("//", "", FarmPalette.SYN_COMMENT, true)
	hl.add_color_region("/*", "*/", FarmPalette.SYN_COMMENT, false)
	hl.add_color_region("#", "", FarmPalette.SYN_PREPROC, true)
	hl.add_color_region("\"", "\"", FarmPalette.SYN_STRING, false)
	hl.add_color_region("'", "'", FarmPalette.SYN_STRING, false)
	editor.syntax_highlighter = hl
	highlighter = hl
	editor.highlight_all_occurrences = true
	editor.caret_blink = true
	for view in extra_views:
		if view:
			(view as TextEdit).syntax_highlighter = hl.duplicate()

# --- Completion --------------------------------------------------------------

func enable_completion() -> void:
	editor.code_completion_enabled = true
	editor.code_completion_prefixes = PackedStringArray()
	editor.code_completion_requested.connect(_on_completion_requested)
	editor.text_changed.connect(on_text_changed)


func on_text_changed() -> void:
	edited.emit()
	if _pending_paren_adjust:
		_pending_paren_adjust = false
		_adjust_caret_in_parens()
	var prefix := _ident_prefix()
	if prefix.length() >= 1 and _prefix_is_ident(prefix) and not _caret_in_comment():
		if prefix != _completion_prefix:
			_completion_prefix = prefix
			editor.request_code_completion(true)
	else:
		_completion_prefix = ""


func _prefix_is_ident(prefix: String) -> bool:
	if prefix.is_empty():
		return false
	var ch := prefix.unicode_at(0)
	return (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95


func _ident_prefix() -> String:
	var line := editor.get_line(editor.get_caret_line())
	var col := editor.get_caret_column()
	var i := col - 1
	while i >= 0:
		var ch := line.unicode_at(i)
		var ok := (ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95
		if not ok:
			break
		i -= 1
	return line.substr(i + 1, col - (i + 1))


func _caret_in_comment() -> bool:
	var line := editor.get_line(editor.get_caret_line())
	var col := editor.get_caret_column()
	var trimmed := line.strip_edges()
	if trimmed.begins_with("#"):
		return true
	var slash := line.find("//")
	return slash >= 0 and slash < col


func _inside_move_call() -> bool:
	var line := editor.get_line(editor.get_caret_line())
	var col := editor.get_caret_column()
	var before := line.substr(0, col)
	var open := before.rfind("move(")
	if open < 0:
		return false
	var close := before.rfind(")")
	return close < open


func _on_completion_requested() -> void:
	var prefix := _ident_prefix()
	_completion_prefix = prefix
	var items := _completion_items()
	if _inside_move_call() and host.movement_unlocked():
		items = _dir_items() + items
	var seen := {}
	for item in items:
		var display: String = item[0]
		var insert: String = item[1]
		var kind: int = item[2]
		var color: Color = item[3]
		if prefix != "" and not insert.begins_with(prefix) and not display.begins_with(prefix):
			var lower_ins := insert.to_lower()
			var lower_pre := prefix.to_lower()
			if not lower_ins.begins_with(lower_pre) and display.find(prefix) < 0:
				continue
		if seen.has(insert):
			continue
		seen[insert] = true
		editor.add_code_completion_option(kind, display, insert, color)
	editor.update_code_completion_options(true)
	_pending_paren_adjust = true


func _completion_items() -> Array:
	var fn := FarmPalette.SYN_FUNC
	var kw := FarmPalette.SYN_KEYWORD
	var sn := FarmPalette.SYN_TYPE
	var en := FarmPalette.SYN_ENUM
	var kind_fn := CodeEdit.KIND_FUNCTION
	var kind_kw := CodeEdit.KIND_PLAIN_TEXT
	var kind_const := CodeEdit.KIND_CONSTANT
	var items: Array = []
	items.append(["harvest()    收割成熟的草", "harvest()", kind_fn, fn])
	items.append(["do_a_flip()    翻一个跟头", "do_a_flip()", kind_fn, fn])
	if host.movement_unlocked():
		items.append(["move(East)    向东走一格，边缘环绕", "move(East)", kind_fn, fn])
		items.append(["move(West)    向西走一格", "move(West)", kind_fn, fn])
		items.append(["move(North)    向北走一格", "move(North)", kind_fn, fn])
		items.append(["move(South)    向南走一格", "move(South)", kind_fn, fn])
		for d in ["East", "West", "North", "South"]:
			items.append([d + "    方向", d, kind_const, FarmPalette.GOLD_SOFT])
	if host.for_unlocked():
		items.append(["for (int i = 0; i < 3; i++)    计数循环，走过一垄", "for (int i = 0; i < 3; i++) {\n        \n    }", kind_kw, sn])
	if host.till_unlocked():
		items.append(["till()    把草地翻成耕地，或把耕地翻回草地", "till()", kind_fn, fn])
	if host.plant_unlocked():
		items.append(["plant(Bush)    在空的耕地上种灌木", "plant(Bush)", kind_fn, fn])
		items.append(["get_entity_type()    脚下的作物", "get_entity_type()", kind_fn, fn])
		items.append(["get_ground_type()    脚下的地面", "get_ground_type()", kind_fn, fn])
		for d in ["Bush", "Grass", "None", "Soil", "Grassland"]:
			items.append([d + "    实体或地面", d, kind_const, FarmPalette.GOLD_SOFT])
	items.append(["int    整数类型 / 入口返回值", "int", kind_kw, kw])
	items.append(["return    结束 main", "return", kind_kw, kw])
	items.append(["using    例如 using namespace std;", "using", kind_kw, kw])
	items.append(["namespace    与 using 一起用", "namespace", kind_kw, kw])
	items.append(["else    否则", "else", kind_kw, kw])
	items.append(["true", "true", kind_kw, kw])
	items.append(["false", "false", kind_kw, kw])
	items.append(["enum    枚举声明", "enum", kind_kw, kw])
	items.append(["void", "void", kind_kw, kw])
	if host.loops_unlocked():
		items.append(["while    循环", "while", kind_kw, kw])
		if host.conditions_unlocked():
			items.append(["while (true) { … }    循环收割模板", "while (true) {\n        if (can_harvest()) {\n            harvest();\n        }\n    }", kind_kw, sn])
		else:
			items.append(["while (true) { harvest(); }    循环收割", "while (true) {\n        harvest();\n    }", kind_kw, sn])
	if host.conditions_unlocked():
		items.append(["if    条件判断", "if", kind_kw, kw])
		items.append(["can_harvest()    脚下的作物是否成熟", "can_harvest()", kind_fn, fn])
		items.append(["if (can_harvest()) { harvest(); }    成熟再收", "if (can_harvest()) {\n        harvest();\n    }", kind_kw, sn])
	items.append(["int main()    标准入口模板", "int main() {\n    \n    return 0;\n}", kind_kw, sn])
	items.append(["#include <bits/stdc++.h>", "#include <bits/stdc++.h>", kind_kw, sn])
	return items


func _dir_items() -> Array:
	var items: Array = []
	for d in [["East", "向东"], ["West", "向西"], ["North", "向北"], ["South", "向南"]]:
		items.append([d[0] + "    " + d[1], d[0], CodeEdit.KIND_CONSTANT, FarmPalette.SYN_ENUM])
	return items


func _adjust_caret_in_parens() -> void:
	var line := editor.get_line(editor.get_caret_line())
	var col := editor.get_caret_column()
	if col >= 2 and col <= line.length() and line[col - 1] == ")" and line[col - 2] == "(":
		editor.set_caret_column(col - 1)
