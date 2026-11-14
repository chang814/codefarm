extends Control
class_name FarmIcon

## Chunky, soft, filled / semi-filled icons. Round caps, fat strokes, simple shapes.

enum Kind {
	PLAY, PLAY_ONCE, STOP, CODE, SKILL, HINT, SETTINGS, LOG,
	HAY, WOOD, MINIMIZE, MAXIMIZE, RESTORE, CLOSE, RESET_CAM,
	HARVEST, LOOP, SPEED, IFF, MOVE, FOR, TILL, PLANT, VARS, FN, CHECK, SOON, LOCK,
	CARROT, PUMPKIN, POWER, WATER, FERT, WEIRD, GOLD, CACTUS, BONE,
	# Appended so earlier values keep their numbers.
	HAT, EXPAND, SENSE, MAZE, MEGA, DEBUG, CLOCK, LAB, DICE, KEY, BARS, COIN,
	CONST, OPS, ARRAY, STRUCT, SWITCH, REF, INCLUDE, YIELD, TREE, COMPANION, SUNFLOWER
}

var kind: Kind = Kind.PLAY:
	set(value):
		kind = value
		queue_redraw()

var icon_color := Color(0.88, 0.84, 0.76, 1):
	set(value):
		icon_color = value
		queue_redraw()

var stroke: float = 2.8


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var pad := minf(size.x, size.y) * 0.08
	draw_kind(self, kind, Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0), icon_color, stroke)


static func draw_kind(ci: CanvasItem, which: Kind, rect: Rect2, color: Color, width: float = 2.8) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var s := minf(rect.size.x, rect.size.y)
	rect = Rect2(rect.get_center() - Vector2.ONE * s * 0.5, Vector2.ONE * s)
	var w := maxf(maxf(width, 2.6), s * 0.125)
	match which:
		Kind.PLAY:
			_play_solid(ci, rect, color, w)
		Kind.PLAY_ONCE:
			_play_outline(ci, rect, color, w)
		Kind.STOP:
			_rounded_rect(ci, Rect2(rect.position + rect.size * 0.20, rect.size * 0.60), color, w, true, 4.0)
		Kind.CODE:
			_code(ci, rect, color, w)
		Kind.SKILL:
			_skill_tree(ci, rect, color, w)
		Kind.HINT:
			_glyph(ci, "bulb", rect, color, w)
		Kind.SETTINGS:
			_sliders(ci, rect, color, w)
		Kind.LOG:
			_document(ci, rect, color, w)
		Kind.HAY:
			_hay(ci, rect, color, w)
		Kind.WOOD:
			_wood(ci, rect, color, w)
		Kind.CARROT:
			_carrot(ci, rect, color, w)
		Kind.PUMPKIN:
			_pumpkin(ci, rect, color, w)
		Kind.POWER:
			_power(ci, rect, color, w)
		Kind.WATER:
			_water(ci, rect, color, w)
		Kind.FERT:
			_fert(ci, rect, color, w)
		Kind.WEIRD:
			_weird(ci, rect, color, w)
		Kind.GOLD:
			_gold(ci, rect, color, w)
		Kind.CACTUS:
			_cactus(ci, rect, color, w)
		Kind.BONE:
			_bone(ci, rect, color, w)
		Kind.MINIMIZE:
			_line(ci, rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.58), rect.position + Vector2(rect.size.x * 0.84, rect.size.y * 0.58), color, w * 1.15)
		Kind.MAXIMIZE:
			_rounded_rect(ci, rect.grow(-s * 0.14), color, w, false, 4.0)
			_rounded_rect(ci, rect.grow(-s * 0.22), _soft(color, 0.35), w, true, 3.2)
		Kind.RESTORE:
			_restore(ci, rect, color, w)
		Kind.CLOSE:
			var inset := rect.size * 0.24
			var a := rect.position + inset
			var b := rect.position + rect.size - inset
			_line(ci, a, b, color, w * 1.08)
			_line(ci, Vector2(b.x, a.y), Vector2(a.x, b.y), color, w * 1.08)
		Kind.RESET_CAM:
			_glyph(ci, "target", rect, color, w)
		Kind.HARVEST:
			_hay(ci, rect, color, w)
		Kind.LOOP:
			_loop(ci, rect, color, w)
		Kind.SPEED:
			_speed(ci, rect, color, w)
		Kind.IFF:
			_iff(ci, rect, color, w)
		Kind.MOVE:
			_move(ci, rect, color, w)
		Kind.FOR:
			_for_icon(ci, rect, color, w)
		Kind.TILL:
			_hoe(ci, rect, color, w)
		Kind.PLANT:
			_sprout(ci, rect, color, w)
		Kind.VARS:
			_vars(ci, rect, color, w)
		Kind.FN:
			_fn(ci, rect, color, w)
		Kind.CHECK:
			_check(ci, rect, color, w)
		Kind.SOON:
			_soon(ci, rect, color, w)
		Kind.LOCK:
			_lock(ci, rect, color, w)
		_:
			_glyph(ci, str(Kind.keys()[which]).to_lower(), rect, color, w)


static func kind_from_name(name: String) -> Kind:
	match name:
		"play":
			return Kind.PLAY
		"stop":
			return Kind.STOP
		"code":
			return Kind.CODE
		"skill":
			return Kind.SKILL
		"hint":
			return Kind.HINT
		"settings":
			return Kind.SETTINGS
		"log":
			return Kind.LOG
		"hay":
			return Kind.HAY
		"wood":
			return Kind.WOOD
		"reset_cam":
			return Kind.RESET_CAM
		"harvest":
			return Kind.HARVEST
		"loop":
			return Kind.LOOP
		"speed":
			return Kind.SPEED
		"iff":
			return Kind.IFF
		"move":
			return Kind.MOVE
		"forl":
			return Kind.FOR
		"till":
			return Kind.TILL
		"plant":
			return Kind.PLANT
		"vars":
			return Kind.VARS
		"fn", "func":
			return Kind.FN
		"constn":
			return Kind.CONST
		"ops":
			return Kind.OPS
		"array":
			return Kind.ARRAY
		"rec":
			return Kind.STRUCT
		"swenum":
			return Kind.SWITCH
		"ref":
			return Kind.REF
		"include":
			return Kind.INCLUDE
		"carrot":
			return Kind.CARROT
		"pumpkin":
			return Kind.PUMPKIN
		"cactus":
			return Kind.CACTUS
		"sun":
			return Kind.SUNFLOWER
		"hayup":
			return Kind.YIELD
		"water":
			return Kind.WATER
		"fert":
			return Kind.FERT
		"tree":
			return Kind.TREE
		"companion":
			return Kind.COMPANION
		"expand":
			return Kind.EXPAND
		"senses":
			return Kind.SENSE
		"costs":
			return Kind.COIN
		"maze":
			return Kind.MAZE
		"dino":
			return Kind.BONE
		"mega":
			return Kind.MEGA
		"debug":
			return Kind.DEBUG
		"timing":
			return Kind.CLOCK
		"debug2":
			return Kind.LAB
		"sim":
			return Kind.DICE
		"autounlock":
			return Kind.KEY
		"hats":
			return Kind.HAT
		"util":
			return Kind.BARS
		_:
			return Kind.CHECK


static func _soft(color: Color, alpha := 0.38) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	ci.draw_line(a, b, color, width, true)
	var r := width * 0.5
	ci.draw_circle(a, r, color)
	ci.draw_circle(b, r, color)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, closed := false) -> void:
	if pts.size() < 2:
		return
	var path := PackedVector2Array(pts)
	if closed:
		path.append(pts[0])
	ci.draw_polyline(path, color, width, true)
	for p in pts:
		ci.draw_circle(p, width * 0.5, color)


static func _arc(ci: CanvasItem, c: Vector2, radius: float, from: float, to: float, color: Color, width: float, pts := 20) -> void:
	ci.draw_arc(c, radius, from, to, pts, color, width, true)
	ci.draw_circle(c + Vector2(cos(from), sin(from)) * radius, width * 0.5, color)
	ci.draw_circle(c + Vector2(cos(to), sin(to)) * radius, width * 0.5, color)


static func _disc(ci: CanvasItem, c: Vector2, radius: float, color: Color) -> void:
	ci.draw_circle(c, radius, color)


static func _rounded_rect(ci: CanvasItem, r: Rect2, color: Color, width: float, filled: bool, radius: float) -> void:
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.48)
	if filled:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(round(maxf(rad, 2.0))))
		sb.draw(ci.get_canvas_item(), r)
		return
	var x := r.position.x
	var y := r.position.y
	var x2 := r.position.x + r.size.x
	var y2 := r.position.y + r.size.y
	_line(ci, Vector2(x + rad, y), Vector2(x2 - rad, y), color, width)
	_line(ci, Vector2(x2, y + rad), Vector2(x2, y2 - rad), color, width)
	_line(ci, Vector2(x2 - rad, y2), Vector2(x + rad, y2), color, width)
	_line(ci, Vector2(x, y2 - rad), Vector2(x, y + rad), color, width)
	ci.draw_arc(Vector2(x2 - rad, y + rad), rad, -PI / 2.0, 0.0, 10, color, width, true)
	ci.draw_arc(Vector2(x2 - rad, y2 - rad), rad, 0.0, PI / 2.0, 10, color, width, true)
	ci.draw_arc(Vector2(x + rad, y2 - rad), rad, PI / 2.0, PI, 10, color, width, true)
	ci.draw_arc(Vector2(x + rad, y + rad), rad, PI, 3.0 * PI / 2.0, 10, color, width, true)


static func _rounded_triangle(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, color: Color, corner: float, filled: bool, width: float) -> void:
	var pts := PackedVector2Array([a, b, c])
	var short := minf((a - b).length(), minf((b - c).length(), (c - a).length()))
	var radius := minf(corner, short * 0.20)
	var out := PackedVector2Array()
	for i in 3:
		var prev: Vector2 = pts[(i + 2) % 3]
		var cur: Vector2 = pts[i]
		var next: Vector2 = pts[(i + 1) % 3]
		var d0_raw: Vector2 = (cur - prev)
		var d1_raw: Vector2 = (next - cur)
		if d0_raw.length_squared() < 0.001 or d1_raw.length_squared() < 0.001:
			continue
		var d0: Vector2 = d0_raw.normalized()
		var d1: Vector2 = d1_raw.normalized()
		var half := acos(clampf(-d0.dot(d1), -1.0, 1.0)) * 0.5
		var cut := radius / maxf(tan(half), 0.12)
		cut = minf(cut, d0_raw.length() * 0.24)
		cut = minf(cut, d1_raw.length() * 0.24)
		var p_in: Vector2 = cur - d0 * cut
		var p_out: Vector2 = cur + d1 * cut
		var n0 := Vector2(-d0.y, d0.x)
		var mid := (a + b + c) / 3.0
		if n0.dot(mid - cur) < 0.0:
			n0 = -n0
		var center: Vector2 = p_in + n0.normalized() * radius
		var ang0 := (p_in - center).angle()
		var ang1 := (p_out - center).angle()
		var delta := ang1 - ang0
		while delta > PI:
			delta -= TAU
		while delta < -PI:
			delta += TAU
		var steps := 8
		for s in range(steps + 1):
			var t := float(s) / float(steps)
			var ang := ang0 + delta * t
			out.append(center + Vector2(cos(ang), sin(ang)) * radius)
	if out.size() < 3:
		if filled:
			ci.draw_colored_polygon(pts, color)
		else:
			_poly(ci, pts, color, width, true)
		return
	if filled:
		ci.draw_colored_polygon(out, color)
	else:
		_poly(ci, out, color, width, true)


static func _play_pts(rect: Rect2) -> Array:
	# Stockier, fatter triangle.
	return [
		rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.18),
		rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.82),
		rect.position + Vector2(rect.size.x * 0.88, rect.size.y * 0.50),
	]


static func _play_solid(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p: Array = _play_pts(rect)
	var corner := minf(rect.size.x, rect.size.y) * 0.11
	_rounded_triangle(ci, p[0], p[1], p[2], color, corner, true, width)


static func _speed(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# Soft, chunky lightning bolt.
	var p := rect.position
	var s := rect.size
	var pts := PackedVector2Array([
		p + Vector2(s.x * 0.58, s.y * 0.08),
		p + Vector2(s.x * 0.28, s.y * 0.52),
		p + Vector2(s.x * 0.50, s.y * 0.52),
		p + Vector2(s.x * 0.38, s.y * 0.92),
		p + Vector2(s.x * 0.76, s.y * 0.42),
		p + Vector2(s.x * 0.52, s.y * 0.42),
	])
	ci.draw_colored_polygon(pts, _soft(color, 0.42))
	_poly(ci, pts, color, width * 0.95, true)


static func _play_outline(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p: Array = _play_pts(rect)
	var corner := minf(rect.size.x, rect.size.y) * 0.11
	_rounded_triangle(ci, p[0], p[1], p[2], _soft(color, 0.32), corner, true, width)
	_rounded_triangle(ci, p[0], p[1], p[2], color, corner, false, width)


static func _code(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var w := width * 1.05
	_poly(ci, PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.40, rect.size.y * 0.18),
		rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.50),
		rect.position + Vector2(rect.size.x * 0.40, rect.size.y * 0.82),
	]), color, w, false)
	_poly(ci, PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.68, rect.size.y * 0.18),
		rect.position + Vector2(rect.size.x * 0.90, rect.size.y * 0.50),
		rect.position + Vector2(rect.size.x * 0.68, rect.size.y * 0.82),
	]), color, w, false)
	_line(ci, rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.22), rect.position + Vector2(rect.size.x * 0.46, rect.size.y * 0.78), color, w)


static func _skill_tree(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var top := rect.position + rect.size * Vector2(0.5, 0.22)
	var left := rect.position + rect.size * Vector2(0.23, 0.76)
	var right := rect.position + rect.size * Vector2(0.77, 0.76)
	var junction := rect.position + rect.size * Vector2(0.5, 0.52)
	_line(ci, top, junction, _soft(color, 0.75), width * 0.8)
	_poly(ci, PackedVector2Array([left, Vector2(left.x, junction.y), Vector2(right.x, junction.y), right]), _soft(color, 0.75), width * 0.8, false)
	var edge := rect.size.x * 0.25
	for center in [top, left, right]:
		_rounded_rect(ci, Rect2(center - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), color, width, true, edge * 0.25)


static func _bulb(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.40)
	var r := minf(rect.size.x, rect.size.y) * 0.30
	_disc(ci, c, r, _soft(color, 0.40))
	_arc(ci, c, r, deg_to_rad(50), deg_to_rad(310), color, width, 22)
	var neck0 := c + Vector2(-r * 0.38, r * 0.72)
	var neck1 := c + Vector2(r * 0.38, r * 0.72)
	var base0 := rect.position + Vector2(rect.size.x * 0.36, rect.size.y * 0.74)
	var base1 := rect.position + Vector2(rect.size.x * 0.64, rect.size.y * 0.74)
	_line(ci, neck0, base0, color, width)
	_line(ci, neck1, base1, color, width)
	_line(ci, base0, base1, color, width)
	_line(ci, base0 + Vector2(0, rect.size.y * 0.09), base1 + Vector2(0, rect.size.y * 0.09), color, width * 1.05)


static func _sliders(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# Two well-spaced fat sliders stay readable at 24px.
	var rows: PackedFloat32Array = PackedFloat32Array([0.34, 0.66])
	var knobs: PackedFloat32Array = PackedFloat32Array([0.64, 0.38])
	for i in 2:
		var y := rect.position.y + rect.size.y * rows[i]
		var x0 := rect.position.x + rect.size.x * 0.16
		var x1 := rect.position.x + rect.size.x * 0.84
		_line(ci, Vector2(x0, y), Vector2(x1, y), color, width)
		var kx := rect.position.x + rect.size.x * knobs[i]
		_rounded_rect(ci, Rect2(Vector2(kx - width, y - width * 1.3), Vector2(width * 2, width * 2.6)), color, width, true, width * 0.65)


static func _document(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var r := Rect2(rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.12), Vector2(rect.size.x * 0.60, rect.size.y * 0.76))
	_rounded_rect(ci, r, _soft(color, 0.32), width, true, 4.0)
	_rounded_rect(ci, r, color, width, false, 4.0)
	for i in 3:
		var y := r.position.y + r.size.y * (0.32 + 0.20 * float(i))
		var x1 := r.position.x + r.size.x * (0.76 if i < 2 else 0.58)
		_line(ci, Vector2(r.position.x + r.size.x * 0.20, y), Vector2(x1, y), color, width * 0.95)


static func _hay(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var base := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.88)
	var tips := PackedVector2Array([
		base + Vector2(-rect.size.x * 0.22, -rect.size.y * 0.68),
		base + Vector2(0.0, -rect.size.y * 0.76),
		base + Vector2(rect.size.x * 0.22, -rect.size.y * 0.66),
	])
	for tip in tips:
		_line(ci, base, tip, color, width * 1.08)
		_disc(ci, tip, width * 1.35, color)
	var tie_a := base + Vector2(-rect.size.x * 0.13, -rect.size.y * 0.32)
	var tie_b := base + Vector2(rect.size.x * 0.13, -rect.size.y * 0.26)
	_line(ci, tie_a, tie_b, color, width * 1.15)


static func _wood(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.52)
	var rx := rect.size.x * 0.34
	var a := c + Vector2(-rx, rx * 0.28)
	var b := c + Vector2(rx, -rx * 0.28)
	_line(ci, a, b, color, width * 3.2)
	_disc(ci, a, width * 1.7, color)
	_disc(ci, b, width * 1.5, color)
	ci.draw_arc(a, width * 1.85, 0.0, TAU, 18, _soft(color, 0.7), width * 0.7, true)


static func _reset_cam(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var box := Rect2(rect.position + rect.size * 0.24, rect.size * 0.50)
	_rounded_rect(ci, box, _soft(color, 0.32), width, true, 3.6)
	_rounded_rect(ci, box, color, width, false, 3.6)
	var c := rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.28)
	var r := minf(rect.size.x, rect.size.y) * 0.22
	_arc(ci, c, r, deg_to_rad(-80), deg_to_rad(110), color, width, 16)
	var ang := deg_to_rad(-80)
	var tangent := Vector2(-sin(ang), cos(ang))
	var tip := c + Vector2(cos(ang), sin(ang)) * r
	var hs := minf(rect.size.x, rect.size.y) * 0.15
	var n := Vector2(-tangent.y, tangent.x)
	_rounded_triangle(ci, tip + tangent * hs * 0.3, tip - tangent * hs * 0.45 + n * hs * 0.5, tip - tangent * hs * 0.45 - n * hs * 0.5, color, hs * 0.2, true, width)


static func _loop(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.34
	ci.draw_arc(c, r * 0.72, 0.0, TAU, 24, _soft(color, 0.28), r * 0.55, true)
	_arc(ci, c, r, deg_to_rad(-50), deg_to_rad(240), color, width * 1.05, 26)
	var ang := deg_to_rad(-50)
	var tangent := Vector2(-sin(ang), cos(ang))
	var tip := c + Vector2(cos(ang), sin(ang)) * r
	var hs := minf(rect.size.x, rect.size.y) * 0.22
	var n := Vector2(-tangent.y, tangent.x)
	_rounded_triangle(ci, tip + tangent * hs * 0.35, tip - tangent * hs * 0.45 + n * hs * 0.55, tip - tangent * hs * 0.45 - n * hs * 0.55, color, hs * 0.2, true, width)


static func _iff(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.get_center()
	var dx := rect.size.x * 0.42
	var dy := rect.size.y * 0.42
	var pts := PackedVector2Array([
		c + Vector2(0, -dy),
		c + Vector2(dx, 0),
		c + Vector2(0, dy),
		c + Vector2(-dx, 0),
	])
	ci.draw_colored_polygon(pts, _soft(color, 0.36))
	_poly(ci, pts, color, width, true)
	var q := c + Vector2(0, -dy * 0.08)
	_arc(ci, q + Vector2(0, -dy * 0.04), dy * 0.20, deg_to_rad(-40), deg_to_rad(200), color, width * 0.95, 14)
	_line(ci, q + Vector2(0, dy * 0.16), q + Vector2(0, dy * 0.28), color, width * 0.95)
	_disc(ci, q + Vector2(0, dy * 0.46), width * 0.62, color)


static func _move(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	var arm := s * 0.10
	var tip := s * 0.42
	var dirs := PackedVector2Array([Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)])
	for d in dirs:
		var n := Vector2(-d.y, d.x)
		var p0: Vector2 = c + d * arm
		var p1: Vector2 = c + d * tip
		_line(ci, p0, p1, color, width * 0.92)
		var hs := s * 0.16
		_rounded_triangle(ci, p1 + d * hs * 0.12, p1 - d * hs * 0.72 + n * hs * 0.62, p1 - d * hs * 0.72 - n * hs * 0.62, color, hs * 0.22, true, width)


static func _for_icon(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var y := rect.position.y + rect.size.y * 0.32
	for i in 3:
		var x := rect.position.x + rect.size.x * (0.22 + 0.22 * float(i))
		_line(ci, Vector2(x, y), Vector2(x, y + rect.size.y * 0.24), color, width * 1.1)
	var c := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.72)
	var r := rect.size.x * 0.22
	_arc(ci, c, r, deg_to_rad(40), deg_to_rad(250), color, width, 16)
	var ang := deg_to_rad(40)
	var tip := c + Vector2(cos(ang), sin(ang)) * r
	var n := Vector2(cos(ang), sin(ang))
	var t := Vector2(-n.y, n.x)
	var hs := rect.size.x * 0.14
	_rounded_triangle(ci, tip + n * hs * 0.1, tip - n * hs * 0.55 + t * hs * 0.5, tip - n * hs * 0.55 - t * hs * 0.5, color, hs * 0.22, true, width)


static func _hoe(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var h0 := rect.position + Vector2(rect.size.x * 0.74, rect.size.y * 0.12)
	var h1 := rect.position + Vector2(rect.size.x * 0.40, rect.size.y * 0.56)
	_line(ci, h0, h1, color, width * 1.1)
	var blade := PackedVector2Array([
		h1,
		rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.58),
		rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.86),
		rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.76),
	])
	ci.draw_colored_polygon(blade, _soft(color, 0.40))
	_poly(ci, blade, color, width, true)


static func _sprout(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var base := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.86)
	var top := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.38)
	_line(ci, base, top, color, width * 1.08)
	# Fat leaf discs sitting on short arcs.
	_disc(ci, top + Vector2(-rect.size.x * 0.16, -rect.size.y * 0.04), minf(rect.size.x, rect.size.y) * 0.14, _soft(color, 0.55))
	_disc(ci, top + Vector2(rect.size.x * 0.16, 0.0), minf(rect.size.x, rect.size.y) * 0.14, _soft(color, 0.55))
	_arc(ci, top + Vector2(-rect.size.x * 0.08, -rect.size.y * 0.02), rect.size.x * 0.22, deg_to_rad(200), deg_to_rad(20), color, width, 14)
	_arc(ci, top + Vector2(rect.size.x * 0.08, 0.0), rect.size.x * 0.22, deg_to_rad(160), deg_to_rad(-20), color, width, 14)


static func _vars(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var r := Rect2(rect.position + rect.size * 0.14, rect.size * 0.72)
	_rounded_rect(ci, r, _soft(color, 0.32), width, true, 4.2)
	_rounded_rect(ci, r, color, width, false, 4.2)
	var a := rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.34)
	var b := rect.position + Vector2(rect.size.x * 0.66, rect.size.y * 0.66)
	_line(ci, a, b, color, width)
	_line(ci, Vector2(b.x, a.y), Vector2(a.x, b.y), color, width)


static func _fn(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var r := Rect2(rect.position + rect.size * 0.14, rect.size * 0.72)
	_rounded_rect(ci, r, _soft(color, 0.32), width, true, 4.2)
	_rounded_rect(ci, r, color, width, false, 4.2)
	var stem0 := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.30)
	var stem1 := rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.72)
	_line(ci, stem0, stem1, color, width)
	_arc(ci, rect.position + Vector2(rect.size.x * 0.56, rect.size.y * 0.34), rect.size.x * 0.12, deg_to_rad(200), deg_to_rad(20), color, width, 10)
	_line(ci, rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.50), rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.50), color, width)


static func _check(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	_poly(ci, PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.52),
		rect.position + Vector2(rect.size.x * 0.40, rect.size.y * 0.78),
		rect.position + Vector2(rect.size.x * 0.88, rect.size.y * 0.22),
	]), color, width * 1.12, false)


static func _soon(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.36
	_disc(ci, c, r, _soft(color, 0.32))
	_arc(ci, c, r, 0.0, TAU, color, width, 24)
	_line(ci, c, c + Vector2(0, -r * 0.50), color, width)
	_line(ci, c, c + Vector2(r * 0.40, r * 0.16), color, width)


static func _lock(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var body := Rect2(rect.position + Vector2(rect.size.x * 0.26, rect.size.y * 0.50), Vector2(rect.size.x * 0.48, rect.size.y * 0.38))
	_rounded_rect(ci, body, _soft(color, 0.40), width, true, 3.6)
	_rounded_rect(ci, body, color, width, false, 3.6)
	var c := Vector2(rect.position.x + rect.size.x * 0.50, rect.position.y + rect.size.y * 0.50)
	_arc(ci, c, rect.size.x * 0.17, PI, TAU, color, width * 1.05, 14)
	_disc(ci, body.get_center() + Vector2(0, body.size.y * 0.04), width * 0.75, color)


static func _restore(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var back := Rect2(rect.position + Vector2(rect.size.x * 0.30, rect.size.y * 0.14), rect.size * 0.52)
	var front := Rect2(rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.32), rect.size * 0.52)
	_rounded_rect(ci, back, color, width * 0.95, false, 3.2)
	_rounded_rect(ci, front, _soft(color, 0.32), width, true, 3.2)
	_rounded_rect(ci, front, color, width, false, 3.2)


static func kind_from_item(name: String) -> Kind:
	match name:
		"hay":
			return Kind.HAY
		"wood":
			return Kind.WOOD
		"carrot":
			return Kind.CARROT
		"pumpkin":
			return Kind.PUMPKIN
		"power":
			return Kind.POWER
		"water", "water_tank":
			return Kind.WATER
		"fertilizer", "fert":
			return Kind.FERT
		"weird":
			return Kind.WEIRD
		"gold":
			return Kind.GOLD
		"cactus":
			return Kind.CACTUS
		"bone":
			return Kind.BONE
		_:
			return Kind.HAY


static func item_color(name: String, fallback: Color) -> Color:
	match name:
		"hay":
			return Color(0.86, 0.74, 0.38, 1)
		"wood":
			return Color(0.72, 0.50, 0.32, 1)
		"carrot":
			return Color(0.92, 0.50, 0.22, 1)
		"pumpkin":
			return Color(0.90, 0.48, 0.16, 1)
		"power":
			return Color(0.92, 0.78, 0.28, 1)
		"water", "water_tank":
			return Color(0.42, 0.70, 0.86, 1)
		"fertilizer", "fert":
			return Color(0.70, 0.62, 0.36, 1)
		"weird":
			return Color(0.66, 0.46, 0.82, 1)
		"gold":
			return Color(0.92, 0.78, 0.28, 1)
		"cactus":
			return Color(0.40, 0.70, 0.40, 1)
		"bone":
			return Color(0.90, 0.86, 0.78, 1)
		_:
			return fallback


static func _carrot(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	var body := PackedVector2Array([
		p + Vector2(s.x * 0.50, s.y * 0.92),
		p + Vector2(s.x * 0.30, s.y * 0.40),
		p + Vector2(s.x * 0.70, s.y * 0.40),
	])
	ci.draw_colored_polygon(body, _soft(color, 0.55))
	_poly(ci, body, color, width, true)
	var top := p + Vector2(s.x * 0.50, s.y * 0.38)
	_line(ci, top, top + Vector2(-s.x * 0.20, -s.y * 0.22), Color(0.36, 0.62, 0.32, 1), width)
	_line(ci, top, top + Vector2(0, -s.y * 0.26), Color(0.36, 0.62, 0.32, 1), width)
	_line(ci, top, top + Vector2(s.x * 0.20, -s.y * 0.22), Color(0.36, 0.62, 0.32, 1), width)


static func _pumpkin(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.58)
	var rx := rect.size.x * 0.32
	var ry := rect.size.y * 0.26
	var fill := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		fill.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(fill, _soft(color, 0.55))
	_poly(ci, fill, color, width, true)
	_arc(ci, c, rx * 0.45, deg_to_rad(70), deg_to_rad(110), color, width * 0.8, 8)
	_line(ci, c + Vector2(0, -ry), c + Vector2(0, -ry - rect.size.y * 0.14), Color(0.36, 0.56, 0.30, 1), width)


static func _power(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	_speed(ci, rect, color, width)


static func _water(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.42)
	var drop := PackedVector2Array([
		c + Vector2(0, -rect.size.y * 0.28),
		c + Vector2(rect.size.x * 0.28, rect.size.y * 0.10),
		c + Vector2(0, rect.size.y * 0.32),
		c + Vector2(-rect.size.x * 0.28, rect.size.y * 0.10),
	])
	ci.draw_colored_polygon(drop, _soft(color, 0.50))
	_poly(ci, drop, color, width, true)


static func _fert(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var bag := Rect2(rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.28), Vector2(rect.size.x * 0.56, rect.size.y * 0.56))
	_rounded_rect(ci, bag, _soft(color, 0.45), width, true, 4.0)
	_rounded_rect(ci, bag, color, width, false, 4.0)
	_line(ci, bag.position + Vector2(bag.size.x * 0.20, bag.size.y * 0.45), bag.position + Vector2(bag.size.x * 0.80, bag.size.y * 0.45), color, width)


static func _weird(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI / 2.0
		var r := s * (0.38 if i % 2 == 0 else 0.18)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, _soft(color, 0.45))
	_poly(ci, pts, color, width, true)


static func _gold(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	var pts := PackedVector2Array()
	for i in 5:
		var a := TAU * float(i) / 5.0 - PI / 2.0
		pts.append(c + Vector2(cos(a), sin(a)) * s * 0.40)
		var b := a + TAU / 10.0
		pts.append(c + Vector2(cos(b), sin(b)) * s * 0.18)
	ci.draw_colored_polygon(pts, _soft(color, 0.55))
	_poly(ci, pts, color, width, true)


static func _cactus(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	_line(ci, p + Vector2(s.x * 0.50, s.y * 0.86), p + Vector2(s.x * 0.50, s.y * 0.18), color, width * 1.35)
	_line(ci, p + Vector2(s.x * 0.50, s.y * 0.48), p + Vector2(s.x * 0.22, s.y * 0.48), color, width * 1.15)
	_line(ci, p + Vector2(s.x * 0.22, s.y * 0.48), p + Vector2(s.x * 0.22, s.y * 0.30), color, width * 1.15)
	_line(ci, p + Vector2(s.x * 0.50, s.y * 0.58), p + Vector2(s.x * 0.76, s.y * 0.58), color, width * 1.15)
	_line(ci, p + Vector2(s.x * 0.76, s.y * 0.58), p + Vector2(s.x * 0.76, s.y * 0.36), color, width * 1.15)


static func _bone(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var a := rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.62)
	var b := rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.38)
	_line(ci, a, b, color, width * 1.15)
	_disc(ci, a + Vector2(-4, -3), width * 0.95, color)
	_disc(ci, a + Vector2(-2, 5), width * 0.95, color)
	_disc(ci, b + Vector2(4, -4), width * 0.95, color)
	_disc(ci, b + Vector2(3, 4), width * 0.95, color)


static func _at(rect: Rect2, x: float, y: float) -> Vector2:
	return rect.position + rect.size * Vector2(x, y)


static func _path(ci: CanvasItem, rect: Rect2, coords: Array, color: Color, width: float, closed := false) -> void:
	var pts := PackedVector2Array()
	for i in range(0, coords.size(), 2):
		pts.append(_at(rect, coords[i], coords[i + 1]))
	_poly(ci, pts, color, width, closed)


static func _ring(ci: CanvasItem, rect: Rect2, x: float, y: float, radius: float, color: Color, width: float, fill := 0.0) -> void:
	var c := _at(rect, x, y)
	var r := radius * minf(rect.size.x, rect.size.y)
	if fill > 0.0:
		ci.draw_circle(c, r, _soft(color, fill))
	ci.draw_arc(c, r, 0.0, TAU, 28, color, width, true)


static func _box(ci: CanvasItem, rect: Rect2, x: float, y: float, w: float, h: float, color: Color, width: float, fill := 0.0) -> void:
	var r := Rect2(_at(rect, x, y), rect.size * Vector2(w, h))
	if fill > 0.0:
		_rounded_rect(ci, r, _soft(color, fill), width, true, 3.6)
	_rounded_rect(ci, r, color, width, false, 3.6)


## One plain shape per idea, drawn with the same rounded stroke as the rest.
static func _glyph(ci: CanvasItem, name: String, rect: Rect2, color: Color, w: float) -> void:
	var s := minf(rect.size.x, rect.size.y)
	match name:
		"bulb":
			_ring(ci, rect, 0.5, 0.40, 0.25, color, w, 0.34)
			_path(ci, rect, [0.40, 0.76, 0.60, 0.76], color, w)
			_path(ci, rect, [0.44, 0.88, 0.56, 0.88], color, w)
		"target":
			_ring(ci, rect, 0.5, 0.5, 0.26, color, w)
			ci.draw_circle(_at(rect, 0.5, 0.5), s * 0.075, color)
			for tick in [[0.5, 0.08, 0.5, 0.22], [0.5, 0.78, 0.5, 0.92], [0.08, 0.5, 0.22, 0.5], [0.78, 0.5, 0.92, 0.5]]:
				_path(ci, rect, tick, color, w)
		"hat":
			_box(ci, rect, 0.30, 0.24, 0.40, 0.46, color, w, 0.34)
			_path(ci, rect, [0.12, 0.74, 0.88, 0.74], color, w * 1.1)
		"expand":
			_box(ci, rect, 0.36, 0.36, 0.28, 0.28, color, w, 0.5)
			for corner in [[0.14, 0.32, 0.14, 0.14, 0.32, 0.14], [0.68, 0.14, 0.86, 0.14, 0.86, 0.32], [0.86, 0.68, 0.86, 0.86, 0.68, 0.86], [0.32, 0.86, 0.14, 0.86, 0.14, 0.68]]:
				_path(ci, rect, corner, color, w)
		"sense":
			_ring(ci, rect, 0.5, 0.40, 0.24, color, w, 0.30)
			ci.draw_circle(_at(rect, 0.5, 0.40), s * 0.07, color)
			_path(ci, rect, [0.33, 0.60, 0.5, 0.90, 0.67, 0.60], color, w)
		"maze":
			_path(ci, rect, [0.86, 0.86, 0.14, 0.86, 0.14, 0.14, 0.86, 0.14, 0.86, 0.62, 0.38, 0.62, 0.38, 0.38, 0.62, 0.38], color, w)
		"mega":
			_ring(ci, rect, 0.5, 0.30, 0.16, color, w, 0.5)
			_ring(ci, rect, 0.27, 0.70, 0.16, color, w, 0.25)
			_ring(ci, rect, 0.73, 0.70, 0.16, color, w, 0.25)
		"debug":
			_box(ci, rect, 0.12, 0.16, 0.76, 0.50, color, w, 0.28)
			_path(ci, rect, [0.30, 0.66, 0.28, 0.88, 0.50, 0.66], color, w)
			for x in [0.34, 0.5, 0.66]:
				ci.draw_circle(_at(rect, x, 0.41), s * 0.045, color)
		"clock":
			_ring(ci, rect, 0.5, 0.5, 0.36, color, w, 0.26)
			_path(ci, rect, [0.5, 0.28, 0.5, 0.5, 0.66, 0.58], color, w)
		"lab":
			_path(ci, rect, [0.38, 0.14, 0.62, 0.14], color, w)
			_path(ci, rect, [0.43, 0.14, 0.43, 0.42, 0.18, 0.84, 0.82, 0.84, 0.57, 0.42, 0.57, 0.14], color, w)
			_path(ci, rect, [0.30, 0.66, 0.70, 0.66], color, w)
		"dice":
			_box(ci, rect, 0.14, 0.14, 0.72, 0.72, color, w, 0.26)
			for dot in [[0.33, 0.33], [0.5, 0.5], [0.67, 0.67]]:
				ci.draw_circle(_at(rect, dot[0], dot[1]), s * 0.06, color)
		"key":
			_ring(ci, rect, 0.32, 0.34, 0.18, color, w, 0.30)
			_path(ci, rect, [0.45, 0.47, 0.84, 0.86], color, w)
			_path(ci, rect, [0.68, 0.70, 0.80, 0.58], color, w)
		"bars":
			_path(ci, rect, [0.24, 0.84, 0.24, 0.58], color, w * 1.5)
			_path(ci, rect, [0.5, 0.84, 0.5, 0.18], color, w * 1.5)
			_path(ci, rect, [0.76, 0.84, 0.76, 0.40], color, w * 1.5)
		"coin":
			_ring(ci, rect, 0.5, 0.5, 0.36, color, w, 0.26)
			_ring(ci, rect, 0.5, 0.5, 0.14, color, w)
		"const":
			_box(ci, rect, 0.14, 0.14, 0.72, 0.72, color, w, 0.26)
			_path(ci, rect, [0.34, 0.41, 0.66, 0.41], color, w)
			_path(ci, rect, [0.34, 0.59, 0.66, 0.59], color, w)
		"ops":
			_path(ci, rect, [0.74, 0.18, 0.26, 0.82], color, w)
			_ring(ci, rect, 0.28, 0.28, 0.12, color, w)
			_ring(ci, rect, 0.72, 0.72, 0.12, color, w)
		"array":
			_box(ci, rect, 0.06, 0.36, 0.27, 0.28, color, w)
			_box(ci, rect, 0.365, 0.36, 0.27, 0.28, color, w, 0.6)
			_box(ci, rect, 0.67, 0.36, 0.27, 0.28, color, w)
		"struct":
			_box(ci, rect, 0.16, 0.14, 0.68, 0.30, color, w, 0.5)
			_box(ci, rect, 0.16, 0.56, 0.68, 0.30, color, w)
		"switch":
			_path(ci, rect, [0.12, 0.5, 0.42, 0.5, 0.80, 0.20], color, w)
			_path(ci, rect, [0.42, 0.5, 0.80, 0.5], color, w)
			_path(ci, rect, [0.42, 0.5, 0.80, 0.80], color, w)
			for y in [0.20, 0.5, 0.80]:
				ci.draw_circle(_at(rect, 0.82, y), s * 0.065, color)
		"ref":
			_path(ci, rect, [0.80, 0.20, 0.80, 0.60, 0.22, 0.60], color, w)
			_path(ci, rect, [0.40, 0.42, 0.22, 0.60, 0.40, 0.78], color, w)
		"include":
			_box(ci, rect, 0.34, 0.10, 0.50, 0.58, color, w)
			_box(ci, rect, 0.16, 0.30, 0.50, 0.58, color, w, 0.6)
		"yield":
			_path(ci, rect, [0.5, 0.80, 0.5, 0.20], color, w)
			_path(ci, rect, [0.26, 0.44, 0.5, 0.18, 0.74, 0.44], color, w)
			_path(ci, rect, [0.24, 0.86, 0.76, 0.86], color, w)
		"tree":
			_ring(ci, rect, 0.5, 0.38, 0.27, color, w, 0.36)
			_path(ci, rect, [0.5, 0.66, 0.5, 0.90], color, w * 1.2)
		"companion":
			_ring(ci, rect, 0.36, 0.5, 0.22, color, w, 0.40)
			_ring(ci, rect, 0.64, 0.5, 0.22, color, w)
		"sunflower":
			ci.draw_circle(_at(rect, 0.5, 0.5), s * 0.15, color)
			for i in 8:
				var dir := Vector2.from_angle(TAU * float(i) / 8.0)
				_line(ci, _at(rect, 0.5, 0.5) + dir * s * 0.27, _at(rect, 0.5, 0.5) + dir * s * 0.40, color, w)
		_:
			_check(ci, rect, color, w)
