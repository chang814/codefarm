extends Node
## The farm bot and its extra drones: the procedural rig (cream bean body,
## fixed black slot eyes, arms and hoe), tile-to-tile movement with edge
## wrapping, idle sway, and the harvest / miss / till / flip / stuck motions.
##
## The simulator stays the source of truth: every frame update() reads the
## drone positions and current action from the host and eases the rig there.

const FarmLayout := preload("res://scripts/farm_layout.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")
const FarmPalette := preload("res://scripts/farm_palette.gd")

## Seconds for an idle (non-program) tile-to-tile glide.
const IDLE_MOVE_TIME := 0.28
## The bot is drawn a little larger than its parts are modelled.
const BOT_SCALE := 1.22

var host: CodefarmHost
var drone: Node3D          # The main bot's scene node ($Farm/Drone).
var camera: Camera3D

# Rig parts of the main bot.
var rig: Node3D
var hoe: Node3D
var arm_l: Node3D
var arm_r: Node3D
var eye_l: Node3D
var eye_r: Node3D
var sprout: Node3D

## Height the bot rests at above the field.
var base_y: float = 0.42
var hover_t: float = 0.0
# A motion currently owns the pose; idle sway and facing wait for it.
var harvesting := false
var flipping := false
var tilling := false

var _harvest_tween: Tween
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _move_t: float = 1.0
var extra_drones: Array = []
var _drones_root: Node3D
var _view_drone: int = 0
# Squash-and-stretch spring: positive is tall and thin, negative is squat.
var _squash := 0.0
var _squash_vel := 0.0

# Dependencies provided by main.
var _farm_root: Node3D
var _juice_anchor: Node3D
var _tile_world: Callable  # (int, int) -> Vector3
var _farm_size: Callable   # () -> int
var _sfx: Callable         # (String) -> void


func setup(sim_host: CodefarmHost, bot_node: Node3D, cam: Camera3D, deps: Dictionary) -> void:
	host = sim_host
	drone = bot_node
	camera = cam
	_farm_root = deps["farm_root"]
	_juice_anchor = deps["juice_anchor"]
	_tile_world = deps["tile_world"]
	_farm_size = deps["farm_size"]
	_sfx = deps["sfx"]
	base_y = FarmLayout.TILE_HEIGHT + 0.18 * BOT_SCALE


## True while a harvest, flip or till motion owns the pose.
func is_busy() -> bool:
	return harvesting or flipping or tilling


## Cancel motion flags (program stop / farm reset). Running tweens finish on their own.
func reset_actions() -> void:
	harvesting = false
	flipping = false
	tilling = false


# --- Placement --------------------------------------------------------------

## Put the bot exactly on its simulator tile, no glide.
func snap() -> void:
	var pos := _tile_pos(host.get_drone_x(), host.get_drone_y())
	drone.position = pos
	_to = pos
	_from = pos
	_move_t = 1.0


func _tile_pos(x: int, y: int) -> Vector3:
	var tile: Vector3 = _tile_world.call(x, y)
	return Vector3(tile.x, base_y, tile.z + 0.06)


func _wrap_target(from: Vector3, logical: Vector3) -> Vector3:
	var span := float(_farm_size.call()) * FarmLayout.TILE_SPACING
	var dx := logical.x - from.x
	var dz := logical.z - from.z
	if span > 0.0:
		if dx > span * 0.5:
			dx -= span
		elif dx < -span * 0.5:
			dx += span
		if dz > span * 0.5:
			dz -= span
		elif dz < -span * 0.5:
			dz += span
	return Vector3(from.x + dx, logical.y, from.z + dz)


func _place_moving_bot(node: Node3D, from: Vector3, to: Vector3, t: float, hop: float) -> Vector3:
	var virtual_to := _wrap_target(from, to)
	var direction := Vector3(virtual_to.x - from.x, 0, virtual_to.z - from.z)
	var wrapped := virtual_to.distance_to(to) > FarmLayout.TILE_SPACING * 0.5
	if wrapped:
		# Fold away at the outgoing edge, then unfold at the matching incoming
		# edge. Never travel through the field or outside the island at full size.
		var step := direction.normalized() * FarmLayout.TILE_SPACING * 0.32
		if t < 0.5:
			var a := t * 2.0
			node.position = from.lerp(from + step, a)
			node.scale = Vector3.ONE * maxf(0.025, 1.0 - a)
		else:
			var a := (t - 0.5) * 2.0
			node.position = (to - step).lerp(to, a)
			node.scale = Vector3.ONE * maxf(0.025, a)
	else:
		node.position = from.lerp(to, t)
		node.scale = Vector3.ONE
	node.position.y = base_y + sin(t * PI) * hop
	return direction


func _camera_face_yaw(node: Node3D) -> float:
	var to_cam := camera.global_position - node.global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.0001:
		return 0.0
	return atan2(to_cam.x, to_cam.z)


# --- Per-frame --------------------------------------------------------------

func update(delta: float) -> void:
	hover_t += delta
	var logical := _tile_pos(host.get_drone_x(), host.get_drone_y())
	var moving := host.is_running() and host.current_action() == "move"
	var move_dir := Vector3.ZERO
	if moving:
		if Vector2(logical.x, logical.z).distance_to(Vector2(_to.x, _to.z)) > 0.04:
			_from = Vector3(drone.position.x, base_y, drone.position.z)
			_to = logical
			_move_t = 0.0
		var t := smoothstep(0.0, 1.0, host.current_action_progress())
		move_dir = _place_moving_bot(drone, _from, _to, t, 0.12)
	else:
		drone.scale = Vector3.ONE
		if Vector2(drone.position.x, drone.position.z).distance_to(Vector2(logical.x, logical.z)) > 0.8:
			drone.position = logical
			_to = logical
			_from = logical
			_move_t = 1.0
		elif Vector2(logical.x, logical.z).distance_to(Vector2(_to.x, _to.z)) > 0.02:
			_from = drone.position
			_to = logical
			_move_t = 0.0
		if _move_t < 1.0:
			_move_t = minf(1.0, _move_t + delta / IDLE_MOVE_TIME)
			var t2 := smoothstep(0.0, 1.0, _move_t)
			_place_moving_bot(drone, _from, _to, t2, 0.08)
			if _move_t >= 1.0:
				drone.position = logical
				drone.scale = Vector3.ONE
		elif not is_busy():
			drone.position.x = logical.x
			drone.position.z = logical.z
			drone.position.y = base_y + sin(hover_t * 1.35) * 0.012
	_update_squash(delta, moving)
	animate(delta, moving, move_dir)
	_update_extra_drones(delta)


## Idle sway, lean into movement, and turn toward the camera (or the move).
func animate(delta: float, moving: bool, move_dir: Vector3) -> void:
	if rig == null or is_busy():
		return
	var face := _camera_face_yaw(drone)
	if moving and move_dir.length_squared() > 0.0001:
		face = atan2(move_dir.x, move_dir.z)
		var lean := clampf(move_dir.length() * 0.35, 0.0, 0.28)
		rig.rotation.x = lerp_angle(rig.rotation.x, -lean, 1.0 - exp(-delta * 8.0))
	else:
		rig.rotation.x = lerp_angle(rig.rotation.x, sin(hover_t * 1.2) * 0.05, 1.0 - exp(-delta * 6.0))
	rig.rotation.y = lerp_angle(rig.rotation.y, face, 1.0 - exp(-delta * 6.0))
	rig.rotation.z = lerp_angle(rig.rotation.z, sin(hover_t * 0.9) * 0.04, 1.0 - exp(-delta * 6.0))
	if arm_r and not moving:
		arm_r.rotation.z = lerp_angle(arm_r.rotation.z, -0.50 + sin(hover_t * 1.1) * 0.05, 1.0 - exp(-delta * 4.0))


## Push the squash spring: negative squats (a landing, a swing), positive stretches.
func kick(amount: float) -> void:
	_squash_vel += amount


func _update_squash(delta: float, moving: bool) -> void:
	if rig == null:
		return
	# A damped spring, stepped at a fixed rate so it stays stable on slow frames.
	var steps := clampi(int(ceil(delta / 0.008)), 1, 12)
	var dt := delta / float(steps)
	for i in steps:
		_squash_vel += (-_squash * 260.0 - _squash_vel * 15.0) * dt
		_squash += _squash_vel * dt
	_squash = clampf(_squash, -0.35, 0.35)
	var k := _squash
	if moving:
		# Stretch through the hop, flatten into the landing.
		var t := clampf(float(host.current_action_progress()), 0.0, 1.0)
		k += 0.16 * sin(t * PI) - 0.14 * smoothstep(0.82, 1.0, t)
	else:
		k += 0.018 * sin(hover_t * 2.2)
	rig.scale = Vector3(1.0 - k * 0.5, 1.0 + k, 1.0 - k * 0.5) * BOT_SCALE
	if sprout:
		sprout.rotation.x = lerp_angle(sprout.rotation.x, -k * 2.2 + sin(hover_t * 1.9) * 0.07, 1.0 - exp(-delta * 10.0))
		sprout.rotation.z = sin(hover_t * 1.5) * 0.10


# --- Motions ----------------------------------------------------------------

func play_stuck() -> void:
	if rig == null:
		return
	_sfx.call("stuck")
	# Always shake around the rig's rest pose. Reading the current pose made a
	# second shake start from the middle of the first, and every rapid repeat
	# left the bot a little further off its tile.
	for key in ["_stuck_turn", "_stuck_slide"]:
		FarmMotion.stop(rig, key)
	var origin_x := 0.0
	var origin_z_rot := 0.0
	rig.position.x = origin_x
	kick(-1.6)
	var tw := rig.create_tween()
	rig.set_meta("_stuck_turn", tw)
	tw.tween_property(rig, "rotation:z", origin_z_rot + 0.18, 0.07).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rig, "rotation:z", origin_z_rot - 0.16, 0.08)
	tw.tween_property(rig, "rotation:z", origin_z_rot + 0.10, 0.07)
	tw.tween_property(rig, "rotation:z", origin_z_rot, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var tw2 := rig.create_tween()
	rig.set_meta("_stuck_slide", tw2)
	tw2.tween_property(rig, "position:x", origin_x + 0.03, 0.06)
	tw2.tween_property(rig, "position:x", origin_x - 0.03, 0.08)
	tw2.tween_property(rig, "position:x", origin_x, 0.10)


## A successful harvest: the swing plus a soft burst of clippings off the tile.
## (The harvest itself flies to the top bar; see farm_collect_fx.gd.)
func play_harvest_success(tile: Vector2i, wood: bool) -> void:
	play_harvest_swing(true)
	var at: Vector3 = _tile_world.call(tile.x, tile.y)
	at.y = FarmLayout.TILE_HEIGHT + 0.14
	spawn_puff(at, FarmPalette.WOOD.lightened(0.15) if wood else FarmPalette.HAY, 7, 0.30)


func play_harvest_swing(success: bool) -> void:
	if _harvest_tween and is_instance_valid(_harvest_tween):
		_harvest_tween.kill()
	harvesting = true
	# One interruptible timeline owns the pose, including the recovery callback.
	# A miss is a flat sideways sweep without reward strands; the crop height
	# follows the simulator's restarted growth. Both swings follow action speed.
	var duration := clampf(float(host.action_ticks()) / 400.0 * 0.85, 0.16, 0.42)
	_harvest_tween = create_tween().set_parallel(true)
	_harvest_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var poses := [
		[rig, Vector3(0.50, 0, 0) if success else Vector3(0.12, -0.25, 0), Vector3.ZERO],
		[arm_r, Vector3(0.95, 0.10, -0.15) if success else Vector3(-0.25, -0.70, -0.50), Vector3(0.20, 0.18, -0.50)],
		[hoe, Vector3(1.15, 0.10, -0.25) if success else Vector3(0.15, -0.85, -0.48), Vector3(0.30, 0.10, -0.48)],
		[arm_l, Vector3(0.35, 0, 0.28), Vector3(0.25, 0, 0.26)],
	]
	for pose in poses:
		if pose[0]:
			_harvest_tween.tween_property(pose[0], "rotation", pose[1], duration * 0.45)
			_harvest_tween.tween_property(pose[0], "rotation", pose[2], duration * 0.55).set_delay(duration * 0.45)
	if success:
		_harvest_tween.tween_property(drone, "position:y", base_y + 0.10, duration * 0.45)
		_harvest_tween.tween_property(drone, "position:y", base_y, duration * 0.55).set_delay(duration * 0.45)
	# The blade lands at the turn of the swing: a little squash sells the hit.
	_harvest_tween.tween_callback(func() -> void: kick(-2.4 if success else -1.2)).set_delay(duration * 0.42)
	_harvest_tween.chain().tween_callback(func() -> void: harvesting = false)


## A burst of small soft blobs that pop outward, drift up and shrink away.
## Used for clippings, tilled soil and landing dust.
func spawn_puff(at: Vector3, color: Color, count: int = 6, spread: float = 0.26) -> void:
	if _juice_anchor == null:
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.034
	mesh.height = 0.068
	mesh.radial_segments = 10
	mesh.rings = 5
	for i in count:
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.lightened(0.10 * float(i % 3))
		mat.roughness = 0.95
		puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_juice_anchor.add_child(puff)
		var ang := TAU * (float(i) + 0.35 * float(i % 2)) / float(count)
		var reach := spread * (0.7 + 0.3 * float((i * 7) % 4) / 3.0)
		var start := at
		var finish := at + Vector3(cos(ang) * reach, 0.16 + 0.10 * float(i % 3), sin(ang) * reach)
		var size := 0.8 + 0.5 * float((i * 5) % 3) / 2.0
		puff.position = start
		puff.scale = Vector3.ONE * 0.2
		var tw := create_tween()
		tw.tween_method(
			func(t: float) -> void:
				var eased := 1.0 - pow(1.0 - t, 3.0)
				puff.position = start.lerp(finish, eased) + Vector3(0, 0.10 * sin(t * PI), 0)
				puff.scale = Vector3.ONE * size * sin(minf(1.0, t * 1.25) * PI * 0.5) * (1.0 - smoothstep(0.55, 1.0, t)),
			0.0,
			1.0,
			0.46 + 0.03 * float(i % 4)
		)
		tw.tween_callback(puff.queue_free)


func play_till() -> void:
	tilling = true
	_sfx.call("till")
	if rig:
		var bob := create_tween()
		bob.tween_property(rig, "rotation:x", 0.42, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		bob.tween_property(rig, "rotation:x", -0.06, 0.14)
		bob.tween_property(rig, "rotation:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	if arm_r:
		var rest_r := Vector3(0.20, 0.18, -0.50)
		var arms := create_tween()
		arms.tween_property(arm_r, "rotation", Vector3(-0.90, 0.15, -0.30), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		arms.tween_property(arm_r, "rotation", Vector3(1.05, 0.08, -0.10), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		arms.tween_property(arm_r, "rotation", rest_r, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hoe:
		var h := create_tween()
		h.tween_property(hoe, "rotation", Vector3(-0.55, 0.15, -0.45), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		h.tween_property(hoe, "rotation", Vector3(1.25, 0.08, -0.20), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		h.tween_property(hoe, "rotation", Vector3(0.30, 0.10, -0.48), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if arm_l:
		var left := create_tween()
		left.tween_property(arm_l, "rotation", Vector3(0.45, 0.0, 0.26), 0.14)
		left.tween_property(arm_l, "rotation", Vector3(0.25, 0.0, 0.26), 0.22)
	var hop := create_tween()
	hop.tween_property(drone, "position:y", base_y + 0.06, 0.10).set_trans(Tween.TRANS_SINE)
	hop.tween_property(drone, "position:y", base_y - 0.04, 0.14)
	hop.tween_property(drone, "position:y", base_y, 0.16).set_trans(Tween.TRANS_SINE)
	hop.tween_callback(func() -> void:
		tilling = false
	)
	var hit := create_tween()
	hit.tween_interval(0.27)
	hit.tween_callback(func() -> void:
		kick(-2.2)
		spawn_puff(Vector3(drone.position.x, FarmLayout.TILE_HEIGHT + 0.06, drone.position.z + 0.10), FarmPalette.SOIL_TOP.lightened(0.18), 6, 0.30)
	)


func play_flip() -> void:
	flipping = true
	_sfx.call("flip")
	if rig == null:
		var tw := create_tween()
		tw.tween_property(drone, "rotation:z", TAU, 0.8).set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(func() -> void:
			drone.rotation.z = 0.0
			flipping = false
		)
		return
	# Rapid flips restart from the ground, never from the top of the last hop.
	FarmMotion.stop(drone, "_flip")
	rig.rotation.x = 0.0
	var start_y := base_y
	var tw := create_tween()
	drone.set_meta("_flip", tw)
	tw.set_parallel(true)
	tw.tween_property(rig, "rotation:x", TAU, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(drone, "position:y", start_y + 0.38, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(drone, "position:y", base_y, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if rig:
			rig.rotation.x = 0.0
		flipping = false
		kick(-3.0)
		spawn_puff(Vector3(drone.position.x, FarmLayout.TILE_HEIGHT + 0.05, drone.position.z), Color(1.0, 0.98, 0.90, 1), 6, 0.28)
	)


# --- Rig construction -------------------------------------------------------

## (Re)build the main bot's rig under the drone node.
func build() -> void:
	for child in drone.get_children():
		child.queue_free()
	drone.scale = Vector3.ONE
	drone.rotation = Vector3.ZERO
	rig = Node3D.new()
	rig.name = "Rig"
	drone.add_child(rig)
	var parts := make_rig(rig)
	eye_l = parts["eye_l"]
	eye_r = parts["eye_r"]
	arm_l = parts["arm_l"]
	arm_r = parts["arm_r"]
	hoe = parts["hoe"]
	sprout = parts["sprout"]


## Build one bot body under `parent`. The main bot and extra drones share it:
## a milk-yellow ball with two black slot eyes, rosy cheeks, a leaf sprout on
## top, stubby arms and a small hoe.
func make_rig(parent: Node3D) -> Dictionary:
	parent.scale = Vector3.ONE * BOT_SCALE
	var cream := _mat(FarmPalette.BOT_BODY, 0.90, 0.0)
	var wood := _mat(FarmPalette.WOOD, 0.92, 0.0)
	var metal := _mat(Color(0.74, 0.80, 0.82, 1), 0.70, 0.10)
	var eye_mat := _mat(Color.BLACK, 0.95, 0.0)
	var cheek_mat := _mat(FarmPalette.BOT_CHEEK, 0.95, 0.0)
	var leaf_mat := _mat(FarmPalette.LEAF_LIGHT, 0.88, 0.0)
	var stem_mat := _mat(FarmPalette.LEAF, 0.88, 0.0)

	# One round body. No separate head, no feet — it hovers.
	var body := SphereMesh.new()
	body.radius = 0.15
	body.height = 0.30
	body.radial_segments = 32
	body.rings = 16
	var body_node := _mesh_inst(body, cream, Vector3(0, -0.01, 0), parent)
	body_node.name = "Body"
	_outline_mesh(body, parent, Vector3(0, -0.01, 0), 1.035)

	# No face plate: two matte black rounded vertical slots sit on the ball.
	var eye_mesh := CapsuleMesh.new()
	eye_mesh.radius = 0.013
	eye_mesh.height = 0.072
	var el := Node3D.new()
	el.name = "EyeLeft"
	var er := Node3D.new()
	er.name = "EyeRight"
	el.position = Vector3(-0.046, 0.022, 0.138)
	er.position = Vector3(0.046, 0.022, 0.138)
	parent.add_child(el)
	parent.add_child(er)
	_mesh_inst(eye_mesh, eye_mat, Vector3.ZERO, el)
	_mesh_inst(eye_mesh, eye_mat, Vector3.ZERO, er)

	# Soft cheeks just under the eyes.
	var cheek := SphereMesh.new()
	cheek.radius = 0.026
	cheek.height = 0.052
	for side in [-1.0, 1.0]:
		var c := _mesh_inst(cheek, cheek_mat, Vector3(side * 0.088, -0.026, 0.112), parent)
		c.rotation = Vector3(0.18, side * 0.62, 0)
		c.scale = Vector3(1.0, 0.62, 0.30)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# A two-leaf sprout on top; it sways and reacts to every hop.
	var sp := Node3D.new()
	sp.name = "Sprout"
	sp.position = Vector3(0, 0.132, 0)
	parent.add_child(sp)
	var stem := CapsuleMesh.new()
	stem.radius = 0.008
	stem.height = 0.07
	_mesh_inst(stem, stem_mat, Vector3(0, 0.03, 0), sp)
	var leaf := SphereMesh.new()
	leaf.radius = 0.042
	leaf.height = 0.084
	for side in [-1.0, 1.0]:
		var l := _mesh_inst(leaf, leaf_mat, Vector3(side * 0.034, 0.075, 0), sp)
		l.rotation = Vector3(0, 0, side * -0.55)
		l.scale = Vector3(1.0, 0.24, 0.58)

	var al := Node3D.new()
	var ar := Node3D.new()
	al.position = Vector3(-0.146, 0.005, 0.02)
	ar.position = Vector3(0.146, 0.005, 0.04)
	al.rotation = Vector3(0.25, 0.0, 0.26)
	ar.rotation = Vector3(0.20, 0.18, -0.50)
	parent.add_child(al)
	parent.add_child(ar)

	var arm := CapsuleMesh.new()
	arm.radius = 0.026
	arm.height = 0.10
	_mesh_inst(arm, cream, Vector3(0, -0.044, 0.01), al)
	_mesh_inst(arm, cream, Vector3(0, -0.044, 0.01), ar)
	_outline_mesh(arm, al, Vector3(0, -0.044, 0.01), 1.07)
	_outline_mesh(arm, ar, Vector3(0, -0.044, 0.01), 1.07)

	# Hoe lives on the rig so its silhouette stays readable: wood handle held
	# at the side, rounded metal head up beside the crown.
	var h := Node3D.new()
	h.name = "Hoe"
	h.position = Vector3(0.179, 0.02, 0.05)
	h.rotation = Vector3(0.30, 0.10, -0.48)
	parent.add_child(h)
	var handle := CapsuleMesh.new()
	handle.radius = 0.013
	handle.height = 0.27
	_mesh_inst(handle, wood, Vector3(0, 0, 0), h)
	var blade := CapsuleMesh.new()
	blade.radius = 0.026
	blade.height = 0.100
	var blade_n := _mesh_inst(blade, metal, Vector3(0.0, 0.150, 0.016), h)
	blade_n.rotation_degrees = Vector3(80, 16, 0)
	blade_n.scale = Vector3(1.70, 1.0, 0.52)

	return {"eye_l": el, "eye_r": er, "arm_l": al, "arm_r": ar, "hoe": h, "sprout": sp}


func _mat(color: Color, rough: float = 0.45, metal: float = 0.0, emission: float = 0.0, emit_color: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = emit_color if emit_color.a > 0.0 else color
		mat.emission_energy_multiplier = emission
	return mat


func _mesh_inst(mesh: Mesh, mat: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	if parent:
		parent.add_child(inst)
	return inst


func _outline_mesh(mesh: Mesh, parent: Node3D, pos: Vector3, scale := 1.045, rot := Vector3.ZERO) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FarmPalette.BOT_OUTLINE
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var inst := _mesh_inst(mesh, mat, pos, parent)
	inst.rotation = rot
	inst.scale = Vector3.ONE * scale
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Extra drones (multi-drone skill) ---------------------------------------

## Bots currently visible, the main bot included.
func visible_drone_nodes() -> int:
	var n := 1
	for item in extra_drones:
		if item is Dictionary and item.has("node") and is_instance_valid(item["node"]) and (item["node"] as Node3D).visible:
			n += 1
	return n


## Match the number of extra drone nodes to the simulator's drone count.
func sync_fleet() -> void:
	var n := 1
	if host and host.has_method("drone_count"):
		n = maxi(1, int(host.drone_count()))
	if _drones_root == null:
		_drones_root = Node3D.new()
		_drones_root.name = "ExtraDrones"
		_farm_root.add_child(_drones_root)
	while extra_drones.size() < n - 1:
		var id := extra_drones.size() + 1
		extra_drones.append(spawn_extra_drone(id))
	while extra_drones.size() > n - 1:
		var last: Dictionary = extra_drones.pop_back()
		if last.has("node") and is_instance_valid(last["node"]):
			(last["node"] as Node3D).queue_free()
	if host and host.has_method("set_view_drone"):
		if _view_drone >= n:
			_view_drone = 0
		host.set_view_drone(_view_drone)


func spawn_extra_drone(id: int) -> Dictionary:
	if _drones_root == null:
		sync_fleet()
	var node := Node3D.new()
	node.name = "Drone_%d" % id
	_drones_root.add_child(node)
	var extra_rig := Node3D.new()
	extra_rig.name = "Rig"
	node.add_child(extra_rig)
	make_rig(extra_rig)
	node.position = _tile_pos(0, 0)
	return {"id": id, "node": node, "rig": extra_rig, "from": node.position, "to": node.position, "t": 1.0}


func _update_extra_drones(delta: float) -> void:
	if not host or not host.has_method("drone_x_at"):
		return
	for item in extra_drones:
		if not (item is Dictionary) or not item.has("node"):
			continue
		var node: Node3D = item["node"]
		if not is_instance_valid(node):
			continue
		var id := int(item["id"])
		var logical := _tile_pos(int(host.drone_x_at(id)), int(host.drone_y_at(id)))
		var to: Vector3 = item["to"]
		if Vector2(logical.x, logical.z).distance_to(Vector2(to.x, to.z)) > 0.02:
			item["from"] = node.position
			item["to"] = logical
			item["t"] = 0.0
		if float(item["t"]) < 1.0:
			item["t"] = minf(1.0, float(item["t"]) + delta / IDLE_MOVE_TIME)
			var t2 := smoothstep(0.0, 1.0, float(item["t"]))
			_place_moving_bot(node, item["from"], item["to"], t2, 0.08)
		else:
			node.scale = Vector3.ONE
			node.position.x = logical.x
			node.position.z = logical.z
			node.position.y = base_y + sin(hover_t * 1.35 + float(id)) * 0.012
		var extra_rig: Node3D = item["rig"]
		if extra_rig:
			var face := _camera_face_yaw(node)
			extra_rig.rotation.y = lerp_angle(extra_rig.rotation.y, face, 1.0 - exp(-delta * 6.0))
			extra_rig.rotation.x = lerp_angle(extra_rig.rotation.x, sin(hover_t * 1.2 + float(id)) * 0.05, 1.0 - exp(-delta * 6.0))
