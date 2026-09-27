class_name FluidMesher
extends RefCounted
## Mesh dell'acqua per tile 16x16: porting di ISO_CORE.meshFluid (core.js 600).
## Superficie sugli angoli condivisi (fluidCorner, la stessa di sampleWater),
## lati verso l'aria, fondo sopra il vuoto, piedi delle cascate. Attributi come
## il prototipo: aW = (profondita', riva o quota relativa, tipo 0/1/2), aFlow =
## (corrente x, corrente z, corpo d'acqua). Identica al prototipo per hash.

## [dx, dz, angolo a, angolo b] delle facce laterali.
const FACES: Array[Array] = [[1, 0, 1, 2], [0, 1, 2, 3], [-1, 0, 3, 0], [0, -1, 0, 1]]


class MeshData:
	extends RefCounted
	var tile: Vector2i
	var version := 0
	var session := 0
	var positions := PackedFloat32Array()
	var normals := PackedFloat32Array()
	var data := PackedFloat32Array()
	var flow := PackedFloat32Array()
	var indices := PackedInt32Array()
	## Piedi delle cascate: [x, y, z, altezza, corpo] per cascata.
	var falls := PackedFloat64Array()
	var top_faces := 0
	var side_faces := 0
	var bottom_faces := 0

	func quads() -> int:
		return indices.size() / 6


static func _quad(m: MeshData, pts: Array[PackedFloat64Array], n: PackedFloat64Array, attrs: Array[PackedFloat64Array], fl: PackedFloat64Array) -> void:
	var b := m.positions.size() / 3
	for k in 4:
		var p: PackedFloat64Array = pts[k]
		var a: PackedFloat64Array = attrs[k]
		m.positions.append_array(PackedFloat32Array([p[0], p[1], p[2]]))
		m.normals.append_array(PackedFloat32Array([n[0], n[1], n[2]]))
		m.data.append_array(PackedFloat32Array([a[0], a[1], a[2]]))
		m.flow.append_array(PackedFloat32Array([fl[0], fl[1], fl[2]]))
	m.indices.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))


static func build(w: WorldData, cx: int, cz: int) -> MeshData:
	return _build(w, Vector2i(cx, cz), cx * 16, cz * 16, mini(w.size_x, cx * 16 + 16), mini(w.size_z, cz * 16 + 16), Vector3.ZERO)


## Finestra della tile con una cella di bordo: blocchi, fluidi, corpi e guide.
## Le celle di bordo fuori dal mondo diventano roccia senza acqua, cosi' la
## mesh della finestra e' identica a quella calcolata sul mondo intero.
## Costa poco (copie di righe) e si passa ai thread di lavoro.
static func window(w: WorldData, cx: int, cz: int) -> WorldData:
	var n := 18
	var win := WorldData.new(n, w.size_y, n)
	var x0 := cx * 16 - 1
	var z0 := cz * 16 - 1
	var sx := w.size_x
	var sz := w.size_z
	var rock := PackedByteArray()
	rock.resize(n)
	rock.fill(BlockCatalog.BEDROCK)
	var zeros := PackedByteArray()
	zeros.resize(n)
	win.blocks = PackedByteArray()
	win.fluid = PackedByteArray()
	var xa := maxi(x0, 0)
	var xb := mini(x0 + n, sx)
	for y in w.size_y:
		for zz in n:
			var z := z0 + zz
			if z < 0 or z >= sz:
				win.blocks.append_array(rock)
				win.fluid.append_array(zeros)
				continue
			var i := (y * sz + z) * sx
			var pre := xa - x0
			var post := x0 + n - xb
			if pre > 0:
				win.blocks.append_array(rock.slice(0, pre))
				win.fluid.append_array(zeros.slice(0, pre))
			win.blocks.append_array(w.blocks.slice(i + xa, i + xb))
			win.fluid.append_array(w.fluid.slice(i + xa, i + xb))
			if post > 0:
				win.blocks.append_array(rock.slice(0, post))
				win.fluid.append_array(zeros.slice(0, post))
	win.water_bodies = PackedInt32Array()
	win.water_bodies.resize(n * n)
	win.water_guide = PackedByteArray()
	win.water_guide.resize(n * n * 2)
	for zz in n:
		for xx in n:
			var x := x0 + xx
			var z := z0 + zz
			if x < 0 or z < 0 or x >= sx or z >= sz:
				continue
			var c := z * sx + x
			if not w.water_bodies.is_empty():
				win.water_bodies[zz * n + xx] = w.water_bodies[c]
			if not w.water_guide.is_empty():
				win.water_guide[(zz * n + xx) * 2] = w.water_guide[c * 2]
				win.water_guide[(zz * n + xx) * 2 + 1] = w.water_guide[c * 2 + 1]
	# Dati per ritrovare la tile.
	win.world_seed = cx * 1000 + cz
	return win


## Mesh della tile (cx, cz) calcolata su una finestra (window()).
static func build_window(win: WorldData, cx: int, cz: int, world_x: int, world_z: int) -> MeshData:
	var x1 := 1 + mini(16, world_x - cx * 16)
	var z1 := 1 + mini(16, world_z - cz * 16)
	return _build(win, Vector2i(cx, cz), 1, 1, x1, z1, Vector3(cx * 16 - 1, 0, cz * 16 - 1))


static func _build(w: WorldData, tile: Vector2i, x0: int, z0: int, x1: int, z1: int, offset: Vector3) -> MeshData:
	var m := MeshData.new()
	m.tile = tile
	if w.fluid.is_empty():
		return m
	var sx := w.size_x
	var sy := w.size_y
	for z in range(z0, z1):
		for x in range(x0, x1):
			for y in sy:
				var f := FluidSystem.fluid_at(w, x, y, z)
				if f == 0:
					continue
				var above := FluidSystem.fluid_at(w, x, y + 1, z)
				var below := FluidSystem.fluid_at(w, x, y - 1, z)
				var lo := y
				var hi := y
				while lo > 0 and FluidSystem.fluid_at(w, x, lo - 1, z) != 0:
					lo -= 1
				while hi < sy - 1 and FluidSystem.fluid_at(w, x, hi + 1, z) != 0:
					hi += 1
				var impact := lo
				if f & FluidSystem.FALLING:
					var iy := y
					while iy > 0 and (FluidSystem.fluid_at(w, x, iy - 1, z) & FluidSystem.FALLING) != 0:
						iy -= 1
					impact = iy if FluidSystem.fluid_at(w, x, iy - 1, z) != 0 else lo
				var base := float(impact)
				var top := FluidSystem.fluid_surface(w, x + 0.5, hi, z + 0.5)
				var depth := top - base
				var v := FluidSystem.fluid_velocity(w, x, y, z)
				var body := 1
				if not w.water_bodies.is_empty():
					body = w.water_bodies[z * sx + x]
					if body == 0:
						body = 1
				var fl := PackedFloat64Array([v[0], v[2], body])
				var pts: Array[PackedFloat64Array] = [
					PackedFloat64Array([x, y + FluidSystem.fluid_corner(w, x, y, z), z]),
					PackedFloat64Array([x + 1, y + FluidSystem.fluid_corner(w, x + 1, y, z), z]),
					PackedFloat64Array([x + 1, y + FluidSystem.fluid_corner(w, x + 1, y, z + 1), z + 1]),
					PackedFloat64Array([x, y + FluidSystem.fluid_corner(w, x, y, z + 1), z + 1]),
				]
				if above == 0 and FluidSystem.fluid_pass(w, x, y + 1, z):
					var shore := 2.5
					for d in 4:
						var nx: int = x + FluidSystem.DIR_X[d]
						var nz: int = z + FluidSystem.DIR_Z[d]
						if FluidSystem.fluid_at(w, nx, y, nz) == 0 and not FluidSystem.fluid_pass(w, nx, y, nz):
							shore = 0.26
							break
					var ux := pts[1][1] - pts[0][1]
					var uz := pts[3][1] - pts[0][1]
					var ln := JsMath.js_hypot3(ux, 1.0, uz)
					var at := PackedFloat64Array([depth, shore, 0])
					_quad(m, pts, PackedFloat64Array([-ux / ln, 1.0 / ln, -uz / ln]), [at, at, at, at], fl)
					m.top_faces += 1
				for fc: Array in FACES:
					var dx: int = fc[0]
					var dz: int = fc[1]
					if FluidSystem.fluid_at(w, x + dx, y, z + dz) != 0 or not FluidSystem.fluid_pass(w, x + dx, y, z + dz):
						continue
					var pa: PackedFloat64Array = pts[int(fc[2])]
					var pb: PackedFloat64Array = pts[int(fc[3])]
					var p: Array[PackedFloat64Array] = [pa, pb, PackedFloat64Array([pb[0], y, pb[2]]), PackedFloat64Array([pa[0], y, pa[2]])]
					var typ := 1.0 if (f & FluidSystem.FALLING) else 2.0
					var attrs: Array[PackedFloat64Array] = []
					for q in p:
						attrs.append(PackedFloat64Array([depth, q[1] - base, typ]))
					_quad(m, p, PackedFloat64Array([dx, 0, dz]), attrs, fl)
					m.side_faces += 1
				if below == 0 and FluidSystem.fluid_pass(w, x, y - 1, z):
					var bp: Array[PackedFloat64Array] = [PackedFloat64Array([x, y, z + 1]), PackedFloat64Array([x + 1, y, z + 1]),
						PackedFloat64Array([x + 1, y, z]), PackedFloat64Array([x, y, z])]
					var ab := PackedFloat64Array([depth, 1, 2])
					_quad(m, bp, PackedFloat64Array([0, -1, 0]), [ab, ab, ab, ab], fl)
					m.bottom_faces += 1
				if (f & FluidSystem.FALLING) and not (below & FluidSystem.FALLING) and (below != 0 or not FluidSystem.fluid_pass(w, x, y - 1, z)):
					m.falls.append_array(PackedFloat64Array([x + 0.5, (y - 0.12) if below != 0 else (y + 0.02), z + 0.5, depth, body]))
	if offset != Vector3.ZERO:
		for i in range(0, m.positions.size(), 3):
			m.positions[i] += offset.x
			m.positions[i + 2] += offset.z
		for i in range(0, m.falls.size(), 5):
			m.falls[i] += offset.x
			m.falls[i + 2] += offset.z
	return m


## ArrayMesh per Godot: CUSTOM0 = aW, CUSTOM1 = aFlow (float RGBA, w = 0).
static func to_array_mesh(m: MeshData, mat: Material) -> ArrayMesh:
	var n := m.positions.size() / 3
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	verts.resize(n)
	norms.resize(n)
	c0.resize(n * 4)
	c1.resize(n * 4)
	for i in n:
		verts[i] = Vector3(m.positions[i * 3], m.positions[i * 3 + 1], m.positions[i * 3 + 2])
		norms[i] = Vector3(m.normals[i * 3], m.normals[i * 3 + 1], m.normals[i * 3 + 2])
		for k in 3:
			c0[i * 4 + k] = m.data[i * 3 + k]
			c1[i * 4 + k] = m.flow[i * 3 + k]
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_CUSTOM0] = c0
	a[Mesh.ARRAY_CUSTOM1] = c1
	a[Mesh.ARRAY_INDEX] = m.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	mesh.surface_set_material(0, mat)
	return mesh
