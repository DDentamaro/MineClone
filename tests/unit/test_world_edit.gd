extends TestCase


func _service(w: WorldData) -> WorldEditService:
	return WorldEditService.new(w, BlockCatalog.load_default())


func test_edit_su_angolo_chunk_sporca_otto_chunk() -> void:
	var w := TestWorlds.empty(32, 32, 32)
	var s := _service(w)
	var r := s.set_block(Vector3i(15, 15, 15), BlockCatalog.STONE)
	check(r.ok(), "edit riuscito")
	check_eq(r.chunks.size(), 8, "chunk toccati")
	for c in r.chunks:
		check_eq(w.chunk_version(c), 1, "versione di %s" % c)
	check_eq(w.revision, 1, "revisione mondo")


func test_edit_interno_un_solo_chunk() -> void:
	var w := TestWorlds.empty()
	var r := _service(w).set_block(Vector3i(5, 5, 5), BlockCatalog.STONE)
	check_eq(r.chunks, [Vector3i.ZERO] as Array[Vector3i], "solo il chunk proprio")


func test_atomicita() -> void:
	var w := TestWorlds.empty()
	var s := _service(w)
	var list: Array[WorldEditService.Edit] = [
		WorldEditService.Edit.new(Vector3i(1, 1, 1), BlockCatalog.STONE),
		WorldEditService.Edit.new(Vector3i(-1, 1, 1), BlockCatalog.STONE),
	]
	var r := s.try_apply(list)
	check_eq(r.status, WorldEditService.Status.REJECTED_OUTSIDE, "rifiutato")
	check_eq(w.get_block_xyz(1, 1, 1), BlockCatalog.AIR, "nessuna scrittura parziale")
	check_eq(w.revision, 0, "revisione invariata")


func test_conflitto_di_versione() -> void:
	var w := TestWorlds.empty()
	var s := _service(w)
	var ci := w.chunk_index(Vector3i.ZERO)
	s.set_block(Vector3i(3, 3, 3), BlockCatalog.STONE)
	var list: Array[WorldEditService.Edit] = [WorldEditService.Edit.new(Vector3i(4, 3, 3), BlockCatalog.DIRT)]
	var r := s.try_apply(list, &"test", {ci: 0})
	check_eq(r.status, WorldEditService.Status.REJECTED_CONFLICT, "versione attesa superata")
	check_eq(w.get_block_xyz(4, 3, 3), BlockCatalog.AIR, "nessuna scrittura")


func test_surface_aggiornata() -> void:
	var w := TestWorlds.flat(4)
	var s := _service(w)
	s.set_block(Vector3i(7, 9, 7), BlockCatalog.STONE)
	check_eq(w.surface_height(7, 7), 9, "dopo piazzamento")
	s.set_block(Vector3i(7, 9, 7), BlockCatalog.AIR)
	check_eq(w.surface_height(7, 7), 3, "dopo rimozione")
	s.set_block(Vector3i(7, 9, 7), BlockCatalog.TORCH)
	check_eq(w.surface_height(7, 7), 3, "la torcia non e' solida")


func test_can_place_come_prototipo() -> void:
	var w := TestWorlds.flat(4)
	var s := _service(w)
	check(s.can_place(Vector3i(5, 4, 5), BlockCatalog.DIRT), "in aria")
	check(not s.can_place(Vector3i(5, 3, 5), BlockCatalog.DIRT), "su pietra no")
	check(not s.can_place(Vector3i(5, 4, 5), BlockCatalog.AIR), "aria non e' un blocco")
	w.blocks[w.index(5, 4, 5)] = BlockCatalog.WATER
	check(s.can_place(Vector3i(5, 4, 5), BlockCatalog.STONE), "in acqua con solido sotto")
	w.blocks[w.index(5, 5, 5)] = BlockCatalog.WATER
	check(not s.can_place(Vector3i(5, 5, 5), BlockCatalog.STONE), "in acqua sopra acqua no")
