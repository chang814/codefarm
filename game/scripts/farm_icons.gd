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

var icon_color := Color(0.33, 0.46, 0.38, 1):
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


static func _document(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var r := Rect2(rect.position + Vector2(rect.size.x * 0.20, rect.size.y * 0.12), Vector2(rect.size.x * 0.60, rect.size.y * 0.76))
	_rounded_rect(ci, r, _soft(color, 0.32), width, true, 4.0)
	_rounded_rect(ci, r, color, width, false, 4.0)
	for i in 3:
		var y := r.position.y + r.size.y * (0.32 + 0.20 * float(i))
		var x1 := r.position.x + r.size.x * (0.76 if i < 2 else 0.58)
		_line(ci, Vector2(r.position.x + r.size.x * 0.20, y), Vector2(x1, y), color, width * 0.95)


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
			return Color(0.90, 0.76, 0.42, 1)
		"wood":
			return Color(0.72, 0.56, 0.42, 1)
		"carrot":
			return Color(0.93, 0.62, 0.38, 1)
		"pumpkin":
			return Color(0.92, 0.64, 0.36, 1)
		"power":
			return Color(0.95, 0.80, 0.42, 1)
		"water", "water_tank":
			return Color(0.50, 0.74, 0.88, 1)
		"fertilizer", "fert":
			return Color(0.74, 0.66, 0.50, 1)
		"weird":
			return Color(0.72, 0.60, 0.84, 1)
		"gold":
			return Color(0.95, 0.80, 0.42, 1)
		"cactus":
			return Color(0.50, 0.72, 0.56, 1)
		"bone":
			return Color(0.80, 0.75, 0.66, 1)
		_:
			return fallback


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


# --- Soft filled icon parts ---------------------------------------------------

const _ICON_LEAF := Color(0.47, 0.66, 0.50, 1)


static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	ci.draw_colored_polygon(pts, color)


## A pointed leaf from `base` to `tip`, `fat` wide at its belly.
static func _leaf_shape(ci: CanvasItem, base: Vector2, tip: Vector2, fat: float, color: Color) -> void:
	var along := tip - base
	var side := Vector2(-along.y, along.x).normalized() * fat
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		pts.append(base + along * t + side * sin(PI * pow(t, 0.8)))
	for i in 9:
		var t := 1.0 - float(i) / 8.0
		pts.append(base + along * t - side * sin(PI * pow(t, 0.8)))
	ci.draw_colored_polygon(pts, color)


static func _shade(color: Color) -> Color:
	return color.darkened(0.22)


static func _shine(color: Color) -> Color:
	return color.lightened(0.34)


static func _code(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# A small rounded code sheet with two soft chevrons.
	var p := rect.position
	var s := rect.size
	_rounded_rect(ci, Rect2(p + s * Vector2(0.06, 0.14), s * Vector2(0.88, 0.72)), _soft(color, 0.20), width, true, s.x * 0.20)
	var w := width * 1.0
	_poly(ci, PackedVector2Array([p + s * Vector2(0.38, 0.32), p + s * Vector2(0.22, 0.50), p + s * Vector2(0.38, 0.68)]), color, w, false)
	_poly(ci, PackedVector2Array([p + s * Vector2(0.62, 0.32), p + s * Vector2(0.78, 0.50), p + s * Vector2(0.62, 0.68)]), color, w, false)


static func _skill_tree(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# A sapling: a stem that branches into three round leaves.
	var p := rect.position
	var s := rect.size
	var root := p + s * Vector2(0.50, 0.92)
	var fork := p + s * Vector2(0.50, 0.56)
	_line(ci, root, fork, color, width)
	var buds := [p + s * Vector2(0.50, 0.24), p + s * Vector2(0.20, 0.44), p + s * Vector2(0.80, 0.44)]
	for bud in buds:
		_line(ci, fork, bud, _soft(color, 0.8), width * 0.85)
	var r := s.x * 0.155
	for i in 3:
		_disc(ci, buds[i], r * (1.15 if i == 0 else 1.0), color)
		_disc(ci, buds[i] + Vector2(-r * 0.28, -r * 0.30), r * 0.34, _shine(color))


static func _bulb(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	var c := p + s * Vector2(0.50, 0.42)
	var r := minf(s.x, s.y) * 0.27
	_disc(ci, c, r, _soft(color, 0.30))
	_arc(ci, c, r, deg_to_rad(55), deg_to_rad(305), color, width, 22)
	_line(ci, c + Vector2(-r * 0.42, r * 0.92), c + Vector2(r * 0.42, r * 0.92), color, width)
	_line(ci, c + Vector2(-r * 0.26, r * 1.42), c + Vector2(r * 0.26, r * 1.42), color, width)
	# A small sparkle: the idea arriving.
	for ray in [Vector2(0, -1), Vector2(-0.80, -0.62), Vector2(0.80, -0.62)]:
		_line(ci, c + ray * r * 1.42, c + ray * r * 1.70, _soft(color, 0.75), width * 0.8)


static func _sliders(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# Two soft tracks with round knobs.
	var rows: PackedFloat32Array = PackedFloat32Array([0.34, 0.68])
	var knobs: PackedFloat32Array = PackedFloat32Array([0.66, 0.36])
	for i in 2:
		var y := rect.position.y + rect.size.y * rows[i]
		var x0 := rect.position.x + rect.size.x * 0.14
		var x1 := rect.position.x + rect.size.x * 0.86
		_line(ci, Vector2(x0, y), Vector2(x1, y), _soft(color, 0.45), width)
		var knob := Vector2(rect.position.x + rect.size.x * knobs[i], y)
		_line(ci, Vector2(x0, y), knob, color, width)
		_disc(ci, knob, width * 1.55, color)
		_disc(ci, knob, width * 0.62, _shine(color))


static func _hay(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# A tied sheaf: three plump golden ears over a short stalk bundle.
	var p := rect.position
	var s := rect.size
	var knot := p + s * Vector2(0.50, 0.62)
	for foot in [Vector2(0.30, 0.94), Vector2(0.50, 0.97), Vector2(0.70, 0.94)]:
		_line(ci, knot, p + s * foot, _shade(color), width * 1.1)
	var ears := [[Vector2(0.24, 0.20), -0.42], [Vector2(0.50, 0.10), 0.0], [Vector2(0.76, 0.20), 0.42]]
	for ear in ears:
		var tip: Vector2 = p + s * (ear[0] as Vector2)
		_line(ci, knot, tip, _shade(color), width * 0.9)
		_oval(ci, knot.lerp(tip, 0.72), s.x * 0.115, s.y * 0.215, color, float(ear[1]))
		_oval(ci, knot.lerp(tip, 0.78) + Vector2(-s.x * 0.03, 0), s.x * 0.04, s.y * 0.10, _shine(color), float(ear[1]))
	_line(ci, knot + Vector2(-s.x * 0.15, 0), knot + Vector2(s.x * 0.15, 0), Color(0.86, 0.52, 0.42, 1), width * 1.25)


static func _wood(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# A short log lying at an angle, cut end facing us.
	var p := rect.position
	var s := rect.size
	var a := p + s * Vector2(0.26, 0.66)
	var b := p + s * Vector2(0.74, 0.38)
	_line(ci, a, b, _shade(color), s.y * 0.40)
	_line(ci, a + Vector2(0, -s.y * 0.07), b + Vector2(0, -s.y * 0.07), color, s.y * 0.16)
	_oval(ci, b, s.x * 0.15, s.y * 0.20, _shine(color), -0.5)
	_oval(ci, b, s.x * 0.075, s.y * 0.10, color, -0.5)
	_leaf_shape(ci, a.lerp(b, 0.35) + Vector2(0, -s.y * 0.18), a.lerp(b, 0.35) + Vector2(-s.x * 0.14, -s.y * 0.40), s.x * 0.07, _ICON_LEAF)


static func _carrot(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	var top := p + s * Vector2(0.50, 0.40)
	for leaf in [Vector2(-0.24, -0.30), Vector2(0.0, -0.38), Vector2(0.24, -0.30)]:
		_leaf_shape(ci, top, top + s * leaf, s.x * 0.085, _ICON_LEAF if leaf.x != 0.0 else _ICON_LEAF.lightened(0.18))
	var body := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var a := PI + PI * t
		body.append(top + Vector2(cos(a) * s.x * 0.24, sin(a) * s.y * 0.13))
	body.append(p + s * Vector2(0.58, 0.80))
	body.append(p + s * Vector2(0.50, 0.96))
	body.append(p + s * Vector2(0.42, 0.80))
	ci.draw_colored_polygon(body, color)
	_line(ci, p + s * Vector2(0.40, 0.46), p + s * Vector2(0.44, 0.66), _shine(color), width * 0.8)
	for y in [0.56, 0.72]:
		_line(ci, p + s * Vector2(0.52, y), p + s * Vector2(0.62, y - 0.02), _shade(color), width * 0.55)


static func _pumpkin(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	var c := p + s * Vector2(0.50, 0.60)
	_oval(ci, c + Vector2(-s.x * 0.19, 0), s.x * 0.20, s.y * 0.27, _shade(color))
	_oval(ci, c + Vector2(s.x * 0.19, 0), s.x * 0.20, s.y * 0.27, _shade(color))
	_oval(ci, c, s.x * 0.21, s.y * 0.30, color)
	_oval(ci, c + Vector2(-s.x * 0.06, -s.y * 0.08), s.x * 0.05, s.y * 0.11, _shine(color))
	_line(ci, c + Vector2(0, -s.y * 0.28), c + Vector2(s.x * 0.06, -s.y * 0.44), _ICON_LEAF.darkened(0.12), width * 1.2)
	_leaf_shape(ci, c + Vector2(s.x * 0.05, -s.y * 0.34), c + Vector2(s.x * 0.34, -s.y * 0.40), s.x * 0.08, _ICON_LEAF)


static func _power(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# Sun energy: a warm disc with soft rays and a small spark.
	var p := rect.position
	var s := rect.size
	var c := p + s * Vector2(0.50, 0.50)
	var r := s.x * 0.22
	for i in 8:
		var d := Vector2.from_angle(TAU * float(i) / 8.0)
		_line(ci, c + d * r * 1.42, c + d * r * 1.90, _shade(color), width * 0.95)
	_disc(ci, c, r * 1.08, _shade(color))
	_disc(ci, c, r * 0.92, color)
	_disc(ci, c + Vector2(-r * 0.30, -r * 0.30), r * 0.30, _shine(color))


static func _water(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	var c := p + s * Vector2(0.50, 0.62)
	var r := s.x * 0.27
	var drop := PackedVector2Array([p + s * Vector2(0.50, 0.08)])
	for i in 17:
		var a := -PI * 0.18 + (PI * 1.36) * float(i) / 16.0
		drop.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(drop, color)
	_arc(ci, c, r * 0.58, PI * 0.55, PI * 0.95, _shine(color), width * 0.8, 8)


static func _fert(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# A tied sack with a sprout mark.
	var p := rect.position
	var s := rect.size
	_rounded_rect(ci, Rect2(p + s * Vector2(0.20, 0.34), s * Vector2(0.60, 0.58)), color, width, true, s.x * 0.18)
	_oval(ci, p + s * Vector2(0.50, 0.26), s.x * 0.20, s.y * 0.10, _shade(color))
	_line(ci, p + s * Vector2(0.34, 0.36), p + s * Vector2(0.66, 0.36), Color(0.86, 0.52, 0.42, 1), width)
	var mark := p + s * Vector2(0.50, 0.78)
	_line(ci, mark, mark + Vector2(0, -s.y * 0.16), _ICON_LEAF.darkened(0.1), width * 0.7)
	_leaf_shape(ci, mark + Vector2(0, -s.y * 0.14), mark + Vector2(-s.x * 0.16, -s.y * 0.26), s.x * 0.05, _ICON_LEAF)
	_leaf_shape(ci, mark + Vector2(0, -s.y * 0.14), mark + Vector2(s.x * 0.16, -s.y * 0.26), s.x * 0.05, _ICON_LEAF.lightened(0.15))


static func _weird(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	# A wobbly blob with bubbles.
	var p := rect.position
	var s := rect.size
	var c := p + s * Vector2(0.50, 0.58)
	var blob := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		var r := s.x * (0.30 + 0.035 * sin(a * 3.0 + 0.6) + 0.02 * cos(a * 5.0))
		blob.append(c + Vector2(cos(a) * r, sin(a) * r * 0.86))
	ci.draw_colored_polygon(blob, color)
	_disc(ci, c + Vector2(-s.x * 0.10, -s.y * 0.07), s.x * 0.07, _shine(color))
	_disc(ci, c + Vector2(s.x * 0.10, s.y * 0.05), s.x * 0.045, _shade(color))
	_disc(ci, p + s * Vector2(0.70, 0.18), s.x * 0.06, _soft(color, 0.8))
	_disc(ci, p + s * Vector2(0.56, 0.08), s.x * 0.035, _soft(color, 0.6))


static func _gold(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var c := rect.get_center()
	var r := rect.size.x * 0.36
	_disc(ci, c + Vector2(0, r * 0.10), r, _shade(color))
	_disc(ci, c, r, color)
	_arc(ci, c, r * 0.64, 0.0, TAU, _shade(color), width * 0.6, 24)
	_arc(ci, c, r * 0.82, PI * 1.08, PI * 1.42, _shine(color), width * 0.8, 8)
	_disc(ci, c, r * 0.16, _shade(color))


static func _cactus(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	_line(ci, p + s * Vector2(0.50, 0.90), p + s * Vector2(0.50, 0.26), color, s.x * 0.24)
	_poly(ci, PackedVector2Array([p + s * Vector2(0.50, 0.62), p + s * Vector2(0.22, 0.62), p + s * Vector2(0.22, 0.42)]), color, s.x * 0.13, false)
	_poly(ci, PackedVector2Array([p + s * Vector2(0.50, 0.52), p + s * Vector2(0.78, 0.52), p + s * Vector2(0.78, 0.34)]), color, s.x * 0.13, false)
	_line(ci, p + s * Vector2(0.45, 0.80), p + s * Vector2(0.45, 0.32), _shine(color), width * 0.55)
	for i in 5:
		var a := TAU * float(i) / 5.0
		_disc(ci, p + s * Vector2(0.50, 0.14) + Vector2(cos(a), sin(a)) * s.x * 0.065, s.x * 0.055, Color(0.95, 0.74, 0.76, 1))
	_disc(ci, p + s * Vector2(0.50, 0.14), s.x * 0.04, Color(0.97, 0.85, 0.52, 1))


static func _bone(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	var a := p + s * Vector2(0.26, 0.72)
	var b := p + s * Vector2(0.74, 0.28)
	var knob := s.x * 0.115
	var along := (b - a).normalized()
	var side := Vector2(-along.y, along.x) * knob * 0.85
	for pass_index in 2:
		var tone := _shade(color) if pass_index == 0 else color
		var grow := 1.0 if pass_index == 0 else 0.72
		_line(ci, a, b, tone, s.x * 0.17 * grow)
		for end in [a, b]:
			_disc(ci, end + side, knob * (1.0 if pass_index == 0 else 0.76), tone)
			_disc(ci, end - side, knob * (1.0 if pass_index == 0 else 0.76), tone)
