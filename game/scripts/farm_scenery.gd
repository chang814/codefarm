extends Node3D
## Living backdrop around the field: a meadow with soft colour patches and slow
## cloud shadows, swaying tufts, small flowers, pebbles, round trees, drifting
## motes and a few butterflies. Everything is generated here from a fixed seed,
## so the project ships no models or textures. Decoration never enters the
## field: it starts outside `inner` and is laid out again when the field grows.

const SEED := 20261114
const REACH := 13.0

const MEADOW_SHADER := """
shader_type spatial;
uniform vec3 tone_a : source_color = vec3(0.50, 0.52, 0.43);
uniform vec3 tone_b : source_color = vec3(0.45, 0.51, 0.39);
uniform vec3 tone_c : source_color = vec3(0.57, 0.57, 0.45);
varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.3 + 1.7) * 0.1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Turn the lattice away from the tile grid and bend it, so patches read
	// as soft drifts rather than squares.
	vec2 p = mat2(vec2(0.82, 0.57), vec2(-0.57, 0.82)) * world_pos.xz;
	p += (vec2(noise(p * 0.21), noise(p * 0.21 + 9.0)) - 0.5) * 3.2;
	float patch = smoothstep(0.22, 0.78, fbm(p * 0.30));
	float light = smoothstep(0.45, 0.90, fbm(p * 0.55 + 31.0));
	vec3 c = mix(tone_a, tone_b, patch);
	c = mix(c, tone_c, light * 0.45);
	// Slow cloud shadows drifting across the meadow.
	float cloud = smoothstep(0.42, 0.80, fbm(p * 0.06 + TIME * vec2(0.035, 0.02)));
	c *= 1.0 - 0.12 * cloud;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const SWAY_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float amp = 0.10;
uniform float flat_light = 1.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = max(VERTEX.y, 0.0);
	VERTEX.x += sin(TIME * 1.5 + wp.x * 1.7 + wp.z * 1.3) * amp * k;
	VERTEX.z += cos(TIME * 1.1 + wp.z * 1.9) * amp * 0.6 * k;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), flat_light));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.0;
}
"""

var _inner := -1.0
var _decor: Node3D
var _flyers: Array = []
var _time := 0.0


## Gives the existing meadow plane its patches and cloud shadows.
func dress_meadow(meadow: MeshInstance3D) -> void:
	var shader := Shader.new()
	shader.code = MEADOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	meadow.material_override = mat


## Lays the decoration out in a ring that starts at `inner` world units from
## the field centre. Calling it again with the same radius does nothing.
func layout(inner: float) -> void:
	if is_equal_approx(inner, _inner):
		return
	_inner = inner
	if _decor:
		_decor.queue_free()
	_decor = Node3D.new()
	_decor.name = "Decor"
	add_child(_decor)
	_flyers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var tuft_mat := _sway_material(0.10, 1.0)
	var greens := [Color(0.27, 0.36, 0.17), Color(0.23, 0.33, 0.16), Color(0.33, 0.39, 0.19), Color(0.26, 0.31, 0.18)]
	var tufts: Array = []
	for i in 170:
		var p := _ring_point(rng, 0.35, REACH, 1.6)
		var s := rng.randf_range(0.5, 0.95)
		tufts.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), p), greens[rng.randi() % greens.size()]])
	_scatter("Tufts", _tuft_mesh(), tuft_mat, tufts, false)

	var petals := [Color(0.78, 0.74, 0.58), Color(0.76, 0.58, 0.20), Color(0.72, 0.42, 0.40), Color(0.52, 0.46, 0.66)]
	var head := SphereMesh.new()
	head.radius = 0.05
	head.height = 0.07
	head.radial_segments = 10
	head.rings = 5
	var flowers: Array = []
	for i in 34:
		# Flowers come in small drifts of one colour rather than evenly.
		var centre := _ring_point(rng, 0.5, REACH - 2.0, 1.3)
		var colour: Color = petals[rng.randi() % petals.size()]
		for j in rng.randi_range(2, 5):
			var off := Vector3(rng.randf_range(-0.45, 0.45), 0.0, rng.randf_range(-0.45, 0.45))
			var s := rng.randf_range(0.8, 1.3)
			flowers.append([Transform3D(Basis().scaled(Vector3.ONE * s), centre + off + Vector3(0, 0.07, 0)), colour])
	_scatter("Flowers", head, _sway_material(0.25, 0.6), flowers, false)

	var stone := SphereMesh.new()
	stone.radius = 0.10
	stone.height = 0.12
	stone.radial_segments = 10
	stone.rings = 5
	var stones: Array = []
	for i in 40:
		var p := _ring_point(rng, 0.3, REACH, 1.0)
		var s := rng.randf_range(0.6, 1.7)
		var tone := rng.randf_range(0.0, 1.0)
		stones.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(1.0, 1.6), s * 0.55, s)), p), Color(0.66, 0.63, 0.55).lerp(Color(0.56, 0.56, 0.52), tone)])
	_scatter("Stones", stone, _plain_material(), stones, true)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.055
	trunk.bottom_radius = 0.085
	trunk.height = 0.5
	trunk.radial_segments = 10
	var crown := SphereMesh.new()
	crown.radius = 0.5
	crown.height = 1.0
	crown.radial_segments = 20
	crown.rings = 10
	var leaves := [Color(0.27, 0.39, 0.19), Color(0.32, 0.43, 0.20), Color(0.23, 0.35, 0.19), Color(0.37, 0.44, 0.21)]
	var trunks: Array = []
	var crowns: Array = []
	for i in 13:
		# Trees keep well back so they never stand between camera and field.
		var p := _ring_point(rng, 3.0, REACH, 0.8)
		var s := rng.randf_range(0.8, 1.35)
		trunks.append([Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 0.25 * s, 0)), Color(0.50, 0.38, 0.28)])
		var colour: Color = leaves[rng.randi() % leaves.size()]
		crowns.append([Transform3D(Basis().scaled(Vector3(s, s * 0.92, s)), p + Vector3(0, 0.82 * s, 0)), colour])
		if rng.randf() < 0.6:
			var side := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3)) * s
			crowns.append([Transform3D(Basis().scaled(Vector3.ONE * s * 0.62), p + side + Vector3(0, 0.62 * s, 0)), colour.darkened(0.06)])
	for i in 22:
		# Low round shrubs fill the space between tufts and trees.
		var p := _ring_point(rng, 1.2, REACH, 1.1)
		var s := rng.randf_range(0.28, 0.55)
		crowns.append([Transform3D(Basis().scaled(Vector3(s * rng.randf_range(1.0, 1.4), s * 0.75, s)), p + Vector3(0, 0.12 * s, 0)), leaves[rng.randi() % leaves.size()].darkened(0.04)])
	_scatter("Trunks", trunk, _plain_material(), trunks, true)
	_scatter("Crowns", crown, _sway_material(0.035, 0.0), crowns, true)

	_add_motes()
	for i in 3:
		_add_butterfly(rng, [Color(0.97, 0.94, 0.82), Color(0.95, 0.84, 0.52), Color(0.93, 0.76, 0.72)][i])


func _process(delta: float) -> void:
	_time += delta
	for flyer in _flyers:
		var node: Node3D = flyer["node"]
		if not is_instance_valid(node):
			continue
		# A wandering loop around a home point, with a quick wing beat.
		var t: float = _time * flyer["speed"] + flyer["phase"]
		var home: Vector3 = flyer["home"]
		var pos := home + Vector3(sin(t) * 1.6 + sin(t * 2.3) * 0.5, 0.45 + sin(t * 1.7) * 0.18, cos(t * 0.8) * 1.3 + cos(t * 2.9) * 0.4)
		var heading := pos - node.position
		node.position = pos
		if heading.length_squared() > 0.000001:
			node.rotation.y = atan2(heading.x, heading.z)
		var beat := 0.25 + absf(sin(_time * 11.0 + flyer["phase"])) * 1.05
		(flyer["left"] as Node3D).rotation.z = beat
		(flyer["right"] as Node3D).rotation.z = -beat


## The welcome close-up looks along the ground; decoration would crowd it.
func set_decor_visible(on: bool) -> void:
	if _decor:
		_decor.visible = on


func decoration_count() -> int:
	var total := 0
	if _decor:
		for child in _decor.get_children():
			if child is MultiMeshInstance3D:
				total += (child as MultiMeshInstance3D).multimesh.instance_count
	return total


## Distance of the nearest decoration from the field centre, for checks.
func nearest_decoration() -> float:
	var nearest := INF
	if _decor:
		for child in _decor.get_children():
			if child is MultiMeshInstance3D:
				var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
				for i in mm.instance_count:
					var o := mm.get_instance_transform(i).origin
					nearest = minf(nearest, Vector2(o.x, o.z).length())
	return nearest


func _ring_point(rng: RandomNumberGenerator, gap: float, reach: float, bias: float) -> Vector3:
	# `bias` above 1 gathers points toward the field edge.
	var t := pow(rng.randf(), bias)
	var radius := _inner + gap + t * maxf(0.5, reach - gap)
	var angle := rng.randf() * TAU
	return Vector3(cos(angle) * radius, -0.12, sin(angle) * radius)


func _scatter(label: String, mesh: Mesh, material: Material, items: Array, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var inst := MultiMeshInstance3D.new()
	inst.name = label
	inst.multimesh = mm
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decor.add_child(inst)


func _sway_material(amp: float, flat_light: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SWAY_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("amp", amp)
	mat.set_shader_parameter("flat_light", flat_light)
	return mat


func _plain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	return mat


func _tuft_mesh() -> ArrayMesh:
	# Three tapered blades fanning from one root.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var basis := Basis(Vector3.UP, TAU * float(i) / 3.0 + 0.4)
		var lean := 0.10 + 0.05 * float(i)
		var height := 0.30 + 0.07 * float(i)
		var a := basis * Vector3(-0.035, 0.0, 0.03)
		var b := basis * Vector3(0.035, 0.0, 0.03)
		var mid_a := basis * Vector3(-0.024, height * 0.55, 0.03 + lean * 0.5)
		var mid_b := basis * Vector3(0.024, height * 0.55, 0.03 + lean * 0.5)
		var tip := basis * Vector3(0.0, height, 0.03 + lean)
		for v in [a, b, mid_b, a, mid_b, mid_a, mid_a, mid_b, tip]:
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.add_vertex(v)
	return st.commit()


func _add_motes() -> void:
	var motes := CPUParticles3D.new()
	motes.name = "Motes"
	motes.amount = 26
	motes.lifetime = 10.0
	motes.preprocess = 10.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(_inner + 5.0, 0.35, _inner + 5.0)
	motes.position = Vector3(0, 0.9, 0)
	motes.direction = Vector3(1.0, 0.12, 0.35)
	motes.spread = 25.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.10
	motes.initial_velocity_max = 0.26
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.3
	# Tiny round specks; a sphere needs no billboarding to stay round.
	var speck := SphereMesh.new()
	speck.radius = 0.013
	speck.height = 0.026
	speck.radial_segments = 8
	speck.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.98, 0.88, 0.45)
	speck.material = mat
	motes.mesh = speck
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decor.add_child(motes)


func _add_butterfly(rng: RandomNumberGenerator, colour: Color) -> void:
	var node := Node3D.new()
	node.name = "Butterfly"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wing := PlaneMesh.new()
	wing.size = Vector2(0.075, 0.09)
	var wings: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		var panel := MeshInstance3D.new()
		panel.mesh = wing
		panel.material_override = mat
		panel.position = Vector3(side * 0.04, 0, 0)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hinge.add_child(panel)
		node.add_child(hinge)
		wings.append(hinge)
	_decor.add_child(node)
	var home := _ring_point(rng, 1.0, 5.0, 1.0)
	node.position = home
	_flyers.append({"node": node, "left": wings[0], "right": wings[1], "home": home, "speed": rng.randf_range(0.28, 0.45), "phase": rng.randf() * TAU})
