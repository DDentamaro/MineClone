extends TestCase
## Aggancio del bersaglio (D-035): scelta, sgancio, colpi e magie che lo seguono.

const DT := 1.0 / 60.0


func _dummy(p: Vector3) -> TrainingDummy:
	return TrainingDummy.new(p)


func test_sceglie_davanti_e_sgancia() -> void:
	var from := Vector3(10, 4, 10)
	var front := _dummy(Vector3(10, 4, 6))
	var back := _dummy(Vector3(10, 4, 12))
	var far := _dummy(Vector3(10, 4, -10))
	var lk := LockOn.new()
	check(lk.toggle(from, 0.0, [back, front, far]), "agganciato")
	check(lk.target == front, "davanti vince su dietro piu' vicino")
	check(not lk.toggle(from, 0.0, [back, front]), "secondo tocco sgancia")
	check(lk.target == null, "sganciato")
	check(lk.toggle(from, 0.0, [back]), "anche alle spalle se e' l'unico")
	check(not LockOn.new().toggle(from, 0.0, [far]), "oltre la portata: niente")


func test_l_aggancio_cade_da_solo() -> void:
	var from := Vector3(10, 4, 10)
	var d := _dummy(Vector3(10, 4, 6))
	var lk := LockOn.new()
	lk.toggle(from, 0.0, [d])
	lk.step(from, [d])
	check(lk.active(), "resta")
	lk.step(from + Vector3(0, 0, 30), [d])
	check(not lk.active(), "troppo lontano")
	lk.toggle(from, 0.0, [d])
	d.alive = false
	lk.step(from, [d])
	check(not lk.active(), "rotto")
	d.alive = true
	lk.toggle(from, 0.0, [d])
	lk.step(from, [])
	check(not lk.active(), "tolto dalla scena")


## Il colpo parte verso il bersaglio agganciato anche a 70°, dove la mira
## assistita (35°) non arriva, e lo prende.
func test_colpo_segue_il_lock() -> void:
	for weapon: StringName in [&"sword", &"fists", &"spear"]:
		for forced in [false, true]:
			var world := TestWorlds.flat(4, 48, 16, 48)
			var motor := PlayerMotor.new(world)
			motor.place_at(Vector3(24.5, 4, 24.5))
			var c := CombatController.new(WeaponLibrary.by_id(weapon))
			c.world = world
			c.facing = 0.0
			var ang := deg_to_rad(70.0)
			var d := _dummy(motor.position + Vector3(-sin(ang), 0, -cos(ang)) * 1.6)
			var ds: Array = [d]
			if forced:
				c.forced = d
			c.press_light()
			for i in int(0.7 / DT):
				c.step(DT, motor, ds, Vector2.ZERO)
				c.events.clear()
				if c.hitstop <= 0.0:
					motor.drive_on = c.drive_on
					motor.drive = c.drive
					motor.move_scale = c.move_scale
					motor.step(DT, Vector2.ZERO, false)
				d.step(DT, world)
			if forced:
				check(d.hits >= 1, "%s: colpisce il bersaglio agganciato a 70°" % weapon)
				check(absf(wrapf(c.facing - ang, -PI, PI)) < 0.3, "%s: girato verso di lui (%.0f°)" % [weapon, rad_to_deg(c.facing)])
			else:
				check_eq(d.hits, 0, "%s: senza lock a 70° non si prende" % weapon)


## Il colpo segue il bersaglio che si sposta durante la carica.
func test_colpo_segue_il_bersaglio_che_si_muove() -> void:
	var world := TestWorlds.flat(4, 48, 16, 48)
	var motor := PlayerMotor.new(world)
	motor.place_at(Vector3(24.5, 4, 24.5))
	var c := CombatController.new(WeaponLibrary.by_id(&"hammer"))
	c.world = world
	var d := _dummy(motor.position + Vector3(0, 0, -1.8))
	c.forced = d
	c.press_light()
	c.step(DT, motor, [d], Vector2.ZERO)
	d.position = motor.position + Vector3(-1.8, 0, 0)
	c.step(DT, motor, [d], Vector2.ZERO)
	check(absf(wrapf(c.facing - PI * 0.5, -PI, PI)) < 0.05, "la carica gira col bersaglio (%.0f°)" % rad_to_deg(c.facing))


## La magia parte verso il bersaglio agganciato (di lato) e il dardo lo insegue.
func test_magia_segue_il_lock() -> void:
	var world := TestWorlds.flat(4, 48, 16, 48)
	TestWorlds.fill(world, Vector3i(0, 3, 0), Vector3i(47, 3, 47), BlockCatalog.STONE)
	var cat := BlockCatalog.load_default()
	var motor := PlayerMotor.new(world)
	motor.place_at(Vector3(24.5, 4, 30.5))
	var m := MagicSystem.new(7)
	m.world = world
	m.edits = WorldEditService.new(world, cat)
	m.catalog = cat
	m.output_bonus = 300.0
	var side := _dummy(Vector3(30.5, 4, 30.5))
	m.known[&"fire_bolt"] = true
	m.equip(&"fire_bolt", 4)
	m.select(4)
	m.forced = side
	m.press()
	m.release()
	var moved := false
	for i in int(1.4 / DT):
		m.step(DT, motor, [side], 0.0, motor.position + Vector3(-0.2, 1.1, -0.3))
		m.events.clear()
		side.step(DT, world)
		if not moved and not m.darts.is_empty():
			# Il bersaglio fa un passo di lato: il dardo curva.
			side.position += Vector3(0, 0, -1.2)
			side.home = side.position
			moved = true
	check(side.hits >= 1, "colpito di lato e dopo il passo (%d)" % side.hits)
