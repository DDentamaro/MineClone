extends SceneTree
func _initialize() -> void:
	var cat := BlockCatalog.load_default()
	var fx := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, cat, false)
	var w := fx.world
	var pal := ChunkMesher.Palette.from_catalog(cat)
	var t0 := Time.get_ticks_usec()
	var quads := 0
	var worst := 0
	for ci in w.chunk_count():
		var x := ci % w.chunks_x()
		var rest := ci / w.chunks_x()
		var c := Vector3i(x, rest / w.chunks_z(), rest % w.chunks_z())
		var t1 := Time.get_ticks_usec()
		var d := ChunkMesher.build(w.blocks, w.size_x, w.size_y, w.size_z, c, pal)
		worst = maxi(worst, Time.get_ticks_usec() - t1)
		quads += d.opaque_quads() + d.water_quads()
	print("432 chunk: %d ms, quad %d, peggior chunk %d ms" % [(Time.get_ticks_usec() - t0) / 1000, quads, worst / 1000])
	quit()
