extends TestCase
## Nuoto e guado: porting di Game.stepWater su una piscina sintetica.

const DT := 1.0 / 60.0


## Terreno pieno fino a y=6 (piedi a 7), fossa x/z 8..23 da y=4 a 6 piena d'acqua,
## e una zona bassa (guado) x 24..27 con acqua in y=6 sopra il fondo a 6.
func _pool() -> WorldData:
	var w := TestWorlds.flat(7, 32, 16, 32)
	TestWorlds.fill(w, Vector3i(8, 4, 8), Vector3i(23, 6, 23), BlockCatalog.WATER)
	for z in 32:
		for x in 32:
			var top := 6
			if x >= 8 and x <= 23 and z >= 8 and z <= 23:
				top = 3
			w.surface[z * 32 + x] = top
	FluidSystem.init_fluid(w)
	for i in 40:
		FluidSystem.step_fluid(w)
	return w


func _motor(w: WorldData, p: Vector3) -> PlayerMotor:
	var m := PlayerMotor.new(w)
	m.place_at(p)
	return m


func test_galleggia_sul_pelo_dell_acqua() -> void:
	var w := _pool()
	var m := _motor(w, Vector3(15.5, 4, 15.5))
	for i in 180:
		m.step(DT, Vector2.ZERO, false)
	var level := float(m.water_query()["level"])
	check(m.swimming, "nuota")
	check_eq(m.water_state, "swim", "stato")
	check(absf(m.position.y - (level - 0.72)) < 0.08, "galleggia a pelo - 0,72 (y=%f, livello=%f)" % [m.position.y, level])


func test_ingresso_genera_uno_schizzo() -> void:
	var w := _pool()
	var m := _motor(w, Vector3(15.5, 9, 15.5))
	m.position.y = 9.0
	m.on_ground = false
	for i in 90:
		m.step(DT, Vector2.ZERO, false)
	check(m.water_events.size() >= 1, "evento d'ingresso")
	if not m.water_events.is_empty():
		check(float(m.water_events[0]["power"]) > 0.35, "potenza dalla velocita' di caduta")


func test_sponda_blocca_e_salto_per_uscire() -> void:
	var w := _pool()
	var m := _motor(w, Vector3(20.5, 4, 15.5))
	for i in 120:
		m.step(DT, Vector2.ZERO, false)
	# Nuota contro la sponda (+X): la sponda e' piu' alta del corpo, non si esce.
	for i in 120:
		m.step(DT, Vector2(1, 0), false)
	check(m.swimming, "ancora in acqua contro la sponda")
	check(m.position.x < 24.0 - PlayerMotor.RADIUS + 0.05, "fermo alla sponda (x=%f)" % m.position.x)
	# Salto dal pelo dell'acqua e avanti: si atterra sulla riva.
	for i in 120:
		m.step(DT, Vector2(1, 0), i == 0)
	check(not m.swimming, "fuori dall'acqua")
	check(m.position.x > 24.0, "sulla riva (x=%f)" % m.position.x)
	check_eq(m.position.y, 7.0, "quota della riva")


func test_nuoto_piu_lento_della_corsa() -> void:
	var w := _pool()
	var m := _motor(w, Vector3(9.5, 4, 15.5))
	for i in 120:
		m.step(DT, Vector2.ZERO, false)
	var x0 := m.position.x
	for i in 60:
		m.step(DT, Vector2(1, 0), false)
	var dist := m.position.x - x0
	check(dist > 1.5 and dist < 2.65, "circa 2,65 u/s con l'accelerazione (%.2f)" % dist)
