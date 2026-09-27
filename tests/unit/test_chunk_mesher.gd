extends TestCase

var _pal := ChunkMesher.Palette.from_catalog(BlockCatalog.load_default())


func _mesh(w: WorldData, c: Vector3i) -> ChunkMesher.MeshData:
	return ChunkMesher.build(w.blocks, w.size_x, w.size_y, w.size_z, c, _pal)


func test_winding_orario_verso_la_normale() -> void:
	for f in 6:
		var c := ChunkMesher.FACE_CORNERS[f]
		var n := Vector3(ChunkMesher.NORMALS[f])
		check((c[1] - c[0]).cross(c[2] - c[0]).dot(n) < 0.0, "faccia %d: winding frontale Godot (orario)" % f)
		for v in c:
			# Ogni angolo giace sul piano della faccia.
			var on_plane := v.dot(n) == (1.0 if n.x + n.y + n.z > 0 else 0.0)
			check(on_plane, "faccia %d: angolo %s sul piano" % [f, v])


func test_blocco_isolato_sei_facce() -> void:
	var w := TestWorlds.empty()
	w.blocks[w.index(5, 5, 5)] = BlockCatalog.STONE
	var d := _mesh(w, Vector3i(0, 0, 0))
	check_eq(d.opaque_quads(), 6, "quad")
	check_eq(d.opaque_vertices.size(), 24, "vertici")


func test_facce_interne_nascoste() -> void:
	var w := TestWorlds.empty()
	w.blocks[w.index(5, 5, 5)] = BlockCatalog.STONE
	w.blocks[w.index(6, 5, 5)] = BlockCatalog.DIRT
	check_eq(_mesh(w, Vector3i.ZERO).opaque_quads(), 10, "due blocchi adiacenti")


func test_bordo_chunk_senza_facce_doppie() -> void:
	var w := TestWorlds.empty()
	w.blocks[w.index(15, 5, 5)] = BlockCatalog.STONE
	w.blocks[w.index(16, 5, 5)] = BlockCatalog.STONE
	check_eq(_mesh(w, Vector3i(0, 0, 0)).opaque_quads(), 5, "chunk A")
	check_eq(_mesh(w, Vector3i(1, 0, 0)).opaque_quads(), 5, "chunk B")


func test_fondo_del_mondo_nascosto_bordi_visibili() -> void:
	var w := TestWorlds.empty()
	w.blocks[w.index(0, 0, 0)] = BlockCatalog.STONE
	# Sotto y=0 e' solido: niente faccia inferiore; i lati sul bordo del mondo si vedono.
	check_eq(_mesh(w, Vector3i.ZERO).opaque_quads(), 5, "blocco nell'angolo del mondo")


func test_acqua_superficie_separata() -> void:
	var w := TestWorlds.flat(4)
	w.blocks[w.index(5, 4, 5)] = BlockCatalog.WATER
	w.blocks[w.index(6, 4, 5)] = BlockCatalog.WATER
	var d := _mesh(w, Vector3i.ZERO)
	# 2 celle d'acqua: sopra 2, lati esterni 6, nessuna faccia verso l'acqua o la pietra.
	check_eq(d.water_quads(), 8, "quad acqua")


func test_colori_erba() -> void:
	var w := TestWorlds.empty()
	w.blocks[w.index(5, 5, 5)] = BlockCatalog.GRASS
	var d := _mesh(w, Vector3i.ZERO)
	var cat := BlockCatalog.load_default()
	var top := 0
	for i in d.opaque_normals.size():
		if d.opaque_normals[i] == Vector3.UP:
			top += 1
			check_eq(d.opaque_colors[i], cat.get_def(BlockCatalog.GRASS).top_color, "colore sopra")
		else:
			check_eq(d.opaque_colors[i], cat.get_def(BlockCatalog.GRASS).side_color, "colore lati")
	check_eq(top, 4, "vertici della faccia superiore")


## Il chunk (6,1,6) della fixture, contato con un percorso indipendente.
func test_fixture_chunk_contro_conteggio_diretto() -> void:
	var cat := BlockCatalog.load_default()
	var fx := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, cat, false)
	var w := fx.world
	var c := Vector3i(6, 1, 6)
	var expected := 0
	var dirs: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
	for y in range(16, 32):
		for z in range(96, 112):
			for x in range(96, 112):
				var id := w.get_block_xyz(x, y, z)
				if not cat.is_opaque(id):
					continue
				for d in dirs:
					var p := Vector3i(x, y, z) + d
					var n := BlockCatalog.BEDROCK if p.y < 0 else w.get_block(p)
					if not cat.is_opaque(n):
						expected += 1
	var got := _mesh(w, c).opaque_quads()
	check_eq(got, expected, "facce visibili chunk (6,1,6)")
	check(got >= 62, "almeno i 62 quad greedy del prototipo")
