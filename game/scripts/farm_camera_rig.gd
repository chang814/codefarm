extends Node
## Farm camera: orbit (right-drag), pan (left-drag with a short glide, middle or
## Shift+right drag), wheel zoom toward the cursor, WASD/Space/Shift fly, and F
## to return home. Look and pan follow the mouse 1:1; only the home move eases.
##
## The rig owns no UI. Main tells it, through the callables passed to setup(),
## whether a screen point is covered by UI, whether a text field has focus, and
## how large the field is.

const FarmLayout := preload("res://scripts/farm_layout.gd")

const PITCH_MIN := 0.262  # 15 deg
const PITCH_MAX := 1.396  # 80 deg
const ZOOM_MIN := 2.0
const ZOOM_MAX := 14.0
const HEIGHT_MIN := -2.0
const HEIGHT_MAX := 10.0
const DIST := 7.2
const MOVE_SPEED := 4.2
const HOME_EASE := 14.0
# Left-drag panning: press on the farm, move past a small threshold, and the
# grabbed ground point stays under the cursor; a short glide follows release.
const LEFT_DRAG_THRESHOLD := 6.0
const PAN_GLIDE_DECAY := 9.0
const PAN_GLIDE_MAX_SPEED := 14.0

var camera: Camera3D

# Goal state (input writes here) and smoothed state (applied to the camera).
var yaw: float = 0.71
var pitch: float = 0.70
var zoom: float = 4.15
var target := Vector3(0, 0.2, 0)
var pos := Vector3(2.55, 3.55, 2.95)
var yaw_s: float = 0.71
var pitch_s: float = 0.70
var zoom_s: float = 4.15
var target_s := Vector3(0, 0.2, 0)
var pos_s := Vector3(2.55, 3.55, 2.95)
var vel := Vector3.ZERO

var orbiting := false
var panning := false
var left_pending := false
var left_dragging := false
var pan_glide := Vector3.ZERO
var _left_press_pos := Vector2.ZERO
var _left_last_pos := Vector2.ZERO
var _left_last_usec := 0

# Dependencies provided by main.
var _point_over_ui: Callable        # (Vector2) -> bool
var _mouse_over_editor: Callable    # () -> bool
var _text_input_focused: Callable   # () -> bool
var _panel_open: Callable           # () -> bool
var _farm_size: Callable            # () -> int
var _code_window_visible: Callable  # () -> bool


func setup(cam: Camera3D, deps: Dictionary) -> void:
	camera = cam
	_point_over_ui = deps["point_over_ui"]
	_mouse_over_editor = deps["mouse_over_editor"]
	_text_input_focused = deps["text_input_focused"]
	_panel_open = deps["panel_open"]
	_farm_size = deps["farm_size"]
	_code_window_visible = deps["code_window_visible"]


# --- Home framing -----------------------------------------------------------

func home_yaw() -> float:
	return 0.71


func home_pitch() -> float:
	return deg_to_rad(40.0)


func home_zoom(size: int = -1) -> float:
	if size < 0:
		size = _shown_size()
	return 4.15 if size <= 1 else 6.35


## Return to the home view for the current field size.
func reset(instant: bool = false) -> void:
	clear_drag()
	var size := _shown_size()
	apply_home(size if size > 0 else 1, instant)
	vel = Vector3.ZERO


func apply_home(size: int, instant: bool) -> void:
	var z := home_zoom(size)
	yaw = home_yaw()
	pitch = home_pitch()
	zoom = z
	target = FarmLayout.farm_center() + _framing_offset(size, z)
	pos = target - look_dir(yaw, pitch) * DIST
	_clamp_pos()
	if instant:
		yaw_s = yaw
		pitch_s = pitch
		zoom_s = zoom
		pos_s = pos
		sync_target_from_pos()
		apply_transform()


func _framing_offset(size: int, z: float) -> Vector3:
	# Shift look-at left so the farm sits in the open space right of the code window.
	var y := home_yaw()
	var p := home_pitch()
	var forward := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))
	var right := Vector3.UP.cross(forward).normalized()
	var amount := z * 0.28
	if not _code_window_visible.call():
		amount = 0.08 * z
	return -right * amount + Vector3(0, 0.04 * float(size - 1), 0)


# --- Transform helpers ------------------------------------------------------

## Direction the camera looks: down toward the farm.
func look_dir(y: float, p: float) -> Vector3:
	var pc := clampf(p, PITCH_MIN, PITCH_MAX)
	return Vector3(-sin(y) * cos(pc), -sin(pc), -cos(y) * cos(pc))


func sync_target_from_pos() -> void:
	target = pos + look_dir(yaw, pitch) * DIST
	target_s = pos_s + look_dir(yaw_s, pitch_s) * DIST


func sync_pos_from_target() -> void:
	pos = target - look_dir(yaw, pitch) * DIST
	pos_s = target_s - look_dir(yaw_s, pitch_s) * DIST


func apply_transform() -> void:
	var p := clampf(pitch_s, PITCH_MIN, PITCH_MAX)
	camera.position = pos_s
	var look := camera.position + look_dir(yaw_s, p) * DIST
	if camera.position.distance_to(look) > 0.001:
		camera.look_at(look, Vector3.UP)
	camera.size = zoom_s
	sync_target_from_pos()


func _clamp_pos() -> void:
	# Wide hard bounds only — do not spring or ease the camera back.
	var span := maxf(12.0, float(maxi(_shown_size(), 1)) * FarmLayout.TILE_SPACING * 5.0)
	var c := FarmLayout.farm_center()
	pos.x = clampf(pos.x, c.x - span, c.x + span)
	pos.z = clampf(pos.z, c.z - span, c.z + span)
	pos.y = clampf(pos.y, HEIGHT_MIN, HEIGHT_MAX)
	zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)


## World point on the ground plane under a screen position.
func ground_point(screen: Vector2) -> Vector3:
	if camera == null:
		return FarmLayout.farm_center()
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return origin
	var dist := (FarmLayout.ground_y() - origin.y) / dir.y
	return origin + dir * dist


func _shown_size() -> int:
	return int(_farm_size.call())


# --- Input ------------------------------------------------------------------

## Stop every drag mode and any glide; restores the cursor.
func clear_drag() -> void:
	orbiting = false
	panning = false
	left_pending = false
	_end_left_drag(false)
	pan_glide = Vector3.ZERO
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func handle_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Releases and Esc-equivalents always clear drag, even over UI.
		if not mb.pressed and (mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE):
			clear_drag()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_button(mb)
			return
		var over_ui: bool = _point_over_ui.call(event_mouse_pos(mb)) or _panel_open.call()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if over_ui or _mouse_over_editor.call() or _text_input_focused.call() or _mouse_over_ui():
				return
			var step := 0.22 * (mb.factor if mb.factor != 0.0 else 1.0)
			var next_zoom := zoom + (step if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -step)
			_zoom_toward_mouse(next_zoom)
			_mark_handled()
			return
		if over_ui:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.shift_pressed:
				panning = true
				orbiting = false
			else:
				orbiting = true
				panning = false
			pan_glide = Vector3.ZERO
			_take_focus_and_handle()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			panning = true
			orbiting = false
			_take_focus_and_handle()
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var d := _mouse_delta(mm)
		if left_pending or left_dragging:
			_handle_left_motion(mm)
			return
		if orbiting:
			# Rotate in place: keep the camera where it is, turn the look direction.
			yaw -= d.x * 0.0055
			pitch += d.y * 0.0045
			pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
			yaw_s = yaw
			pitch_s = pitch
			sync_target_from_pos()
			apply_transform()
			_mark_handled()
		elif panning:
			_pan_by_pixels(d)
			_mark_handled()
	elif event is InputEventKey and event.pressed and not event.echo and not _text_input_focused.call():
		if event.keycode == KEY_F and not event.ctrl_pressed and not event.alt_pressed:
			reset(false)
			_mark_handled()


func event_mouse_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		var ev := event as InputEventMouse
		if ev.global_position != Vector2.ZERO:
			return ev.global_position
		return ev.position
	if get_viewport():
		return get_viewport().get_mouse_position()
	return Vector2.ZERO


func _mouse_over_ui() -> bool:
	if get_viewport():
		return _point_over_ui.call(get_viewport().get_mouse_position())
	return false


func _mouse_delta(mm: InputEventMouseMotion) -> Vector2:
	# Use relative motion so canvas_items stretch / hiDPI does not skew the drag.
	if mm.relative != Vector2.ZERO:
		return mm.relative
	return mm.screen_relative


func _mark_handled() -> void:
	if get_viewport():
		get_viewport().set_input_as_handled()


func _take_focus_and_handle() -> void:
	if get_viewport():
		get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()


func _handle_left_button(mb: InputEventMouseButton) -> void:
	if mb.pressed:
		pan_glide = Vector3.ZERO
		# Only a press on the farm itself can become a drag; UI keeps its clicks.
		if _point_over_ui.call(event_mouse_pos(mb)) or _panel_open.call():
			return
		left_pending = true
		left_dragging = false
		_left_press_pos = event_mouse_pos(mb)
		_left_last_pos = _left_press_pos
		_left_last_usec = Time.get_ticks_usec()
		return
	left_pending = false
	if left_dragging:
		_end_left_drag(true)
		# The release ends a drag, not a click on whatever is under it.
		_mark_handled()


func _handle_left_motion(mm: InputEventMouseMotion) -> void:
	if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		left_pending = false
		_end_left_drag(true)
		return
	var p := event_mouse_pos(mm)
	if left_pending and not left_dragging:
		if p.distance_to(_left_press_pos) < LEFT_DRAG_THRESHOLD:
			return
		left_dragging = true
		left_pending = false
		vel = Vector3.ZERO
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		if get_viewport():
			get_viewport().gui_release_focus()
	var now := Time.get_ticks_usec()
	var moved := _pan_grab(_left_last_pos, p)
	var dt := maxf(0.001, float(now - _left_last_usec) / 1000000.0)
	# Smoothed release velocity for the glide.
	pan_glide = pan_glide.lerp(moved / dt, 0.45)
	_left_last_pos = p
	_left_last_usec = now
	_mark_handled()


func _end_left_drag(glide: bool) -> void:
	if not left_dragging:
		return
	left_dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	# Holding still before letting go means no glide.
	var idle := float(Time.get_ticks_usec() - _left_last_usec) / 1000000.0
	if not glide or idle > 0.08:
		pan_glide = Vector3.ZERO
	elif pan_glide.length() > PAN_GLIDE_MAX_SPEED:
		pan_glide = pan_glide.normalized() * PAN_GLIDE_MAX_SPEED


# Move the camera so the ground point under `from` ends up under `to`.
# Returns the world-space camera move.
func _pan_grab(from: Vector2, to: Vector2) -> Vector3:
	apply_transform()
	var move := ground_point(from) - ground_point(to)
	move.y = 0.0
	var before := pos
	pos += move
	_clamp_pos()
	pos_s = pos
	zoom_s = zoom
	sync_target_from_pos()
	apply_transform()
	return pos - before


func _pan_by_pixels(delta: Vector2) -> void:
	# Grab-the-ground: the point under the cursor follows the mouse.
	var vp_h := 1.0
	if get_viewport():
		vp_h = maxf(1.0, get_viewport().get_visible_rect().size.y)
	var scale := maxf(0.5, zoom_s) / vp_h
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	pos += -right.normalized() * delta.x * scale + up.normalized() * delta.y * scale
	_clamp_pos()
	pos_s = pos
	zoom_s = zoom
	sync_target_from_pos()
	apply_transform()


func _zoom_toward_mouse(next_zoom: float) -> void:
	next_zoom = clampf(next_zoom, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(next_zoom, zoom):
		return
	var mouse := Vector2.ZERO
	if get_viewport():
		mouse = get_viewport().get_mouse_position()
	apply_transform()
	var before := ground_point(mouse)
	zoom = next_zoom
	zoom_s = next_zoom
	apply_transform()
	var after := ground_point(mouse)
	pos += before - after
	_clamp_pos()
	pos_s = pos
	sync_target_from_pos()
	apply_transform()


# --- Per-frame --------------------------------------------------------------

## Keyboard flight (WASD, Space up, Shift down). Stops on release.
func update_input(delta: float) -> void:
	var wish := Vector3.ZERO
	if not _text_input_focused.call() and not _panel_open.call():
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		if right.length_squared() < 0.0001:
			right = Vector3.RIGHT
		right = right.normalized()
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
		if Input.is_key_pressed(KEY_W):
			wish += forward
		if Input.is_key_pressed(KEY_S):
			wish -= forward
		if Input.is_key_pressed(KEY_A):
			wish -= right
		if Input.is_key_pressed(KEY_D):
			wish += right
		if Input.is_key_pressed(KEY_SPACE):
			wish.y += 1.0
		if Input.is_key_pressed(KEY_SHIFT) and not panning:
			wish.y -= 1.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	if wish.length_squared() > 0.0:
		pan_glide = Vector3.ZERO
		vel = wish * MOVE_SPEED
		pos += vel * delta
		_clamp_pos()
		pos_s = pos
		sync_target_from_pos()
	else:
		# Stop almost immediately so the view does not slide or arc.
		vel = Vector3.ZERO


func update(delta: float) -> void:
	# Look and pan stay 1:1 with the mouse. Only F / 回正 uses a short ease.
	if not left_dragging and pan_glide.length_squared() > 0.0:
		# Short, light glide after a left-drag.
		var before := pos
		pos += pan_glide * delta
		_clamp_pos()
		sync_target_from_pos()
		if pos.distance_squared_to(before) < 1e-10:
			pan_glide = Vector3.ZERO
		pan_glide *= exp(-delta * PAN_GLIDE_DECAY)
		if pan_glide.length() < 0.02:
			pan_glide = Vector3.ZERO
	var looking := orbiting or panning or left_dragging or pan_glide.length_squared() > 0.0 \
		or vel.length_squared() > 0.00001
	if looking:
		yaw_s = yaw
		pitch_s = pitch
		pos_s = pos
		zoom_s = zoom
		apply_transform()
		return
	var k := 1.0 - exp(-delta * HOME_EASE)
	yaw_s = lerp_angle(yaw_s, yaw, k)
	pitch_s = lerpf(pitch_s, pitch, k)
	zoom_s = lerpf(zoom_s, zoom, k)
	pos_s = pos_s.lerp(pos, k)
	apply_transform()
