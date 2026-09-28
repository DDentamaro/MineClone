class_name LockMarker
extends Node3D
## Segno dell'aggancio (D-035): un triangolo rosso tridimensionale (piramide a
## base triangolare con la punta in giu') che gira lento e ondeggia sopra la
## testa del bersaglio agganciato. Facce a tinte diverse e contorno scuro (scafo
## rovesciato), cosi' si legge in 3D anche senza luci; sempre visibile, anche
## dietro alberi e muri. All'aggancio compare con un piccolo scatto di scala.

const SIZE := 0.17
const DEPTH := 0.30
const SPIN := 2.4
const LIFT := 0.42

var _mesh: MeshInstance3D
var _hull: MeshInstance3D
var _t := 0.0
var _pop := 0.0
var _target: CombatTarget


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _pyramid(1.0, [Color(1.0, 0.32, 0.26), Color(0.92, 0.12, 0.08), Color(0.62, 0.05, 0.04), Color(0.80, 0.08, 0.06)])
	_mesh.material_override = _material(false)
	_hull = MeshInstance3D.new()
	_hull.mesh = _pyramid(1.28, [Color(0.18, 0.0, 0.0)])
	_hull.material_override = _material(true)
	for m: MeshInstance3D in [_hull, _mesh]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	visible = false


func _material(hull: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_FRONT if hull else BaseMaterial3D.CULL_BACK
	mat.render_priority = 11 if not hull else 10
	return mat


## Piramide: base (triangolo equilatero) in alto a y = 0, punta a y = -DEPTH.
## `cols` = [base, lato 1, lato 2, lato 3] (uno solo = tutto dello stesso colore).
func _pyramid(k: float, cols: Array) -> ArrayMesh:
	var top: Array[Vector3] = []
	for i in 3:
		var a := TAU * i / 3.0
		top.append(Vector3(cos(a), 0, sin(a)) * SIZE * k)
	var tip := Vector3(0, -DEPTH * k, 0)
	var off := Vector3(0, (k - 1.0) * DEPTH * 0.35, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[top[0], top[1], top[2]], [top[0], tip, top[1]], [top[1], tip, top[2]], [top[2], tip, top[0]]]
	var mid := (top[0] + top[1] + top[2] + tip) * 0.25
	for f in faces.size():
		var fv: Array = faces[f]
		var a: Vector3 = fv[0]
		var b: Vector3 = fv[1]
		var c: Vector3 = fv[2]
		# Godot: faccia davanti in senso orario vista da fuori.
		if (b - a).cross(c - a).dot((a + b + c) / 3.0 - mid) > 0.0:
			var sw := b
			b = c
			c = sw
		st.set_color(cols[mini(f, cols.size() - 1)])
		for v: Vector3 in [a, b, c]:
			st.add_vertex(v + off)
	return st.commit()


func set_target(tg: CombatTarget) -> void:
	if tg != _target and tg != null:
		_pop = 1.0
	_target = tg


func update(dt: float) -> void:
	if _target == null or not _target.alive:
		visible = false
		return
	visible = true
	_t += dt
	_pop = maxf(0.0, _pop - dt * 5.0)
	var bob := sin(_t * 3.2) * 0.05
	global_position = _target.position + Vector3(0, _target.height + LIFT + bob, 0)
	rotation.y = _t * SPIN
	scale = Vector3.ONE * (1.0 + _pop * 0.7)
