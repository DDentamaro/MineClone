extends TestCase
## Oggetti, inventario, ricette, raccolta e bottino (M5).


func test_libreria_completa() -> void:
	check(ItemLibrary.get_item(&"pick_iron") != null, "piccone di ferro")
	check_eq(ItemLibrary.get_item(&"sword_gold").weapon, &"sword", "arma della spada d'oro")
	check_eq(ItemLibrary.get_item(&"chest_iron").slot, "chest", "corazza")
	check(ItemLibrary.get_item(&"chest_wood") == null, "niente armature di legno")
	for r in Recipes.all():
		check(ItemLibrary.get_item(r.out) != null, "prodotto %s" % r.out)
		for k: StringName in r.inputs:
			check(ItemLibrary.get_item(k) != null, "ingrediente %s di %s" % [k, r.out])
	for w: String in ItemLibrary.WEAPONS:
		check(WeaponLibrary.by_id(StringName(w)).id == StringName(w), "arma %s nella WeaponLibrary" % w)


func test_pile_e_niente_duplicazioni() -> void:
	var inv := Inventory.new(4)
	check_eq(inv.add_item(&"dirt", 100), 0, "100 terra entrano")
	check_eq(inv.count(&"dirt"), 100, "conteggio")
	check(inv.get_slot(0).count == 64 and inv.get_slot(1).count == 36, "pile da 64")
	check_eq(inv.add_item(&"stone", 200), 72, "restano fuori 72 pietre")
	check_eq(inv.total_items(), 228, "totale")
	Inventory.move(inv, 1, inv, 0)
	check_eq(inv.total_items(), 228, "unire non crea oggetti")
	Inventory.move(inv, 2, inv, 0)
	check_eq(inv.total_items(), 228, "scambiare non perde oggetti")
	check(not inv.remove(&"dirt", 101), "non si tolgono oggetti che non ci sono")
	check_eq(inv.count(&"dirt"), 100, "rimozione rifiutata senza effetti")
	check(inv.remove(&"dirt", 100), "tolte")
	check_eq(inv.count(&"dirt"), 0, "vuoto")


func test_equipaggiamento_non_si_impila() -> void:
	var inv := Inventory.new(4)
	var rng := RandomNumberGenerator.new()
	inv.add(Loot.make_equipment(&"sword_iron", 2, rng))
	inv.add(Loot.make_equipment(&"sword_iron", 0, rng))
	check(inv.get_slot(0) != null and inv.get_slot(1) != null, "due slot")
	check_eq((inv.get_slot(0).data["mods"] as Dictionary).size(), 2, "raro: due affissi")
	check(Loot.full_name(inv.get_slot(0)).begins_with("Spada di ferro "), "nome con suffisso: %s" % Loot.full_name(inv.get_slot(0)))


func test_ricette_tutto_o_niente() -> void:
	var rng := RandomNumberGenerator.new()
	var inv := Inventory.new(6)
	inv.add_item(&"wood", 5)
	var r := Recipes.find(&"workbench")
	check(Recipes.craft(r, inv, [], rng) != null, "banco a mano")
	check_eq(inv.count(&"wood"), 1, "legno consumato")
	var pick := Recipes.find(&"pick_wood")
	check(not Recipes.can_craft(pick, inv, []), "il piccone vuole il banco")
	inv.add_item(&"wood", 4)
	inv.add_item(&"stick", 2)
	check(Recipes.craft(pick, inv, ["workbench"], rng) != null, "piccone al banco")
	check_eq(inv.count(&"stick"), 0, "bastoni consumati")
	# Inventario pieno: il prodotto non entra, niente viene consumato.
	var full := Inventory.new(2)
	full.add_item(&"wood", 64)
	full.add_item(&"dirt", 64)
	var before := full.total_items()
	check(Recipes.craft(Recipes.find(&"stick"), full, [], rng) == null, "rifiutato se pieno")
	check_eq(full.total_items(), before, "nessuna perdita")


func test_regole_di_raccolta() -> void:
	var hand: ItemDefinition = null
	var wpick := ItemLibrary.get_item(&"pick_wood")
	var spick := ItemLibrary.get_item(&"pick_stone")
	check(absf(Harvest.break_time(BlockCatalog.STONE, hand) - 7.5) < 1e-4, "pietra a mani nude 1,5×5")
	check(absf(Harvest.break_time(BlockCatalog.STONE, wpick) - 1.125) < 1e-4, "pietra col piccone di legno")
	check(not Harvest.drops(BlockCatalog.STONE, hand), "niente pietra a mani nude")
	check(Harvest.drops(BlockCatalog.STONE, wpick), "pietra col piccone")
	check(not Harvest.drops(BlockCatalog.COPPER, wpick), "il rame vuole la pietra")
	check(Harvest.drops(BlockCatalog.COPPER, spick), "rame col piccone di pietra")
	check(not Harvest.drops(BlockCatalog.GOLD, ItemLibrary.get_item(&"pick_copper")), "l'oro vuole il ferro")
	check(Harvest.drops(BlockCatalog.DIRT, hand), "terra a mani nude")
	check_eq(Harvest.break_time(BlockCatalog.BEDROCK, spick), INF, "roccia madre")
	check(Harvest.tree_time(1.0, ItemLibrary.get_item(&"axe_wood")) < Harvest.tree_time(1.0, hand), "l'ascia abbatte prima")


func test_statistiche_dell_equipaggiamento() -> void:
	var eq := Equipment.new()
	var s := ItemStack.new(&"sword_gold")
	s.data = {"rarity": 1, "mods": {"strength": 0.1}}
	check(eq.equip(s) == s, "la spada non va nell'armatura")
	eq.equip(ItemStack.new(&"chest_iron"))
	var st := eq.stats(s)
	check(absf(st.melee - (1.2 + 0.1)) < 1e-4, "danno: oro 1,2 + forza 0,1 (%f)" % st.melee)
	check(st.defense > 3.0, "difesa della corazza di ferro")
	check_eq(Equipment.slot_for(ItemStack.new(&"head_copper")), "head", "slot dell'elmo")



func test_impugna_da_forziere_e_indossa() -> void:
	var items := PlayerItems.new()
	items.starter_kit()
	var box := Inventory.new(18)
	var rng := RandomNumberGenerator.new()
	box.add(Loot.make_equipment(&"hammer_iron", 0, rng))
	box.add(Loot.make_equipment(&"chest_iron", 0, rng))
	# Barra con la spada in 0 (scelta): il martello va nel primo slot libero e diventa quello in mano.
	check(items.wield_from(box, 0), "impugnato")
	check_eq(items.held().id, &"hammer_iron", "martello in mano")
	check_eq(items.selected, 1, "nel primo slot libero della barra")
	check_eq(items.inv.get_slot(0).id, &"sword_wood", "la spada resta in barra")
	check(box.get_slot(0) == null, "tolto dall'armeria")
	check(not items.wield_from(box, 1), "l'armatura non si impugna")
	check(items.wear_from(box, 1), "indossata")
	check_eq(items.equipment.get_slot("chest").id, &"chest_iron", "busto di ferro")
	check(items.stats().defense > 0.0, "difesa")
	# Barra piena: scambio con quello in mano, che torna al posto del nuovo.
	for k in PlayerItems.HOTBAR:
		if items.inv.get_slot(k) == null:
			items.inv.set_slot(k, ItemStack.new(&"stone", 5))
	box.add(Loot.make_equipment(&"spear_iron", 0, rng))
	var at := -1
	for k in box.size():
		if box.get_slot(k) != null and box.get_slot(k).id == &"spear_iron":
			at = k
	check(items.wield_from(box, at), "scambio")
	check_eq(items.held().id, &"spear_iron", "lancia in mano")
	check_eq(box.get_slot(at).id, &"hammer_iron", "il martello torna nell'armeria")


func test_confronto_delle_statistiche() -> void:
	var a := Equipment.Stats.new()
	var b := Equipment.Stats.new()
	b.defense = 2.5
	b.melee = 1.6
	var d := BagPanel.stat_diff(a, b)
	check_eq(d.size(), 2, "due differenze")
	check(d[0][1] and d[1][1], "entrambe migliori")
	check(String(d[1][0]).contains("1.60"), "danno mostrato come moltiplicatore (%s)" % d[1][0])
	check(BagPanel.stat_diff(b, b).is_empty(), "nessuna differenza")
