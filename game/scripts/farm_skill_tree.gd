extends Node
## The 技能树 panel: a zoomable, draggable learning-path canvas with one card
## per skill, curved branch lines, buy / shortfall feedback, and a detail
## sheet with the skill's pain, remedy and full exemplar.
##
## Buying goes through the simulator (host.try_unlock). What a purchase means
## for the rest of the game (hay, hint, save) is main's job via `bought`.

const FarmIcon := preload("res://scripts/farm_icons.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")
const FarmPalette := preload("res://scripts/farm_palette.gd")
const FarmUiKit := preload("res://scripts/farm_ui_kit.gd")

## A skill was unlocked from the tree.
signal bought(id: String)
## The tree should be rebuilt (costs and states changed) if it is still shown.
signal rebuild_requested
## 载入: replace main.cpp with this skill's exemplar.
signal load_exemplar_requested(id: String)
## 复制: the exemplar text was put on the clipboard.
signal template_copied(text: String)

var host: CodefarmHost
var ui: FarmUiKit
## The scroll/zoom container and the detail sheet while the panel is open.
var scroll: ScrollContainer
var detail: Control
var selected_id := ""
## Zoom and scroll restored on the next build (and saved with progress).
var view := {"zoom": 1.0, "scroll": Vector2.ZERO}

var _root: Control
var _glow_nodes: Array = []
var _more_hint: Control
var _sfx: Callable          # (String) -> void
var _highlighter: Callable  # () -> CodeHighlighter


func setup(sim_host: CodefarmHost, ui_kit: FarmUiKit, deps: Dictionary) -> void:
	host = sim_host
	ui = ui_kit
	_sfx = deps["sfx"]
	_highlighter = deps["highlighter"]


## Remember the current view and forget the nodes (the overlay is being cleared).
func release() -> void:
	if is_instance_valid(scroll) and scroll.is_inside_tree():
		view = {"zoom": scroll.get("zoom"), "scroll": Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)}
		scroll = null
	_glow_nodes.clear()
	detail = null
	_root = null


## Current zoom/scroll, read live while the tree is open.
func capture_view() -> Dictionary:
	if is_instance_valid(scroll):
		view = {"zoom": scroll.zoom, "scroll": Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)}
	return view


## Gentle glow on cards that can be bought now.
func pulse(t: float) -> void:
	var p := 0.5 + 0.5 * sin(t * 2.4)
	for card in _glow_nodes:
		if card is Control and is_instance_valid(card):
			var m := 1.0 + 0.08 * p
			(card as Control).modulate = Color(m, m, 0.92 + 0.08 * p, 1)


func _nodes() -> Array:
	return FarmSkillData.nodes(host)


func _template(id: String) -> String:
	return FarmSkillData.exemplar(id)


func _owned(id: String) -> bool:
	return id == "harvest" or bool(host.is_unlocked(id))


## Build the tree into `parent` (the overlay body). Restores the last view.
func build(parent: Control) -> void:
	_glow_nodes.clear()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(root)
	_root = root

	var sc := preload("res://scripts/farm_skill_scroll.gd").new()
	sc.node_clicked.connect(click)
	sc.name = "SkillScroll"
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = 44
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(sc)
	scroll = sc

	var wrap := Control.new()
	wrap.name = "SkillWrap"
	wrap.custom_minimum_size = FarmSkillData.CANVAS_SIZE
	sc.add_child(wrap)
	var canvas := Control.new()
	canvas.name = "SkillCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.add_child(canvas)
	sc.configure(canvas, wrap, FarmSkillData.CANVAS_SIZE)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(toolbar)
	var guide := Label.new()
	guide.text = "学习路线 · 左拖 / 滚轮缩放"
	guide.tooltip_text = "主线向下，支线补充；完整前置见节点提示。左键拖动，滚轮缩放。"
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(guide, 17, FarmPalette.TEXT)
	toolbar.add_child(guide)
	var zoom_label := Label.new()
	ui.apply_font(zoom_label, 16, FarmPalette.TEXT)
	zoom_label.text = "100%"
	toolbar.add_child(zoom_label)
	sc.zoom_changed.connect(func(value: float) -> void: zoom_label.text = "%d%%" % roundi(value * 100.0))
	var overview := ui.make_button("全貌", false, 72)
	overview.name = "SkillFitAll"
	overview.tooltip_text = "缩放到完整技能树"
	overview.pressed.connect(sc.fit_all)
	toolbar.add_child(overview)
	var actual := ui.make_button("还原", false, 72)
	actual.name = "SkillZoomReset"
	actual.pressed.connect(func() -> void: sc.zoom_about(1.0))
	toolbar.add_child(actual)

	var nodes := _nodes()
	var index := {}
	for node in nodes:
		index[node["id"]] = node

	var lines := Control.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node_w := 100.0
	var node_h := 120.0
	lines.draw.connect(func() -> void:
		var pairs := FarmSkillData.edges()
		for pair in pairs:
			var a: Dictionary = index[pair[0]]
			var b: Dictionary = index[pair[1]]
			var same_row: bool = absf(float((a["pos"] as Vector2).y) - float((b["pos"] as Vector2).y)) < 8.0
			var pa: Vector2
			var pb: Vector2
			var detour := false
			if same_row:
				var left_first: bool = (a["pos"] as Vector2).x <= (b["pos"] as Vector2).x
				pa = a["pos"] + Vector2(node_w if left_first else 0.0, node_h * 0.5)
				pb = b["pos"] + Vector2(0.0 if left_first else node_w, node_h * 0.5)
				var x0 := minf(pa.x, pb.x)
				var x1 := maxf(pa.x, pb.x)
				for other in nodes:
					if str(other["id"]) == str(a["id"]) or str(other["id"]) == str(b["id"]):
						continue
					var op: Vector2 = other["pos"]
					if absf(op.y - float((a["pos"] as Vector2).y)) < 8.0 and op.x + 10.0 < x1 and op.x + node_w - 10.0 > x0:
						detour = true
						break
			else:
				pa = a["pos"] + Vector2(node_w * 0.5, node_h - 2.0)
				pb = b["pos"] + Vector2(node_w * 0.5, 2.0)
			var col := Color(0.62, 0.58, 0.50, 0.30)
			var width := 2.0
			if a["owned"] and b["owned"]:
				col = Color(0.56, 0.72, 0.58, 0.95)
				width = 2.6
			elif a["owned"] and not b.get("soon", false):
				col = Color(0.56, 0.72, 0.58, 0.50)
				width = 2.2
			_draw_skill_branch(lines, pa, pb, col, width, detour)
	)
	canvas.add_child(lines)

	for node in nodes:
		var card := _node_card(node)
		card.position = node["pos"]
		canvas.add_child(card)
	lines.queue_redraw()

	_more_hint = Control.new()
	_more_hint.name = "SkillMoreHint"
	_more_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_more_hint.offset_top = -36
	_more_hint.offset_bottom = 0
	_more_hint.draw.connect(func() -> void:
		if scroll == null:
			return
		var bar := scroll.get_v_scroll_bar()
		if bar and bar.value < bar.max_value - scroll.size.y - 8:
			var w := _more_hint.size.x
			var h := _more_hint.size.y
			_more_hint.draw_rect(Rect2(0, 0, w, h), Color(0.975, 0.957, 0.910, 0.0))
			var fade := Color(0.975, 0.957, 0.910, 0.75)
			for i in 10:
				var a := 0.0 + 0.07 * float(i)
				_more_hint.draw_rect(Rect2(0, h * float(i) / 10.0, w, h / 10.0 + 1), Color(fade.r, fade.g, fade.b, a))
			var mid := Vector2(w * 0.5, h * 0.62)
			_more_hint.draw_colored_polygon(PackedVector2Array([
				mid + Vector2(-10, -4), mid + Vector2(10, -4), mid + Vector2(0, 6)
			]), Color(0.68, 0.49, 0.25, 0.60))
	)
	root.add_child(_more_hint)
	var vbar := sc.get_v_scroll_bar()
	if vbar:
		vbar.value_changed.connect(func(_v: float) -> void:
			if _more_hint:
				_more_hint.queue_redraw()
		)
	# Nudge scroll so the first view already shows a cut-off lower branch.
	sc.zoom_about(float(view["zoom"]), Vector2.ZERO)
	sc.call_deferred("_apply_zoom_scroll", view["scroll"])
	detail = _make_detail()
	detail.visible = false
	root.add_child(detail)
	sc.blocking_control = detail
	if selected_id != "":
		open_detail(selected_id)


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


func _append_round_corner(points: PackedVector2Array, p: Vector2, q: Vector2, r: Vector2, radius: float) -> void:
	var v1 := p - q
	var v2 := r - q
	var l1 := v1.length()
	var l2 := v2.length()
	if l1 < 1.0 or l2 < 1.0:
		points.append(q)
		return
	var rad := minf(radius, minf(l1, l2) * 0.48)
	var a := q + v1 * (rad / l1)
	var c := q + v2 * (rad / l2)
	points.append(a)
	for i in range(1, 7):
		var t := float(i) / 6.0
		points.append(_cubic_bezier(a, a.lerp(q, 0.55), c.lerp(q, 0.55), c, t))
	points.append(c)


func _draw_skill_branch(ci: Control, a: Vector2, b: Vector2, col: Color, width: float, detour_below: bool = false) -> void:
	var dy := b.y - a.y
	var dx := b.x - a.x
	var points := PackedVector2Array()
	if detour_below:
		var dip := 28.0
		points.append(a)
		_append_round_corner(points, a, Vector2(a.x, a.y + dip), Vector2(b.x, a.y + dip), 14.0)
		_append_round_corner(points, Vector2(a.x, a.y + dip), Vector2(b.x, a.y + dip), b, 14.0)
		points.append(b)
	elif absf(dx) < 8.0:
		# Same column: a slightly eased vertical.
		var mid := (a + b) * 0.5
		for i in 8:
			var t := float(i) / 7.0
			points.append(_cubic_bezier(a, Vector2(a.x, mid.y), Vector2(b.x, mid.y), b, t))
	elif absf(dy) < 28.0:
		var sx := signf(dx) * clampf(absf(dx) * 0.4, 24.0, 56.0)
		_append_round_corner(points, a, a + Vector2(sx, 0), b, 18.0)
		points.append(b)
		if points.is_empty() or points[0] != a:
			var prefixed := PackedVector2Array([a])
			prefixed.append_array(points)
			points = prefixed
	else:
		# Rounded orthogonal: down from parent, across, down into the child.
		# Keep the horizontal in the corridor just below the parent so lines don't cut cards.
		var stub := 22.0
		var mid := Vector2(b.x, a.y + stub)
		var drop := Vector2(b.x, b.y)
		points.append(a)
		_append_round_corner(points, a, Vector2(a.x, a.y + stub), mid, 16.0)
		_append_round_corner(points, Vector2(a.x, a.y + stub), mid, drop, 16.0)
		points.append(b)
	if points.size() < 2:
		return
	ci.draw_polyline(points, col, width, true)


func _node_card(node: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Skill_" + str(node["id"])
	card.custom_minimum_size = FarmSkillData.CARD_SIZE
	card.size = FarmSkillData.CARD_SIZE
	var owned: bool = node["owned"]
	var soon: bool = node.get("soon", false)
	var id := str(node["id"])
	var can_buy := false
	if not soon and id != "harvest":
		can_buy = bool(node.get("can_buy", false)) or (not owned and host.can_unlock(id))
	var bg := Color(0.99, 0.93, 0.76, 1) if owned else Color(0.93, 0.92, 0.87, 1)
	if soon:
		bg = Color(0.92, 0.91, 0.87, 0.6)
	elif not owned:
		bg = Color(0.945, 0.935, 0.895, 1)
	var style := ui.flat(bg, 16, Vector4(6, 5, 6, 4), 4)
	if can_buy:
		style.border_color = Color(0.50, 0.70, 0.54, 1)
		style.set_border_width_all(2)
	elif owned:
		style.border_color = Color(0.90, 0.76, 0.48, 0.9)
		style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not soon else Control.CURSOR_ARROW
	if soon:
		card.tooltip_text = "即将开放"
	elif not owned:
		card.tooltip_text = "前置：%s\n%s" % [FarmSkillData.prerequisite_text(id), FarmSkillData.cost_text(node.get("cost_map", {}))]
	else:
		card.tooltip_text = "已解锁 · 点击查看"
	card.tooltip_text = FarmSkillData.guidance(id) + "\n" + card.tooltip_text

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var icon := FarmIcon.new()
	if soon:
		icon.kind = FarmIcon.Kind.LOCK
		icon.icon_color = Color(0.60, 0.58, 0.52, 0.5)
	else:
		icon.kind = FarmIcon.kind_from_name(id)
		icon.icon_color = FarmPalette.ACCENT_SOFT if owned else Color(0.56, 0.56, 0.50, 0.85)
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)

	var title := Label.new()
	title.text = str(node["name"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(title, 18, FarmPalette.INK if owned else Color(0.40, 0.38, 0.34, 0.90 if not soon else 0.45), false)
	col.add_child(title)
	var purpose := Label.new()
	purpose.name = "SkillPurpose"
	purpose.text = str(node["pain"])
	purpose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purpose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	purpose.custom_minimum_size.x = 0
	ui.apply_font(purpose, 12, FarmPalette.TEXT_DIM)
	purpose.add_theme_constant_override("line_spacing", -4)
	col.add_child(purpose)

	var cmap: Dictionary = node.get("cost_map", {})
	var price_text := FarmSkillData.cost_text(cmap) if not cmap.is_empty() else (str(node.get("cost", 0)) if int(node.get("cost", 0)) > 0 else "")
	if (not owned or can_buy) and not soon and price_text != "" and price_text != "0":
		var cost := Label.new()
		cost.text = price_text.replace(" + ", "\n")
		cost.name = "CostLabel"
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost.max_lines_visible = 2
		cost.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cost.tooltip_text = price_text
		ui.apply_font(cost, 12, FarmPalette.ACCENT_SOFT if can_buy else Color(0.56, 0.53, 0.47, 0.9), false)
		cost.add_theme_constant_override("line_spacing", -4)
		col.add_child(cost)

	var shortfall := Label.new()
	shortfall.name = "Shortfall"
	shortfall.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortfall.visible = false
	ui.apply_font(shortfall, 14, FarmPalette.DANGER)
	var feedback := Control.new()
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(feedback)
	feedback.add_child(shortfall)
	shortfall.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shortfall.offset_top = -26
	shortfall.offset_bottom = -2

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_node_clicked(id, card)
			card.accept_event()
	)
	if not soon:
		card.mouse_entered.connect(func() -> void: style.bg_color = bg.lightened(0.10))
		card.mouse_exited.connect(func() -> void: style.bg_color = bg)
	card.set_meta("skill_id", id)
	card.set_meta("can_buy", can_buy)
	card.set_meta("base_border", style.border_color)
	if can_buy:
		_glow_nodes.append(card)
	return card


## Click a node as the player would (tests and scripted tours use this).
func click(id: String) -> void:
	var card: Control = null
	if is_instance_valid(_root):
		card = _root.find_child("Skill_" + id, true, false)
	on_node_clicked(id, card)


func on_node_clicked(id: String, card: Control = null) -> void:
	var nodes := _nodes()
	var node: Dictionary = {}
	for n in nodes:
		if str(n["id"]) == id:
			node = n
			break
	if node.is_empty() or node.get("soon", false):
		return
	if id == "harvest" or (node["owned"] and not host.can_unlock(id)):
		open_detail(id)
		return
	if host.can_unlock(id):
		var code: int = int(host.try_unlock(id))
		if code == 0:
			bought.emit(id)
			selected_id = ""
			if card:
				var shown_scroll_id := scroll.get_instance_id()
				card.pivot_offset = card.size * 0.5
				_play_unlock_flourish(card)
				var tw := create_tween()
				tw.tween_interval(0.26)
				tw.tween_callback(func() -> void:
					# A late unlock flourish must not rebuild a NEW tree after
					# close/reopen and reset the player's current scroll.
					if is_instance_valid(scroll) and scroll.get_instance_id() == shown_scroll_id:
						rebuild_requested.emit()
				)
			else:
				rebuild_requested.emit()
		return
	# Not enough hay or missing prerequisite: shake, show shortfall if it's hay.
	open_detail(id)
	if card:
		_shake_card(card)
		if host.prerequisite_met(id):
			var need: int = int(host.hay_shortfall(id))
			var badge: Label = card.find_child("Shortfall", true, false)
			if badge:
				badge.text = "差 %d" % need
				badge.visible = true
				var cost: Label = card.find_child("CostLabel", true, false)
				if cost:
					cost.visible = false
				var tw := card.create_tween()
				tw.tween_interval(0.9)
				tw.tween_callback(func() -> void:
					if is_instance_valid(badge):
						badge.visible = false
					if is_instance_valid(cost):
						cost.visible = true
				)


func _shake_card(card: Control) -> void:
	_sfx.call("deny")
	FarmMotion.stop(card, "_fm_shake")
	var origin: Vector2 = card.get_meta("_fm_shake_origin", card.position)
	card.set_meta("_fm_shake_origin", origin)
	var tw := card.create_tween()
	card.set_meta("_fm_shake", tw)
	tw.tween_property(card, "position:x", origin.x - 5, 0.04)
	tw.tween_property(card, "position:x", origin.x + 5, 0.05)
	tw.tween_property(card, "position:x", origin.x - 3, 0.04)
	tw.tween_property(card, "position:x", origin.x, 0.05)


func _play_unlock_flourish(card: Control) -> void:
	_sfx.call("unlock")
	if card == null:
		return
	FarmMotion.stop(card, "_fm_feedback")
	var tw := card.create_tween()
	card.set_meta("_fm_feedback", tw)
	tw.tween_property(card, "scale:x", 0.08, 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(card, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func scroll_toward(id: String) -> void:
	if scroll == null:
		return
	for node in _nodes():
		if str(node["id"]) == id:
			var pos: Vector2 = node["pos"] * float(scroll.get("zoom"))
			scroll.scroll_vertical = int(max(0.0, pos.y - 280.0))
			scroll.scroll_horizontal = int(max(0.0, pos.x - 420.0))
			return


func _make_detail() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SkillDetail"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -210
	panel.offset_bottom = 210
	panel.add_theme_stylebox_override("panel", ui.flat(FarmPalette.PANEL_DEEP, 20, Vector4(18, 16, 18, 16), 18))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.name = "DetailTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(title, 22, FarmPalette.ACCENT_SOFT, true)
	head.add_child(title)
	var close := ui.make_icon_button(FarmIcon.Kind.CLOSE, "关闭", false, Vector2(44, 44))
	close.pressed.connect(func() -> void:
		close_detail()
	)
	head.add_child(close)
	var knowledge := Label.new()
	knowledge.name = "DetailKnowledge"
	knowledge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.apply_font(knowledge, 19, FarmPalette.TEXT)
	v.add_child(knowledge)
	var ex_title := Label.new()
	ex_title.name = "DetailExemplarTitle"
	ex_title.text = "范本"
	ui.apply_font(ex_title, 18, FarmPalette.ACCENT_SOFT, true)
	v.add_child(ex_title)
	var code := CodeEdit.new()
	code.name = "DetailCode"
	code.editable = false
	code.gutters_draw_line_numbers = false
	code.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	code.custom_minimum_size = Vector2(0, 168)
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if ui.font_mono:
		code.add_theme_font_override("font", ui.font_mono)
	code.add_theme_font_size_override("font_size", 16)
	code.add_theme_color_override("font_color", FarmPalette.SYN_IDENT)
	code.add_theme_color_override("font_readonly_color", FarmPalette.SYN_IDENT)
	var ed := ui.flat(FarmPalette.EDITOR_BG, 12, Vector4(10, 8, 10, 8))
	code.add_theme_stylebox_override("normal", ed)
	code.add_theme_stylebox_override("read_only", ed)
	code.add_theme_stylebox_override("focus", ed)
	v.add_child(code)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	var copy_btn := ui.make_button("复制", false, 88)
	copy_btn.name = "CopyTemplate"
	copy_btn.tooltip_text = "复制完整主程序到剪贴板"
	copy_btn.pressed.connect(copy_selected_template)
	actions.add_child(copy_btn)
	var insert_btn := ui.make_button("载入", false, 88)
	insert_btn.name = "InsertTemplate"
	insert_btn.tooltip_text = "替换 main.cpp，并载入配套头文件"
	insert_btn.pressed.connect(_insert_selected_template)
	actions.add_child(insert_btn)
	var copied := Label.new()
	copied.name = "CopiedHint"
	copied.text = "已复制"
	copied.visible = false
	ui.apply_font(copied, 17, FarmPalette.ACCENT_SOFT)
	actions.add_child(copied)
	return panel


func _mark_selection(id: String) -> void:
	if not is_instance_valid(scroll):
		return
	for card in scroll.find_children("Skill_*", "PanelContainer", true, false):
		if card.has_meta("skill_id"):
			var style: StyleBoxFlat = card.get_theme_stylebox("panel")
			style.border_color = FarmPalette.ACCENT_SOFT if str(card.get_meta("skill_id")) == id else card.get_meta("base_border")


func open_detail(id: String) -> void:
	selected_id = id
	_mark_selection(id)
	if is_instance_valid(scroll):
		scroll.call("_cancel_drag")
	if detail == null:
		return
	var title: Label = detail.find_child("DetailTitle", true, false)
	var knowledge: Label = detail.find_child("DetailKnowledge", true, false)
	var code: CodeEdit = detail.find_child("DetailCode", true, false)
	var name := id
	for n in _nodes():
		if str(n["id"]) == id:
			name = str(n["name"])
			break
	if title:
		title.text = name
	var owned := _owned(id)
	if knowledge:
		var lines: PackedStringArray = [FarmSkillData.pain(id), FarmSkillData.remedy(id), "下一行：" + FarmSkillData.next_line(id)]
		if id in ["speed", "iff"]:
			lines = [FarmSkillData.pain(id), "在 while 里加：if (can_harvest()) harvest();"]
		if not owned:
			lines.append("前置：" + FarmSkillData.prerequisite_text(id))
		knowledge.text = "\n".join(lines)
	var ex_title: Label = detail.find_child("DetailExemplarTitle", true, false)
	if ex_title:
		ex_title.text = "完整范本 · 载入替换主程序" if owned else "范本：解锁后显示"
	if code:
		# The exemplar is shown only once the skill is owned.
		code.text = _template(id) if owned else ""
		code.visible = owned
		var hl: CodeHighlighter = _highlighter.call()
		if hl:
			code.syntax_highlighter = hl.duplicate()
	for btn_name in ["CopyTemplate", "InsertTemplate"]:
		var btn: Control = detail.find_child(btn_name, true, false)
		if btn:
			btn.visible = owned
	FarmMotion.open_popup(detail)


func close_detail() -> void:
	selected_id = ""
	_mark_selection("")
	if detail:
		FarmMotion.close_popup(detail)


func copy_selected_template() -> void:
	if not _owned(selected_id):
		return
	var text := _template(selected_id)
	if text.is_empty():
		return
	template_copied.emit(text)
	DisplayServer.clipboard_set(text)
	if detail:
		var hint: Label = detail.find_child("CopiedHint", true, false)
		FarmMotion.flash_label(hint)


func _insert_selected_template() -> void:
	load_exemplar_requested.emit(selected_id)
