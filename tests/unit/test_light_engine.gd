extends TestCase
## Luce voxel: calcolo completo = computeLight del prototipo; aggiornamento
## locale = calcolo completo dopo ogni edit.

var _cat := BlockCatalog.load_default()


func test_calcolo_completo_uguale_alla_fixture() -> void:
	var fx := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, _cat, false)
	var w := fx.world
	var files: Dictionary = fx.manifest["files"]
	var le := LightEngine.new(w, _cat)
	w.sun.fill(7)
	w.blk.fill(7)
	le.compute_all()
	check_eq(WorldFixture.sha256_hex(w.sun), str(files["sun"]["sha256"]), "sole")
	check_eq(WorldFixture.sha256_hex(w.blk), str(files["blk"]["sha256"]), "luce blocchi")


## Ritaglio 40x48x40 della fixture attorno allo spawn, con qualche torcia.
func _crop() -> WorldData:
	var src := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, _cat, false).world
	var w := WorldData.new(40, 48, 40, _cat.solid_table())
	for y in 48:
		for z in 40:
			for x in 40:
				w.blocks[w.index(x, y, z)] = src.get_block_xyz(x + 76, y, z + 76)
	return w


func _reference(w: WorldData) -> WorldData:
	var r := WorldData.new(w.size_x, w.size_y, w.size_z, _cat.solid_table())
	r.blocks = w.blocks.duplicate()
	LightEngine.new(r, _cat).compute_all()
	return r


func test_aggiornamento_locale_uguale_al_calcolo_completo() -> void:
	var w := _crop()
	var le := LightEngine.new(w, _cat)
	le.compute_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var ids: Array[int] = [BlockCatalog.AIR, BlockCatalog.STONE, BlockCatalog.TORCH, BlockCatalog.DIRT, BlockCatalog.AIR, BlockCatalog.LAVA]
	var mismatches := 0
	for step in 160:
		# Edit concentrati vicino alla superficie, dove la luce cambia davvero.
		var x := rng.randi_range(0, 39)
		var z := rng.randi_range(0, 39)
		var top := 0
		for y in range(47, -1, -1):
			if w.is_solid_at(x, y, z):
				top = y
				break
		var c := Vector3i(x, clampi(top + rng.randi_range(-3, 4), 0, 47), z)
		var edits: Array[Vector3i] = [c]
		w.blocks[w.index(c.x, c.y, c.z)] = ids[rng.randi_range(0, ids.size() - 1)]
		# Ogni tanto un edit multiplo (come i crateri).
		if step % 7 == 0 and c.x < 39:
			var c2 := c + Vector3i(1, 0, 0)
			w.blocks[w.index(c2.x, c2.y, c2.z)] = BlockCatalog.AIR
			edits.append(c2)
		le.update_cells(edits)
		if step % 8 == 7 or step == 159:
			var r := _reference(w)
			if r.sun != w.sun or r.blk != w.blk:
				mismatches += 1
	check_eq(mismatches, 0, "controlli con differenze")


func test_ombra_di_un_tetto_e_rimozione() -> void:
	var w := TestWorlds.flat(4, 16, 16, 16)
	var le := LightEngine.new(w, _cat)
	le.compute_all()
	check_eq(w.sun[w.index(8, 4, 8)], 15, "pieno sole")
	TestWorlds.fill(w, Vector3i(6, 10, 6), Vector3i(10, 10, 10), BlockCatalog.STONE)
	var cells: Array[Vector3i] = []
	for z in range(6, 11):
		for x in range(6, 11):
			cells.append(Vector3i(x, 10, z))
	le.update_cells(cells)
	check_eq(w.sun[w.index(8, 4, 8)], 12, "sotto il tetto 5x5: tre passi laterali dalla colonna libera")
	check(le.changed_chunks().has(Vector3i.ZERO), "chunk da rimeshare")
	for c in cells:
		w.blocks[w.index(c.x, c.y, c.z)] = BlockCatalog.AIR
	le.update_cells(cells)
	check_eq(w.sun[w.index(8, 4, 8)], 15, "di nuovo pieno sole")


func test_torcia_accesa_e_spenta() -> void:
	var w := TestWorlds.flat(4, 16, 16, 16)
	var le := LightEngine.new(w, _cat)
	le.compute_all()
	w.blocks[w.index(8, 4, 8)] = BlockCatalog.TORCH
	le.update_cells([Vector3i(8, 4, 8)] as Array[Vector3i])
	check_eq(w.blk[w.index(8, 4, 8)], 14, "torcia")
	check_eq(w.blk[w.index(11, 4, 8)], 11, "tre passi")
	w.blocks[w.index(8, 4, 8)] = BlockCatalog.AIR
	le.update_cells([Vector3i(8, 4, 8)] as Array[Vector3i])
	var lit := 0
	for v in w.blk:
		if v > 0:
			lit += 1
	check_eq(lit, 0, "nessuna luce residua")
