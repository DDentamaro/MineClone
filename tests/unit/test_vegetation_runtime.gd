extends TestCase

var _cat := BlockCatalog.load_default()


func _veg(w: WorldData) -> VegetationRuntime:
	var v := VegetationRuntime.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(v)
	v.setup(w, _cat, 1931)
	return v


func _blades(v: VegetationRuntime, col: Vector2i) -> int:
	var inst: MeshInstance3D = v._grass_nodes.get(col)
	if inst == null:
		return 0
	return inst.mesh.surface_get_array_len(0) / 4


func test_alberi_ed_erba_della_fixture() -> void:
	var w := WorldFactory.from_fixture(_cat)
	var v := _veg(w)
	v.flush()
	check_eq(v.spots.size(), 498, "alberi")
	check(v.tree_grid.size() > 50, "celle della griglia alberi")
	var total := 0
	for col: Vector2i in v._grass_nodes:
		total += _blades(v, col)
	check_eq(total, 402080, "fili d'erba come il prototipo")
	v.free()


func test_erba_rigenerata_dopo_un_edit() -> void:
	var w := WorldFactory.from_fixture(_cat)
	var v := _veg(w)
	v.flush()
	var edits := WorldEditService.new(w, _cat)
	edits.light = LightEngine.new(w, _cat)
	edits.chunks_changed.connect(v.mark_dirty)
	var col := Vector2i(6, 6)
	var before := _blades(v, col)
	# Toglie l'erba da una fila di colonne: la terra sotto non ha fili.
	var list: Array[WorldEditService.Edit] = []
	for x in range(97, 107):
		var h := w.surface_height(x, 100)
		if w.get_block_xyz(x, h, 100) == BlockCatalog.GRASS:
			list.append(WorldEditService.Edit.new(Vector3i(x, h, 100), BlockCatalog.DIRT))
	check(list.size() > 3, "celle d'erba da togliere: %d" % list.size())
	edits.try_apply(list)
	check(not v.is_idle(), "colonna in coda")
	v.flush()
	check(_blades(v, col) < before, "meno fili dopo l'edit (%d -> %d)" % [before, _blades(v, col)])
	v.free()


func test_nuovo_mondo_scarta_il_lavoro_precedente() -> void:
	var v := _veg(WorldFactory.from_fixture(_cat))
	var small := TestWorlds.flat(4)
	v.setup(small, _cat, 7)
	v.flush()
	check_eq(v.spots.size(), 0, "nessun albero del mondo precedente (pietra, niente erba)")
	check_eq(v._grass_nodes.size(), 0, "nessuna erba")
	v.free()
