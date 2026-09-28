class_name AimIndicator
extends MeshInstance3D
## Indicatore di mira delle magie alla Brawl Stars (D-034), disegnato a terra
## mentre il dito tiene e direziona il pulsante Magia: una fascia dal giocatore
## nella direzione scelta (proiettili, raggi, getti), un cerchio sul punto
## scelto (aree) o un anello attorno all'eroe (magie su di se'). Segue il
## terreno campionando la quota ogni mezzo metro; colore della scuola.

var world: WorldData
var _mat: StandardMaterial3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = true
	_mat.render_priority = 10
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	mesh = ImmediateMesh.new()
	visible = false


func _h(x: float, z: float, y_ref: float) -> float:
	if world == null:
		return y_ref
	return VoxelQuery.field_height(world, x, z, y_ref + 1.5) + 0.04


func hide_aim() -> void:
	visible = false


## `shape` "line" | "point" | "self"; `dir` nel piano XZ; `dist` distanza del
## punto (per "point"); `length` e `width` della fascia o raggio del cerchio.
func show_aim(shape: String, origin: Vector3, dir: Vector2, dist: float, length: float, width: float, col: Color) -> void:
	var im := mesh as ImmediateMesh
	im.clear_surfaces()
	visible = true
	var fill := Color(col, 0.38)
	var edge := Color(col.lightened(0.35), 0.85)
	match shape:
		"line":
			var f := Vector3(dir.x, 0, dir.y).normalized()
			var side := Vector3(-f.z, 0, f.x) * width * 0.5
			var steps := maxi(2, int(length / 0.5))
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in steps:
				var a := origin + f * (length * i / steps)
				var b := origin + f * (length * (i + 1) / steps)
				var qa := [a - side, a + side, b + side, b - side]
				var ys := []
				for q: Vector3 in qa:
					ys.append(Vector3(q.x, _h(q.x, q.z, origin.y), q.z))
				# Piu' chiara verso la punta (dove arriva la magia).
				var k := 0.6 + 0.4 * float(i) / steps
				for tri in [[0, 1, 2], [0, 2, 3]]:
					for j: int in tri:
						im.surface_set_color(Color(fill, fill.a * k))
						im.surface_add_vertex(ys[j])
			im.surface_end()
			_outline_line(im, origin, f, side, length, edge)
		"point":
			var c := origin + Vector3(dir.x, 0, dir.y).normalized() * dist
			_disc(im, c, width, fill, edge, origin.y)
			# Filo dal giocatore al punto.
			im.surface_begin(Mesh.PRIMITIVE_LINES)
			var steps2 := maxi(2, int(dist / 0.5))
			for i in steps2:
				var a2 := origin.lerp(c, float(i) / steps2)
				var b2 := origin.lerp(c, float(i + 1) / steps2)
				im.surface_set_color(Color(edge, 0.5))
				im.surface_add_vertex(Vector3(a2.x, _h(a2.x, a2.z, origin.y), a2.z))
				im.surface_set_color(Color(edge, 0.5))
				im.surface_add_vertex(Vector3(b2.x, _h(b2.x, b2.z, origin.y), b2.z))
			im.surface_end()
		_:
			_disc(im, origin, width, Color(fill, fill.a * 0.6), edge, origin.y)


func _disc(im: ImmediateMesh, c: Vector3, r: float, fill: Color, edge: Color, y_ref: float) -> void:
	var seg := 32
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var cy := _h(c.x, c.z, y_ref)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * r
		im.surface_set_color(fill)
		im.surface_add_vertex(Vector3(c.x, cy, c.z))
		im.surface_set_color(Color(fill, fill.a * 1.4))
		im.surface_add_vertex(Vector3(p0.x, _h(p0.x, p0.z, y_ref), p0.z))
		im.surface_set_color(Color(fill, fill.a * 1.4))
		im.surface_add_vertex(Vector3(p1.x, _h(p1.x, p1.z, y_ref), p1.z))
	im.surface_end()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * r
		im.surface_set_color(edge)
		im.surface_add_vertex(Vector3(p0.x, _h(p0.x, p0.z, y_ref), p0.z))
		im.surface_set_color(edge)
		im.surface_add_vertex(Vector3(p1.x, _h(p1.x, p1.z, y_ref), p1.z))
	im.surface_end()


func _outline_line(im: ImmediateMesh, o: Vector3, f: Vector3, side: Vector3, length: float, edge: Color) -> void:
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var steps := maxi(2, int(length / 0.5))
	for s: float in [-1.0, 1.0]:
		for i in steps:
			var a := o + f * (length * i / steps) + side * s
			var b := o + f * (length * (i + 1) / steps) + side * s
			im.surface_set_color(edge)
			im.surface_add_vertex(Vector3(a.x, _h(a.x, a.z, o.y), a.z))
			im.surface_set_color(edge)
			im.surface_add_vertex(Vector3(b.x, _h(b.x, b.z, o.y), b.z))
	var e0 := o + f * length - side
	var e1 := o + f * length + side
	im.surface_set_color(edge)
	im.surface_add_vertex(Vector3(e0.x, _h(e0.x, e0.z, o.y), e0.z))
	im.surface_set_color(edge)
	im.surface_add_vertex(Vector3(e1.x, _h(e1.x, e1.z, o.y), e1.z))
	im.surface_end()
