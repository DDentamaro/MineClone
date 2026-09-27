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

	func hand() -> Vector3:
		return motor.position + Vector3(-0.2, 1.1, -0.3)

	func step(n: int) -> void:
		for i in n:
			magic.step(DT, motor, dummies, 0.0, hand())
			for d in dummies:
				d.step(DT, world)
			events.append_array(magic.events)
			magic.events.clear()

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


func test_mana_raccolta_e_rilascio() -> void:
	var s := Scene.new()
	s.magic.select(0)
	s.magic.press()
	s.step(1)
	check_eq(s.magic.phase, MagicSystem.Phase.GATHER, "raccolta")
	check(absf(s.magic.mana - (MagicSystem.MANA_MAX - 14.0)) < 0.5, "costo pagato (%f)" % s.magic.mana)
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


func test_mana_insufficiente() -> void:
	var s := Scene.new()
	s.magic.mana = 5.0
	s.magic.press()
	s.magic.release()
	s.step(1)
	check_eq(s.magic.phase, MagicSystem.Phase.NONE, "niente raccolta")
	check(s.texts().has("MANA"), "avviso")


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
