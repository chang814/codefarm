extends Node
## The field: one plot per simulator tile (soil tile, grass blades, bush,
## crop and a far-distance LOD), the rounded earth pad, the meadow and its
## scenery. update() mirrors the simulator's ground and entities every frame;
## tiles are batched into MultiMeshes for speed.

const FarmLayout := preload("res://scripts/farm_layout.gd")
const FarmScenery := preload("res://scripts/farm_scenery.gd")

## The field grew or shrank; the camera re-frames on this.
signal size_changed(size: int)

var host: CodefarmHost
var camera: Camera3D
var farm_root: Node3D
var farm_earth: MeshInstance3D

## Vector2i(x, y) -> plot Dictionary (root, blades, bush, crop, lod, juice, ...).
var plots: Dictionary = {}
## Side length currently built and shown.
var shown_size: int = 1
## Hide every plant (screenshots, welcome close-up).
var hide_plants := false
var meadow: MeshInstance3D
var scenery: FarmScenery

var _time: float = 0.0
var _plots_root: Node3D
var _grass_mat: StandardMaterial3D
var _soil_mat: StandardMaterial3D
var _wet_soil_mat: StandardMaterial3D
var _bush_mats: Array[StandardMaterial3D] = []
var _blade_young: StandardMaterial3D
var _blade_mid: StandardMaterial3D
var _blade_ripe: StandardMaterial3D
var _blade_mats: Array[StandardMaterial3D] = []
var _blade_meshes: Array[ArrayMesh] = []
var _tile_mm_grass: MultiMeshInstance3D
var _tile_mm_soil: MultiMeshInstance3D
var _tile_mm_wet: MultiMeshInstance3D


func setup(sim_host: CodefarmHost, cam: Camera3D, root: Node3D, earth: MeshInstance3D) -> void:
	host = sim_host
	camera = cam
	farm_root = root
	farm_earth = earth


## A harvest flattens the tile's grass and gives it a short juice flash.
func flatten_after_harvest(tile: Vector2i) -> void:
	if not plots.has(tile):
		return
	plots[tile]["juice"] = 0.28
	for blade in plots[tile]["blades"]:
		blade["visual"] = maxf(FarmLayout.STUBBLE, float(blade["visual"]) * 0.45)


## Visible plant nodes standing in front of `at` (toward the camera), within
## a narrow column. The welcome close-up hides these to keep the bot clear.
func plants_in_front_of(at: Vector3) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for key in plots:
		var plot: Dictionary = plots[key]
		var nodes: Array = [plot["bush"], plot["crop"], plot["lod"]]
		for blade in plot["blades"]:
			nodes.append(blade["pivot"])
		for node in nodes:
			var pos: Vector3 = node.global_position
			if node.visible and pos.z > at.z - 0.10 and absf(pos.x - at.x) < 0.62:
				found.append(node)
	return found


func tile_world(tx: int, ty: int, size: int = -1) -> Vector3:
	if size < 0:
		size = shown_size
	var origin := (size - 1) * 0.5
	return Vector3((tx - origin) * FarmLayout.TILE_SPACING, 0.0, (ty - origin) * FarmLayout.TILE_SPACING)


func init() -> void:
	_plots_root = Node3D.new()
	_plots_root.name = "Plots"
	farm_root.add_child(_plots_root)
	_blade_young = _make_blade_mat(Color(0.32, 0.46, 0.24, 1), 0.0)
	_blade_mid = _make_blade_mat(Color(0.40, 0.58, 0.28, 1), 0.0)
	_blade_ripe = _make_blade_mat(Color(0.58, 0.68, 0.28, 1), 0.22)
	_blade_mats = [_blade_young, _blade_mid, _blade_ripe]
	_blade_meshes = [
		_make_blade_mesh(0.06, 0.028, 0.006, 0.32),
		_make_blade_mesh(0.09, 0.024, 0.005, 0.30),
		_make_blade_mesh(0.04, 0.030, 0.007, 0.34),
		_make_blade_mesh(0.11, 0.022, 0.004, 0.28),
	]
	_grass_mat = _make_soil_mat(Color(0.36, 0.30, 0.20, 1), Color(0.24, 0.20, 0.14, 1))
	_soil_mat = _make_soil_mat(Color(0.30, 0.22, 0.15, 1), Color(0.20, 0.14, 0.10, 1))
	var bush_leaf := StandardMaterial3D.new()
	bush_leaf.albedo_color = Color(0.32, 0.48, 0.28, 1)
	bush_leaf.roughness = 0.62
	var bush_leaf2 := StandardMaterial3D.new()
	bush_leaf2.albedo_color = Color(0.42, 0.56, 0.30, 1)
	bush_leaf2.roughness = 0.55
	var bush_wood := StandardMaterial3D.new()
	bush_wood.albedo_color = Color(0.42, 0.28, 0.16, 1)
	bush_wood.roughness = 0.8
	_bush_mats = [bush_leaf, bush_leaf2, bush_wood]
	ensure_size(1)
	_update_earth(1)


func ensure_size(size: int) -> void:
	if size < 1:
		size = 1
	if size == shown_size and plots.size() >= size * size:
		return
	var previous := shown_size
	for key in plots.keys():
		var plot: Dictionary = plots[key]
		var tx: int = plot["x"]
		var ty: int = plot["y"]
		plot["root"].visible = tx < size and ty < size
	for y in size:
		for x in size:
			var key := Vector2i(x, y)
			if not plots.has(key):
				plots[key] = _make_plot(x, y)
	shown_size = size
	_position_plots(size)
	_update_earth(size)
	_rebuild_tile_batches(size)
	if size != previous:
		size_changed.emit(size)


func _position_plots(size: int) -> void:
	for y in size:
		for x in size:
			var plot: Dictionary = plots[Vector2i(x, y)]
			plot["root"].position = tile_world(x, y, size)
			plot["root"].visible = true


func update(delta: float) -> void:
	_time += delta
	var size := host.get_world_size()
	for y in size:
		for x in size:
			var key := Vector2i(x, y)
			if not plots.has(key):
				continue
			var plot: Dictionary = plots[key]
			if plot["juice"] > 0.0:
				plot["juice"] = maxf(0.0, plot["juice"] - delta)
			var ground: String = host.tile_ground(x, y)
			var entity: String = host.tile_entity(x, y)
			var tile_mesh: MeshInstance3D = plot["tile"]
			tile_mesh.material_override = _soil_mat if ground == "Soil" else _grass_mat
			var ratio := clampf(float(host.tile_grow_ratio(x, y)), 0.0, 1.0)
			var grass_node: Node3D = plot["grass"]
			var bush_node: Node3D = plot["bush"]
			var crop_node: Node3D = plot["crop"]
			var is_grass := entity == "Grass"
			var is_bush := entity == "Bush"
			var styled := entity in ["Carrot", "Tree", "Sunflower", "Pumpkin", "DeadPumpkin", "Cactus", "Hedge", "Treasure", "Apple"]
			grass_node.visible = is_grass and not hide_plants
			bush_node.visible = is_bush and not hide_plants
			crop_node.visible = styled and not hide_plants
			if is_bush:
				var bscale := 0.22 + 0.78 * ratio
				bush_node.scale = Vector3(bscale, bscale, bscale)
				bush_node.rotation.y = 0.15 * sin(_time * 0.7 + float(x + y))
			if styled:
				if plot.get("crop_kind", "") != entity:
					_style_crop(crop_node, entity, ratio)
					plot["crop_kind"] = entity
				var s := 0.30 + 0.70 * ratio
				if entity == "Hedge" or entity == "Treasure":
					crop_node.scale = Vector3.ONE
					crop_node.rotation.y = 0.0
				else:
					crop_node.scale = Vector3(s, s, s)
					if (not _field_is_far(plot)) and (entity not in ["Cactus"]):
						crop_node.rotation.y = 0.08 * sin(_time * 0.6 + float(x + y))
			else:
				plot["crop_kind"] = ""
			var water := 0.0
			if host.has_method("tile_water"):
				water = float(host.tile_water(x, y))
			if ground == "Soil" and water > 0.15:
				if _wet_soil_mat == null:
					_wet_soil_mat = _crop_mat(Color(0.22, 0.20, 0.16, 1))
				tile_mesh.material_override = _wet_soil_mat
			_sync_batched_tile(x, y, ground, water)
			if plot.has("glow"):
				var glow: MeshInstance3D = plot["glow"]
				var ripe := is_grass and ratio >= 0.995
				glow.visible = ripe
				if ripe and plot.has("glow_mat"):
					var gm: StandardMaterial3D = plot["glow_mat"]
					var pulse := 0.10 + 0.08 * sin(_time * 2.1 + float(x * 2 + y))
					gm.emission_energy_multiplier = pulse
					gm.albedo_color.a = 0.10 + pulse * 0.35
			if not is_grass:
				if plot.has("lod"):
					plot["lod"].visible = false
				continue
			var far := _field_is_far(plot) or size >= 12
			if plot.has("lod"):
				var lod: MeshInstance3D = plot["lod"]
				if far and size >= 8:
					lod.visible = true and not hide_plants
					var ls := 0.45 + 0.7 * ratio
					lod.scale = Vector3(ls, 0.25 + 0.9 * ratio, ls)
					grass_node.visible = false
					continue
				else:
					lod.visible = false
			if size >= 8 and (_time * 10.0) - floor(_time * 10.0) > 0.35 and plot["juice"] <= 0.0:
				continue
			for blade in plot["blades"]:
				var local := clampf((ratio - float(blade["stagger"]) * 0.7) / (1.0 - float(blade["stagger"]) * 0.5), 0.0, 1.0)
				var target := FarmLayout.STUBBLE + (float(blade["tall"]) - FarmLayout.STUBBLE) * local
				var visual: float = blade["visual"]
				if target + 0.08 < visual:
					visual = lerpf(visual, FarmLayout.STUBBLE, 1.0 - exp(-delta * 18.0))
				else:
					visual = lerpf(visual, target, 1.0 - exp(-delta * 8.0))
				blade["visual"] = visual
				var pivot: Node3D = blade["pivot"]
				pivot.scale = Vector3(1.0, visual, 1.0)
				var sway := sin(_time * 1.25 + float(blade["phase"])) * 0.07 * (0.2 + 0.8 * visual)
				var tip_bend := 0.10 * visual
				pivot.rotation.z = float(blade["lean"]) * 0.25 + sway
				pivot.rotation.x = float(blade["lean"]) + sway * 0.4 + tip_bend
				var inst: MeshInstance3D = blade["mesh"]
				if local < 0.35:
					inst.material_override = _blade_young
				elif local < 0.92:
					inst.material_override = _blade_mid
				else:
					inst.material_override = _blade_ripe


func _make_plot(x: int, y: int) -> Dictionary:

	var root := Node3D.new()
	root.name = "Plot_%d_%d" % [x, y]
	_plots_root.add_child(root)

	var tile := MeshInstance3D.new()
	tile.mesh = _make_beveled_tile_mesh()
	tile.material_override = _grass_mat
	tile.position = Vector3(0, 0, 0)
	root.add_child(tile)

	var grass := Node3D.new()
	grass.position = Vector3(0, FarmLayout.TILE_HEIGHT, 0)
	root.add_child(grass)

	var bush := _make_bush_node()
	bush.visible = false
	root.add_child(bush)

	var crop := _make_crop_node()
	crop.visible = false
	root.add_child(crop)

	var rng := RandomNumberGenerator.new()
	rng.seed = 814 + x * 37 + y * 91
	var blades: Array = []
	var placed: Array[Vector2] = []
	var attempts := 0
	var blade_cap := 20 if shown_size < 8 else (8 if shown_size < 16 else 4)
	while blades.size() < blade_cap and attempts < 80:
		attempts += 1
		var px := rng.randf_range(-0.38, 0.38)
		var pz := rng.randf_range(-0.38, 0.38)
		var ok := true
		for prev in placed:
			if Vector2(px, pz).distance_to(prev) < 0.11:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector2(px, pz))
		var pivot := Node3D.new()
		pivot.position = Vector3(px, 0, pz)
		var yaw := rng.randf_range(0.0, TAU)
		var lean := rng.randf_range(-0.10, 0.16)
		pivot.rotation = Vector3(0.0, yaw, 0.0)
		grass.add_child(pivot)
		var inst := MeshInstance3D.new()
		inst.mesh = _blade_meshes[blades.size() % _blade_meshes.size()]
		inst.material_override = _blade_mid
		inst.position = Vector3.ZERO
		var tall := rng.randf_range(0.82, 1.16)
		pivot.add_child(inst)
		blades.append({
			"pivot": pivot,
			"mesh": inst,
			"tall": tall,
			"stagger": rng.randf_range(0.0, 0.28),
			"phase": rng.randf_range(0.0, TAU),
			"lean": lean,
			"yaw": yaw,
			"visual": 1.0,
		})
	var glow := MeshInstance3D.new()
	glow.name = "RipeGlow"
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.22
	glow_mesh.height = 0.10
	glow_mesh.radial_segments = 16
	glow_mesh.rings = 8
	glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.70, 0.82, 0.32, 0.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.72, 0.84, 0.32, 1)
	glow_mat.emission_energy_multiplier = 0.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.roughness = 1.0
	glow.material_override = glow_mat
	glow.position = Vector3(0, 0.04, 0)
	glow.visible = false
	grass.add_child(glow)
	var lod := MeshInstance3D.new()
	lod.name = "GrassLod"
	var lod_mesh := SphereMesh.new()
	lod_mesh.radius = 0.42
	lod_mesh.height = 0.28
	lod_mesh.radial_segments = 8
	lod_mesh.rings = 4
	lod.mesh = lod_mesh
	lod.material_override = _blade_ripe if _blade_ripe else _crop_mat(Color(0.48, 0.62, 0.28, 1))
	lod.position = Vector3(0, FarmLayout.TILE_HEIGHT + 0.04, 0)
	lod.visible = false
	root.add_child(lod)
	return {"x": x, "y": y, "root": root, "tile": tile, "grass": grass, "bush": bush, "crop": crop, "blades": blades, "juice": 0.0, "glow": glow, "glow_mat": glow_mat, "lod": lod}


func _make_soil_mat(top: Color, side: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = top
	mat.roughness = 0.92
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	return mat


func _make_beveled_tile_mesh() -> ArrayMesh:
	# A soft block: rounded corners and a rounded top edge with smooth
	# normals, so light rolls over the rim instead of breaking on hard creases.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := FarmLayout.TILE_WIDTH * 0.5
	var h := FarmLayout.TILE_HEIGHT
	var corner := 0.13
	var bevel := 0.065
	var top_c := Color(1.0, 1.0, 1.0, 1)
	var side_c := Color(0.64, 0.62, 0.57, 1)
	var foot_c := Color(0.52, 0.50, 0.46, 1)
	var corner_steps := 6
	var bevel_steps := 4
	# Each ring: [inset, height, colour, tilt of the normal toward straight up].
	var rings: Array = [[0.0, 0.0, foot_c, 0.0], [0.0, h - bevel, side_c, 0.0]]
	for k in range(1, bevel_steps + 1):
		var ang := float(k) / float(bevel_steps) * PI * 0.5
		rings.append([bevel * (1.0 - cos(ang)), h - bevel + bevel * sin(ang), side_c.lerp(top_c, float(k) / float(bevel_steps)), ang])
	var dirs: Array[Vector2] = []
	var centres: Array[Vector2] = []
	for c in 4:
		var centre := Vector2(w - corner, w - corner).rotated(float(c) * PI * 0.5)
		for step in corner_steps + 1:
			dirs.append(Vector2.from_angle(float(c) * PI * 0.5 + float(step) / float(corner_steps) * PI * 0.5))
			centres.append(centre)
	var count := dirs.size()
	var point := func(ring: Array, i: int) -> Vector3:
		var flat: Vector2 = centres[i] + dirs[i] * (corner - float(ring[0]))
		return Vector3(flat.x, float(ring[1]), flat.y)
	var normal := func(ring: Array, i: int) -> Vector3:
		var tilt := float(ring[3])
		return Vector3(dirs[i].x * cos(tilt), sin(tilt), dirs[i].y * cos(tilt)).normalized()
	var emit := func(pos: Vector3, nrm: Vector3, col: Color) -> void:
		st.set_normal(nrm)
		st.set_color(col)
		st.add_vertex(pos)
	# Godot draws clockwise triangles as front faces; orient each one outward.
	var tri := func(p: Array, n: Array, c: Array) -> void:
		var facing: Vector3 = (p[2] - p[0]).cross(p[1] - p[0])
		var order := [0, 1, 2] if facing.dot(n[0] + n[1] + n[2]) > 0.0 else [0, 2, 1]
		for index in order:
			emit.call(p[index], n[index], c[index])
	for r in rings.size() - 1:
		var low: Array = rings[r]
		var high: Array = rings[r + 1]
		for i in count:
			var j := (i + 1) % count
			var p := [point.call(low, i), point.call(low, j), point.call(high, j), point.call(high, i)]
			var n := [normal.call(low, i), normal.call(low, j), normal.call(high, j), normal.call(high, i)]
			var c := [low[2], low[2], high[2], high[2]]
			tri.call([p[0], p[1], p[2]], [n[0], n[1], n[2]], [c[0], c[1], c[2]])
			tri.call([p[0], p[2], p[3]], [n[0], n[2], n[3]], [c[0], c[2], c[3]])
	var last: Array = rings[rings.size() - 1]
	var middle := Vector3(0, h, 0)
	for i in count:
		var j := (i + 1) % count
		tri.call([middle, point.call(last, i), point.call(last, j)], [Vector3.UP, Vector3.UP, Vector3.UP], [top_c, top_c, top_c])
	return st.commit()


func _make_bush_node() -> Node3D:
	var root := Node3D.new()
	root.name = "Bush"
	root.position = Vector3(0, FarmLayout.TILE_HEIGHT, 0)
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.04
	cyl.height = 0.16
	stem.mesh = cyl
	stem.material_override = _bush_mats[2]
	stem.position = Vector3(0, 0.08, 0)
	root.add_child(stem)
	for i in 3:
		var ball := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.13 if i == 0 else 0.10
		sph.height = sph.radius * 2.0
		ball.mesh = sph
		ball.material_override = _bush_mats[i % 2]
		var ox := 0.0 if i == 0 else (0.10 if i == 1 else -0.09)
		var oz := 0.0 if i == 0 else (0.07 if i == 1 else 0.08)
		ball.position = Vector3(ox, 0.20 + 0.02 * i, oz)
		root.add_child(ball)
	return root


func _crop_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	mat.metallic = 0.0
	return mat


func _make_crop_node() -> Node3D:
	var root := Node3D.new()
	root.name = "Crop"
	root.position = Vector3(0, FarmLayout.TILE_HEIGHT, 0)
	return root


func _crop_add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _crop_mat(color)
	inst.position = pos
	inst.rotation = rot
	inst.scale = scale
	parent.add_child(inst)
	return inst


func _style_crop(node: Node3D, entity: String, ratio: float) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()
	var s := 0.30 + 0.70 * clampf(ratio, 0.0, 1.0)
	node.scale = Vector3(s, s, s)
	match entity:
		"Carrot":
			# Tapered orange root sitting in the soil, plus a fan of green leaves.
			var root := CylinderMesh.new()
			root.top_radius = 0.09
			root.bottom_radius = 0.012
			root.height = 0.42
			root.radial_segments = 10
			_crop_add(node, root, Color(0.92, 0.45, 0.16, 1), Vector3(0, 0.10, 0))
			var shoulder := SphereMesh.new()
			shoulder.radius = 0.09
			shoulder.height = 0.10
			_crop_add(node, shoulder, Color(0.90, 0.42, 0.14, 1), Vector3(0, 0.30, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
			for i in 5:
				var leaf := BoxMesh.new()
				leaf.size = Vector3(0.07, 0.22, 0.02)
				var ang := deg_to_rad(-40 + 20 * i)
				var inst := _crop_add(node, leaf, Color(0.30, 0.58, 0.24, 1), Vector3(sin(ang) * 0.05, 0.42, cos(ang) * 0.03), Vector3(-0.55, ang, 0.15))
				inst.scale = Vector3(1, 1.0 + 0.1 * (i % 2), 1)
			node.scale = Vector3(s, s, s)
		"Tree":
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.05
			trunk.bottom_radius = 0.09
			trunk.height = 0.62
			_crop_add(node, trunk, Color(0.44, 0.28, 0.15, 1), Vector3(0, 0.31, 0))
			var c1 := SphereMesh.new(); c1.radius = 0.28; c1.height = 0.44
			var c2 := SphereMesh.new(); c2.radius = 0.20; c2.height = 0.34
			var c3 := SphereMesh.new(); c3.radius = 0.18; c3.height = 0.30
			_crop_add(node, c1, Color(0.22, 0.48, 0.26, 1), Vector3(0.0, 0.70, 0.0))
			_crop_add(node, c2, Color(0.30, 0.56, 0.28, 1), Vector3(0.16, 0.64, 0.08))
			_crop_add(node, c3, Color(0.26, 0.50, 0.24, 1), Vector3(-0.14, 0.78, -0.06))
		"Sunflower":
			var stem := CylinderMesh.new()
			stem.top_radius = 0.03
			stem.bottom_radius = 0.045
			stem.height = 0.62
			_crop_add(node, stem, Color(0.34, 0.52, 0.22, 1), Vector3(0, 0.31, 0))
			var disk := SphereMesh.new()
			disk.radius = 0.11
			disk.height = 0.12
			_crop_add(node, disk, Color(0.28, 0.16, 0.08, 1), Vector3(0, 0.66, 0.04), Vector3(-0.25, 0, 0))
			for i in 10:
				var petal := SphereMesh.new()
				petal.radius = 0.055
				petal.height = 0.16
				var a := TAU * float(i) / 10.0
				_crop_add(node, petal, Color(0.94, 0.76, 0.16, 1), Vector3(cos(a) * 0.16, 0.66 + sin(a) * 0.04, 0.04 + sin(a) * 0.02), Vector3(0, 0, a), Vector3(0.55, 1.15, 0.35))
			var leaf := BoxMesh.new()
			leaf.size = Vector3(0.12, 0.18, 0.02)
			_crop_add(node, leaf, Color(0.32, 0.56, 0.24, 1), Vector3(0.10, 0.28, 0.02), Vector3(0.4, 0.5, 0.8))
		"Pumpkin":
			var fruit := SphereMesh.new()
			fruit.radius = 0.26
			fruit.height = 0.36
			_crop_add(node, fruit, Color(0.90, 0.48, 0.14, 1), Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(1.15, 0.78, 1.05))
			var rib := SphereMesh.new()
			rib.radius = 0.24
			rib.height = 0.34
			_crop_add(node, rib, Color(0.80, 0.38, 0.10, 1), Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(0.70, 0.82, 1.18))
			var stem := CylinderMesh.new()
			stem.top_radius = 0.025
			stem.bottom_radius = 0.04
			stem.height = 0.10
			_crop_add(node, stem, Color(0.32, 0.42, 0.18, 1), Vector3(0, 0.36, 0), Vector3(0.15, 0, 0.2))
		"DeadPumpkin":
			var wilt := SphereMesh.new()
			wilt.radius = 0.20
			wilt.height = 0.22
			_crop_add(node, wilt, Color(0.42, 0.32, 0.20, 1), Vector3(0, 0.10, 0), Vector3.ZERO, Vector3(1.1, 0.55, 0.9))
		"Cactus":
			var col := CylinderMesh.new()
			col.top_radius = 0.09
			col.bottom_radius = 0.11
			col.height = 0.52
			_crop_add(node, col, Color(0.28, 0.54, 0.32, 1), Vector3(0, 0.26, 0))
			var cap := SphereMesh.new()
			cap.radius = 0.09
			cap.height = 0.12
			_crop_add(node, cap, Color(0.30, 0.56, 0.34, 1), Vector3(0, 0.52, 0))
			var arm_h := CylinderMesh.new()
			arm_h.top_radius = 0.05
			arm_h.bottom_radius = 0.06
			arm_h.height = 0.20
			_crop_add(node, arm_h, Color(0.26, 0.50, 0.30, 1), Vector3(0.14, 0.30, 0), Vector3(0, 0, 1.2))
			var arm_u := CylinderMesh.new()
			arm_u.top_radius = 0.05
			arm_u.bottom_radius = 0.055
			arm_u.height = 0.18
			_crop_add(node, arm_u, Color(0.26, 0.50, 0.30, 1), Vector3(0.24, 0.40, 0))
			var arm_h2 := CylinderMesh.new()
			arm_h2.top_radius = 0.045
			arm_h2.bottom_radius = 0.055
			arm_h2.height = 0.16
			_crop_add(node, arm_h2, Color(0.28, 0.52, 0.32, 1), Vector3(-0.12, 0.26, 0.02), Vector3(0, 0, -1.2))
			var arm_u2 := CylinderMesh.new()
			arm_u2.top_radius = 0.045
			arm_u2.bottom_radius = 0.05
			arm_u2.height = 0.16
			_crop_add(node, arm_u2, Color(0.28, 0.52, 0.32, 1), Vector3(-0.20, 0.34, 0.02))

		"Hedge":
			var wall := BoxMesh.new()
			wall.size = Vector3(0.98, 0.78, 0.98)
			_crop_add(node, wall, Color(0.18, 0.34, 0.20, 1), Vector3(0, 0.39, 0))
			var top := BoxMesh.new()
			top.size = Vector3(1.02, 0.16, 1.02)
			_crop_add(node, top, Color(0.24, 0.42, 0.24, 1), Vector3(0, 0.80, 0))
			var post := CylinderMesh.new()
			post.top_radius = 0.05
			post.bottom_radius = 0.06
			post.height = 0.86
			_crop_add(node, post, Color(0.36, 0.24, 0.14, 1), Vector3(0.40, 0.43, 0.40))
			_crop_add(node, post, Color(0.36, 0.24, 0.14, 1), Vector3(-0.40, 0.43, -0.40))
			node.scale = Vector3.ONE
		"Treasure":
			var box := BoxMesh.new()
			box.size = Vector3(0.36, 0.22, 0.28)
			_crop_add(node, box, Color(0.86, 0.64, 0.18, 1), Vector3(0, 0.14, 0))
			var lid := BoxMesh.new()
			lid.size = Vector3(0.38, 0.08, 0.30)
			_crop_add(node, lid, Color(0.92, 0.74, 0.24, 1), Vector3(0, 0.28, 0))
			var band := BoxMesh.new()
			band.size = Vector3(0.08, 0.24, 0.30)
			_crop_add(node, band, Color(0.72, 0.52, 0.14, 1), Vector3(0, 0.16, 0))
			var gem := SphereMesh.new()
			gem.radius = 0.07
			gem.height = 0.10
			_crop_add(node, gem, Color(0.40, 0.82, 0.86, 1), Vector3(0, 0.36, 0))
			node.scale = Vector3.ONE * maxf(0.85, s)
		"Apple":
			var ap := SphereMesh.new()
			ap.radius = 0.13
			ap.height = 0.24
			_crop_add(node, ap, Color(0.84, 0.20, 0.18, 1), Vector3(0, 0.14, 0))
			var st := CylinderMesh.new()
			st.top_radius = 0.015
			st.bottom_radius = 0.02
			st.height = 0.08
			_crop_add(node, st, Color(0.36, 0.24, 0.12, 1), Vector3(0, 0.28, 0))
		_:
			var sph := SphereMesh.new()
			sph.radius = 0.14
			sph.height = 0.28
			_crop_add(node, sph, Color(0.70, 0.70, 0.55, 1), Vector3(0, 0.14, 0))


func _earth_pad_radius(half: float, ang: float) -> float:
	# Rounded-square (superellipse) with a little edge noise — not a hard circle.
	var n := 4.6
	var denom := pow(pow(absf(cos(ang)), n) + pow(absf(sin(ang)), n), 1.0 / n)
	var r := half / maxf(denom, 0.001)
	r *= 1.0 + 0.048 * sin(ang * 3.0 + 0.4) + 0.03 * cos(ang * 5.0 - 0.8) + 0.018 * sin(ang * 7.0 + 1.1)
	return r


func _make_earth_pad_mesh(half: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var segs := 40
	var top_c := Color(0.46, 0.48, 0.40, 1)
	var pts: Array = []
	pts.append(Vector3(0, 0.0, 0))
	for r in range(1, rings + 1):
		var t := float(r) / float(rings)
		for s in segs:
			var ang := TAU * float(s) / float(segs)
			var rad := _earth_pad_radius(half, ang) * t
			# Almost flat; only the outer lip eases down into the meadow.
			var y := 0.0
			if t > 0.86:
				var k := (t - 0.86) / 0.14
				y = -0.10 * k * k
			pts.append(Vector3(cos(ang) * rad, y, sin(ang) * rad))
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		st.set_color(top_c)
		st.add_vertex(a)
		st.set_color(top_c)
		st.add_vertex(b)
		st.set_color(top_c)
		st.add_vertex(c)
	for s in segs:
		var s2 := (s + 1) % segs
		tri.call(pts[0], pts[1 + s], pts[1 + s2])
	for r in range(1, rings):
		var base := 1 + (r - 1) * segs
		var nxt := 1 + r * segs
		for s in segs:
			var s2 := (s + 1) % segs
			tri.call(pts[base + s], pts[nxt + s], pts[nxt + s2])
			tri.call(pts[base + s], pts[nxt + s2], pts[base + s2])
	st.generate_normals()
	return st.commit()


func _ensure_meadow() -> void:
	if meadow != null and is_instance_valid(meadow):
		return
	meadow = MeshInstance3D.new()
	meadow.name = "Meadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(56, 56)
	meadow.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.52, 0.43, 1)
	mat.roughness = 1.0
	meadow.material_override = mat
	meadow.position = Vector3(0, -0.12, 0)
	meadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if farm_root:
		farm_root.add_child(meadow)
		# Keep the pad above the meadow in the tree, meadow first.
		farm_root.move_child(meadow, 0)
		scenery = FarmScenery.new()
		scenery.name = "Scenery"
		farm_root.add_child(scenery)
		scenery.dress_meadow(meadow)


func _update_earth(size: int) -> void:
	_ensure_meadow()
	var field := float(maxi(1, size)) * FarmLayout.TILE_SPACING
	var half := field * 0.5 + 0.92
	farm_earth.mesh = _make_earth_pad_mesh(half)
	if scenery:
		# The pad is a rounded square; its corners reach about 1.22 x half.
		scenery.layout(half * 1.25 + 0.3)
	var earth_mat := StandardMaterial3D.new()
	earth_mat.albedo_color = Color(1, 1, 1, 1)
	earth_mat.roughness = 1.0
	earth_mat.vertex_color_use_as_albedo = true
	farm_earth.material_override = earth_mat
	farm_earth.position = Vector3(0, -0.05, 0)


func _make_blade_mat(albedo: Color, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.62
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(0.72, 0.84, 0.30, 1)
		mat.emission_energy_multiplier = emission
	return mat


func _make_blade_mesh(bend: float, base_w: float, tip_w: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 6
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := height * t0
		var y1 := height * t1
		var z0 := bend * t0 * t0
		var z1 := bend * t1 * t1
		var w0 := lerpf(base_w, tip_w, t0 * t0)
		var w1 := lerpf(base_w, tip_w, t1 * t1)
		var c0 := Color(0.22, 0.38, 0.16, 1).lerp(Color(0.70, 0.84, 0.34, 1), pow(t0, 0.85))
		var c1 := Color(0.22, 0.38, 0.16, 1).lerp(Color(0.70, 0.84, 0.34, 1), pow(t1, 0.85))
		var a := Vector3(-w0, y0, z0)
		var b := Vector3(w0, y0, z0)
		var c := Vector3(w1, y1, z1)
		var d := Vector3(-w1, y1, z1)
		st.set_color(c0)
		st.add_vertex(a)
		st.set_color(c0)
		st.add_vertex(b)
		st.set_color(c1)
		st.add_vertex(c)
		st.set_color(c0)
		st.add_vertex(a)
		st.set_color(c1)
		st.add_vertex(c)
		st.set_color(c1)
		st.add_vertex(d)
	st.generate_normals()
	return st.commit()


func _field_is_far(plot: Dictionary) -> bool:
	if camera == null or not plot.has("root"):
		return false
	var pos: Vector3 = (plot["root"] as Node3D).global_position
	return camera.global_position.distance_to(pos) > 11.0


func _make_tile_multimesh(mat: Material) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_beveled_tile_mesh()
	mm.instance_count = 0
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_plots_root.add_child(inst)
	return inst


func _rebuild_tile_batches(size: int) -> void:
	var use_batch := size >= 8
	if use_batch:
		if _tile_mm_grass == null:
			_tile_mm_grass = _make_tile_multimesh(_grass_mat)
		if _tile_mm_soil == null:
			_tile_mm_soil = _make_tile_multimesh(_soil_mat)
		if _wet_soil_mat == null:
			_wet_soil_mat = _crop_mat(Color(0.22, 0.20, 0.16, 1))
		if _tile_mm_wet == null:
			_tile_mm_wet = _make_tile_multimesh(_wet_soil_mat)
		var count := size * size
		for inst in [_tile_mm_grass, _tile_mm_soil, _tile_mm_wet]:
			inst.visible = true
			inst.multimesh.instance_count = count
		for y in size:
			for x in size:
				var idx := y * size + x
				var xf := Transform3D(Basis.IDENTITY, tile_world(x, y, size))
				_tile_mm_grass.multimesh.set_instance_transform(idx, xf)
				_tile_mm_soil.multimesh.set_instance_transform(idx, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
				_tile_mm_wet.multimesh.set_instance_transform(idx, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	else:
		for inst in [_tile_mm_grass, _tile_mm_soil, _tile_mm_wet]:
			if inst:
				inst.visible = false
	for y in size:
		for x in size:
			var plot: Dictionary = plots[Vector2i(x, y)]
			var tile: MeshInstance3D = plot["tile"]
			tile.visible = not use_batch


func _sync_batched_tile(x: int, y: int, ground: String, water: float) -> void:
	if shown_size < 8 or _tile_mm_grass == null:
		return
	var idx := y * shown_size + x
	if idx < 0 or idx >= _tile_mm_grass.multimesh.instance_count:
		return
	var xf := Transform3D(Basis.IDENTITY, tile_world(x, y, shown_size))
	var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
	var wet := ground == "Soil" and water > 0.15
	var soil := ground == "Soil" and not wet
	_tile_mm_grass.multimesh.set_instance_transform(idx, xf if ground != "Soil" else hidden)
	_tile_mm_soil.multimesh.set_instance_transform(idx, xf if soil else hidden)
	if _tile_mm_wet:
		_tile_mm_wet.multimesh.set_instance_transform(idx, xf if wet else hidden)
