extends TestCase
## Runtime dei chunk: costruzione, edit, scarto dei risultati obsoleti.


func _runtime(w: WorldData) -> WorldRuntime:
	var rt := WorldRuntime.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(rt)
	rt.setup(w, BlockCatalog.load_default())
	return rt


## Vero se la mesh del chunk ha un vertice in `p` (coordinate di mondo).
func _has_vertex(rt: WorldRuntime, c: Vector3i, p: Vector3) -> bool:
	var inst := rt.chunk_instance(c)
	if inst == null or inst.mesh == null:
		return false
	for v: Vector3 in inst.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.is_equal_approx(p):
			return true
	return false


func test_costruzione_iniziale_e_chunk_vuoti() -> void:
	var w := TestWorlds.flat(4)
	var rt := _runtime(w)
	rt.flush()
	check(rt.is_idle(), "nessun lavoro residuo")
	check(rt.chunk_instance(Vector3i(0, 0, 0)) != null, "chunk con terreno")
	check(rt.chunk_instance(Vector3i(0, 0, 1)) != null, "altro chunk con terreno")
	# 32x16x32 -> 2x1x2 chunk, tutti con pavimento.
	check_eq(rt.stats["applied"], 4, "chunk applicati")
	rt.free()


func test_edit_rimeshato() -> void:
	var w := TestWorlds.flat(4)
	var rt := _runtime(w)
	var edits := WorldEditService.new(w, BlockCatalog.load_default())
	edits.chunks_changed.connect(rt.mark_dirty)
	rt.flush()
	check(not _has_vertex(rt, Vector3i.ZERO, Vector3(6, 5, 6)), "prima: nessun blocco")
	edits.set_block(Vector3i(5, 4, 5), BlockCatalog.STONE)
	check(not rt.is_idle(), "chunk sporco in coda")
	rt.flush()
	check(_has_vertex(rt, Vector3i.ZERO, Vector3(6, 5, 6)), "spigolo superiore del nuovo blocco")
	rt.free()


func test_risultato_obsoleto_scartato() -> void:
	var w := TestWorlds.flat(4)
	var rt := _runtime(w)
	var edits := WorldEditService.new(w, BlockCatalog.load_default())
	edits.chunks_changed.connect(rt.mark_dirty)
	rt.flush()
	# Primo edit: parte il job con lo snapshot che contiene un solo blocco.
	edits.set_block(Vector3i(5, 4, 5), BlockCatalog.STONE)
	rt._launch()
	# Secondo edit prima che il risultato venga applicato.
	edits.set_block(Vector3i(9, 4, 9), BlockCatalog.STONE)
	rt.flush()
	check(int(rt.stats["discarded"]) >= 1, "il risultato del primo job e' stato scartato")
	check(_has_vertex(rt, Vector3i.ZERO, Vector3(6, 5, 6)), "primo blocco nella mesh finale")
	check(_has_vertex(rt, Vector3i.ZERO, Vector3(10, 5, 10)), "secondo blocco nella mesh finale")
	rt.free()


func test_nuova_sessione_ignora_job_precedenti() -> void:
	var w := TestWorlds.flat(4)
	var rt := _runtime(w)
	rt._launch()
	var w2 := TestWorlds.flat(2)
	rt.setup(w2, BlockCatalog.load_default())
	rt.flush()
	# Pavimento alto 2: nessun vertice sopra y=2 nei chunk della nuova sessione.
	var inst := rt.chunk_instance(Vector3i.ZERO)
	var arrays := inst.mesh.surface_get_arrays(0)
	var max_y := -1.0
	for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		max_y = maxf(max_y, v.y)
	check_eq(max_y, 2.0, "nessuna mesh del mondo precedente")
	rt.free()
