class_name DebugLines
extends MeshInstance3D
## Linee colorate ricostruite a ogni frame: riquadri dei colpi (pulsante
## "Hitbox" del prototipo) e cubo del cursore di costruzione.

var _mesh := ImmediateMesh.new()
var _open := false


func _ready() -> void:
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 10
	mat.no_depth_test = false
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	top_level = true
	global_transform = Transform3D.IDENTITY


func begin() -> void:
	_mesh.clear_surfaces()
	_open = false


func line(a: Vector3, b: Vector3, c: Color) -> void:
	if not _open:
		_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_open = true
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)


func box(lo: Vector3, hi: Vector3, c: Color) -> void:
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)]
	for i in 4:
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % 4]
		line(a, b, c)
		line(Vector3(a.x, hi.y, a.z), Vector3(b.x, hi.y, b.z), c)
		line(a, Vector3(a.x, hi.y, a.z), c)


## Arco nel piano orizzontale: centro, raggio, angoli (radianti, convenzione della
## direzione del giocatore: avanti = (-sin, -cos)).
func arc(center: Vector3, r: float, a0: float, a1: float, c: Color, radial: bool = false) -> void:
	var n := maxi(4, int(absf(a1 - a0) / 0.15))
	var prev := Vector3.ZERO
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		var q := center + Vector3(-sin(a), 0, -cos(a)) * r
		if i > 0:
			line(prev, q, c)
		prev = q
	if radial:
		line(center, center + Vector3(-sin(a0), 0, -cos(a0)) * r, c)
		line(center, center + Vector3(-sin(a1), 0, -cos(a1)) * r, c)


func cylinder(base: Vector3, r: float, h: float, c: Color) -> void:
	arc(base, r, 0.0, TAU, c)
	arc(base + Vector3(0, h, 0), r, 0.0, TAU, c)
	for k in 4:
		var a := k * PI * 0.5
		var o := Vector3(-sin(a), 0, -cos(a)) * r
		line(base + o, base + o + Vector3(0, h, 0), c)


func finish() -> void:
	if _open:
		_mesh.surface_end()
		_open = false
