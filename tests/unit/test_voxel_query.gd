extends TestCase

var _opaque := BlockCatalog.load_default().opaque_table()


func test_raycast_dall_alto() -> void:
	var w := TestWorlds.flat(4)
	var hit := VoxelQuery.raycast(w, _opaque, Vector3(5.5, 10.0, 5.5), Vector3.DOWN, 50.0)
	check(hit != null, "colpisce")
	if hit:
		check_eq(hit.cell, Vector3i(5, 3, 5), "cella")
		check_eq(hit.normal, Vector3i(0, 1, 0), "normale in su")
		check(absf(hit.distance - 6.0) < 1e-4, "distanza %f" % hit.distance)


func test_raycast_laterale_e_diagonale() -> void:
	var w := TestWorlds.empty()
	w.blocks[w.index(10, 5, 5)] = BlockCatalog.STONE
	var hit := VoxelQuery.raycast(w, _opaque, Vector3(2.5, 5.5, 5.5), Vector3.RIGHT, 50.0)
	check(hit != null and hit.cell == Vector3i(10, 5, 5) and hit.normal == Vector3i(-1, 0, 0), "faccia -X")
	var d := Vector3(1, -1, 0).normalized()
	var hit2 := VoxelQuery.raycast(w, _opaque, Vector3(6.5, 9.5, 5.5), d, 50.0)
	check(hit2 != null and hit2.cell == Vector3i(10, 5, 5), "diagonale")


func test_raycast_manca_e_torcia() -> void:
	var w := TestWorlds.empty()
	check(VoxelQuery.raycast(w, _opaque, Vector3(5, 5, 5), Vector3.UP, 50.0) == null, "nessun blocco")
	w.blocks[w.index(5, 8, 5)] = BlockCatalog.TORCH
	var hit := VoxelQuery.raycast(w, _opaque, Vector3(5.5, 5.5, 5.5), Vector3.UP, 50.0)
	check(hit != null and hit.id == BlockCatalog.TORCH, "la torcia e' selezionabile")
	w.blocks[w.index(5, 8, 5)] = BlockCatalog.WATER
	check(VoxelQuery.raycast(w, _opaque, Vector3(5.5, 5.5, 5.5), Vector3.UP, 50.0) == null, "l'acqua no")


func test_field_height_galleria() -> void:
	var w := TestWorlds.flat(4)
	# Tetto a y=6..8 sopra la colonna: dal basso si vede il pavimento, dall'alto il tetto.
	TestWorlds.fill(w, Vector3i(5, 6, 5), Vector3i(5, 8, 5), BlockCatalog.STONE)
	check_eq(VoxelQuery.field_height(w, 5.5, 5.5, 4.0), 4.0, "dentro la galleria")
	check_eq(VoxelQuery.field_height(w, 5.5, 5.5, 9.0), 9.0, "sopra il tetto")
	check_eq(VoxelQuery.field_height(w, -1.0, 5.5, 4.0), 0.0, "fuori mondo")
