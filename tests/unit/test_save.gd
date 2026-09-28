extends TestCase
## Salvataggio (M5): formato, file rovinati, ciclo completo del gioco.


func _scene() -> GameRoot:
	var root: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root


func test_formato_e_verifica() -> void:
	var st := {"a": 1, "b": PackedByteArray([1, 2, 3]), "v": Vector3(1, 2, 3)}
	var bytes := SaveService.encode(st)
	check_eq(SaveService.decode(bytes), st, "andata e ritorno")
	var bad := bytes.duplicate()
	bad[bad.size() - 1] ^= 0xff
	check(SaveService.decode(bad).is_empty(), "byte rovinati rifiutati")
	check(SaveService.decode(PackedByteArray([1, 2, 3])).is_empty(), "file troppo corto")


func test_file_rovinato_usa_il_backup() -> void:
	SaveService.delete_all()
	check(SaveService.save({"n": 1}), "primo salvataggio")
	check(SaveService.save({"n": 2}), "secondo salvataggio")
	check_eq(int(SaveService.load_state()["n"]), 2, "il piu' recente")
	# Il file principale si rovina (crash a meta' scrittura su un altro sistema).
	var f := FileAccess.open(SaveService.path, FileAccess.WRITE)
	f.store_buffer(PackedByteArray([0, 1, 2]))
	f.close()
	check_eq(int(SaveService.load_state().get("n", -1)), 1, "si recupera il backup")
	# Un .tmp lasciato da una scrittura interrotta non conta.
	SaveService.save({"n": 3})
	var t := FileAccess.open(SaveService.path + ".tmp", FileAccess.WRITE)
	t.store_string("mezzo file")
	t.close()
	check_eq(int(SaveService.load_state()["n"]), 3, "il .tmp non disturba")
	SaveService.delete_all()


func test_raccogli_costruisci_chiudi_riapri() -> void:
	SaveService.delete_all()
	var g := _scene()
	# Blocco posato, oggetto piazzato con contenuto, albero abbattuto, zaino, armatura.
	g.items.inv.set_slot(1, ItemStack.new(&"stone", 3))
	g.items.select(1)
	var eye := g.motor.eye_position()
	var hit := VoxelQuery.raycast(g.world, g.catalog.opaque_table(), eye + Vector3(2, 0, 0), Vector3.DOWN, 20.0)
	check(g.apply_action(hit), "pietra posata")
	var cell := hit.cell + hit.normal
	var hit2 := VoxelQuery.raycast(g.world, g.catalog.opaque_table(), eye + Vector3(-2, 0, 0), Vector3.DOWN, 20.0)
	var chest := g._objects.place("chest", hit2.cell + hit2.normal)
	chest.inv.add_item(&"gold_ingot", 4)
	g._vegetation.flush()
	var tree := g._vegetation.spots[5]
	g._vegetation.kill_tree(tree)
	g.items.equipment.equip(ItemStack.new(&"head_iron"))
	g.checkpoint = Vector3(90.5, 28, 90.5)
	var blocks_before := g.world.blocks.duplicate()
	var items_before := JSON.stringify(g.items.to_dict())
	check(g.save_game(), "salvato: %s" % g.last_edit)
	g.free()
	var g2 := _scene()
	g2._vegetation.flush()
	g2._process(0.016)
	check_eq(g2.world.get_block(cell), BlockCatalog.STONE, "la pietra c'e' ancora")
	check(g2.world.blocks == blocks_before, "tutti i blocchi uguali")
	check_eq(JSON.stringify(g2.items.to_dict()), items_before, "zaino ed equipaggiamento uguali")
	var c2 := g2._objects.at(chest.cell)
	check(c2 != null and c2.type == "chest", "forziere al suo posto")
	check(c2 != null and c2.inv.count(&"gold_ingot") == 4, "col suo contenuto")
	check(g2._vegetation.spots[5].dead, "albero ancora abbattuto")
	check_eq(g2.checkpoint, Vector3(90.5, 28, 90.5), "falò ricordato")
	check_eq(g2._objects.list.filter(func(o: WorldObjects.Obj) -> bool: return o.type == "treasure").size(), 10, "tesori non duplicati")
	g2.free()
	SaveService.delete_all()


func test_strutture_delle_magie_non_si_salvano() -> void:
	var w := TestWorlds.flat(4)
	var c := Vector3i(5, 4, 5)
	TestWorlds.fill(w, c, c, BlockCatalog.DIRT)
	var skip: Array[Vector3i] = [c]
	var d := SaveService.world_state(w, skip)
	var b: PackedByteArray = d["blocks"]
	check_eq(int(b[w.index(c.x, c.y, c.z)]), BlockCatalog.AIR, "salvata come aria")
	check_eq(w.get_block(c), BlockCatalog.DIRT, "il mondo in gioco non cambia")
