class_name ChunkMesher
extends RefCounted
## Mesher a facce visibili per un chunk 16^3 (M1). Funzione pura: legge solo gli
## array passati, quindi gira su thread di lavoro purche' riceva uno snapshot
## immutabile dei blocchi (WorldRuntime passa una copia `duplicate()`, perche' i
## Packed*Array sono condivisi per riferimento). Greedy meshing e AO: M2.
##
## Superfici prodotte: opachi (colore per vertice) e acqua (trasparente).
## Posizioni locali all'origine del chunk.

const CS := WorldData.CHUNK_SIZE

## Facce: 0 +X, 1 -X, 2 +Y, 3 -Y, 4 +Z, 5 -Z.
const NORMALS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Angoli delle facce del cubo unitario, in ordine orario visto dall'esterno
## (winding frontale di Godot). Verificato da test_chunk_mesher.gd.
static var FACE_CORNERS: Array[PackedVector3Array] = _build_face_corners()


class MeshData:
	extends RefCounted
	var chunk: Vector3i
	var version: int = 0
	var session: int = 0
	var opaque_vertices := PackedVector3Array()
	var opaque_normals := PackedVector3Array()
	var opaque_colors := PackedColorArray()
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


## Tabelle per ID, precalcolate dal catalogo sul main thread.
class Palette:
	extends RefCounted
	var opaque := PackedByteArray()
	var top := PackedColorArray()
	var side := PackedColorArray()

	static func from_catalog(cat: BlockCatalog) -> Palette:
		var p := Palette.new()
		p.opaque = cat.opaque_table().duplicate()
		p.top.resize(cat.count())
		p.side.resize(cat.count())
		for i in cat.count():
			var def := cat.get_def(i)
			p.top[i] = def.top_color
			p.side[i] = def.side_color
		return p


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
		# Godot considera frontali i triangoli in senso orario visti dalla camera:
		# (b-a)x(c-a) deve puntare in verso opposto alla normale.
		var n := Vector3(NORMALS[f])
		if (c[1] - c[0]).cross(c[2] - c[0]).dot(n) > 0.0:
			c.reverse()
		out.append(c)
	return out


## Costruisce la mesh del chunk `chunk` da uno snapshot dei blocchi.
static func build(blocks: PackedByteArray, sx: int, sy: int, sz: int, chunk: Vector3i, pal: Palette) -> MeshData:
	var out := MeshData.new()
	out.chunk = chunk
	var x0 := chunk.x * CS
	var y0 := chunk.y * CS
	var z0 := chunk.z * CS
	var x1 := mini(x0 + CS, sx)
	var y1 := mini(y0 + CS, sy)
	var z1 := mini(z0 + CS, sz)
	var layer := sx * sz
	var opaque := pal.opaque
	var nb := PackedInt32Array()
	nb.resize(6)
	for y in range(y0, y1):
		for z in range(z0, z1):
			var i := (y * sz + z) * sx + x0
			for x in range(x0, x1):
				var id := blocks[i]
				if id == 0:
					i += 1
					continue
				# Vicini fuori dal mondo: aria ai lati e sopra, solido sotto.
				nb[0] = blocks[i + 1] if x + 1 < sx else 0
				nb[1] = blocks[i - 1] if x > 0 else 0
				nb[2] = blocks[i + layer] if y + 1 < sy else 0
				nb[3] = blocks[i - layer] if y > 0 else BlockCatalog.BEDROCK
				nb[4] = blocks[i + sx] if z + 1 < sz else 0
				nb[5] = blocks[i - sx] if z > 0 else 0
				var local := Vector3(x - x0, y - y0, z - z0)
				if id == BlockCatalog.WATER:
					for f in 6:
						var n := nb[f]
						if n != BlockCatalog.WATER and opaque[n] == 0:
							_add_quad(out.water_vertices, out.water_normals, out.opaque_colors, out.water_indices, local, f, Color.WHITE, false)
				elif id == BlockCatalog.TORCH:
					_add_torch(out, local, pal.top[id])
				elif opaque[id] == 1:
					for f in 6:
						if opaque[nb[f]] == 0:
							var col := pal.top[id] if f == 2 else pal.side[id]
							_add_quad(out.opaque_vertices, out.opaque_normals, out.opaque_colors, out.opaque_indices, local, f, col, true)
				i += 1
	return out


## I Packed*Array sono passati per riferimento: gli append modificano l'originale.
static func _add_quad(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array,
		origin: Vector3, face: int, color: Color, with_color: bool) -> void:
	var base := verts.size()
	var n := Vector3(NORMALS[face])
	for c in FACE_CORNERS[face]:
		verts.append(origin + c)
		norms.append(n)
		if with_color:
			cols.append(color)
	idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


static func _add_torch(out: MeshData, origin: Vector3, color: Color) -> void:
	# Paletto 0,2 x 0,6 centrato nella cella (il prototipo usa 5 quad; qui 6).
	var scale := Vector3(0.2, 0.6, 0.2)
	var offset := Vector3(0.4, 0.0, 0.4)
	for f in 6:
		var col := Color(1.0, 0.85, 0.4) if f == 2 else color
		var base := out.opaque_vertices.size()
		for c in FACE_CORNERS[f]:
			out.opaque_vertices.append(origin + offset + c * scale)
			out.opaque_normals.append(Vector3(NORMALS[f]))
			out.opaque_colors.append(col)
		out.opaque_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## Converte i dati in ArrayMesh (main thread). Superficie 0 = opachi, 1 = acqua.
static func to_array_mesh(data: MeshData, opaque_mat: Material, water_mat: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not data.opaque_indices.is_empty():
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = data.opaque_vertices
		a[Mesh.ARRAY_NORMAL] = data.opaque_normals
		a[Mesh.ARRAY_COLOR] = data.opaque_colors
		a[Mesh.ARRAY_INDEX] = data.opaque_indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
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
