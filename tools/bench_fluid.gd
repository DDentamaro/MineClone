extends SceneTree
func _initialize() -> void:
	var cat := BlockCatalog.load_default()
	var w := WorldFactory.from_fixture(cat)
	var t0 := Time.get_ticks_usec()
	FluidSystem.init_fluid(w, w.fluid)
	print("init_fluid %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
	var worst_t := 0
	var total := 0
	var times: Array[int] = []
	for cz in 12:
		for cx in 12:
			var t1 := Time.get_ticks_usec()
			var m := FluidMesher.build(w, cx, cz)
			var d := Time.get_ticks_usec() - t1
			total += d
			if m.quads() > 0:
				times.append(d)
			worst_t = maxi(worst_t, d)
	times.sort()
	print("144 tile %d ms, peggiore %.1f ms, mediana tile con acqua %.1f ms (%d tile)" % [total / 1000, worst_t / 1000.0, times[times.size() / 2] / 1000.0, times.size()])
	var q := 0
	t0 = Time.get_ticks_usec()
	for i in 20:
		q += FluidSystem.step_fluid(w).size() / 2
	print("20 tick a riposo %d ms, %d aggiornamenti" % [(Time.get_ticks_usec() - t0) / 1000, q])
	# Canale dal bordo del lago (lo scenario della fixture di resa): tick con acqua in moto.
	var edits := WorldEditService.new(w, cat)
	for x in range(78, 82):
		for y in [34, 35]:
			edits.set_block(Vector3i(x, y, 11), BlockCatalog.AIR)
	var worst := 0
	q = 0
	t0 = Time.get_ticks_usec()
	for i in 30:
		var t2 := Time.get_ticks_usec()
		q += FluidSystem.step_fluid(w).size() / 2
		worst = maxi(worst, Time.get_ticks_usec() - t2)
	print("30 tick in moto %d ms (peggiore %.1f ms), %d aggiornamenti" % [(Time.get_ticks_usec() - t0) / 1000, worst / 1000.0, q])
	t0 = Time.get_ticks_usec()
	var win := FluidMesher.window(w, 4, 0)
	var tw := (Time.get_ticks_usec() - t0) / 1000.0
	print("finestra di una tile %.2f ms" % tw)
	quit()
