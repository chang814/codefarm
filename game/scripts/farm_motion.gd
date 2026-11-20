extends Object
class_name FarmMotion

## Short, soft UI motion used by windows, overlays, and chrome buttons.
## Feedback settles quickly; window geometry has its own 300ms transition.

const OPEN_DUR := 0.24
const CLOSE_DUR := 0.17
const HOVER_DUR := 0.15
const TRANS := Tween.TRANS_CUBIC
const EASE := Tween.EASE_OUT
const HOVER_SCALE := 1.025
const PRESS_SCALE := 0.955
const OPEN_SCALE := 0.985
const LIFT := 14.0


static func stop(node: Node, key: String = "_fm_tw") -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta(key):
		var tw: Variant = node.get_meta(key)
		if tw is Tween and is_instance_valid(tw):
			tw.kill()
		node.remove_meta(key)


static func _make(node: Node, key: String = "_fm_tw") -> Tween:
	stop(node, key)
	var tw := node.create_tween()
	tw.set_parallel(true)
	node.set_meta(key, tw)
	return tw


static func center_pivot(ctrl: Control) -> void:
	if ctrl:
		ctrl.pivot_offset = ctrl.size * 0.5


static func tween_scale(ctrl: Control, to: Vector2, dur: float = HOVER_DUR) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	center_pivot(ctrl)
	var tw := _make(ctrl, "_fm_scale")
	tw.tween_property(ctrl, "scale", to, dur).set_trans(TRANS).set_ease(EASE)


static func bind_hover(ctrl: Control, hover_scale: float = HOVER_SCALE, press_scale: float = PRESS_SCALE) -> void:
	if ctrl == null or ctrl.get_meta("_fm_hover", false):
		return
	ctrl.set_meta("_fm_hover", true)
	ctrl.resized.connect(func() -> void: center_pivot(ctrl))
	center_pivot(ctrl)
	var rest: Color = Color.WHITE
	var shared: StyleBoxFlat
	if ctrl is Button and not ctrl.get_meta("_fm_custom_draw", false):
		var source := ctrl.get_theme_stylebox("normal")
		if source is StyleBoxFlat:
			shared = source.duplicate()
			rest = shared.bg_color
			for state in ["normal", "hover", "pressed", "hover_pressed"]:
				ctrl.add_theme_stylebox_override(state, shared)
	var update := func(over: bool, down: bool) -> void:
		if ctrl is BaseButton and ctrl.disabled:
			over = false
			down = false
		var tw := _make(ctrl, "_fm_feedback")
		var duration := 0.085 if down else 0.18
		tw.tween_property(ctrl, "scale", Vector2.ONE * (press_scale if down else (hover_scale if over else 1.0)), duration).set_trans(TRANS).set_ease(EASE)
		var target := 1.0 if over else 0.0
		tw.tween_method(func(value: float) -> void:
			ctrl.set_meta("_fm_over", value)
			ctrl.queue_redraw(), float(ctrl.get_meta("_fm_over", 0.0)), target, duration)
		if shared:
			var color := rest.darkened(0.12) if down else (rest.lightened(0.12) if over else rest)
			tw.tween_property(shared, "bg_color", color, duration).set_trans(TRANS).set_ease(EASE)
	ctrl.mouse_entered.connect(func() -> void: update.call(true, ctrl is BaseButton and ctrl.is_pressed()))
	ctrl.mouse_exited.connect(func() -> void: update.call(false, false))
	if ctrl is BaseButton:
		ctrl.button_down.connect(func() -> void: update.call(true, true))
		ctrl.button_up.connect(func() -> void: update.call(ctrl.is_hovered(), false))
		ctrl.focus_entered.connect(func() -> void: update.call(true, false))
		ctrl.focus_exited.connect(func() -> void: update.call(ctrl.is_hovered(), false))


## Content lives inside a clipping Control, outside container-driven positioning.
## Kill the previous tween so fast navigation always continues from current state.
static func slide_content(ctrl: Control, direction: float = 1.0) -> void:
	var interrupted := ctrl.has_meta("_fm_content") and absf(ctrl.position.x) > 0.1
	stop(ctrl, "_fm_content")
	if not interrupted:
		ctrl.position.x = 12.0 * direction
		ctrl.modulate.a = 0.75
	var tw := _make(ctrl, "_fm_content")
	tw.tween_property(ctrl, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_QUART).set_ease(EASE)
	tw.tween_property(ctrl, "modulate:a", 1.0, 0.18).set_trans(TRANS).set_ease(EASE)


static func open_popup(ctrl: Control, dur: float = OPEN_DUR) -> void:
	if ctrl == null:
		return
	var was_visible := ctrl.visible
	stop(ctrl)
	ctrl.set_meta("_fm_closing", false)
	ctrl.visible = true
	center_pivot(ctrl)
	if not was_visible:
		ctrl.modulate.a = 0.0
		ctrl.scale = Vector2(OPEN_SCALE, OPEN_SCALE)
	var tw := _make(ctrl)
	tw.tween_property(ctrl, "modulate:a", 1.0, dur).set_trans(TRANS).set_ease(EASE)
	tw.tween_property(ctrl, "scale", Vector2.ONE, dur).set_trans(TRANS).set_ease(EASE)


static func close_popup(ctrl: Control, dur: float = CLOSE_DUR, on_done: Callable = Callable()) -> void:
	if ctrl == null or not ctrl.visible:
		if on_done.is_valid():
			on_done.call()
		return
	center_pivot(ctrl)
	ctrl.set_meta("_fm_closing", true)
	var tw := _make(ctrl)
	tw.tween_property(ctrl, "modulate:a", 0.0, dur).set_trans(TRANS).set_ease(EASE)
	tw.tween_property(ctrl, "scale", Vector2(OPEN_SCALE, OPEN_SCALE), dur).set_trans(TRANS).set_ease(EASE)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(ctrl):
			ctrl.set_meta("_fm_closing", false)
			ctrl.visible = false
			ctrl.modulate.a = 1.0
			ctrl.scale = Vector2.ONE
		if on_done.is_valid():
			on_done.call()
	)


static func open_overlay(backdrop: Control, card: Control, dur: float = OPEN_DUR) -> void:
	var was_visible := card != null and card.visible
	if backdrop:
		stop(backdrop)
		if not backdrop.visible:
			backdrop.modulate.a = 0.0
		backdrop.visible = true
	if card == null:
		if backdrop:
			var twb := _make(backdrop)
			twb.tween_property(backdrop, "modulate:a", 1.0, dur).set_trans(TRANS).set_ease(EASE)
		return
	stop(card)
	card.visible = true
	if not was_visible:
		card.modulate.a = 0.0
	if not card.has_meta("_fm_base_top"):
		card.set_meta("_fm_base_top", card.offset_top)
		card.set_meta("_fm_base_bot", card.offset_bottom)
	var base_top: float = float(card.get_meta("_fm_base_top"))
	var base_bot: float = float(card.get_meta("_fm_base_bot"))
	if not was_visible:
		card.offset_top = base_top + LIFT
		card.offset_bottom = base_bot + LIFT
	var tw := _make(card)
	if backdrop:
		tw.tween_property(backdrop, "modulate:a", 1.0, dur).set_trans(TRANS).set_ease(EASE)
	tw.tween_property(card, "modulate:a", 1.0, dur).set_trans(TRANS).set_ease(EASE)
	tw.tween_property(card, "offset_top", base_top, dur).set_trans(TRANS).set_ease(EASE)
	tw.tween_property(card, "offset_bottom", base_bot, dur).set_trans(TRANS).set_ease(EASE)


static func close_overlay(backdrop: Control, card: Control, dur: float = CLOSE_DUR, instant: bool = false) -> void:
	var finish := func() -> void:
		if backdrop and is_instance_valid(backdrop):
			backdrop.visible = false
			backdrop.modulate.a = 1.0
		if card and is_instance_valid(card):
			card.visible = false
			card.modulate.a = 1.0
			if card.has_meta("_fm_base_top"):
				card.offset_top = float(card.get_meta("_fm_base_top"))
				card.offset_bottom = float(card.get_meta("_fm_base_bot"))
	if instant:
		if card:
			stop(card)
		if backdrop:
			stop(backdrop)
		finish.call()
		return
	if card == null or not card.visible:
		finish.call()
		return
	var base_top: float = float(card.get_meta("_fm_base_top")) if card.has_meta("_fm_base_top") else card.offset_top
	var base_bot: float = float(card.get_meta("_fm_base_bot")) if card.has_meta("_fm_base_bot") else card.offset_bottom
	var tw := _make(card)
	if backdrop:
		tw.tween_property(backdrop, "modulate:a", 0.0, dur).set_trans(TRANS).set_ease(EASE)
	tw.tween_property(card, "modulate:a", 0.0, dur).set_trans(TRANS).set_ease(EASE)
	tw.tween_property(card, "offset_top", base_top + LIFT, dur).set_trans(TRANS).set_ease(EASE)
	tw.tween_property(card, "offset_bottom", base_bot + LIFT, dur).set_trans(TRANS).set_ease(EASE)
	tw.chain().tween_callback(finish)


## Show a short status label (for example 已复制), then fade it out.
static func flash_label(label: Label) -> void:
	if label == null:
		return
	label.visible = true
	label.modulate = Color(1, 1, 1, 1)
	stop(label, "_copied")
	var tw := label.create_tween()
	label.set_meta("_copied", tw)
	tw.tween_interval(0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.visible = false
			label.modulate = Color(1, 1, 1, 1)
	)
