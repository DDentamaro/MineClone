extends TestCase
## Combattimento del giocatore (M4): catene, colpi per bersaglio, forme dei
## colpi, aggancio, schivata, hitstop, carica, picchiata.

const DT := 1.0 / 60.0


class Rig:
	extends RefCounted
	var world: WorldData
	var motor: PlayerMotor
	var combat: CombatController
	var dummies: Array[TrainingDummy] = []
	var started: Array[StringName] = []
	var stick := Vector2.ZERO

	func _init(weapon: StringName) -> void:
		world = TestWorlds.flat(4, 48, 16, 48)
		motor = PlayerMotor.new(world)
		motor.place_at(Vector3(24.5, 4, 24.5))
		combat = CombatController.new(WeaponLibrary.by_id(weapon))
		combat.facing = 0.0
		combat.world = world
		combat.opaque = BlockCatalog.load_default().opaque_table()

	func dummy(rel: Vector2) -> TrainingDummy:
		var d := TrainingDummy.new(Vector3(motor.position.x + rel.x, 4, motor.position.z + rel.y))
		dummies.append(d)
		return d

	func step(n: int = 1) -> void:
		for i in n:
			combat.step(DT, motor, dummies, stick)
			for e in combat.events:
				if e["type"] == "start":
					started.append((e["attack"] as AttackDefinition).id)
			combat.events.clear()
			if combat.hitstop <= 0.0:
				motor.drive_on = combat.drive_on
				motor.drive = combat.drive
				motor.move_scale = combat.move_scale
				motor.step(DT, stick, false)
			for d in dummies:
				d.step(DT, world)

	## Esegue finche' il controller non torna libero (al massimo `secs`).
	func settle(secs: float = 3.0) -> void:
		var n := int(secs / DT)
		for i in n:
			step()
			if not combat.is_busy() and combat.hitstop <= 0.0:
				return


func test_catena_della_spada() -> void:
	var r := Rig.new(&"sword")
	for i in 4:
		r.combat.press_light()
		r.step(int(0.3 / DT))
	r.settle()
	check_eq(r.started, [&"slash", &"backhand", &"cleave", &"whirl"] as Array[StringName], "catena L L L L")


func test_ramo_forte_della_catena() -> void:
	var r := Rig.new(&"sword")
	r.combat.press_light()
	r.step(int(0.3 / DT))
	r.combat.press_heavy()
	r.combat.release_heavy()
	r.settle()
	check_eq(r.started, [&"slash", &"rise"] as Array[StringName], "L + forte = montante")


func test_un_colpo_per_bersaglio() -> void:
	var r := Rig.new(&"sword")
	var d := r.dummy(Vector2(0, -1.4))
	r.combat.press_light()
	r.settle()
	check_eq(d.hits, 1, "un solo colpo per attacco")
	check(d.hp < TrainingDummy.MAX_HP, "danno applicato")
	check(d.velocity.length() > 0.5 or d.position.distance_to(d.home) > 0.05, "spinta")


func test_l_arco_non_colpisce_alle_spalle() -> void:
	var r := Rig.new(&"sword")
	var back := r.dummy(Vector2(0, 1.4))
	r.combat.press_light()
	r.settle()
	check_eq(back.hits, 0, "fendente: nessun colpo alle spalle")
	var r2 := Rig.new(&"sword")
	var back2 := r2.dummy(Vector2(0.0, 1.4))
	r2.combat.weapon = WeaponLibrary.by_id(&"sword")
	r2.combat._start_attack(&"whirl", r2.motor, r2.dummies, Vector2.ZERO)
	r2.settle()
	check_eq(back2.hits, 1, "giro: colpisce anche alle spalle")


func test_portata_degli_affondi() -> void:
	var spear := Rig.new(&"spear")
	var d := spear.dummy(Vector2(0, -2.7))
	spear.combat.lock_target = null
	spear.combat._start_attack(&"thrust", spear.motor, [], Vector2.ZERO)
	spear.settle()
	check_eq(d.hits, 1, "la lancia arriva a 2,7")
	var fists := Rig.new(&"fists")
	var d2 := fists.dummy(Vector2(0, -2.7))
	fists.combat._start_attack(&"jab", fists.motor, [], Vector2.ZERO)
	fists.settle()
	check_eq(d2.hits, 0, "il pugno no")


func test_aggancio_gira_e_accorcia() -> void:
	var r := Rig.new(&"sword")
	# Bersaglio a 3,5 unita' a 45° a sinistra: fuori portata senza scatto.
	var rel := CombatController.forward(deg_to_rad(45.0)) * 3.5
	var d := r.dummy(rel)
	var p0 := r.motor.position
	r.combat.press_light()
	r.step(2)
	check(r.combat.lock_target == d, "bersaglio agganciato")
	check(absf(wrapf(r.combat.facing - deg_to_rad(45.0), -PI, PI)) < 0.05, "girato verso il bersaglio (%f)" % r.combat.facing)
	r.settle()
	check(r.motor.position.distance_to(p0) > 0.8, "lo scatto accorcia la distanza")
	check_eq(d.hits, 1, "colpito")


func test_schivata_e_annullamento() -> void:
	var r := Rig.new(&"hammer")
	r.combat.press_light()
	# Nel rientro del colpo la schivata annulla il resto.
	var a := WeaponLibrary.by_id(&"hammer").attack(&"swing")
	r.step(int((a.windup + a.active) / DT) + 3)
	check_eq(r.combat.phase(), 2, "in rientro")
	r.stick = Vector2(1, 0)
	var p0 := r.motor.position
	r.combat.press_dodge()
	r.step(1)
	check_eq(r.combat.state, CombatController.State.DODGE, "capriola partita")
	r.step(3)
	check(r.combat.invulnerable(), "invulnerabile all'inizio")
	r.stick = Vector2.ZERO
	r.settle()
	check(r.motor.position.x - p0.x > 2.0, "spostamento della capriola (%f)" % (r.motor.position.x - p0.x))
	check(not r.combat.invulnerable(), "fine invulnerabilita'")


func test_colpo_dopo_la_capriola() -> void:
	var r := Rig.new(&"sword")
	r.combat.press_dodge()
	r.step(int(CombatController.DODGE_TIME * 0.6 / DT))
	r.combat.press_light()
	r.settle()
	check_eq(r.started, [&"dash_cut"] as Array[StringName], "attacco in corsa")


func test_hitstop_congela_il_colpo() -> void:
	var r := Rig.new(&"sword")
	r.dummy(Vector2(0, -1.4))
	r.combat.press_light()
	var frozen := false
	for i in 60:
		r.step()
		if r.combat.hitstop > 0.0:
			var t0 := r.combat.t
			r.step()
			frozen = r.combat.t == t0
			break
	check(frozen, "tempo del colpo fermo durante l'hitstop")


func test_carica_aumenta_il_danno() -> void:
	var tap := Rig.new(&"hammer")
	var d1 := tap.dummy(Vector2(0, -1.3))
	tap.combat.press_heavy()
	tap.combat.release_heavy()
	tap.settle()
	var held := Rig.new(&"hammer")
	var d2 := held.dummy(Vector2(0, -1.3))
	held.combat.press_heavy()
	held.step(int(1.2 / DT))
	check(held.combat.charging or held.combat.charge > 0.9, "in carica")
	held.combat.release_heavy()
	held.settle()
	check(d1.hits == 1 and d2.hits == 1, "entrambi colpiti (%d, %d)" % [d1.hits, d2.hits])
	check(TrainingDummy.MAX_HP - d2.hp > (TrainingDummy.MAX_HP - d1.hp) * 1.5, "danno caricato maggiore (%f vs %f)" % [TrainingDummy.MAX_HP - d2.hp, TrainingDummy.MAX_HP - d1.hp])


func test_picchiata_dall_aria() -> void:
	var r := Rig.new(&"hammer")
	var d := r.dummy(Vector2(0, -1.0))
	r.motor.start_jump()
	r.step(int(0.25 / DT))
	check(not r.motor.on_ground, "in aria")
	r.combat.press_light()
	r.step(2)
	check_eq(r.combat.attack.id, &"meteor", "attacco in picchiata")
	r.settle()
	check(r.motor.on_ground, "atterrato")
	check_eq(d.hits, 1, "urto ad area all'atterraggio")


func test_giro_colpisce_piu_volte_con_rehit() -> void:
	var r := Rig.new(&"greatsword")
	var d := r.dummy(Vector2(0, -1.5))
	d.home = d.position
	r.combat._start_attack(&"cyclone", r.motor, [], Vector2.ZERO)
	r.settle()
	check(d.hits >= 2, "turbine: colpi ripetuti (%d)" % d.hits)


func test_manichino_si_rompe_e_ricompare() -> void:
	var w := TestWorlds.flat(4)
	var d := TrainingDummy.new(Vector3(10.5, 4, 10.5))
	d.take_hit(Vector3(6, 0, 0), 100.0)
	check(not d.alive and d.broke, "rotto")
	for i in int((TrainingDummy.RESPAWN + 0.1) / DT):
		d.step(DT, w)
	check(d.alive, "ricomparso")
	check_eq(d.position, d.home, "al suo posto")
	check_eq(d.hp, TrainingDummy.MAX_HP, "PV pieni")


func test_manichino_vola_e_torna_a_casa() -> void:
	var w := TestWorlds.flat(4)
	var d := TrainingDummy.new(Vector3(10.5, 4, 10.5))
	d.take_hit(Vector3(8, 9, 0), 1.0)
	var top := 0.0
	for i in 30:
		d.step(DT, w)
		top = maxf(top, d.position.y)
	check(top > 5.0, "lanciato in aria (%f)" % top)
	for i in int(6.0 / DT):
		d.step(DT, w)
	check(d.on_ground, "a terra")
	check(Vector2(d.position.x - 10.5, d.position.z - 10.5).length() < 0.35, "tornato a casa (%s)" % d.position)
	check(d.tilt.length() < 0.05, "oscillazione smorzata")


func test_tutte_le_catene_sono_valide() -> void:
	for w in WeaponLibrary.all():
		for id in [w.light_start, w.heavy_start, w.dash_attack, w.air_attack]:
			check(w.attack(id) != null, "%s: attacco %s" % [w.id, id])
		for a: AttackDefinition in w.attacks.values():
			for n in [a.next_light, a.next_heavy]:
				check(n == &"" or w.attack(n) != null, "%s.%s -> %s" % [w.id, a.id, n])
			check(a.total() > 0.2 and a.total() < 1.6, "%s.%s durata %f" % [w.id, a.id, a.total()])


func test_niente_colpi_attraverso_i_muri() -> void:
	for id in [&"sword", &"spear", &"hammer"]:
		var r := Rig.new(id)
		var d := r.dummy(Vector2(0, -1.8))
		# Muro alto due blocchi tra giocatore e manichino.
		var z := floori(r.motor.position.z - 1.0)
		TestWorlds.fill(r.world, Vector3i(20, 4, z), Vector3i(28, 5, z), BlockCatalog.STONE)
		r.combat._start_attack(WeaponLibrary.by_id(id).light_start, r.motor, [], Vector2.ZERO)
		r.settle()
		r.combat._start_attack(WeaponLibrary.by_id(id).heavy_start, r.motor, [], Vector2.ZERO)
		r.settle()
		check_eq(d.hits, 0, "%s: nessun colpo oltre il muro" % id)
