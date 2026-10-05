extends TestCase
## Arena di partenza, set d'armatura come oggetti, espositori (D-054).


func _arena_world() -> WorldData:
	var cat := BlockCatalog.load_default()
	var w := WorldFactory.from_fixture(cat)
	Arena.stamp(w, cat)
	return w


func test_ring_di_marmo_e_colonne() -> void:
	var w := _arena_world()
	check(Arena.has(w), "arena stampata")
	var c := w.arena
	var floor_y := c.y - 1
	var marble := 0
	var wet := 0
	for z in range(c.z - Arena.HALF, c.z + Arena.HALF + 1):
		for x in range(c.x - Arena.HALF, c.x + Arena.HALF + 1):
			marble += 1 if w.get_block_xyz(x, floor_y, z) == BlockCatalog.MARBLE else 0
			for y in range(floor_y, floor_y + 3):
				wet += 1 if w.get_block_xyz(x, y, z) == BlockCatalog.WATER or w.fluid[w.index(x, y, z)] > 0 else 0
	var side := Arena.HALF * 2 + 1
	check_eq(marble, side * side, "ring pieno di marmo")
	check_eq(wet, 0, "niente acqua sul ring")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var x: int = c.x + sx * Arena.HALF
			var z: int = c.z + sz * Arena.HALF
			check_eq(w.get_block_xyz(x, floor_y + Arena.PILLAR, z), BlockCatalog.MARBLE, "colonna d'angolo")
			check_eq(w.surface_height(x, z), floor_y + Arena.PILLAR, "superficie della colonna")
	# Fuori dal ring la piana brulla un blocco piu' in basso.
	check_eq(w.get_block_xyz(c.x + Arena.HALF + 2, floor_y - 1, c.z), BlockCatalog.DIRT, "piana di terra attorno")
	check_eq(w.get_block_xyz(c.x + Arena.HALF + 2, floor_y, c.z), BlockCatalog.AIR, "ring rialzato di un blocco")
	var sp := w.spawn_point()
	check_eq(w.get_block_xyz(floori(sp.x), floori(sp.y) - 1, floori(sp.z)), BlockCatalog.MARBLE, "si nasce sul ring")


func test_armature_come_oggetti() -> void:
	for id in [&"head_leather", &"head_leather_hood", &"chest_leather", &"legs_leather", &"feet_leather"]:
		var d := ItemLibrary.get_item(id)
		check(d != null and d.kind == ItemDefinition.Kind.ARMOR, "%s esiste" % id)
		if d != null:
			check(d.armor_style.begins_with("leather"), "%s: forma di cuoio" % id)
			check(d.defense < ItemLibrary.get_item(StringName("%s_copper" % d.slot)).defense, "%s: piu' leggero del rame" % id)
	check_eq(ItemLibrary.get_item(&"head_leather").armor_style, "leather_cap", "casco")
	check_eq(ItemLibrary.get_item(&"head_leather_hood").armor_style, "leather_hood", "cappuccio")
	for s in Equipment.SLOTS:
		check_eq(ItemLibrary.get_item(StringName("%s_iron" % s)).armor_style, "iron", "%s di ferro da cavaliere" % s)
		check_eq(ItemLibrary.get_item(StringName("%s_copper" % s)).armor_style, "", "%s di rame come prima" % s)
	var eq := Equipment.new()
	eq.equip(ItemStack.new(&"head_leather_hood"))
	eq.equip(ItemStack.new(&"chest_iron"))
	var st := eq.styles()
	check_eq(st["head"], "leather_hood", "forma della testa indossata")
	check_eq(st["chest"], "iron", "forma del busto indossato")
	check_eq(st["legs"], "", "slot vuoto")
	check_eq(eq.colors()["head"], ItemLibrary.LEATHER, "colore del cuoio")


func test_espositore_veste_il_manichino() -> void:
	var w := _arena_world()
	var objs := WorldObjects.new()
	objs.world = w
	objs.place_arena(w.arena)
	var stands := objs.list.filter(func(o: WorldObjects.Obj) -> bool: return o.type == "armor_stand")
	check_eq(stands.size(), 3, "tre espositori (cuoio, ferro, maglia)")
	for o: WorldObjects.Obj in stands:
		check(o.rig != null, "manichino")
		check_eq(o.rig._armor_colors.size(), 4, "veste i quattro pezzi")
		# Si toglie il busto: il manichino resta senza.
		for i in o.inv.size():
			var s := o.inv.get_slot(i)
			if s != null and s.def().slot == "chest":
				o.inv.take(i)
				break
		check(not o.rig._armor_colors.has("chest"), "busto tolto dal manichino")
	check(objs.pick_up(stands[0], Inventory.new(30)) == false, "l'espositore non si raccoglie")
	objs.free()
