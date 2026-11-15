extends Node
## The field: one plot per simulator tile (soil tile, grass blades, bush,
## crop and a far-distance LOD), the rounded earth pad, the meadow and its
## scenery. update() mirrors the simulator's ground and entities every frame;
## tiles are batched into MultiMeshes for speed.

const FarmLayout := preload("res://scripts/farm_layout.gd")
const FarmScenery := preload("res://scripts/farm_scenery.gd")
const FarmPalette := preload("res://scripts/farm_palette.gd")

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
var _tile_mat: StandardMaterial3D
var _wet_soil_mat: StandardMaterial3D
var _grass_tile_mesh: ArrayMesh
var _soil_tile_mesh: ArrayMesh
var _part_mats: Dictionary = {}
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
	# Blades carry their own base-to-tip gradient; the material only tints it:
	# fresh green while growing, hay gold once ripe.
	_blade_young = _make_blade_mat(Color(0.84, 0.96, 0.86, 1), 0.0)
	_blade_mid = _make_blade_mat(Color(1.0, 1.0, 1.0, 1), 0.0)
	_blade_ripe = _make_blade_mat(Color(1.0, 0.94, 0.68, 1), 0.06)
	_blade_mats = [_blade_young, _blade_mid, _blade_ripe]
	_blade_meshes = [
		_make_blade_mesh(0.06, 0.034, 0.010, 0.32),
		_make_blade_mesh(0.09, 0.030, 0.009, 0.30),
		_make_blade_mesh(0.04, 0.036, 0.011, 0.34),
		_make_blade_mesh(0.11, 0.028, 0.008, 0.28),
	]
	_tile_mat = _make_tile_mat(Color.WHITE)
	_wet_soil_mat = _make_tile_mat(FarmPalette.WET_TINT)
	_grass_tile_mesh = _make_tile_mesh(FarmPalette.TURF_TOP, FarmPalette.TURF_LIP, FarmPalette.EARTH_SIDE, FarmPalette.EARTH_FOOT, false)
	_soil_tile_mesh = _make_tile_mesh(FarmPalette.SOIL_TOP, FarmPalette.SOIL_TOP.darkened(0.06), FarmPalette.SOIL_SIDE, FarmPalette.SOIL_FOOT, true)
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
			tile_mesh.mesh = _soil_tile_mesh if ground == "Soil" else _grass_tile_mesh
			tile_mesh.material_override = _tile_mat
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
			# A plant pops in when it appears and gives a small wobble when it ripens.
			var shown: String = entity if (is_bush or styled) else ""
			if plot.get("shown_kind", "") != shown:
				plot["shown_kind"] = shown
				plot["pop"] = 1.0 if shown != "" else 0.0
				plot["was_ripe"] = false
			if shown != "" and ratio >= 0.999 and not plot.get("was_ripe", false):
				plot["was_ripe"] = true
				plot["pop"] = maxf(float(plot.get("pop", 0.0)), 0.55)
			var pop: float = plot.get("pop", 0.0)
			if pop > 0.0:
				pop = maxf(0.0, pop - delta * 2.4)
				plot["pop"] = pop
			var stretch := 1.0 + 0.30 * sin((1.0 - pop) * TAU * 1.25) * pop
			var squash := Vector3(2.0 - stretch, stretch, 2.0 - stretch)
			if is_bush:
				var bscale := 0.22 + 0.78 * ratio
				bush_node.scale = squash * bscale
				bush_node.rotation.y = 0.15 * sin(_time * 0.7 + float(x + y))
			if styled:
				if plot.get("crop_kind", "") != entity:
					_style_crop(crop_node, entity, ratio)
					plot["crop_kind"] = entity
				var s := 0.30 + 0.70 * ratio
				if entity == "Hedge" or entity == "Treasure":
					crop_node.scale = squash
					crop_node.rotation.y = 0.0
				else:
					crop_node.scale = squash * s
					if (not _field_is_far(plot)) and (entity not in ["Cactus"]):
						crop_node.rotation.y = 0.08 * sin(_time * 0.6 + float(x + y))
						crop_node.rotation.z = 0.035 * sin(_time * 1.1 + float(x * 3 + y))
			else:
				plot["crop_kind"] = ""
			var water := 0.0
			if host.has_method("tile_water"):
				water = float(host.tile_water(x, y))
			if ground == "Soil" and water > 0.15:
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
	tile.mesh = _grass_tile_mesh
	tile.material_override = _tile_mat
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
	glow_mat.albedo_color = Color(1.0, 0.90, 0.52, 0.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.90, 0.52, 1)
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
	lod.material_override = _part_mat(FarmPalette.TURF_TOP.lerp(FarmPalette.HAY, 0.45))
	lod.position = Vector3(0, FarmLayout.TILE_HEIGHT + 0.04, 0)
	lod.visible = false
	root.add_child(lod)
	return {"x": x, "y": y, "root": root, "tile": tile, "grass": grass, "bush": bush, "crop": crop, "blades": blades, "juice": 0.0, "glow": glow, "glow_mat": glow_mat, "lod": lod}


func _make_tile_mat(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	return mat


## One shared matte material per colour, so a field of crops stays cheap.
func _part_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _part_mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.88
		mat.metallic = 0.0
		_part_mats[key] = mat
	return _part_mats[key]


## A soft block: generously rounded corners and a rolled top edge with smooth
## normals. `lip_c` is the band just under the rim (turf hanging over earth);
## `furrows` adds low planting ridges on top.
func _make_tile_mesh(top_c: Color, lip_c: Color, side_c: Color, foot_c: Color, furrows: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := FarmLayout.TILE_WIDTH * 0.5
	var h := FarmLayout.TILE_HEIGHT
	var corner := 0.20
	var bevel := 0.09
	var corner_steps := 8
	var bevel_steps := 5
	# Each ring: [inset, height, colour, tilt of the normal toward straight up].
	var rings: Array = [[0.03, 0.0, foot_c, 0.0], [0.0, h * 0.30, side_c, 0.0], [0.0, h * 0.52, side_c, 0.0], [0.0, h * 0.64, lip_c, 0.0], [0.0, h - bevel, lip_c, 0.0]]
	for k in range(1, bevel_steps + 1):
		var ang := float(k) / float(bevel_steps) * PI * 0.5
		rings.append([bevel * (1.0 - cos(ang)), h - bevel + bevel * sin(ang), lip_c.lerp(top_c, float(k) / float(bevel_steps)), ang])
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
	if furrows:
		# Three low rounded ridges across the bed.
		var ridge := CapsuleMesh.new()
		ridge.radius = 0.05
		ridge.height = FarmLayout.TILE_WIDTH - 0.34
		ridge.radial_segments = 8
		ridge.rings = 3
		var ridge_st := SurfaceTool.new()
		for k in 3:
			var xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 0.42, 1.0)), Vector3((float(k) - 1.0) * 0.27, h - 0.012, 0.0))
			ridge_st.clear()
			ridge_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			ridge_st.append_from(ridge, 0, xf)
			var arrays := ridge_st.commit_to_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in idx:
				st.set_normal(norms[i])
				st.set_color(top_c.lightened(0.05))
				st.add_vertex(verts[i])
	return st.commit()


# --- Plant models -------------------------------------------------------------
# Every plant is assembled from rounded parts (spheres, capsules, leaves) and
# merged into ONE vertex-coloured mesh per kind, cached and shared by all
# tiles. A full field therefore costs one mesh instance per plant.

var _model_parts: Array = []
var _model_cache: Dictionary = {}
var _model_mat: StandardMaterial3D
var _leaf_shape: ArrayMesh


func _ball(radius: float, height: float = -1.0) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 if height < 0.0 else height
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


func _pill(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 4
	return mesh


## A unit leaf: a pointed oval one unit long (+Z) and half as wide, cupped
## along its midrib and drooping toward the tip.
func _leaf() -> ArrayMesh:
	if _leaf_shape:
		return _leaf_shape
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8
	var rows: Array = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		var w := 0.25 * pow(sin(PI * pow(t, 0.75)), 0.85)
		var z := t
		var y := -0.22 * t * t
		rows.append([Vector3(-w, y + w * 0.38, z), Vector3(0, y, z), Vector3(w, y + w * 0.38, z)])
	for i in segs:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for side in 2:
			var quad := [a[side], a[side + 1], b[side + 1], b[side]]
			for index in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(quad[index])
	st.generate_normals()
	_leaf_shape = st.commit()
	return _leaf_shape


func _xf(pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled_local(scale), pos)


## Queue one part of the model being built. `parent` nests it (a flower head).
func _part(mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE, parent := Transform3D.IDENTITY) -> void:
	_model_parts.append([mesh, color, parent * _xf(pos, rot, scale)])


## A leaf of `length` growing from `pos`, turned `yaw` around up and tilted
## `pitch` above the ground (0 lies flat, PI/2 stands straight up).
func _leaf_part(color: Color, pos: Vector3, yaw: float, pitch: float, length: float, width := 1.0, parent := Transform3D.IDENTITY) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	_model_parts.append([_leaf(), color, parent * Transform3D(basis.scaled_local(Vector3(length * width, length, length)), pos)])


func _finish_model() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var piece := SurfaceTool.new()
	for part in _model_parts:
		var xf: Transform3D = part[2]
		piece.clear()
		piece.begin(Mesh.PRIMITIVE_TRIANGLES)
		piece.append_from(part[0], 0, xf)
		var arrays := piece.commit_to_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		# Primitive meshes are indexed; the hand-built leaf is a plain triangle list.
		var order: Array = range(verts.size())
		if arrays[Mesh.ARRAY_INDEX] != null:
			order = Array(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array)
		for i in order:
			st.set_normal(norms[i])
			st.set_color(part[1])
			st.add_vertex(verts[i])
	_model_parts.clear()
	st.index()
	return st.commit()


func _plant_material() -> StandardMaterial3D:
	if _model_mat == null:
		_model_mat = StandardMaterial3D.new()
		_model_mat.vertex_color_use_as_albedo = true
		_model_mat.vertex_color_is_srgb = true
		_model_mat.roughness = 0.9
		_model_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _model_mat


func _make_model_node(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = name
	root.position = Vector3(0, FarmLayout.TILE_HEIGHT, 0)
	var inst := MeshInstance3D.new()
	inst.name = "Model"
	inst.material_override = _plant_material()
	root.add_child(inst)
	return root


func _make_bush_node() -> Node3D:
	var root := _make_model_node("Bush")
	(root.get_node("Model") as MeshInstance3D).mesh = _plant_mesh("Bush")
	return root


func _make_crop_node() -> Node3D:
	return _make_model_node("Crop")


## Show `entity` on a crop node.
func _style_crop(node: Node3D, entity: String, ratio: float) -> void:
	(node.get_node("Model") as MeshInstance3D).mesh = _plant_mesh(entity)
	var s := 0.30 + 0.70 * clampf(ratio, 0.0, 1.0)
	node.scale = Vector3(s, s, s)


func _plant_mesh(entity: String) -> ArrayMesh:
	if _model_cache.has(entity):
		return _model_cache[entity]
	var P := FarmPalette
	_model_parts.clear()
	match entity:
		"Bush":
			# A low mound of leaf puffs on twiggy stems, dotted with berries.
			_part(_pill(0.040, 0.18), P.WOOD, Vector3(0, 0.08, 0))
			_part(_pill(0.022, 0.16), P.WOOD, Vector3(0.07, 0.10, 0.03), Vector3(0, 0, -0.7))
			_part(_pill(0.022, 0.16), P.WOOD, Vector3(-0.07, 0.10, 0.02), Vector3(0, 0, 0.7))
			for puff in [
				[Vector3(0.0, 0.21, 0.0), 0.150, P.LEAF], [Vector3(0.15, 0.16, 0.05), 0.110, P.LEAF_LIGHT],
				[Vector3(-0.14, 0.16, 0.04), 0.105, P.LEAF_DEEP], [Vector3(0.03, 0.16, -0.14), 0.105, P.LEAF],
				[Vector3(-0.02, 0.15, 0.14), 0.100, P.LEAF_LIGHT], [Vector3(-0.01, 0.32, 0.01), 0.095, P.LEAF_LIGHT],
				[Vector3(0.10, 0.28, -0.06), 0.075, P.LEAF], [Vector3(-0.10, 0.27, -0.05), 0.070, P.LEAF_DEEP],
				[Vector3(0.20, 0.11, -0.07), 0.065, P.LEAF_DEEP], [Vector3(-0.20, 0.10, -0.05), 0.060, P.LEAF]]:
				_part(_ball(puff[1]), puff[2], puff[0])
			for berry in [Vector3(0.11, 0.27, 0.11), Vector3(-0.12, 0.23, 0.12), Vector3(0.20, 0.19, 0.0), Vector3(-0.03, 0.39, 0.07), Vector3(0.04, 0.20, 0.21), Vector3(-0.21, 0.15, 0.03), Vector3(0.14, 0.33, -0.03)]:
				_part(_ball(0.024), P.BLOSSOM, berry)
			for i in 4:
				_leaf_part(P.LEAF_LIGHT, Vector3(0, 0.03, 0), TAU * float(i) / 4.0 + 0.6, 0.25, 0.20, 0.9)
		"Carrot":
			# A small row: orange shoulders peeking out under feathery tops.
			for spot in [[Vector3(-0.17, 0, 0.12), 1.0, 0.0], [Vector3(0.15, 0, -0.10), 0.86, 1.3], [Vector3(0.02, 0, 0.26), 0.74, 2.4], [Vector3(-0.04, 0, -0.26), 0.66, 4.0]]:
				var at: Vector3 = spot[0]
				var k: float = spot[1]
				_part(_ball(0.115 * k, 0.045 * k), P.SOIL_TOP.lightened(0.08), at + Vector3(0, 0.006, 0))
				_part(_ball(0.075 * k), P.CARROT, at + Vector3(0, 0.030 * k, 0), Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
				_part(_ball(0.060 * k), P.CARROT.lightened(0.10), at + Vector3(0, 0.060 * k, 0), Vector3.ZERO, Vector3(1.0, 0.45, 1.0))
				for i in 6:
					var yaw := TAU * float(i) / 6.0 + float(spot[2])
					var up := 1.10 if i % 2 == 0 else 0.75
					var tall := (0.26 if i % 2 == 0 else 0.20) * k
					_part(_pill(0.007 * k, tall * 0.55), P.LEAF, at + Vector3(sin(yaw) * 0.018, 0.07 * k + tall * 0.20, cos(yaw) * 0.018), Vector3(0.35 * cos(yaw), 0, -0.35 * sin(yaw)))
					_leaf_part(P.LEAF_LIGHT if i % 2 == 0 else P.LEAF, at + Vector3(sin(yaw) * 0.03, 0.08 * k, cos(yaw) * 0.03), yaw, up, tall, 0.62)
		"Tree":
			_part(_pill(0.070, 0.56), P.WOOD, Vector3(0, 0.27, 0))
			for i in 4:
				var a := TAU * float(i) / 4.0 + 0.5
				_part(_ball(0.060), P.WOOD.darkened(0.05), Vector3(cos(a) * 0.07, 0.02, sin(a) * 0.07), Vector3.ZERO, Vector3(1.2, 0.7, 1.2))
			_part(_pill(0.030, 0.22), P.WOOD, Vector3(0.09, 0.44, 0.03), Vector3(0, 0, -0.9))
			_part(_pill(0.028, 0.20), P.WOOD, Vector3(-0.08, 0.47, -0.02), Vector3(0, 0, 0.9))
			for puff in [
				[Vector3(0.0, 0.72, 0.0), 0.270, P.LEAF], [Vector3(0.20, 0.61, 0.08), 0.195, P.LEAF_LIGHT],
				[Vector3(-0.19, 0.64, -0.04), 0.190, P.LEAF_DEEP], [Vector3(0.03, 0.92, -0.02), 0.175, P.LEAF_LIGHT],
				[Vector3(-0.04, 0.63, 0.21), 0.150, P.LEAF], [Vector3(0.06, 0.66, -0.21), 0.150, P.LEAF_DEEP],
				[Vector3(0.21, 0.82, -0.05), 0.120, P.LEAF], [Vector3(-0.18, 0.85, 0.06), 0.115, P.LEAF_LIGHT],
				[Vector3(0.30, 0.55, -0.08), 0.085, P.LEAF_DEEP], [Vector3(-0.30, 0.56, 0.06), 0.080, P.LEAF],
				[Vector3(0.12, 0.50, 0.24), 0.080, P.LEAF_LIGHT], [Vector3(-0.02, 1.05, 0.02), 0.085, P.LEAF]]:
				_part(_ball(puff[1]), puff[2], puff[0])
			for bloom in [Vector3(0.17, 0.82, 0.14), Vector3(-0.13, 0.76, 0.22), Vector3(0.02, 1.02, 0.11), Vector3(0.28, 0.66, 0.10), Vector3(-0.27, 0.70, 0.10), Vector3(-0.06, 0.56, 0.31), Vector3(0.10, 0.60, 0.27)]:
				_part(_ball(0.015), P.BLOSSOM.lightened(0.25), bloom)
		"Sunflower":
			_part(_pill(0.026, 0.36), P.LEAF, Vector3(0.0, 0.17, 0.0), Vector3(0.05, 0, 0.04))
			_part(_pill(0.024, 0.34), P.LEAF, Vector3(-0.006, 0.47, 0.012), Vector3(0.10, 0, -0.03))
			for spec in [[0.20, 0.6, 0.30], [0.30, 3.5, 0.26], [0.42, 1.9, 0.20]]:
				_leaf_part(P.LEAF_LIGHT, Vector3(0, spec[0], 0), spec[1], 0.42, spec[2], 1.25)
			var head := _xf(Vector3(0, 0.67, 0.045), Vector3(-0.72, 0, 0))
			_part(_ball(0.115), P.LEAF_DEEP, Vector3(0, 0, -0.022), Vector3.ZERO, Vector3(1.0, 1.0, 0.35), head)
			for i in 16:
				var a := TAU * float(i) / 16.0
				_part(_ball(0.060), P.PETAL, Vector3(cos(a) * 0.165, sin(a) * 0.165, 0.0), Vector3(0, 0, a - PI * 0.5), Vector3(0.42, 1.30, 0.20), head)
			for i in 16:
				var a := TAU * (float(i) + 0.5) / 16.0
				_part(_ball(0.050), P.PETAL.lightened(0.18), Vector3(cos(a) * 0.130, sin(a) * 0.130, 0.012), Vector3(0, 0, a - PI * 0.5), Vector3(0.42, 1.20, 0.20), head)
			_part(_ball(0.100), P.SEED, Vector3(0, 0, 0.014), Vector3.ZERO, Vector3(1.0, 1.0, 0.40), head)
			for i in 10:
				var a := TAU * float(i) / 10.0
				_part(_ball(0.014), P.SEED.lightened(0.22), Vector3(cos(a) * 0.062, sin(a) * 0.062, 0.046), Vector3.ZERO, Vector3.ONE, head)
			_part(_ball(0.040), P.SEED.lightened(0.14), Vector3(0, 0, 0.040), Vector3.ZERO, Vector3(1.0, 1.0, 0.5), head)
		"Pumpkin":
			# Overlapping lobes around a core read as soft ribs; vine and leaves trail off.
			_part(_ball(0.200), P.PUMPKIN_DEEP, Vector3(0, 0.175, 0), Vector3.ZERO, Vector3(1.0, 0.84, 1.0))
			for i in 9:
				var a := TAU * float(i) / 9.0
				_part(_ball(0.120), P.PUMPKIN if i % 2 == 0 else P.PUMPKIN.lightened(0.08), Vector3(cos(a) * 0.150, 0.175, sin(a) * 0.150), Vector3(0, -a, 0), Vector3(0.80, 1.28, 1.0))
			_part(_ball(0.075), P.PUMPKIN_DEEP.darkened(0.06), Vector3(0, 0.315, 0), Vector3.ZERO, Vector3(1.0, 0.35, 1.0))
			_part(_pill(0.028, 0.10), P.LEAF_DEEP, Vector3(0.0, 0.355, 0.0), Vector3(0.10, 0, 0.12))
			_part(_pill(0.022, 0.08), P.LEAF_DEEP, Vector3(0.022, 0.405, 0.010), Vector3(0.2, 0, -0.9))
			for i in 7:
				# A curling tendril.
				var t := float(i) / 6.0
				var a := 2.2 + t * 3.6
				_part(_ball(0.016 - 0.006 * t), P.LEAF, Vector3(0.24 + cos(a) * 0.05 * (1.0 - t * 0.5) + t * 0.10, 0.03 + 0.05 * sin(t * PI), 0.10 + sin(a) * 0.05))
			_part(_pill(0.012, 0.30), P.LEAF, Vector3(0.17, 0.02, 0.12), Vector3(PI * 0.5, 0.9, 0))
			_leaf_part(P.LEAF_LIGHT, Vector3(0.22, 0.03, 0.16), 0.5, 0.28, 0.24, 1.7)
			_leaf_part(P.LEAF, Vector3(-0.20, 0.03, 0.14), -1.0, 0.24, 0.22, 1.7)
			_leaf_part(P.LEAF_LIGHT, Vector3(-0.10, 0.03, -0.22), 3.6, 0.22, 0.18, 1.7)
		"DeadPumpkin":
			_part(_ball(0.19), P.WILT.darkened(0.08), Vector3(0, 0.09, 0), Vector3.ZERO, Vector3(1.0, 0.50, 1.0))
			for i in 7:
				var a := TAU * float(i) / 7.0
				_part(_ball(0.115), P.WILT if i % 2 == 0 else P.WILT.darkened(0.05), Vector3(cos(a) * 0.135, 0.085, sin(a) * 0.135), Vector3(0, -a, 0), Vector3(0.80, 0.70, 1.0))
			_part(_pill(0.022, 0.09), P.WILT.darkened(0.25), Vector3(0.02, 0.17, 0), Vector3(0.5, 0, 0.6))
			_leaf_part(P.WILT.darkened(0.12), Vector3(0.20, 0.02, 0.12), 0.6, 0.05, 0.20, 1.5)
		"Cactus":
			_part(_pill(0.115, 0.54), P.CACTUS, Vector3(0, 0.27, 0))
			for i in 8:
				# Soft vertical ribs.
				var a := TAU * float(i) / 8.0
				_part(_pill(0.030, 0.44), P.CACTUS.lightened(0.09), Vector3(cos(a) * 0.092, 0.27, sin(a) * 0.092))
			_part(_pill(0.058, 0.24), P.CACTUS.lightened(0.04), Vector3(0.16, 0.27, 0), Vector3(0, 0, PI * 0.5))
			_part(_pill(0.058, 0.22), P.CACTUS.lightened(0.04), Vector3(0.25, 0.37, 0))
			_part(_pill(0.050, 0.20), P.CACTUS.darkened(0.04), Vector3(-0.14, 0.20, 0.02), Vector3(0, 0, PI * 0.5))
			_part(_pill(0.050, 0.18), P.CACTUS.darkened(0.04), Vector3(-0.21, 0.29, 0.02))
			for dot in [Vector3(0.0, 0.40, 0.118), Vector3(0.07, 0.25, 0.10), Vector3(-0.08, 0.32, 0.09), Vector3(0.11, 0.14, 0.05), Vector3(-0.05, 0.12, 0.11), Vector3(0.25, 0.40, 0.058), Vector3(-0.21, 0.31, 0.072), Vector3(0.10, 0.46, -0.07), Vector3(-0.11, 0.42, -0.04)]:
				_part(_ball(0.011), Color(0.98, 0.96, 0.90, 1), dot)
			for spot in [[Vector3(0, 0.545, 0), 1.0], [Vector3(0.25, 0.485, 0), 0.6]]:
				var c: Vector3 = spot[0]
				var k: float = spot[1]
				for i in 6:
					var a := TAU * float(i) / 6.0
					_part(_ball(0.036 * k), P.BLOSSOM, c + Vector3(cos(a) * 0.042 * k, 0.012 * k, sin(a) * 0.042 * k), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
				_part(_ball(0.024 * k), P.PETAL, c + Vector3(0, 0.026 * k, 0))
		"Hedge":
			# A clipped hedge wall: soft block, puffy top, leaf tufts on the faces.
			var wall := BoxMesh.new()
			wall.size = Vector3(0.96, 0.62, 0.96)
			_part(wall, P.LEAF_DEEP, Vector3(0, 0.31, 0))
			for corner in [Vector3(-0.24, 0.62, -0.24), Vector3(0.24, 0.62, -0.24), Vector3(-0.24, 0.62, 0.24), Vector3(0.24, 0.62, 0.24)]:
				_part(_ball(0.34), P.LEAF, corner, Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
			_part(_ball(0.34), P.LEAF_LIGHT, Vector3(0, 0.70, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
			for i in 12:
				var a := TAU * float(i) / 12.0
				var out := Vector3(cos(a), 0, sin(a))
				var edge := out / maxf(absf(out.x), absf(out.z)) * 0.47
				_part(_ball(0.10 + 0.03 * float(i % 3)), P.LEAF if i % 2 == 0 else P.LEAF_LIGHT, edge + Vector3(0, 0.20 + 0.14 * float(i % 3), 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
		"Treasure":
			var box := BoxMesh.new()
			box.size = Vector3(0.38, 0.20, 0.28)
			_part(box, P.WOOD, Vector3(0, 0.12, 0))
			_part(_pill(0.145, 0.42), P.WOOD.lightened(0.12), Vector3(0, 0.22, 0), Vector3(0, 0, PI * 0.5), Vector3(0.80, 1.0, 0.98))
			var band := BoxMesh.new()
			band.size = Vector3(0.06, 0.30, 0.30)
			for x in [-0.12, 0.12]:
				_part(band, P.GOLD_LEAF, Vector3(x, 0.17, 0))
			_part(_ball(0.045), P.GOLD_LEAF.lightened(0.2), Vector3(0, 0.20, 0.15))
			for x in [-0.12, 0.12]:
				_part(_ball(0.018), P.GOLD_LEAF.lightened(0.25), Vector3(x, 0.10, 0.15))
		"Apple":
			_part(_ball(0.14), P.APPLE, Vector3(0, 0.14, 0), Vector3.ZERO, Vector3(1.0, 0.92, 1.0))
			_part(_ball(0.06), P.APPLE.lightened(0.16), Vector3(-0.05, 0.20, 0.07), Vector3.ZERO, Vector3(1.0, 0.8, 0.6))
			_part(_pill(0.014, 0.08), P.WOOD, Vector3(0, 0.29, 0), Vector3(0, 0, 0.2))
			_leaf_part(P.LEAF_LIGHT, Vector3(0.01, 0.29, 0), 1.2, 0.35, 0.13, 1.2)
		_:
			_part(_ball(0.14), P.WILT, Vector3(0, 0.14, 0))
	_model_cache[entity] = _finish_model()
	return _model_cache[entity]


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
	var pts: Array = []
	var cols: Array = []
	pts.append(Vector3(0, 0.0, 0))
	cols.append(FarmPalette.PAD)
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
			# The rim melts into the meadow instead of ending in a line.
			cols.append(FarmPalette.PAD.lerp(FarmPalette.MEADOW_A, smoothstep(0.62, 1.0, t)))
	var tri := func(a: int, b: int, c: int) -> void:
		for i in [a, b, c]:
			st.set_color(cols[i])
			st.add_vertex(pts[i])
	for s in segs:
		var s2 := (s + 1) % segs
		tri.call(0, 1 + s, 1 + s2)
	for r in range(1, rings):
		var base := 1 + (r - 1) * segs
		var nxt := 1 + r * segs
		for s in segs:
			var s2 := (s + 1) % segs
			tri.call(base + s, nxt + s, nxt + s2)
			tri.call(base + s, nxt + s2, base + s2)
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
	mat.albedo_color = FarmPalette.MEADOW_A
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
	earth_mat.vertex_color_is_srgb = true
	farm_earth.material_override = earth_mat
	farm_earth.position = Vector3(0, -0.05, 0)


func _make_blade_mat(albedo: Color, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = FarmPalette.HAY
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
		var c0 := FarmPalette.BLADE_BASE.lerp(FarmPalette.BLADE_TIP, pow(t0, 0.85))
		var c1 := FarmPalette.BLADE_BASE.lerp(FarmPalette.BLADE_TIP, pow(t1, 0.85))
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


func _make_tile_multimesh(mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
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
			_tile_mm_grass = _make_tile_multimesh(_grass_tile_mesh, _tile_mat)
		if _tile_mm_soil == null:
			_tile_mm_soil = _make_tile_multimesh(_soil_tile_mesh, _tile_mat)
		if _tile_mm_wet == null:
			_tile_mm_wet = _make_tile_multimesh(_soil_tile_mesh, _wet_soil_mat)
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
