class_name ChunkMesher
extends RefCounted
## Mesher di un chunk 16^3: porting di ISO_CORE.meshChunk (HTML ~4638) con
## greedy meshing, AO negli angoli, luce della cella d'aria davanti alla faccia e
## torce come piccoli box. Stessi vertici, dati e indici del prototipo (verificati
## per hash su tutti i 432 chunk della fixture); il winding viene reso orario
## (frontale per Godot) solo in to_array_mesh().
##
## Funzione pura: legge solo gli array passati, quindi gira sui thread di lavoro
## purche' riceva snapshot immutabili (WorldRuntime passa copie `duplicate()`).
## L'acqua usa ancora le facce semplici di M1 (la mesh dei fluidi arriva con M3).

const CS := WorldData.CHUNK_SIZE
## Lato del volume imbottito (chunk + 1 cella per parte).
const P := CS + 2
const PAD_Y := P * P
const PAD_Z := P
## Passo nel volume imbottito lungo x, y, z.
const STRIDE: Array[int] = [1, PAD_Y, PAD_Z]

## Facce: 0 +X, 1 -X, 2 +Y, 3 -Y, 4 +Z, 5 -Z.
const NORMALS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Angoli per le facce semplici dell'acqua, in ordine orario visto dall'esterno.
static var FACE_CORNERS: Array[PackedVector3Array] = _build_face_corners()


class MeshData:
	extends RefCounted
	var chunk: Vector3i
	var version: int = 0
	var session: int = 0
	## Coordinate di mondo, come il prototipo.
	var opaque_vertices := PackedVector3Array()
	var opaque_uvs := PackedVector2Array()
	## 4 byte per vertice: tile, faccia | cut<<3 | ao<<4, sole, luce blocchi.
	var opaque_data := PackedByteArray()
	## Indici nel winding del prototipo (antiorario).
	var opaque_indices := PackedInt32Array()
	var water_vertices := PackedVector3Array()
	var water_normals := PackedVector3Array()
	var water_indices := PackedInt32Array()

	func opaque_quads() -> int:
		return opaque_indices.size() / 6

	func water_quads() -> int:
		return water_indices.size() / 6

	func is_empty() -> bool:
		return opaque_indices.is_empty() and water_indices.is_empty()


## Tabelle per ID precalcolate sul main thread.
class Palette:
	extends RefCounted
	var opaque := PackedByteArray()

	static func from_catalog(cat: BlockCatalog) -> Palette:
		var p := Palette.new()
		p.opaque = cat.opaque_table().duplicate()
		return p


class Snapshot:
	extends RefCounted
	var blocks := PackedByteArray()
	var sun := PackedByteArray()
	var blk := PackedByteArray()
	var sx: int
	var sy: int
	var sz: int

	static func of(w: WorldData) -> Snapshot:
		var s := Snapshot.new()
		s.blocks = w.blocks.duplicate()
		s.sun = w.sun.duplicate()
		s.blk = w.blk.duplicate()
		s.sx = w.size_x
		s.sy = w.size_y
		s.sz = w.size_z
		return s


static func _build_face_corners() -> Array[PackedVector3Array]:
	var raw: Array = [
		[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
		[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
		[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	]
	var out: Array[PackedVector3Array] = []
	for f in 6:
		var c := PackedVector3Array(raw[f])
		var n := Vector3(NORMALS[f])
		if (c[1] - c[0]).cross(c[2] - c[0]).dot(n) > 0.0:
			c.reverse()
		out.append(c)
	return out


## `slice`: i blocchi con y > slice sono ignorati (sezione del prototipo).
static func build(s: Snapshot, chunk: Vector3i, pal: Palette, slice: int = -1) -> MeshData:
	var out := MeshData.new()
	out.chunk = chunk
	var sx := s.sx
	var sy := s.sy
	var sz := s.sz
	if slice < 0:
		slice = sy - 1
	var org := [chunk.x * CS, chunk.y * CS, chunk.z * CS]
	var x1 := mini(org[0] + CS, sx)
	var y1 := mini(mini(org[1] + CS, sy), slice + 1)
	var z1 := mini(org[2] + CS, sz)
	if y1 <= org[1]:
		return out
	var dims := [x1 - org[0], y1 - org[1], z1 - org[2]]
	var opaque := pal.opaque
	var bl := s.blocks

	# Volumi imbottiti: vis (opaco e sotto la sezione), id, sole e luce blocchi
	# della cella, con le regole di bordo di vis/blockAt/lightAt del prototipo.
	var pv := PackedByteArray()
	var pb := PackedByteArray()
	var ps := PackedByteArray()
	var pl := PackedByteArray()
	pv.resize(P * P * P)
	pb.resize(P * P * P)
	ps.resize(P * P * P)
	pl.resize(P * P * P)
	for ly in range(-1, CS + 1):
		var y: int = org[1] + ly
		for lz in range(-1, CS + 1):
			var z: int = org[2] + lz
			var pi := (ly + 1) * PAD_Y + (lz + 1) * PAD_Z
			for lx in range(-1, CS + 1):
				var x: int = org[0] + lx
				var k := pi + lx + 1
				var inside := x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz
				var i := (y * sz + z) * sx + x
				if inside:
					pb[k] = bl[i]
				# lightAt: sopra la sezione (o il mondo) = cielo, fuori dal mondo = buio.
				if y > slice:
					ps[k] = 15
				elif inside:
					pv[k] = opaque[bl[i]]
					ps[k] = s.sun[i]
					pl[k] = s.blk[i]

	var verts := out.opaque_vertices
	var uvs := out.opaque_uvs
	var dat := out.opaque_data
	var idx := out.opaque_indices
	var nv := 0
	var mask := PackedInt32Array()
	mask.resize(CS * CS)
	var p0 := PAD_Y + PAD_Z + 1
	for d in 3:
		var u := (d + 1) % 3
		var v := (d + 2) % 3
		var sd: int = STRIDE[d]
		var su: int = STRIDE[u]
		var sv: int = STRIDE[v]
		var du_: int = dims[u]
		var dv_: int = dims[v]
		var dd_: int = dims[d]
		var xd := -1
		while xd < dd_:
			var n := 0
			for xv in dv_:
				for xu in du_:
					var pa := p0 + xd * sd + xv * sv + xu * su
					var a := pv[pa]
					var b := pv[pa + sd]
					var key := 0
					if a == 1 and b == 0 and xd >= 0:
						var tile := pb[pa]
						var cut := 0
						if d == 1 and org[1] + xd == slice and org[1] + xd + 1 < sy and opaque[pb[pa + sd]] == 1:
							cut = 1
						var sl := 15 if cut == 1 else ps[pa + sd]
						var ll := 0 if cut == 1 else pl[pa + sd]
						var ao := 255 if cut == 1 else _ao_face(pv, pa + sd, su, sv)
						key = 1 | (tile << 1) | (sl << 6) | (ll << 10) | (cut << 14) | (1 << 15) | (ao << 16)
					elif b == 1 and a == 0 and xd < dd_ - 1:
						var tile2 := pb[pa + sd]
						key = 1 | (tile2 << 1) | (ps[pa] << 6) | (pl[pa] << 10) | (_ao_face(pv, pa, su, sv) << 16)
					mask[n] = key
					n += 1
			xd += 1
			n = 0
			for j in dv_:
				var i := 0
				while i < du_:
					var c := mask[n]
					if c == 0:
						i += 1
						n += 1
						continue
					var w := 1
					while i + w < du_ and mask[n + w] == c:
						w += 1
					var h := 1
					var done := false
					while j + h < dv_:
						for k in w:
							if mask[n + k + h * du_] != c:
								done = true
								break
						if done:
							break
						h += 1
					var front := (c >> 15) & 1
					var tile3 := (c >> 1) & 31
					var s4 := (c >> 6) & 15
					var l4 := (c >> 10) & 15
					var cut2 := (c >> 14) & 1
					var pos := [0, 0, 0]
					pos[d] = org[d] + xd
					pos[u] = org[u] + i
					pos[v] = org[v] + j
					var duv := [0, 0, 0]
					var dvv := [0, 0, 0]
					duv[u] = w
					dvv[v] = h
					var q0 := Vector3(pos[0], pos[1], pos[2])
					var qu := Vector3(duv[0], duv[1], duv[2])
					var qv := Vector3(dvv[0], dvv[1], dvv[2])
					verts.append(q0)
					verts.append(q0 + qu)
					verts.append(q0 + qu + qv)
					verts.append(q0 + qv)
					uvs.append(Vector2(0, 0))
					uvs.append(Vector2(w, 0))
					uvs.append(Vector2(w, h))
					uvs.append(Vector2(0, h))
					var face := d * 2 + (0 if front == 1 else 1)
					var f := face | (cut2 << 3)
					var ao := (c >> 16) & 255
					var a0 := ao & 3
					var a1 := (ao >> 2) & 3
					var a2 := (ao >> 4) & 3
					var a3 := (ao >> 6) & 3
					dat.append_array(PackedByteArray([tile3, f | (a0 << 4), s4, l4, tile3, f | (a1 << 4), s4, l4,
						tile3, f | (a2 << 4), s4, l4, tile3, f | (a3 << 4), s4, l4]))
					var flip := a0 + a2 < a1 + a3
					if front == 1:
						if flip:
							idx.append_array(PackedInt32Array([nv + 1, nv + 2, nv + 3, nv + 1, nv + 3, nv]))
						else:
							idx.append_array(PackedInt32Array([nv, nv + 1, nv + 2, nv, nv + 2, nv + 3]))
					else:
						if flip:
							idx.append_array(PackedInt32Array([nv + 1, nv + 3, nv + 2, nv + 1, nv, nv + 3]))
						else:
							idx.append_array(PackedInt32Array([nv, nv + 2, nv + 1, nv, nv + 3, nv + 2]))
					nv += 4
					for hh in h:
						for ww in w:
							mask[n + ww + hh * du_] = 0
					i += w
					n += w

	# Torce: box auto-illuminato, non greedy (ordine z, y, x come il prototipo).
	for z in range(org[2], z1):
		for y in range(org[1], y1):
			for x in range(org[0], x1):
				if bl[(y * sz + z) * sx + x] != BlockCatalog.TORCH:
					continue
				nv = _add_torch(out, x, y, z, nv)

	# Acqua: facce verso celle non opache e non d'acqua (provvisorio fino a M3).
	for y in range(org[1], y1):
		for z in range(org[2], z1):
			for x in range(org[0], x1):
				var i := (y * sz + z) * sx + x
				if bl[i] != BlockCatalog.WATER:
					continue
				for fi in 6:
					var nn: Vector3i = NORMALS[fi]
					var nx := x + nn.x
					var ny := y + nn.y
					var nz := z + nn.z
					var nb := 0
					if ny < 0:
						nb = BlockCatalog.BEDROCK
					elif nx >= 0 and nz >= 0 and nx < sx and ny < sy and nz < sz:
						nb = bl[(ny * sz + nz) * sx + nx]
					if nb == BlockCatalog.WATER or opaque[nb] == 1:
						continue
					var base := out.water_vertices.size()
					var o := Vector3(x, y, z)
					for corner in FACE_CORNERS[fi]:
						out.water_vertices.append(o + corner)
						out.water_normals.append(Vector3(nn))
					out.water_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	return out


static func _ao_face(pv: PackedByteArray, pc: int, su: int, sv: int) -> int:
	var r := 0
	# Angoli (-1,-1), (1,-1), (1,1), (-1,1) nel piano (u, v).
	for c in 4:
		var ku := -1 if (c == 0 or c == 3) else 1
		var kv := -1 if c < 2 else 1
		var s1 := pv[pc + ku * su]
		var s2 := pv[pc + kv * sv]
		var cc := pv[pc + ku * su + kv * sv]
		var val := 0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + cc)
		r |= val << (2 * c)
	return r


static func _add_torch(out: MeshData, x: int, y: int, z: int, nv: int) -> int:
	var s := 0.15
	var cx := x + 0.5
	var cz := z + 0.5
	var yb := float(y)
	var yt := y + 0.55
	var boxes := [
		[Vector3(cx + s, yb, cz - s), Vector3(cx + s, yb, cz + s), Vector3(cx + s, yt, cz + s), Vector3(cx + s, yt, cz - s), 0],
		[Vector3(cx - s, yb, cz + s), Vector3(cx - s, yb, cz - s), Vector3(cx - s, yt, cz - s), Vector3(cx - s, yt, cz + s), 1],
		[Vector3(cx - s, yt, cz - s), Vector3(cx + s, yt, cz - s), Vector3(cx + s, yt, cz + s), Vector3(cx - s, yt, cz + s), 2],
		[Vector3(cx - s, yb, cz + s), Vector3(cx + s, yb, cz + s), Vector3(cx + s, yt, cz + s), Vector3(cx - s, yt, cz + s), 4],
		[Vector3(cx + s, yb, cz - s), Vector3(cx - s, yb, cz - s), Vector3(cx - s, yt, cz - s), Vector3(cx + s, yt, cz - s), 5],
	]
	for f: Array in boxes:
		for k in 4:
			out.opaque_vertices.append(f[k])
		out.opaque_uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0), Vector2(0.3, 0.55), Vector2(0, 0.55)]))
		var fc: int = f[4]
		for k in 4:
			out.opaque_data.append_array(PackedByteArray([BlockCatalog.TORCH, fc, 15, 15]))
		out.opaque_indices.append_array(PackedInt32Array([nv, nv + 1, nv + 2, nv, nv + 2, nv + 3]))
		nv += 4
	return nv


## ArrayMesh per Godot (main thread): superficie 0 = blocchi (dati in CUSTOM0,
## RGBA8 normalizzato), superficie 1 = acqua. Il winding viene invertito.
static func to_array_mesh(data: MeshData, opaque_mat: Material, water_mat: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not data.opaque_indices.is_empty():
		var normals := PackedVector3Array()
		normals.resize(data.opaque_vertices.size())
		for vtx in normals.size():
			normals[vtx] = Vector3(NORMALS[data.opaque_data[vtx * 4 + 1] & 7])
		# Ogni triangolo orario rispetto alla normale della faccia (il prototipo
		# usa materiali double-sided e le torce hanno winding misto).
		var idx := data.opaque_indices.duplicate()
		var vv := data.opaque_vertices
		for t in range(0, idx.size(), 3):
			var a := vv[idx[t]]
			if (vv[idx[t + 1]] - a).cross(vv[idx[t + 2]] - a).dot(normals[idx[t]]) > 0.0:
				var tmp := idx[t + 1]
				idx[t + 1] = idx[t + 2]
				idx[t + 2] = tmp
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = data.opaque_vertices
		a[Mesh.ARRAY_NORMAL] = normals
		a[Mesh.ARRAY_TEX_UV] = data.opaque_uvs
		a[Mesh.ARRAY_CUSTOM0] = data.opaque_data
		a[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {},
			Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(mesh.get_surface_count() - 1, opaque_mat)
	if not data.water_indices.is_empty():
		var w := []
		w.resize(Mesh.ARRAY_MAX)
		w[Mesh.ARRAY_VERTEX] = data.water_vertices
		w[Mesh.ARRAY_NORMAL] = data.water_normals
		w[Mesh.ARRAY_INDEX] = data.water_indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, w)
		mesh.surface_set_material(mesh.get_surface_count() - 1, water_mat)
	return mesh
