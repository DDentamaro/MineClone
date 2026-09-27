extends TestCase
## Mesh dell'acqua: identica a meshFluid del prototipo sul mondo iniziale e dopo
## uno scenario (canale scavato dal bordo di un lago, 30 tick di simulazione).

var _cat := BlockCatalog.load_default()


func _world() -> WorldData:
	var w := WorldFactory.from_fixture(_cat)
	FluidSystem.init_fluid(w, w.fluid)
	return w


func _compare(w: WorldData, ref: Dictionary, falls_file: String) -> void:
	var bad := 0
	var quads := 0
	var falls := PackedFloat64Array()
	for t: Dictionary in ref["tiles"]:
		var c: Array = t["c"]
		var m := FluidMesher.build(w, int(c[0]), int(c[1]))
		quads += m.quads()
		falls.append_array(m.falls)
		var ok := m.quads() == int(t["quads"]) and m.top_faces == int(t["top"]) and m.side_faces == int(t["side"]) \
			and m.bottom_faces == int(t["bottom"]) \
			and WorldFixture.sha256_hex(m.positions.to_byte_array()) == str(t["pos"]) \
			and WorldFixture.sha256_hex(m.normals.to_byte_array()) == str(t["normal"]) \
			and WorldFixture.sha256_hex(m.data.to_byte_array()) == str(t["data"]) \
			and WorldFixture.sha256_hex(m.flow.to_byte_array()) == str(t["flow"]) \
			and WorldFixture.sha256_hex(m.indices.to_byte_array()) == str(t["index"])
		if not ok:
			bad += 1
			if bad <= 2:
				current_failures.append("tile %s: quad %d/%d" % [c, m.quads(), int(t["quads"])])
	check_eq(bad, 0, "tile diverse dal prototipo")
	check_eq(quads, int(ref["quads"]), "quad totali")
	var rf := RenderFixture.buffer(falls_file).to_float64_array()
	check_eq(falls.size() / 5, int(ref["falls"]), "cascate")
	check(falls == rf, "piedi delle cascate identici")


func test_acqua_iniziale_uguale_al_prototipo() -> void:
	var w := _world()
	_compare(w, RenderFixture.manifest()["water"]["initial"], "water_falls_initial.f64")


func test_canale_e_simulazione_uguali_al_prototipo() -> void:
	var w := _world()
	var sc: Dictionary = RenderFixture.manifest()["water"]["scenario"]
	var edits := WorldEditService.new(w, _cat)
	for e: Array in sc["edits"]:
		edits.set_block(Vector3i(int(e[0]), int(e[1]), int(e[2])), BlockCatalog.AIR)
	for t in int(sc["ticks"]):
		FluidSystem.step_fluid(w)
	check_eq(WorldFixture.sha256_hex(w.fluid), str(sc["fluid_sha256"]), "fluidi dopo 30 tick")
	check_eq(WorldFixture.sha256_hex(w.water_level), str(sc["waterLevel_sha256"]), "livelli delle colonne")
	_compare(w, RenderFixture.manifest()["water"]["channel"], "water_falls_channel.f64")


func test_finestra_uguale_al_mondo_intero() -> void:
	var w := _world()
	var bad := 0
	for t: Array in [[0, 0], [11, 11], [4, 0], [5, 5], [3, 7], [11, 2], [0, 9]]:
		var full := FluidMesher.build(w, t[0], t[1])
		var win := FluidMesher.build_window(FluidMesher.window(w, t[0], t[1]), t[0], t[1], w.size_x, w.size_z)
		if full.positions != win.positions or full.data != win.data or full.flow != win.flow \
				or full.indices != win.indices or full.normals != win.normals or full.falls != win.falls:
			bad += 1
			current_failures.append("tile %s: %d/%d quad" % [t, win.quads(), full.quads()])
	check_eq(bad, 0, "tile diverse tra finestra e mondo")
