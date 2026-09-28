extends TestCase
## Magia (M4): regole del prototipo (inventario §8) su mondi sintetici.

const DT := 1.0 / 60.0


class Scene:
	extends RefCounted
	var world: WorldData
	var edits: WorldEditService
	var motor: PlayerMotor
	var magic: MagicSystem
	var dummies: Array[TrainingDummy] = []
	var events: Array[Dictionary] = []

	func _init(ground_id: int = BlockCatalog.STONE) -> void:
		world = TestWorlds.flat(4, 48, 16, 48)
		TestWorlds.fill(world, Vector3i(0, 3, 0), Vector3i(47, 3, 47), ground_id)
		var cat := BlockCatalog.load_default()
		edits = WorldEditService.new(world, cat)
		motor = PlayerMotor.new(world)
		motor.place_at(Vector3(24.5, 4, 30.5))
		magic = MagicSystem.new(7)
		magic.world = world
		magic.edits = edits
		magic.catalog = cat
		magic.output_bonus = 300.0

	func hand() -> Vector3:
		return motor.position + Vector3(-0.2, 1.1, -0.3)

	func step(n: int) -> void:
		for i in n:
			magic.step(DT, motor, dummies, 0.0, hand())
			for d in dummies:
				d.step(DT, world)
			events.append_array(magic.events)
			magic.events.clear()

	## Magia del libro: conosciuta, nello slot 5, Output largo.
	func cast_id(id: StringName, hold_frames: int = 40) -> void:
		magic.known[id] = true
		magic.equip(id, 4)
		magic.select(4)
		magic.press()
		step(hold_frames)
		magic.release()
		step(2)

	func step_dt(n: int, dt: float) -> void:
		for i in n:
			magic.step(dt, motor, dummies, 0.0, hand())
			for d in dummies:
				d.step(dt, world)
			events.append_array(magic.events)
			magic.events.clear()

	func damage() -> float:
		var t := 0.0
		for e in events:
			if e["type"] == "hit":
				t += float(e["damage"])
		return t

	func cast(spell: int, hold_frames: int = 40) -> void:
		magic.select(spell)
		magic.press()
		step(hold_frames)
		magic.release()
		step(2)

	func texts() -> Array[String]:
		var out: Array[String] = []
		for e in events:
			if e["type"] == "text":
				out.append(e["text"])
		return out


func test_raccolta_e_rilascio() -> void:
	var s := Scene.new()
	s.magic.select(0)
	s.magic.press()
	s.step(1)
	check_eq(s.magic.phase, MagicSystem.Phase.GATHER, "raccolta")
	s.step(int(0.5 / DT))
	check_eq(s.magic.darts.size(), 0, "tenuto: il dardo aspetta il rilascio")
	s.magic.release()
	s.step(1)
	check_eq(s.magic.darts.size(), 1, "dardo partito al rilascio")
	check_eq(s.magic.phase, MagicSystem.Phase.RECOVER, "recupero")
	check(s.magic.pressure > 0.1, "il lancio alza la pressione (%f)" % s.magic.pressure)


func test_tocco_lancia_da_solo() -> void:
	var s := Scene.new()
	s.magic.select(3)
	s.magic.press()
	s.magic.release()
	s.step(int(0.3 / DT))
	check(s.magic.darts.size() == 1 or s.events.any(func(e: Dictionary) -> bool: return e["type"] == "release"), "lancio automatico")


func test_pressione_satura_e_riparte() -> void:
	var s := Scene.new()
	s.magic.output_bonus = 0.0
	var n := 0
	while not s.magic.saturated and n < 8:
		s.cast_id(&"fire_bolt", 30)
		s.step(int(0.4 / DT))
		n += 1
	check(s.magic.saturated, "satura dopo %d lanci (p %f)" % [n, s.magic.pressure])
	check(n >= 3, "non satura subito (%d)" % n)
	check_eq(s.magic.blocked_reason(s.magic.spell()), "NUCLEO SATURO", "bloccata")
	s.events.clear()
	s.magic.press()
	s.magic.release()
	s.step(2)
	check_eq(s.magic.phase, MagicSystem.Phase.NONE, "niente raccolta da saturo")
	check(s.texts().has("NUCLEO SATURO"), "avviso")
	s.step(int(3.0 / DT))
	check(not s.magic.saturated and s.magic.pressure < 0.85, "riparte sotto .85 (%f)" % s.magic.pressure)


func test_alternare_gli_elementi_pesa_meno() -> void:
	var a := Scene.new()
	a.magic.output_bonus = 0.0
	a.cast_id(&"fire_bolt", 30)
	a.step(int(0.4 / DT))
	a.cast_id(&"fire_bolt", 30)
	var b := Scene.new()
	b.magic.output_bonus = 0.0
	b.cast_id(&"fire_bolt", 30)
	b.step(int(0.4 / DT))
	b.cast_id(&"water_bolt", 30)
	check(b.magic.pressure < a.magic.pressure - 0.1, "alternanza ×0,55 (%f < %f)" % [b.magic.pressure, a.magic.pressure])


func test_output_massimo() -> void:
	var s := Scene.new()
	s.magic.output_bonus = 0.0
	s.magic.known[&"fire_ball"] = true
	s.magic.equip(&"fire_ball", 4)
	s.magic.select(4)
	check_eq(s.magic.blocked_reason(s.magic.spell()), "OUTPUT 125/65", "oltre l'Output (60 + 5 di studio)")
	s.magic.press()
	s.magic.release()
	s.step(2)
	check_eq(s.magic.phase, MagicSystem.Phase.NONE, "non parte")
	s.magic.output_bonus = 70.0
	check_eq(s.magic.blocked_reason(s.magic.spell()), "", "con l'equipaggiamento si")
	var before := s.magic.output_cap()
	s.magic.learn(&"water_geyser")
	check(absf(s.magic.output_cap() - before - MagicSystem.STUDY) < 1e-4, "lo studio alza l'Output")


func test_impegno_al_78_e_coda() -> void:
	var s := Scene.new()
	var sp := SpellDefinition.by_id(&"fire_bolt")
	s.magic.known[sp.id] = true
	s.magic.equip(sp.id, 4)
	s.magic.select(4)
	s.magic.press()
	s.step(int(sp.cast_dur * 0.7 / DT))
	check(not s.magic.committed, "non ancora impegnata al 70%")
	s.step(int(sp.cast_dur * 0.15 / DT) + 2)
	check(s.magic.committed, "impegnata dopo il 78%")
	s.magic.release()
	s.step(int(sp.cast_dur * 0.2 / DT) + 2)
	check_eq(s.magic.phase, MagicSystem.Phase.RECOVER, "lanciata")
	# Pressione durante il recupero: parte da sola alla fine.
	s.magic.press()
	s.magic.release()
	s.step(int((sp.recover + sp.cast_dur + 0.2) / DT))
	var rel := s.events.filter(func(e: Dictionary) -> bool: return e["type"] == "release")
	check_eq(rel.size(), 2, "il lancio in coda parte")


func test_dardo_di_fuoco_brucia_il_manichino() -> void:
	var s := Scene.new()
	var d := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	s.dummies.append(d)
	s.cast(0, 30)
	s.step(int(0.8 / DT))
	check(d.hits >= 1, "colpito")
	check(s.magic.has_status(d, "burn") or d.hp < TrainingDummy.MAX_HP - 20.0, "brucia")
	var hp0 := d.hp
	s.step(int(1.0 / DT))
	check(d.hp < hp0 or not s.magic.has_status(d, "burn"), "danno nel tempo (%f -> %f)" % [hp0, d.hp])


func test_fuoco_su_bagnato_fa_vapore_senza_danno() -> void:
	var s := Scene.new()
	var d := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	s.dummies.append(d)
	s.magic.apply_status(d, "wet")
	check_eq(s.magic.status_react(d, "fire"), 0.0, "moltiplicatore 0")
	check(not s.magic.has_status(d, "wet"), "bagnato consumato")
	s.magic.apply_status(d, "burn")
	check_eq(s.magic.status_react(d, "water"), 1.25, "shock termico")
	check(not s.magic.has_status(d, "burn"), "fuoco spento")
	check_eq(s.magic.status_react(d, "earth"), 1.0, "neutro")
	var t := []
	for e in s.magic.events:
		if e["type"] == "text":
			t.append(e["text"])
	check(t.has("VAPORE") and t.has("SHOCK TERMICO"), "scritte %s" % [t])


func test_aria_su_bagnato_spinge_di_piu() -> void:
	var dry := Scene.new()
	var d1 := TrainingDummy.new(Vector3(24.5, 4, 26.5))
	dry.dummies.append(d1)
	dry.cast(3, 20)
	dry.step(5)
	var wet := Scene.new()
	var d2 := TrainingDummy.new(Vector3(24.5, 4, 26.5))
	wet.dummies.append(d2)
	wet.magic.apply_status(d2, "wet")
	wet.cast(3, 20)
	wet.step(5)
	check(d1.hits == 1 and d2.hits == 1, "entrambi colpiti")
	check(d2.home.distance_to(d2.position) > d1.home.distance_to(d1.position) * 1.4, "spinta ×1,8 sul bagnato")


func test_fuoco_sull_erba_si_propaga_e_brucia() -> void:
	var s := Scene.new(BlockCatalog.GRASS)
	s.cast(0, 30)
	s.step(int(1.5 / DT))
	check(s.magic.fire.size() >= 1, "erba accesa (%d celle)" % s.magic.fire.size())
	s.step(int(8.0 / DT))
	var dirt := 0
	for z in 48:
		for x in 48:
			if s.world.get_block_xyz(x, 3, z) == BlockCatalog.DIRT:
				dirt += 1
	check(dirt >= 1, "erba bruciata diventa terra (%d)" % dirt)
	check(s.magic.fire.size() < MagicSystem.FIRE_MAX, "il fuoco non dilaga")


func test_acqua_spegne_e_bagna() -> void:
	var s := Scene.new(BlockCatalog.GRASS)
	var c := Vector3i(24, 3, 24)
	check(s.magic.ignite(c, true, 0), "accesa")
	s.magic.wet_around(Vector3(24.5, 4.0, 24.5), 1)
	check(not s.magic.fire.has(c), "spenta")
	check(not s.magic.ignite(c, true, 0), "il bagnato non prende fuoco")
	check(s.magic.events.any(func(e: Dictionary) -> bool: return e["type"] == "text" and e["text"] == "SPENTO"), "SPENTO")


func test_masso_fa_cratere_nel_terreno_tenero() -> void:
	var s := Scene.new(BlockCatalog.DIRT)
	s.cast(2, 40)
	s.step(int(1.5 / DT))
	check_eq(s.magic.crater_items, 1, "un blocco preso")
	var holes := 0
	for z in 48:
		for x in 48:
			if s.world.get_block_xyz(x, 3, z) == BlockCatalog.AIR:
				holes += 1
	check_eq(holes, 1, "un cratere")


func test_masso_rimbalza_sulla_pietra() -> void:
	var s := Scene.new(BlockCatalog.STONE)
	s.magic.select(2)
	s.magic.press()
	s.step(40)
	s.magic.release()
	var bounced := false
	for i in 90:
		s.step(1)
		for d in s.magic.darts:
			if d.bounces > 0:
				bounced = true
	check(bounced, "rimbalzo sulla pietra")
	check_eq(s.magic.crater_items, 0, "nessun cratere")


func test_voci_sintetizzate() -> void:
	var rng := RandomNumberGenerator.new()
	for el in ["fire", "water", "earth", "air"]:
		var s := MagicAudio.impact_samples(el, 1.0, rng)
		var peak := 0.0
		for v in s:
			peak = maxf(peak, absf(v))
		check(s.size() > 1000 and peak > 0.05 and peak < 1.0, "%s: impatto (%d campioni, picco %f)" % [el, s.size(), peak])
		var tail := 0.0
		for i in range(s.size() - 200, s.size()):
			tail = maxf(tail, absf(s[i]))
		check(tail < peak * 0.1, "%s: decade" % el)
	var g := MagicAudio.gather_samples("fire", 0.36, rng)
	var a := 0.0
	var b := 0.0
	for i in 400:
		a = maxf(a, absf(g[i]))
		b = maxf(b, absf(g[int(0.36 * MagicAudio.RATE) + i]))
	check(b > a * 3.0, "la raccolta cresce (%f -> %f)" % [a, b])


func test_raggio_coerenza_cala_con_la_distanza() -> void:
	var sp := SpellDefinition.by_id(&"zoltraak")
	var got := []
	for dist: float in [3.0, 12.0]:
		var s := Scene.new()
		var d := TrainingDummy.new(Vector3(24.5, 4, 30.5 - dist))
		s.dummies.append(d)
		s.magic._targets_cache = s.dummies
		s.magic.rng.seed = 3
		var from := s.hand()
		var aim := d.position + Vector3(0, 0.8, 0)
		s.magic.runtime.beam(sp, from, (aim - from).normalized())
		got.append(TrainingDummy.MAX_HP - d.hp)
	check(got[0] > 0.0 and got[1] > 0.0, "colpiti entrambi %s" % [got])
	check(got[0] > got[1] * 1.6, "vicino piu' forte (%s)" % [got])
	check(absf(MagicSystem.coherence(sp, 10.0) - sp.coh_floor) < 1e-4, "minimo della coerenza")


func test_raffica_sei_colpi() -> void:
	var s := Scene.new()
	s.cast_id(&"fire_volley", 30)
	s.step(int(1.0 / DT))
	var rel := s.events.filter(func(e: Dictionary) -> bool: return e["type"] == "release")
	check_eq(rel.size(), 6, "sei proiettili")


func test_orbe_scoppia_sui_vicini() -> void:
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	var b := TrainingDummy.new(Vector3(25.9, 4, 25.2))
	s.dummies.append_array([a, b])
	s.cast_id(&"orbe", 45)
	s.step(int(1.2 / DT))
	check(a.hits >= 1, "colpito il primo")
	check(b.hits >= 1, "lo scoppio prende il vicino")
	check(s.events.any(func(e: Dictionary) -> bool: return e["type"] == "burst_ring"), "anello dello scoppio")


func test_getto_indipendente_dal_frame_rate() -> void:
	var tot := []
	for fps: float in [60.0, 20.0]:
		var s := Scene.new()
		var d := TrainingDummy.new(Vector3(24.5, 4, 27.5))
		s.dummies.append(d)
		s.magic.rng.seed = 5
		s.cast_id(&"fire_jet", 25)
		s.events.clear()
		s.step_dt(int(1.0 * fps), 1.0 / fps)
		var t := 0.0
		for e in s.events:
			if e["type"] == "hit" and e["el"] == "fire" and e.get("quiet", false):
				t += float(e["damage"])
		tot.append(t)
	check(tot[0] > 15.0, "il getto fa danno (%s)" % [tot])
	check(absf(tot[0] - tot[1]) < tot[0] * 0.2, "stesso danno a 60 e 20 fps (%s)" % [tot])


func test_vuoto_attira() -> void:
	var s := Scene.new()
	# Il primo e' agganciato (centro del vuoto), il secondo sta di lato.
	s.dummies.append(TrainingDummy.new(Vector3(24.5, 4, 22.5)))
	var d := TrainingDummy.new(Vector3(27.5, 4, 22.5))
	s.dummies.append(d)
	s.cast_id(&"air_vacuum", 50)
	var c := s.magic.aim
	var d0 := Vector2(d.position.x - c.x, d.position.z - c.z).length()
	var best := d0
	for i in int(1.6 / DT):
		s.step(1)
		best = minf(best, Vector2(d.position.x - c.x, d.position.z - c.z).length())
	check(best < d0 - 0.8, "trascinato verso il centro (%f -> %f)" % [d0, best])


func test_ascensione_solleva() -> void:
	var s := Scene.new()
	var d := TrainingDummy.new(Vector3(24.5, 4, 20.5))
	s.dummies.append(d)
	s.cast_id(&"air_updraft", 70)
	var top := d.position.y
	for i in int(2.0 / DT):
		s.step(1)
		top = maxf(top, d.position.y)
	check(top > 5.0, "sollevato (%f)" % top)


func _raised(s: Scene) -> int:
	var n := 0
	for z in 48:
		for x in 48:
			for y in range(4, 16):
				if s.world.get_block_xyz(x, y, z) == BlockCatalog.DIRT:
					n += 1
	return n


func test_muraglia_si_alza_e_crolla() -> void:
	var s := Scene.new()
	s.cast_id(&"earth_wall", 40)
	s.step(5)
	var n := _raised(s)
	check_eq(n, 15, "5 × 3 blocchi di terra")
	check_eq(s.magic.runtime.struct_cells().size(), 15, "celle della struttura")
	s.step(int(6.5 / DT))
	check_eq(_raised(s), 0, "crollata")
	check(s.events.any(func(e: Dictionary) -> bool: return e["type"] == "crumble"), "evento del crollo")


func test_colonna_solleva_il_giocatore() -> void:
	var s := Scene.new()
	var y0 := s.motor.position.y
	s.cast_id(&"earth_pillar", 45)
	s.step(10)
	check(s.motor.position.y >= y0 + 2.9, "in cima alla colonna (%f)" % s.motor.position.y)
	check(s.motor.on_ground, "ci sta sopra")


func test_ventaglio_aria_sul_fuoco() -> void:
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	var b := TrainingDummy.new(Vector3(26.5, 4, 25.5))
	s.dummies.append_array([a, b])
	s.magic._targets_cache = s.dummies
	s.magic.apply_status(a, "burn")
	s.magic.spell_hit(a, SpellDefinition.by_id(&"air_lash"), 10.0, Vector2(0, -1), a.position)
	check_eq(int(s.magic.statuses[a]["burn"]["st"]), 2, "una pila in piu'")
	check(s.magic.has_status(b, "burn"), "la fiamma passa al vicino")
	check(s.magic.events.any(func(e: Dictionary) -> bool: return e["type"] == "text" and e["text"] == "VENTAGLIO"), "VENTAGLIO")


func test_conduzione_karma_sul_bagnato() -> void:
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	var b := TrainingDummy.new(Vector3(26.5, 4, 25.5))
	var c := TrainingDummy.new(Vector3(34.5, 4, 25.5))
	s.dummies.append_array([a, b, c])
	s.magic._targets_cache = s.dummies
	for d in s.dummies:
		s.magic.apply_status(d, "wet")
	s.magic.spell_hit(a, SpellDefinition.by_id(&"dardo"), 20.0, Vector2(0, -1), a.position)
	check(b.hp < TrainingDummy.MAX_HP, "la scossa salta sul vicino bagnato")
	check_eq(c.hp, TrainingDummy.MAX_HP, "troppo lontano")
	check(s.magic.events.any(func(e: Dictionary) -> bool: return e["type"] == "arc"), "arco")


func test_fango_rallenta_e_flusso_accelera() -> void:
	var s := Scene.new()
	s.magic.runtime.add_mud(s.motor.position, 1.5)
	s.step(1)
	check(absf(s.magic.player_speed() - 0.70) < 1e-4, "fango ×0,70 (%f)" % s.magic.player_speed())
	check(s.magic.has_status(s.magic.player, "wet"), "e bagna")
	var f := Scene.new()
	f.cast_id(&"flusso", 20)
	f.step(3)
	check(absf(f.magic.player_speed() - 1.55) < 1e-4, "flusso ×1,55 (%f)" % f.magic.player_speed())


func test_libro_e_barra_salvati() -> void:
	var m := MagicSystem.new(1)
	check(m.known.has(&"ago") and not m.known.has(&"nova"), "livello 1 noto, il resto no")
	check(not m.equip(&"nova", 4), "non si equipaggia una magia sconosciuta")
	m.learn(&"nova")
	check(m.equip(&"nova", 4), "equipaggiata")
	m.select(4)
	var d := m.to_dict()
	var m2 := MagicSystem.new(2)
	m2.load_dict(d)
	check(m2.known.has(&"nova"), "conosciuta dopo il caricamento")
	check_eq(m2.bar[4], &"nova", "barra ripristinata")
	check_eq(m2.bar_index, 4, "scelta ripristinata")
