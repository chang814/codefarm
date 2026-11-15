extends Control
## The harvest flying home: icons leap off the tile, arc across the screen to
## their counter in the top bar, and the counter gives a small bounce with a
## floating "+n". Purely visual; counts always come from the simulator.

const FarmIcon := preload("res://scripts/farm_icons.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")

const TOKEN_SIZE := 30.0
const MAX_TOKENS := 6
const FLIGHT := 0.52

var _font: Font


func _ready() -> void:
	name = "CollectFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_font(font: Font) -> void:
	_font = font


## Fly `amount` of something from a screen point to `chip` (a top-bar counter
## row). `kind` and `color` pick the icon.
func collect(from: Vector2, chip: Control, kind: FarmIcon.Kind, color: Color, amount: int) -> void:
	if amount <= 0 or not is_instance_valid(chip) or not is_inside_tree():
		return
	var count := clampi(2 + int(log(float(amount)) / log(2.0)), 2, MAX_TOKENS)
	for i in count:
		_launch(from, chip, kind, color, i, count, amount if i == count - 1 else 0)


func _launch(from: Vector2, chip: Control, kind: FarmIcon.Kind, color: Color, index: int, count: int, payload: int) -> void:
	var token := FarmIcon.new()
	token.kind = kind
	token.icon_color = color
	token.size = Vector2.ONE * TOKEN_SIZE
	token.pivot_offset = token.size * 0.5
	token.scale = Vector2.ZERO
	add_child(token)
	# Fan out from the tile first, then get pulled into the counter.
	var ang := -PI * 0.5 + (float(index) - float(count - 1) * 0.5) * 0.55
	var burst := from + Vector2(cos(ang), sin(ang)) * (46.0 + 9.0 * float(index % 3))
	var half := token.size * 0.5
	var tw := create_tween()
	tw.tween_interval(0.035 * float(index))
	tw.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(chip):
				return
			var target := chip.get_global_rect().get_center()
			# Pop out quickly, hang for a beat, then accelerate home.
			var out := 1.0 - pow(1.0 - minf(1.0, t / 0.34), 3.0)
			var home := pow(clampf((t - 0.26) / 0.74, 0.0, 1.0), 2.4)
			var pos := from.lerp(burst, out).lerp(target, home)
			token.global_position = pos - half
			var grow := sin(minf(1.0, t / 0.22) * PI * 0.5)
			token.scale = Vector2.ONE * grow * lerpf(1.12, 0.62, home)
			token.rotation = (1.0 - home) * 0.5 * sin(t * 9.0 + float(index)),
		0.0,
		1.0,
		FLIGHT + 0.02 * float(index)
	)
	tw.tween_callback(func() -> void:
		token.queue_free()
		if is_instance_valid(chip):
			_arrive(chip, color, payload)
	)


func _arrive(chip: Control, color: Color, payload: int) -> void:
	# Every arrival nudges the counter; the last one carries the "+n".
	chip.pivot_offset = chip.size * 0.5
	FarmMotion.stop(chip, "_collect_pop")
	chip.scale = Vector2.ONE * (1.16 if payload > 0 else 1.08)
	var pop := chip.create_tween()
	chip.set_meta("_collect_pop", pop)
	pop.tween_property(chip, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if payload <= 0:
		return
	var plus := Label.new()
	plus.text = "+%d" % payload
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		plus.add_theme_font_override("font", _font)
	plus.add_theme_font_size_override("font_size", 20)
	plus.add_theme_color_override("font_color", color)
	plus.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	plus.add_theme_constant_override("outline_size", 6)
	add_child(plus)
	var rect := chip.get_global_rect()
	plus.global_position = Vector2(rect.get_center().x - 14.0, rect.end.y + 2.0)
	var rise := plus.create_tween().set_parallel(true)
	rise.tween_property(plus, "position:y", plus.position.y + 22.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(plus, "modulate:a", 0.0, 0.35).set_delay(0.45)
	rise.chain().tween_callback(plus.queue_free)
