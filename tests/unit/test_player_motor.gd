extends TestCase
## Locomozione a terra: parita' con le regole del prototipo e collisioni volumetriche.

const DT := 1.0 / 60.0


func test_salto_tenuto_non_rimbalza() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(8.5, 4, 8.5))
	_run(m, 2.0, Vector2.ZERO, 120)
	check(m.on_ground, "tenere il salto non ne fa partire un secondo")
	check_eq(m.position.y, 4.0, "atterrato e resta a terra")


func test_salto_ricordato_prima_di_atterrare() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(8.5, 4, 8.5))
	m.position.y = 4.1
	m.on_ground = false
	m.velocity.y = -3.0
	m.step(DT, Vector2.ZERO, true)
	for i in 5:
		m.step(DT, Vector2.ZERO, false)
	check(m.velocity.y > 0.0, "una pressione poco prima di atterrare e' ricordata")


func test_tolleranza_dopo_il_bordo() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(8.5, 4, 8.5))
	m.step(DT, Vector2.ZERO, false)
	m.on_ground = false
	m.position.y = 5.0
	m.step(DT, Vector2.ZERO, true)
	check(m.velocity.y > 0.0, "breve tolleranza dopo aver lasciato il suolo")
	m.step(DT, Vector2.ZERO, false)
	var before := m.velocity.y
	m.step(DT, Vector2.ZERO, true)
	check(m.velocity.y < before, "niente doppio salto nella tolleranza")


func test_tolleranza_scade() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(8.5, 4, 8.5))
	m.step(DT, Vector2.ZERO, false)
	m.on_ground = false
	m.position.y = 10.0
	for i in 12:
		m.step(DT, Vector2.ZERO, false)
	m.step(DT, Vector2.ZERO, true)
	check(m.velocity.y < 0.0, "niente salto molto dopo il bordo")


func _run(m: PlayerMotor, seconds: float, move: Vector2, jump_frames: int = 0) -> Dictionary:
	var max_y := m.position.y
	var min_y := m.position.y
	var steps := int(seconds / DT)
	for i in steps:
		m.step(DT, move, i < jump_frames)
		max_y = maxf(max_y, m.position.y)
		min_y = minf(min_y, m.position.y)
	return {"max_y": max_y, "min_y": min_y}


func _motor(w: WorldData, p: Vector3) -> PlayerMotor:
	var m := PlayerMotor.new(w)
	m.place_at(p)
	return m


func test_fermo_resta_al_suolo() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(8.5, 4, 8.5))
	var r := _run(m, 2.0, Vector2.ZERO)
	check_eq(m.position.y, 4.0, "quota")
	check_eq(r["max_y"], 4.0, "nessun sobbalzo")
	check(m.on_ground, "a terra")


func test_cammina_alla_velocita_del_prototipo() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(4.5, 4, 8.5))
	_run(m, 1.0, Vector2(1, 0))
	# 5,5 u/s con accelerazione 40*1,3: ~5,4 u in un secondo.
	check(m.position.x > 9.5 and m.position.x < 10.1, "x dopo 1 s: %f" % m.position.x)
	check_eq(m.position.y, 4.0, "quota costante")


func test_sale_un_gradino_con_la_rampa() -> void:
	var w := TestWorlds.flat(4)
	TestWorlds.fill(w, Vector3i(12, 4, 0), Vector3i(31, 4, 31), BlockCatalog.STONE)
	var m := _motor(w, Vector3(8.5, 4, 8.5))
	_run(m, 2.0, Vector2(1, 0))
	check(m.position.x > 13.0, "ha superato il gradino (x=%f)" % m.position.x)
	check_eq(m.position.y, 5.0, "sopra il gradino")


func test_muro_di_due_blocchi_blocca() -> void:
	var w := TestWorlds.flat(4)
	TestWorlds.fill(w, Vector3i(12, 4, 0), Vector3i(12, 5, 31), BlockCatalog.STONE)
	var m := _motor(w, Vector3(8.5, 4, 8.5))
	_run(m, 2.0, Vector2(1, 0))
	check(m.position.x < 12.0, "fermo davanti al muro (x=%f)" % m.position.x)
	check_eq(m.position.y, 4.0, "non sale")
	check(m.blocked, "segnalato come bloccato")


func test_salto_apice() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(8.5, 4, 8.5))
	var r := _run(m, 1.5, Vector2.ZERO, 1)
	check(absf(float(r["max_y"]) - 6.1) < 0.1, "apice ~2,1 sopra (max %f)" % r["max_y"])
	check_eq(m.position.y, 4.0, "riatterrato")


func test_soffitto_ferma_il_salto() -> void:
	var w := TestWorlds.flat(4)
	# Soffitto spesso a y=6..8: spazio libero di due blocchi.
	TestWorlds.fill(w, Vector3i(0, 6, 0), Vector3i(31, 8, 31), BlockCatalog.STONE)
	var m := _motor(w, Vector3(8.5, 4, 8.5))
	var r := _run(m, 1.5, Vector2.ZERO, 1)
	check(float(r["max_y"]) <= 6.0 - PlayerMotor.HEIGHT + 1e-4, "la testa resta sotto il soffitto (max %f)" % r["max_y"])
	check_eq(m.position.y, 4.0, "torna al pavimento, non sul tetto")


func test_galleria_attraversata_senza_salire_sul_tetto() -> void:
	var w := TestWorlds.flat(4)
	# Massiccio con galleria alta 2 lungo X da x=10 a x=20.
	TestWorlds.fill(w, Vector3i(10, 4, 0), Vector3i(20, 10, 31), BlockCatalog.STONE)
	TestWorlds.fill(w, Vector3i(10, 4, 7), Vector3i(20, 5, 9), BlockCatalog.AIR)
	var m := _motor(w, Vector3(6.5, 4, 8.5))
	var r := _run(m, 4.0, Vector2(1, 0))
	check(m.position.x > 21.0, "uscito dalla galleria (x=%f)" % m.position.x)
	check(float(r["max_y"]) < 4.7, "mai sopra il tetto (max %f)" % r["max_y"])


func test_sporgenza_all_altezza_della_testa() -> void:
	var w := TestWorlds.flat(4)
	# Varco alto un solo blocco: il corpo (1,4) non passa.
	TestWorlds.fill(w, Vector3i(12, 5, 0), Vector3i(12, 8, 31), BlockCatalog.STONE)
	var m := _motor(w, Vector3(8.5, 4, 8.5))
	_run(m, 2.0, Vector2(1, 0))
	check(m.position.x < 12.0, "non entra (x=%f)" % m.position.x)
	check_eq(m.position.y, 4.0, "non sale sulla sporgenza")


func test_caduta_e_recupero_atterraggio() -> void:
	var w := TestWorlds.flat(4)
	TestWorlds.fill(w, Vector3i(0, 4, 0), Vector3i(10, 7, 31), BlockCatalog.STONE)
	var m := _motor(w, Vector3(8.5, 8, 8.5))
	var landed := false
	for i in 120:
		m.step(DT, Vector2(1, 0), false)
		if m.land_t > 0.0:
			landed = true
	check(landed, "rallentamento dopo una caduta di 4 blocchi")
	check_eq(m.position.y, 4.0, "a terra in basso")


func test_scende_un_gradino_a_passo() -> void:
	var w := TestWorlds.flat(4)
	TestWorlds.fill(w, Vector3i(0, 4, 0), Vector3i(10, 4, 31), BlockCatalog.STONE)
	var m := _motor(w, Vector3(8.5, 5, 8.5))
	var went_airborne := false
	for i in 90:
		m.step(DT, Vector2(1, 0), false)
		if not m.on_ground:
			went_airborne = true
	check(not went_airborne, "discesa di un blocco senza caduta balistica")
	check_eq(m.position.y, 4.0, "in basso")


func test_fixture_spawn_stabile_e_passeggiata() -> void:
	var cat := BlockCatalog.load_default()
	var w := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, cat, false).world
	var m := _motor(w, w.spawn_point())
	_run(m, 2.0, Vector2.ZERO)
	check_eq(m.position, Vector3(96.5, 28, 96.5), "spawn stabile")
	var dirs: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(-0.7071, -0.7071), Vector2(0.6, -0.8)]
	for d in dirs:
		_run(m, 3.0, d, 30)
		var p := m.position
		check(is_finite(p.x) and is_finite(p.y) and is_finite(p.z), "posizione finita")
		check(m.space_free(p.x, p.z, p.y), "mai dentro un solido (%s)" % p)
		check(p.y >= m.ground(p.x, p.z) - 1e-4, "mai sotto il suolo")


func test_sovrapposizione_per_piazzare() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(8.5, 4, 8.5))
	check(m.overlaps_cell(Vector3i(8, 4, 8)), "cella dei piedi")
	check(m.overlaps_cell(Vector3i(8, 5, 8)), "cella della testa")
	check(not m.overlaps_cell(Vector3i(8, 6, 8)), "sopra la testa")
	check(not m.overlaps_cell(Vector3i(9, 4, 8)), "accanto")


func test_tronco_respinge() -> void:
	var m := _motor(TestWorlds.flat(4), Vector3(6.5, 4, 8.62))
	var t := Vegetation.TreeSpot.new()
	t.x = 9.0
	t.y = 4.0
	t.z = 8.5
	t.scale = 1.0
	m.tree_grid = {Vector2i(1, 1): [t]}
	var min_d := 99.0
	for i in 90:
		m.step(DT, Vector2(1, 0), false)
		min_d = minf(min_d, Vector2(m.position.x - t.x, m.position.z - t.z).length())
	check(min_d >= 0.30 + PlayerMotor.RADIUS - 1e-4, "mai dentro il tronco (min %f)" % min_d)
	check(m.position.x > 9.5, "scivola attorno al tronco (x=%f)" % m.position.x)
