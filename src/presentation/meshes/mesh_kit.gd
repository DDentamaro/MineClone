class_name MeshKit
extends RefCounted
## Primitive convesse a facce piatte per personaggi, armi e manichini (M4):
## scatole smussate, rastremate, prismi e lame. Ogni pezzo e' convesso: le
## facce sono orientate verso l'esterno rispetto al suo baricentro, in senso
## orario visto da fuori (fronte di Godot). Colori nei vertici, in spazio
## "display" come le palette dei blocchi.

var st := SurfaceTool.new()
var _has := false


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Poligono convesso (ventaglio) orientato lontano da `inside`.
func poly(pts: Array, color: Color, inside: Vector3) -> void:
	if pts.size() < 3:
		return
	var p0: Vector3 = pts[0]
	var n := Vector3.ZERO
	for i in range(1, pts.size() - 1):
		n += (pts[i] - p0).cross(pts[i + 1] - p0)
	if n.length_squared() < 1e-14:
		return
	var c := Vector3.ZERO
	for p: Vector3 in pts:
		c += p
	c /= pts.size()
	var outward := n.dot(c - inside) > 0.0
	n = n.normalized() if outward else -n.normalized()
	for i in range(1, pts.size() - 1):
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[i]
		var d: Vector3 = pts[i + 1]
		# Fronte in senso orario: il prodotto vettoriale punta verso l'interno.
		if outward:
			var t := b
			b = d
			d = t
		for v in [a, b, d]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)
	_has = true


## Scatola smussata: semiassi `h`, smusso `bevel`, rastremazione del fondo
## (`taper` scala x/z della faccia inferiore), trasformata da `xf`.
func box(center: Vector3, size: Vector3, color: Color, bevel: float = 0.02, taper: float = 1.0, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	var map := func(p: Vector3) -> Vector3:
		var k := lerpf(taper, 1.0, (p.y + h.y) / (2.0 * h.y))
		return xf * (center + Vector3(p.x * k, p.y, p.z * k))
	var inside: Vector3 = xf * center
	var col := func(p: Vector3, n: Vector3) -> Color:
		# Leggera occlusione verso il basso: le facce inferiori piu' scure.
		return color.darkened(0.10) if n.y < -0.5 else color
	# Facce.
	for ax in 3:
		for s in [-1.0, 1.0]:
			var u := (ax + 1) % 3
			var v := (ax + 2) % 3
			var pts: Array[Vector3] = []
			for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var p := Vector3.ZERO
				p[ax] = s * h[ax]
				p[u] = c[0] * (h[u] - b)
				p[v] = c[1] * (h[v] - b)
				pts.append(map.call(p))
			var nn := Vector3.ZERO
			nn[ax] = s
			poly(pts, col.call(Vector3.ZERO, nn), inside)
	if b <= 0.0:
		return
	# Spigoli smussati.
	for ax in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		for su in [-1.0, 1.0]:
			for sv in [-1.0, 1.0]:
				var pts: Array[Vector3] = []
				for sa in [-1.0, 1.0]:
					var p := Vector3.ZERO
					p[ax] = sa * (h[ax] - b)
					p[u] = su * h[u]
					p[v] = sv * (h[v] - b)
					var q := p
					q[u] = su * (h[u] - b)
					q[v] = sv * h[v]
					if sa < 0.0:
						pts.append(map.call(p))
						pts.append(map.call(q))
					else:
						pts.append(map.call(q))
						pts.append(map.call(p))
				var nn := Vector3.ZERO
				nn[u] = su
				nn[v] = sv
				poly(pts, col.call(Vector3.ZERO, nn), inside)
	# Angoli.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var pts: Array[Vector3] = [
					map.call(Vector3(sx * h.x, sy * (h.y - b), sz * (h.z - b))),
					map.call(Vector3(sx * (h.x - b), sy * h.y, sz * (h.z - b))),
					map.call(Vector3(sx * (h.x - b), sy * (h.y - b), sz * h.z))]
				poly(pts, col.call(Vector3.ZERO, Vector3(0, sy, 0)), inside)


## Prisma lungo Y da `y0` a `y1` con sezione regolare di `sides` lati;
## `r1` raggio in cima (cono tronco), `twist` ruota la sezione.
func prism(base: Vector3, y0: float, y1: float, r0: float, r1: float, sides: int, color: Color, xf: Transform3D = Transform3D.IDENTITY, twist: float = 0.0) -> void:
	var inside: Vector3 = xf * (base + Vector3(0, (y0 + y1) * 0.5, 0))
	var bot: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in sides:
		var a := TAU * (i + 0.5) / sides + twist
		bot.append(xf * (base + Vector3(cos(a) * r0, y0, sin(a) * r0)))
		top.append(xf * (base + Vector3(cos(a) * r1, y1, sin(a) * r1)))
	for i in sides:
		var j := (i + 1) % sides
		poly([bot[i], bot[j], top[j], top[i]], color, inside)
	poly(bot, color.darkened(0.12), inside)
	if r1 > 0.0005:
		poly(top, color, inside)


## Lama piatta lungo +Y: sezione a rombo (larghezza `w`, spessore `t`), da
## `y0` a `y1`, poi punta fino a `y1 + tip` (con `tip_w` larghezza residua).
func blade(y0: float, y1: float, w: float, t: float, tip: float, color: Color, edge: Color, xf: Transform3D = Transform3D.IDENTITY, w_top: float = -1.0) -> void:
	if w_top < 0.0:
		w_top = w
	var inside: Vector3 = xf * Vector3(0, (y0 + y1) * 0.5, 0)
	var sec := func(y: float, ww: float, tt: float) -> Array:
		return [xf * Vector3(ww * 0.5, y, 0), xf * Vector3(0, y, tt * 0.5), xf * Vector3(-ww * 0.5, y, 0), xf * Vector3(0, y, -tt * 0.5)]
	var a: Array = sec.call(y0, w, t)
	var b: Array = sec.call(y1, w_top, t)
	var p := xf * Vector3(0, y1 + tip, 0)
	for i in 4:
		var j := (i + 1) % 4
		# Le facce vicine al filo (vertici 0 e 2) sono piu' chiare.
		var c := edge if (i == 0 or i == 2) else color
		poly([a[i], a[j], b[j], b[i]], c, inside)
		poly([b[i], b[j], p], edge, inside)
	poly(a, color.darkened(0.2), inside)


## Rotazione attorno a un asse passante per `pivot` (per pezzi inclinati).
static func rot_about(axis: Vector3, angle: float, pivot: Vector3) -> Transform3D:
	var b := Basis(axis.normalized(), angle)
	return Transform3D(b, pivot - b * pivot)


func commit() -> ArrayMesh:
	if not _has:
		return null
	return st.commit()
