class_name WeaponTrail
extends MeshInstance3D
## Scia della lama (M4): nastro additivo tra base e punta dell'arma negli
## ultimi `LIFE` secondi, interpolato con Catmull-Rom perche' a 60 Hz un
## fendente percorre anche 30° per frame.

const LIFE := 0.11
const SUB := 4

var color := Color(0.75, 0.88, 1.0)
var _samples: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/presentation/shaders/trail.gdshader")
	mat.render_priority = 7
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	top_level = true
	global_transform = Transform3D.IDENTITY


## Aggiunge un campione (se `emit`) e invecchia gli altri.
func push(dt: float, seg: PackedVector3Array, emit: bool) -> void:
	for s in _samples:
		s["age"] = float(s["age"]) + dt
	while not _samples.is_empty() and float(_samples[0]["age"]) > LIFE:
		_samples.remove_at(0)
	if emit and seg.size() == 2:
		_samples.append({"a": seg[0], "b": seg[1], "age": 0.0})
	_rebuild()


func clear() -> void:
	_samples.clear()
	_rebuild()


func sample_count() -> int:
	return _samples.size()


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _rebuild() -> void:
	_mesh.clear_surfaces()
	var n := _samples.size()
	if n < 2:
		return
	var pts_a: Array[Vector3] = []
	var pts_b: Array[Vector3] = []
	var ages: Array[float] = []
	for i in n - 1:
		var i0 := maxi(0, i - 1)
		var i3 := mini(n - 1, i + 2)
		for k in SUB:
			var t := float(k) / SUB
			pts_a.append(_cr(_samples[i0]["a"], _samples[i]["a"], _samples[i + 1]["a"], _samples[i3]["a"], t))
			pts_b.append(_cr(_samples[i0]["b"], _samples[i]["b"], _samples[i + 1]["b"], _samples[i3]["b"], t))
			ages.append(lerpf(_samples[i]["age"], _samples[i + 1]["age"], t))
	pts_a.append(_samples[n - 1]["a"])
	pts_b.append(_samples[n - 1]["b"])
	ages.append(_samples[n - 1]["age"])
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts_a.size() - 1:
		var k0 := 1.0 - ages[i] / LIFE
		var k1 := 1.0 - ages[i + 1] / LIFE
		var c0 := Color(color.r, color.g, color.b, clampf(k0, 0.0, 1.0) * 0.85)
		var c1 := Color(color.r, color.g, color.b, clampf(k1, 0.0, 1.0) * 0.85)
		# La base del nastro e' piu' tenue della punta.
		var cb0 := Color(c0.r, c0.g, c0.b, c0.a * 0.25)
		var cb1 := Color(c1.r, c1.g, c1.b, c1.a * 0.25)
		for v in [[pts_a[i], cb0], [pts_b[i], c0], [pts_b[i + 1], c1], [pts_a[i], cb0], [pts_b[i + 1], c1], [pts_a[i + 1], cb1]]:
			_mesh.surface_set_color(v[1])
			_mesh.surface_add_vertex(v[0])
	_mesh.surface_end()
