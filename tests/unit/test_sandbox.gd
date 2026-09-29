extends TestCase
## Raccolta, oggetti piazzati e forzieri (M5).


func test_interaction_requires_reach_and_clear_line() -> void:
	var a := _setup()
	var w: WorldData = a[0]
	var objs: WorldObjects = a[2]
	var s := SandboxController.new()
	s.world = w
	s.catalog = BlockCatalog.load_default()
	s.objects = objs
	s.motor = PlayerMotor.new(w)
	s.motor.place_at(Vector3(8.5, 4, 8.5))
	var near := objs.place("chest", Vector3i(10, 4, 8))
	var far := objs.place("chest", Vector3i(20, 4, 8))
	check(s.can_use(near), "near chest accessible")
	check(not s.can_use(far), "remote chest rejected")
	check_eq(s.nearest_usable(), near, "context prompt picks usable chest")
	TestWorlds.fill(w, Vector3i(9, 4, 8), Vector3i(9, 6, 8), BlockCatalog.STONE)
	check(not s.can_use(near), "cannot interact through a wall")
	check(s.nearest_usable() == null, "no prompt through a wall")
	check(not s.can_use(null), "missing object is safe")
	objs.free()


func _setup(ground: int = BlockCatalog.STONE) -> Array:
	var w := TestWorlds.flat(4, 32, 16, 32)
	TestWorlds.fill(w, Vector3i(0, 3, 0), Vector3i(31, 3, 31), ground)
	var cat := BlockCatalog.load_default()
	var h := Harvester.new()
	h.world = w
	h.catalog = cat
	h.edits = WorldEditService.new(w, cat)
	h.items = PlayerItems.new()
	var objs := WorldObjects.new()
	objs.world = w
	h.objects = objs
	return [w, h, objs]


func _dig(h: Harvester, cell: Vector3i, secs: float) -> bool:
	var eye := Vector3(cell) + Vector3(0.5, 2.2, 1.5)
	var dir := (Axes.cell_center(cell) - eye).normalized()
	for i in int(secs * 60.0):
		var t := h.pick(eye, dir, eye)
		if h.step(1.0 / 60.0, t) >= 1.0:
			return true
	return false


func test_piccone_rompe_la_pietra() -> void:
	var a := _setup()
	var w: WorldData = a[0]
	var h: Harvester = a[1]
	h.items.inv.add(Loot.make_equipment(&"pick_wood", 0, RandomNumberGenerator.new()))
	h.items.select(0)
	var wear0 := h.items.held().wear()
	check(not _dig(h, Vector3i(10, 3, 10), 1.0), "non ancora rotta dopo 1 s (serve 1,125 s)")
	check(_dig(h, Vector3i(10, 3, 10), 0.3), "rotta poco dopo")
	check_eq(w.get_block(Vector3i(10, 3, 10)), BlockCatalog.AIR, "blocco tolto")
	check_eq(h.items.inv.count(&"stone"), 1, "pietra nello zaino")
	check_eq(h.items.held().wear(), wear0 - 1, "usura del piccone")
	(a[2] as Node).free()


func test_a_mani_nude_niente_pietra() -> void:
	var a := _setup()
	var h: Harvester = a[1]
	check(_dig(h, Vector3i(10, 3, 10), 8.0), "rotta a mani nude (7,5 s)")
	check_eq(h.items.inv.count(&"stone"), 0, "ma senza bottino")
	(a[2] as Node).free()


func test_zaino_pieno_non_rompe() -> void:
	var a := _setup(BlockCatalog.DIRT)
	var w: WorldData = a[0]
	var h: Harvester = a[1]
	for i in 30:
		h.items.inv.add_item(&"stone", 64)
	check(not _dig(h, Vector3i(10, 3, 10), 3.0), "non si rompe (terra a mani nude: 2,5 s)")
	check_eq(w.get_block(Vector3i(10, 3, 10)), BlockCatalog.DIRT, "blocco intatto")
	check(h.events.any(func(e: Dictionary) -> bool: return e["type"] == "full"), "avviso zaino pieno")
	(a[2] as Node).free()


func test_oggetti_piazzati_e_raccolti() -> void:
	var a := _setup()
	var objs: WorldObjects = a[2]
	var h: Harvester = a[1]
	var o := objs.place("chest", Vector3i(8, 4, 8))
	check(o != null, "forziere piazzato")
	check(objs.place("workbench", Vector3i(8, 4, 8)) == null, "cella occupata")
	check(objs.place("workbench", Vector3i(8, 6, 8)) == null, "niente a mezz'aria")
	o.inv.add_item(&"iron_ingot", 5)
	var hit := objs.pick(Vector3(8.5, 8, 8.5), Vector3.DOWN)
	check(hit == o, "colpito dal raggio")
	check(objs.pick_up(o, h.items.inv), "raccolto")
	check_eq(h.items.inv.count(&"chest"), 1, "forziere nello zaino")
	check_eq(h.items.inv.count(&"iron_ingot"), 5, "col contenuto")
	check_eq(objs.list.size(), 0, "tolto dal mondo")
	objs.free()


func test_forziere_non_si_raccoglie_se_non_entra() -> void:
	var a := _setup()
	var objs: WorldObjects = a[2]
	var inv := Inventory.new(1)
	var o := objs.place("chest", Vector3i(8, 4, 8))
	o.inv.add_item(&"stone", 3)
	check(not objs.pick_up(o, inv), "rifiutato")
	check_eq(objs.list.size(), 1, "ancora al suo posto")
	check_eq(o.inv.count(&"stone"), 3, "contenuto intatto")
	check_eq(inv.total_items(), 0, "zaino intatto")
	objs.free()


func test_tesori_deterministici() -> void:
	var w := WorldFactory.from_fixture(BlockCatalog.load_default())
	var o1 := WorldObjects.new()
	o1.world = w
	o1.scatter_treasure(w.world_seed, w.spawn_point())
	var o2 := WorldObjects.new()
	o2.world = w
	o2.scatter_treasure(w.world_seed, w.spawn_point())
	check_eq(o1.list.size(), 10, "dieci tesori")
	check_eq(JSON.stringify(o1.to_array()), JSON.stringify(o2.to_array()), "stesso seme, stessi tesori")
	var has_eq := false
	for s in o1.list[0].inv.slots:
		if s != null and s.def().is_equipment():
			has_eq = true
	check(has_eq, "equipaggiamento nel bottino")
	check(not o1.pick_up(o1.list[0], Inventory.new(30)), "il tesoro non si raccoglie")
	o1.free()
	o2.free()
