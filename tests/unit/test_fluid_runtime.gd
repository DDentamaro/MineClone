extends TestCase

var _cat := BlockCatalog.load_default()


func _world() -> WorldData:
	var w := WorldFactory.from_fixture(_cat)
	FluidSystem.init_fluid(w, w.fluid)
	return w


func _runtime(w: WorldData) -> FluidRuntime:
	var rt := FluidRuntime.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(rt)
	rt.setup(w)
	return rt


func test_tile_iniziali_come_il_prototipo() -> void:
	var rt := _runtime(_world())
	rt.flush()
	check_eq(rt.tile_count(), 40, "40 tile con acqua (come View.setWater)")
	check_eq(rt.falls.size() / 5, 34, "piedi delle cascate")
	rt.free()


func test_canale_rigenera_solo_le_tile_toccate() -> void:
	var w := _world()
	var rt := _runtime(w)
	rt.flush()
	var rebuilt: int = rt.stats["rebuilt"]
	var sc: Dictionary = RenderFixture.manifest()["water"]["scenario"]
	var edits := WorldEditService.new(w, _cat)
	for e: Array in sc["edits"]:
		edits.set_block(Vector3i(int(e[0]), int(e[1]), int(e[2])), BlockCatalog.AIR)
	for t in 30:
		FluidSystem.step_fluid(w)
	rt.flush()
	var extra: int = int(rt.stats["rebuilt"]) - rebuilt
	check(extra > 0 and extra <= 6, "tile ricostruite dopo il canale: %d" % extra)
	var total := 0
	for inst: MeshInstance3D in rt._tiles.values():
		total += inst.mesh.surface_get_array_index_len(0) / 6
	check_eq(total, int(RenderFixture.manifest()["water"]["channel"]["quads"]), "quad totali = prototipo dopo il canale")
	rt.free()


func test_nuovo_mondo_scarta_le_tile_vecchie() -> void:
	var rt := _runtime(_world())
	rt._work(0.0, false)
	var dry := TestWorlds.flat(4)
	FluidSystem.init_fluid(dry)
	rt.setup(dry)
	rt.flush()
	check_eq(rt.tile_count(), 0, "nessuna tile del mondo precedente")
	rt.free()


func test_impulsi_a_rotazione() -> void:
	var rt := _runtime(TestWorlds.flat(4))
	for i in 20:
		rt.add_impulse(i, 5, 0, 1.0, 1)
	var imp: PackedVector4Array = rt.material.get_shader_parameter(&"impulses")
	check_eq(imp.size(), 16, "16 slot")
	check_eq(imp[3].x, 19.0, "il 20° impulso sovrascrive lo slot 3")
	rt.clear_impulses()
	imp = rt.material.get_shader_parameter(&"impulses")
	check_eq(imp[3], Vector4.ZERO, "azzerati")
	rt.free()
