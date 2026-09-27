extends SceneTree
## Tempi del mondo su un solo thread (headless): generazione, luce, meshing,
## vegetazione. Uso: godot --headless --path . --script res://tools/bench_mesh.gd


func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0


func _initialize() -> void:
	var cat := BlockCatalog.load_default()
	var t0 := Time.get_ticks_usec()
	var w := WorldData.new(192, 48, 192, cat.solid_table())
	WorldGenerator.generate(w, 1931, {"caves": false})
	w.world_seed = 1931
	print("generazione seme 1931: %.0f ms" % _ms(t0))
	t0 = Time.get_ticks_usec()
	LightEngine.new(w, cat).compute_all()
	print("luce completa: %.0f ms" % _ms(t0))
	var pal := ChunkMesher.Palette.from_catalog(cat)
	var snap := ChunkMesher.Snapshot.of(w)
	t0 = Time.get_ticks_usec()
	var quads := 0
	var worst := 0.0
	for ci in w.chunk_count():
		var x := ci % w.chunks_x()
		var rest := ci / w.chunks_x()
		var t1 := Time.get_ticks_usec()
		var d := ChunkMesher.build(snap, Vector3i(x, rest / w.chunks_z(), rest % w.chunks_z()), pal)
		worst = maxf(worst, _ms(t1))
		quads += d.opaque_quads()
	print("mesh 432 chunk: %.0f ms, %d quad, chunk peggiore %.1f ms" % [_ms(t0), quads, worst])
	t0 = Time.get_ticks_usec()
	var spots := Vegetation.tree_spots(w, cat.opaque_table(), 1931)
	print("posizioni alberi: %.0f ms (%d)" % [_ms(t0), spots.size()])
	t0 = Time.get_ticks_usec()
	var blades := 0
	for cz in 12:
		for cx in 12:
			blades += Vegetation.grass_blades(w, cx, cz, 1931, 0.27).size() / 7
	print("fili d'erba: %.0f ms (%d)" % [_ms(t0), blades])
	var le := LightEngine.new(w, cat)
	var cells: Array[Vector3i] = [Vector3i(96, 28, 96)]
	w.blocks[w.index(96, 28, 96)] = BlockCatalog.STONE
	t0 = Time.get_ticks_usec()
	le.update_cells(cells)
	print("luce locale per un blocco: %.2f ms, %d chunk da rimeshare" % [_ms(t0), le.changed_chunks().size()])
	quit()
