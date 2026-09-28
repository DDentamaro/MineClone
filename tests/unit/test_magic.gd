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
	check(s.magic.pressure > 0.1, "la pressione sale appena parte la raccolta (%f)" % s.magic.pressure)
	s.step(int(0.5 / DT))
	check_eq(s.magic.darts.size(), 0, "tenuto: il dardo aspetta il rilascio")
	s.magic.release()
	s.step(1)
	check_eq(s.magic.darts.size(), 1, "dardo partito al rilascio")
	check_eq(s.magic.phase, MagicSystem.Phase.RECOVER, "recupero")


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
	var hp0 := d.hp
	check_eq(s.magic.status_react(d, "water"), 1.0, "shock termico: moltiplicatore 1")
	check(absf(hp0 - d.hp - 4.0) < 1e-4, "4 × pile di danno silenzioso (%f)" % (hp0 - d.hp))
	check(not s.magic.has_status(d, "burn"), "fuoco spento")
	check_eq(s.magic.status_react(d, "earth"), 1.0, "neutro")
	var t := []
	for e in s.magic.events:
		if e["type"] == "text":
			t.append(e["text"])
	check(t.has("VAPORE") and t.has("SHOCK TERMICO"), "scritte %s" % [t])


func test_acqua_e_aria_spingono() -> void:
	# statusFromHit (RMNDWN L21619): acqua e aria con |knockback| >= .6 danno SPINTO.
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	var b := TrainingDummy.new(Vector3(20.5, 4, 25.5))
	var c := TrainingDummy.new(Vector3(28.5, 4, 25.5))
	s.dummies.append_array([a, b, c])
	s.magic._targets_cache = s.dummies
	s.magic.spell_hit(a, SpellDefinition.by_id(&"water_bolt"), 10.0, Vector2(0, -1), a.position)
	s.magic.spell_hit(b, SpellDefinition.by_id(&"air_lash"), 10.0, Vector2(0, -1), b.position)
	s.magic.spell_hit(c, SpellDefinition.by_id(&"fire_bolt"), 10.0, Vector2(0, -1), c.position)
	check(s.magic.has_status(a, "pushed") and s.magic.has_status(a, "wet"), "acqua: bagnato e spinto")
	check(s.magic.has_status(b, "pushed"), "aria: spinto")
	check(not s.magic.has_status(c, "pushed") and s.magic.has_status(c, "burn"), "fuoco: brucia, non spinge")


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
	# Voci d'impatto di RMNDWN (IMPACT_VOICE): durate per materiale, pesante piu' lungo.
	var rng := RandomNumberGenerator.new()
	for el in ["fire", "water", "earth", "air", "karma"]:
		var s := MagicAudio.impact_samples(el, 1.0, rng)
		var peak := 0.0
		for v in s:
			peak = maxf(peak, absf(v))
		check(s.size() > 1000 and peak > 0.03 and peak < 0.5, "%s: impatto (%d campioni, picco %f)" % [el, s.size(), peak])
		var tail := 0.0
		for i in range(s.size() - 200, s.size()):
			tail = maxf(tail, absf(s[i]))
		check(tail < peak * 0.1, "%s: decade" % el)
		check(MagicAudio.voice_dur(el, true) > MagicAudio.voice_dur(el, false), "%s: il colpo pesante dura di piu'" % el)
	check(absf(MagicAudio.voice_dur("fire", false) - 0.08) < 1e-6 and absf(MagicAudio.voice_dur("earth", true) - 0.26) < 1e-6, "durate di RMNDWN")


## Un colpo del Karma lanciato da `from` verso il manichino: danno fatto.
func _karma_shot(s: Scene, id: StringName, d: TrainingDummy) -> float:
	var sp := SpellDefinition.by_id(id)
	s.magic._targets_cache = s.dummies
	var from := s.hand()
	var aim := d.position + Vector3(0, 0.8, 0)
	s.magic._spawn_dart(sp, from, (aim - from).normalized())
	s.step(int(0.8 / DT))
	return TrainingDummy.MAX_HP - d.hp


func test_raggio_coerenza_cala_con_la_distanza() -> void:
	var sp := SpellDefinition.by_id(&"zoltraak")
	var got := []
	for dist: float in [3.0, 12.0]:
		var s := Scene.new()
		var d := TrainingDummy.new(Vector3(24.5, 4, 30.5 - dist))
		s.dummies.append(d)
		s.magic.rng.seed = 3
		got.append(_karma_shot(s, &"zoltraak", d))
	check(got[0] > 0.0 and got[1] > 0.0, "colpiti entrambi %s" % [got])
	check(got[0] > got[1] * 1.6, "vicino piu' forte (%s)" % [got])
	check(absf(MagicSystem.coherence(sp, 10.0) - sp.coh_floor) < 1e-4, "minimo della coerenza")


func test_karma_testa_che_si_ferma_sul_primo_corpo() -> void:
	# RMNDWN L29483: la testa viaggia a `speed` e si ferma sul primo corpo.
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 26.5))
	var b := TrainingDummy.new(Vector3(24.5, 4, 22.5))
	s.dummies.append_array([a, b])
	s.magic._targets_cache = s.dummies
	var sp := SpellDefinition.by_id(&"zoltraak")
	var from := s.hand()
	s.magic._spawn_dart(sp, from, (b.position + Vector3(0, 0.8, 0) - from).normalized())
	s.step(1)
	check_eq(a.hits, 0, "al primo passo non e' ancora arrivato (64 m/s)")
	s.step(int(0.3 / DT))
	check_eq(a.hits, 1, "colpito il primo")
	check_eq(b.hits, 0, "il secondo e' coperto: niente trapasso")


func test_karma_a_fine_portata_svanisce() -> void:
	var s := Scene.new()
	var sp := SpellDefinition.by_id(&"ago")
	s.magic._spawn_dart(sp, s.hand() + Vector3(0, 6, 0), Vector3(0, 0, -1))
	s.step(int(1.2 / DT))
	check(not s.events.any(func(e: Dictionary) -> bool: return e["type"] == "impact"), "nessun impatto a fine portata")
	check(s.events.any(func(e: Dictionary) -> bool: return e["type"] == "karma_fade"), "si dissolve")
	check(s.magic.darts.is_empty(), "sparito")


func test_roster_karma_come_rmndwn() -> void:
	var ago := SpellDefinition.by_id(&"ago")
	var spina := SpellDefinition.by_id(&"spina")
	var dardo := SpellDefinition.by_id(&"dardo")
	check_eq(ago.salvo_n, 1, "Ago: un colpo solo")
	check_eq(spina.salvo_n, 1, "Spina: un raggio solo")
	check(absf(dardo.r - 0.085) < 1e-5 and absf(dardo.body_len - 2.40) < 1e-5 and absf(dardo.decoh - 5.2) < 1e-5 and absf(dardo.coh_floor - 0.62) < 1e-5,
		"Dardo: r .085, fascio 2,40, decoerenza 5,2, minimo .62")
	check(SpellDefinition.by_id(&"fire_volley").fan_deg == 0.0, "la raffica di fuoco non si apre a ventaglio")


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
	# Il primo e' agganciato (centro del vuoto), il secondo sta nella sfera 1,8.
	s.dummies.append(TrainingDummy.new(Vector3(24.5, 4, 22.5)))
	var d := TrainingDummy.new(Vector3(25.9, 4, 22.5))
	s.dummies.append(d)
	s.cast_id(&"air_vacuum", 50)
	var c := s.magic.aim
	var d0 := Vector2(d.position.x - c.x, d.position.z - c.z).length()
	var best := d0
	var pushed := false
	for i in int(1.0 / DT):
		s.step(1)
		best = minf(best, Vector2(d.position.x - c.x, d.position.z - c.z).length())
		pushed = pushed or s.magic.has_status(d, "pushed")
	check(best < d0 - 0.5, "trascinato verso il centro (%f -> %f)" % [d0, best])
	check(pushed, "spinto")


func test_ascensione_non_solleva() -> void:
	# RMNDWN: nessun sollevamento, solo lo stagger (24) al contatto dopo 2,3 s.
	var s := Scene.new()
	var d := TrainingDummy.new(Vector3(24.5, 4, 20.5))
	s.dummies.append(d)
	s.cast_id(&"air_updraft", 70)
	var top := d.position.y
	for i in int(1.5 / DT):
		s.step(1)
		top = maxf(top, d.position.y)
	check(top < 4.05, "resta a terra (%f)" % top)
	check_eq(d.stagger_total, 0.0, "prima del contatto niente")
	s.step(int(1.2 / DT))
	check(absf(d.stagger_total - 24.0) < 1e-3, "stagger 24 al contatto (%f)" % d.stagger_total)
	check_eq(d.hp, TrainingDummy.MAX_HP, "nessun danno")


func test_diluvio_colpo_al_contatto_poi_continuo() -> void:
	# D-032: fuoco e acqua ad area colpiscono al contatto (40%) e poi di continuo
	# ogni .25 s per `tick_for` (il 60% spalmato): 1 + 12 colpi, danno totale ~42.
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 22.5))
	var b := TrainingDummy.new(Vector3(26.0, 4, 22.5))
	s.dummies.append_array([a, b])
	s.magic.rng.seed = 4
	s.cast_id(&"water_rain", 55)
	s.step(int(4.5 / DT))
	check_eq(a.hits, 13, "contatto + 12 colpi continui sul bersaglio")
	check_eq(b.hits, 13, "e sul vicino nella sfera")
	var tot := 0.0
	var full := 0
	for e in s.events:
		if e["type"] == "hit" and e["target"] == a:
			tot += float(e["damage"])
			if not e["quiet"]:
				full += 1
	check_eq(full, 1, "un solo colpo pieno (il contatto)")
	check(tot > 42.0 * 0.8 and tot < 42.0 * 1.35, "danno totale vicino a 42 (%f)" % tot)
	check(s.events.filter(func(e: Dictionary) -> bool: return e["type"] == "contact").size() == 1, "un contatto")


func test_aree_d_aria_un_colpo_solo() -> void:
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 22.5))
	s.dummies.append(a)
	s.cast_id(&"air_cyclone", 70)
	s.step(int(3.5 / DT))
	check_eq(a.hits, 1, "il ciclone colpisce una volta al contatto")


func test_bruciatura_manda_colpi_continui() -> void:
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	s.dummies.append(a)
	s.magic.apply_status(a, "burn")
	s.step(int(1.0 / DT))
	var dots := s.events.filter(func(e: Dictionary) -> bool: return e["type"] == "dot")
	check_eq(dots.size(), 2, "due tick di bruciatura in 1 s (ogni .45 s)")


func test_palla_di_fuoco_danno_pieno_nell_area() -> void:
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	var b := TrainingDummy.new(Vector3(25.7, 4, 25.2))
	s.dummies.append_array([a, b])
	s.magic.rng.seed = 9
	s.cast_id(&"fire_ball", 50)
	s.step(int(1.5 / DT))
	var dmg := {}
	for e in s.events:
		if e["type"] == "hit":
			dmg[e["target"]] = float(e["damage"])
	check(dmg.has(a) and dmg.has(b), "entrambi nell'area")
	check(float(dmg.get(b, 0.0)) > 58.0 * 0.85, "il vicino prende il danno pieno (%f)" % float(dmg.get(b, 0.0)))


func test_braci_non_feriscono() -> void:
	var s := Scene.new()
	var d := TrainingDummy.new(Vector3(24.5, 4, 29.3))
	s.dummies.append(d)
	s.cast_id(&"fire_embers", 40)
	s.step(int(2.0 / DT))
	check_eq(d.hp, TrainingDummy.MAX_HP, "difesa: niente danno")
	check_eq(d.hits, 0, "niente colpi")


func test_schiocco_alla_mira() -> void:
	# La frusta arriva al bersaglio a 6 m (contatto .44 s), primo corpo soltanto.
	var s := Scene.new()
	var d := TrainingDummy.new(Vector3(24.5, 4, 24.5))
	s.dummies.append(d)
	s.cast_id(&"air_lash", 20)
	check_eq(d.hits, 0, "non ancora")
	s.step(int(0.6 / DT))
	check_eq(d.hits, 1, "colpito a distanza")


func test_hitstop_breve_e_refrattario() -> void:
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	s.dummies.append(a)
	s.magic._targets_cache = s.dummies
	var fb := SpellDefinition.by_id(&"fire_bolt")
	s.magic.spell_hit(a, fb, 24.0, Vector2(0, -1), a.position)
	# .025 × famiglia .30 × fuoco .55 ≈ 4 ms (il vecchio port: 17 ms).
	check(absf(s.magic.hitstop - 0.025 * 0.30 * 0.55) < 1e-5, "hitstop %f" % s.magic.hitstop)
	s.magic.hitstop = 0.0
	s.magic.spell_hit(a, fb, 24.0, Vector2(0, -1), a.position)
	check_eq(s.magic.hitstop, 0.0, "nel refrattario (.16 s) niente hitstop")
	var juice := s.magic.events.filter(func(e: Dictionary) -> bool: return e["type"] == "hit" and e["juice"])
	check_eq(juice.size(), 1, "una sola scossa")
	s.step(int(0.2 / DT))
	s.magic.spell_hit(a, fb, 24.0, Vector2(0, -1), a.position)
	check(s.magic.hitstop > 0.0, "dopo il refrattario si")


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
	var first := _raised(s)
	check(first > 0 and first < 13, "sale dal suolo a strati (%d)" % first)
	s.step(int(0.8 / DT))
	var n := _raised(s)
	check_eq(n, 13, "5 × 3 blocchi con gli angoli in alto arrotondati")
	check_eq(s.magic.runtime.struct_cells().size(), 13, "celle della struttura")
	s.step(int(3.2 / DT))
	check_eq(_raised(s), 0, "crollata")
	check(s.events.any(func(e: Dictionary) -> bool: return e["type"] == "crumble"), "evento del crollo")


func test_colonna_solleva_il_giocatore() -> void:
	var s := Scene.new()
	var y0 := s.motor.position.y
	s.cast_id(&"earth_pillar", 45)
	check(s.motor.position.y < y0 + 2.0, "sale piano (%f)" % s.motor.position.y)
	s.step(int(1.4 / DT))
	check(s.motor.position.y >= y0 + 2.9, "in cima alla colonna (%f)" % s.motor.position.y)
	check(s.motor.on_ground, "ci sta sopra")
	s.step(int(1.6 / DT))
	check_eq(s.magic.runtime.struct_cells().size(), 0, "regge 2,8 s poi crolla")


func test_ventaglio_aria_sul_fuoco() -> void:
	var s := Scene.new()
	var a := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	var b := TrainingDummy.new(Vector3(26.5, 4, 25.5))
	s.dummies.append_array([a, b])
	s.magic._targets_cache = s.dummies
	s.magic.apply_status(a, "burn")
	s.magic.spell_hit(a, SpellDefinition.by_id(&"air_lash"), 10.0, Vector2(0, -1), a.position)
	check_eq(int(s.magic.statuses[a]["burn"]["st"]), 1, "la pila rispetta l'intervallo di .9 s")
	s.magic.statuses[a]["burn"]["since"] = 1.0
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
	check(absf(a.stagger_total - 20.0 * 1.8) < 1e-3, "stagger ×1,8 (%f)" % a.stagger_total)
	check(s.magic.has_status(a, "wet"), "il bagnato resta")
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


func test_coni_gemelli() -> void:
	# Si alzano ai lati del caster (±1 m), restano .45 s, poi partono e colpiscono.
	var s := Scene.new()
	var d := TrainingDummy.new(Vector3(24.5, 4, 24.5))
	s.dummies.append(d)
	s.cast_id(&"earth_twins", 30)
	var cones := s.magic.darts.filter(func(x: MagicSystem.Dart) -> bool: return x.spell.id == &"earth_twins")
	check_eq(cones.size(), 2, "due coni")
	if cones.size() == 2:
		var a: MagicSystem.Dart = cones[0]
		var b: MagicSystem.Dart = cones[1]
		check(a.hold > 0.0 and absf(a.p.x - b.p.x) > 1.6, "fermi ai lati (%f)" % absf(a.p.x - b.p.x))
	s.step(int(1.2 / DT))
	check_eq(d.hits, 2, "entrambi i coni colpiscono")
	var dmg := 0.0
	for e in s.events:
		if e["type"] == "hit" and e["target"] == d:
			dmg += float(e["damage"])
	check(dmg > 46.0 * 0.8 and dmg < 46.0 * 1.6, "danno dei due coni ~46 (%f)" % dmg)


## D-034: mira alla Brawl Stars. Il dardo va dove punta il dito, non sul
## bersaglio davanti; il tocco secco resta a mira automatica.
func test_mira_direzionata_sceglie_il_bersaglio_di_lato() -> void:
	var s := Scene.new()
	var front := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	var side := TrainingDummy.new(Vector3(30.5, 4, 30.5))
	s.dummies.append(front)
	s.dummies.append(side)
	s.magic.known[&"fire_bolt"] = true
	s.magic.equip(&"fire_bolt", 4)
	s.magic.select(4)
	s.magic.press_aimed(Vector2(1, 0), 1.0)
	s.magic.release()
	s.step(int(1.2 / DT))
	check(side.hits >= 1, "colpito il manichino a destra")
	check_eq(front.hits, 0, "quello davanti resta illeso")
	check_eq(s.magic.aim_dir, Vector2.ZERO, "direzione consumata dal lancio")


func test_tocco_secco_mira_automatica() -> void:
	var s := Scene.new()
	var front := TrainingDummy.new(Vector3(24.5, 4, 25.5))
	s.dummies.append(front)
	s.magic.known[&"fire_bolt"] = true
	s.magic.equip(&"fire_bolt", 4)
	s.magic.select(4)
	s.magic.press_aimed(Vector2.ZERO, 0.0)
	s.magic.release()
	s.step(int(1.2 / DT))
	check(front.hits >= 1, "mira automatica sul manichino davanti")


func test_mira_a_punto_segue_la_distanza() -> void:
	var sp := SpellDefinition.by_id(&"fire_columns")
	check_eq(sp.aim_shape(), "point", "colonne: cerchio sul punto")
	check_eq(SpellDefinition.by_id(&"fire_bolt").aim_shape(), "line", "dardo: fascia")
	var s := Scene.new()
	s.magic.known[&"fire_columns"] = true
	s.magic.equip(&"fire_columns", 4)
	s.magic.select(4)
	s.magic.press_aimed(Vector2(1, 0), 0.5)
	s.magic.release()
	s.step(int(0.5 / DT))
	var want := sp.aim_range() * 0.5
	var got := s.magic.aim - s.motor.position
	check(absf(got.x - want) < 1.0 and absf(got.z) < 1.0, "punto a %.1f m a destra (%s)" % [want, got])
