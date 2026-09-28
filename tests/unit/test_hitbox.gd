extends TestCase
## Hitbox sulle armi (D-028): sfera contro capsula, contatto spazzato, solo con
## la lama in movimento e solo nella fase attiva (piu' il primo tratto del
## seguito); con l'eroe vero la spada colpisce chi tocca, non chi sta dietro.

const DT := 1.0 / 60.0


func _setup(weapon: StringName = &"sword") -> Array:
	var world := TestWorlds.flat(4, 48, 16, 48)
	var motor := PlayerMotor.new(world)
	motor.place_at(Vector3(24.5, 4, 24.5))
	var c := CombatController.new(WeaponLibrary.by_id(weapon))
	c.facing = 0.0
	c.world = world
	c.opaque = BlockCatalog.load_default().opaque_table()
	return [world, motor, c]


func test_sfera_contro_capsula() -> void:
	var d := TrainingDummy.new(Vector3(10, 4, 10))
	check(CombatController.sphere_capsule(Vector3(10.4, 4.8, 10), 0.1, d), "tocca il fianco")
	check(not CombatController.sphere_capsule(Vector3(10.6, 4.8, 10), 0.1, d), "troppo lontana")
	check(not CombatController.sphere_capsule(Vector3(10, 6.0, 10), 0.1, d), "sopra la testa")


## Lama finta: una sfera che attraversa il manichino da destra a sinistra in un
## solo passo (niente passaggio a vuoto).
func _swing_through(c: CombatController, motor: PlayerMotor, d: TrainingDummy, until_phase: int, u_min: float) -> bool:
	var hit_before := d.hits
	c.press_light()
	var y := 4.9
	for i in 120:
		var ph := c.phase() if c.state == CombatController.State.ATTACK else -1
		var right := ph == until_phase and c.phase_u() >= u_min
		var x := d.position.x + (-1.0 if right else 1.0)
		c.hitboxes = [[Vector3(x, y, d.position.z), 0.1]]
		c.step(DT, motor, [d], Vector2.ZERO)
		c.events.clear()
		if right:
			# Un passo dopo l'attraversamento si torna a destra: niente altri contatti.
			c.hitboxes = [[Vector3(x, y, d.position.z), 0.1]]
			break
	return d.hits > hit_before


func test_contatto_spazzato_nella_fase_attiva() -> void:
	var s := _setup()
	var motor: PlayerMotor = s[1]
	var c: CombatController = s[2]
	var d := TrainingDummy.new(Vector3(24.5, 4, 23.3))
	check(_swing_through(c, motor, d, 1, 0.3), "la lama attraversa il bersaglio nel colpo: colpito")
	var s2 := _setup()
	var d2 := TrainingDummy.new(Vector3(24.5, 4, 23.3))
	check(not _swing_through(s2[2], s2[1], d2, 0, 0.5), "nella carica non ferisce")


func test_lama_ferma_non_ferisce() -> void:
	var s := _setup()
	var motor: PlayerMotor = s[1]
	var c: CombatController = s[2]
	var d := TrainingDummy.new(Vector3(24.5, 4, 23.3))
	c.press_light()
	for i in 60:
		# Sfera appoggiata sul bersaglio ma immobile.
		c.hitboxes = [[d.position + Vector3(0.3, 0.8, 0), 0.1]]
		c.step(DT, motor, [d], Vector2.ZERO)
	check_eq(d.hits, 0, "la guardia appoggiata non conta")


func test_niente_colpi_attraverso_i_muri_con_la_lama() -> void:
	var s := _setup()
	var world: WorldData = s[0]
	var motor: PlayerMotor = s[1]
	var c: CombatController = s[2]
	TestWorlds.fill(world, Vector3i(22, 4, 23), Vector3i(27, 6, 23), BlockCatalog.STONE)
	var d := TrainingDummy.new(Vector3(24.5, 4, 22.3))
	check(not _swing_through(c, motor, d, 1, 0.3), "muro tra giocatore e bersaglio")


## Con l'eroe vero: la spada dello slash ferisce il manichino davanti, non quello
## dietro, e il colpo arriva nella fase attiva o subito dopo.
func test_spada_vera_colpisce_davanti_non_dietro() -> void:
	var s := _setup()
	var world: WorldData = s[0]
	var motor: PlayerMotor = s[1]
	var c: CombatController = s[2]
	var root := (Engine.get_main_loop() as SceneTree).root
	var av := PlayerAvatar.new()
	root.add_child(av)
	av.set_weapon(WeaponLibrary.by_id(&"sword"))
	av.position = motor.position
	var front := TrainingDummy.new(motor.position + Vector3(0.1, 0, -1.0))
	var back := TrainingDummy.new(motor.position + Vector3(0, 0, 1.3))
	var targets: Array[TrainingDummy] = [front, back]
	var hit_phase := -1
	c.press_light()
	for i in 90:
		av.animate(DT, motor, c)
		c.hitboxes = av.rig.hitboxes()
		var before := front.hits
		c.step(DT, motor, targets, Vector2.ZERO)
		c.events.clear()
		motor.drive_on = c.drive_on
		motor.drive = c.drive
		motor.step(DT, Vector2.ZERO, false)
		av.position = motor.position
		for d in targets:
			d.step(DT, world)
		if front.hits > before and hit_phase < 0:
			hit_phase = c.phase()
	check(front.hits >= 1, "colpito quello davanti")
	check_eq(back.hits, 0, "non quello dietro")
	check(hit_phase == 1 or hit_phase == 2, "colpo nella fase attiva o nel seguito (%d)" % hit_phase)
	av.free()
