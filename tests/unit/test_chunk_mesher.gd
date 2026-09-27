extends TestCase
## Mesher greedy: parita' per hash con meshChunk del prototipo e regole di bordo.

var _cat := BlockCatalog.load_default()
var _pal := ChunkMesher.Palette.from_catalog(_cat)


func _snap(w: WorldData) -> ChunkMesher.Snapshot:
	return ChunkMesher.Snapshot.of(w)


func _lit(w: WorldData) -> WorldData:
	LightEngine.new(w, _cat).compute_all()
	return w


func test_parita_con_il_prototipo_su_tutti_i_chunk() -> void:
	var fx := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, _cat, false)
	var snap := _snap(fx.world)
	var chunks: Array = RenderFixture.manifest()["chunks"]
	var bad := 0
	var quads := 0
	for e: Dictionary in chunks:
		var c: Array = e["c"]
		var d := ChunkMesher.build(snap, Vector3i(int(c[0]), int(c[1]), int(c[2])), _pal)
		quads += d.opaque_quads()
		var ok := d.opaque_quads() == int(e["quads"]) \
			and WorldFixture.sha256_hex(d.opaque_vertices.to_byte_array()) == str(e["pos"]) \
			and WorldFixture.sha256_hex(d.opaque_uvs.to_byte_array()) == str(e["uv"]) \
			and WorldFixture.sha256_hex(d.opaque_data) == str(e["data"]) \
			and WorldFixture.sha256_hex(d.opaque_indices.to_byte_array()) == str(e["index"])
		if not ok:
			bad += 1
			if bad <= 3:
				current_failures.append("chunk %s: quad %d/%d" % [c, d.opaque_quads(), int(e["quads"])])
	check_eq(bad, 0, "chunk diversi dal prototipo")
	check_eq(quads, int(RenderFixture.manifest()["totals"]["quads"]), "quad totali (41172)")


func test_winding_godot_e_normali() -> void:
	var w := _lit(TestWorlds.empty())
	w.blocks[w.index(5, 5, 5)] = BlockCatalog.STONE
	w.blocks[w.index(9, 5, 5)] = BlockCatalog.TORCH
	var d := ChunkMesher.build(_snap(w), Vector3i.ZERO, _pal)
	check_eq(d.opaque_quads(), 6 + 5, "cubo + torcia")
	var mesh := ChunkMesher.to_array_mesh(d, null, null)
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var wrong := 0
	for t in range(0, ix.size(), 3):
		var face_n := (v[ix[t + 1]] - v[ix[t]]).cross(v[ix[t + 2]] - v[ix[t]])
		if face_n.dot(n[ix[t]]) >= 0.0:
			wrong += 1
	check_eq(wrong, 0, "triangoli non orari rispetto alla normale")


func test_bordo_chunk_senza_facce_doppie() -> void:
	var w := _lit(TestWorlds.empty())
	w.blocks[w.index(15, 5, 5)] = BlockCatalog.STONE
	w.blocks[w.index(16, 5, 5)] = BlockCatalog.STONE
	var s := _snap(w)
	check_eq(ChunkMesher.build(s, Vector3i(0, 0, 0), _pal).opaque_quads(), 5, "chunk A")
	check_eq(ChunkMesher.build(s, Vector3i(1, 0, 0), _pal).opaque_quads(), 5, "chunk B")


func test_greedy_unisce_il_pavimento() -> void:
	var w := _lit(TestWorlds.flat(4))
	var d := ChunkMesher.build(_snap(w), Vector3i.ZERO, _pal)
	# Chunk 16x16 pieno fino a y=3: sopra un solo quad; lati sul bordo del mondo
	# (-X, -Z) uno per lato; niente fondo (y=0 poggia sul "solido" sotto il mondo? no:
	# il prototipo disegna la faccia -Y del fondo, visibile solo da sotto).
	var tops := 0
	for q in d.opaque_quads():
		if d.opaque_data[q * 16 + 1] & 7 == 2:
			tops += 1
	check_eq(tops, 1, "una sola faccia superiore")


func test_acqua_superficie_separata() -> void:
	var w := _lit(TestWorlds.flat(4))
	w.blocks[w.index(5, 4, 5)] = BlockCatalog.WATER
	w.blocks[w.index(6, 4, 5)] = BlockCatalog.WATER
	var d := ChunkMesher.build(_snap(w), Vector3i.ZERO, _pal)
	check_eq(d.water_quads(), 8, "quad acqua")
