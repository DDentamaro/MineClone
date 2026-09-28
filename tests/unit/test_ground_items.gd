extends TestCase
## Oggetti a terra (D-028): getta, cade, si raccoglie dopo 1 s, sparisce dopo 5 minuti.

const DT := 1.0 / 60.0


func _setup() -> Array:
	var w := TestWorlds.flat(4)
	var g := GroundItems.new()
	g.world = w
	return [w, g]


func test_getta_cade_e_si_riprende() -> void:
	var s := _setup()
	var g: GroundItems = s[1]
	var inv := Inventory.new(30)
	var player := Vector3(10.5, 4, 10.5)
	g.drop(Loot.make_equipment(&"sword_iron", 2, RandomNumberGenerator.new()), player, Vector3(0, 0, -1))
	var picked: Array[ItemStack] = []
	for i in int(0.8 / DT):
		picked.append_array(g.step(DT, player, inv))
	check(picked.is_empty(), "non si riprende subito")
	check(g.list[0].landed, "a terra (%s)" % g.list[0].p)
	check(absf(g.list[0].p.y - 4.0) < 0.01, "sul suolo")
	check(g.list[0].p.z < player.z - 0.5, "davanti al giocatore")
	# Il giocatore ci passa sopra.
	var at := g.list[0].p
	for i in int(1.0 / DT):
		picked.append_array(g.step(DT, at, inv))
	check_eq(picked.size(), 1, "raccolto")
	check(g.list.is_empty(), "sparito da terra")
	check_eq(inv.count(&"sword_iron"), 1, "nello zaino")
	check_eq(inv.get_slot(0).rarity(), 2, "rarita' conservata")
	g.free()


func test_zaino_pieno_resta_a_terra() -> void:
	var s := _setup()
	var g: GroundItems = s[1]
	var inv := Inventory.new(1)
	inv.add_item(&"stone", 64)
	var p := Vector3(10.5, 4, 10.5)
	g.drop(ItemStack.new(&"wood", 5), p, Vector3.FORWARD)
	for i in int(2.0 / DT):
		g.step(DT, g.list[0].p, inv)
	check_eq(g.list.size(), 1, "resta a terra")
	check_eq(g.list[0].stack.count, 5, "intatto")
	g.free()


func test_sparisce_dopo_cinque_minuti() -> void:
	var s := _setup()
	var g: GroundItems = s[1]
	g.drop(ItemStack.new(&"wood", 3), Vector3(10.5, 4, 10.5), Vector3.FORWARD)
	for i in 299:
		g.step(1.0, Vector3(1.5, 4, 1.5), null)
	check_eq(g.list.size(), 1, "ancora li' a 299 s")
	g.step(1.5, Vector3(1.5, 4, 1.5), null)
	check(g.list.is_empty(), "sparito dopo 300 s")
	g.free()


func test_salvataggio() -> void:
	var s := _setup()
	var g: GroundItems = s[1]
	g.drop(ItemStack.new(&"wood", 3), Vector3(10.5, 4, 10.5), Vector3.FORWARD)
	g.step(10.0, Vector3(1.5, 4, 1.5), null)
	var a := g.to_array()
	var g2 := GroundItems.new()
	g2.world = s[0]
	g2.load_array(SaveService.decode(SaveService.encode({"g": a}))["g"])
	check_eq(g2.list.size(), 1, "ripristinato")
	check_eq(g2.list[0].stack.count, 3, "quantita'")
	check(absf(g2.list[0].age - g.list[0].age) < 1e-3, "eta' conservata: il conto dei 5 minuti continua")
	g.free()
	g2.free()
