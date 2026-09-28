extends TestCase
## Integrazione: scena principale con fixture, costruzione e scavo di debug.


func _scene() -> GameRoot:
	var root: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root


func _hit_down(g: GameRoot, dx: float) -> VoxelQuery.VoxelHit:
	var eye := g.motor.eye_position()
	return VoxelQuery.raycast(g.world, g.catalog.opaque_table(), eye + Vector3(dx, 0, 0), Vector3.DOWN, 20.0)


func _hold(g: GameRoot, id: StringName, n: int = 1) -> void:
	g.items.inv.set_slot(1, ItemStack.new(id, n))
	g.items.select(1)


func test_avvio_allo_spawn() -> void:
	var g := _scene()
	check(g.world != null, "mondo caricato")
	check_eq(g.motor.position, Vector3(96.5, 28, 96.5), "giocatore allo spawn")
	check_eq(g.items.inv.get_slot(0).id, &"sword_wood", "spada di legno iniziale")
	check_eq(g._objects.list.size(), 10, "forzieri del tesoro nel mondo")
	g.free()


func test_costruisci_consuma_e_scava_in_debug() -> void:
	var g := _scene()
	_hold(g, &"stone", 2)
	var hit := _hit_down(g, 2.0)
	check(hit != null, "suolo davanti")
	var cell := hit.cell + hit.normal
	var rev := g.world.revision
	check(g.apply_action(hit), "piazzato: %s" % g.last_edit)
	check_eq(g.world.get_block(cell), BlockCatalog.STONE, "blocco nel mondo")
	check_eq(g.world.revision, rev + 1, "un solo edit")
	check_eq(g.items.inv.count(&"stone"), 1, "una pietra consumata")
	# Nello stesso punto non si posa due volte (la cella e' occupata).
	var hit2 := _hit_down(g, 2.0)
	check_eq(hit2.cell, cell, "ora il raggio colpisce il nuovo blocco")
	check(g.debug_dig(hit2), "rimosso: %s" % g.last_edit)
	check_eq(g.world.get_block(cell), BlockCatalog.AIR, "tornato aria")
	# Senza blocchi in mano non si posa niente.
	g.items.select(3)
	check(not g.apply_action(_hit_down(g, 2.0)), "mano vuota")
	g.free()


func test_non_si_costruisce_dentro_il_giocatore_ne_lontano() -> void:
	var g := _scene()
	_hold(g, &"stone", 5)
	var under := _hit_down(g, 0.0)
	var rev := g.world.revision
	check(not g.apply_action(under), "sovrapposto al giocatore")
	var far := _hit_down(g, 0.0)
	far.cell += Vector3i(12, 0, 0)
	check(not g.apply_action(far), "fuori portata")
	check_eq(g.world.revision, rev, "nessun edit")
	check_eq(g.items.inv.count(&"stone"), 5, "nulla consumato")
	# La torcia non e' solida: si puo' posare anche nella cella del giocatore.
	_hold(g, &"torch", 1)
	check(g.apply_action(under), "torcia sotto i piedi: %s" % g.last_edit)
	g.free()


func test_roccia_madre_non_scavabile() -> void:
	var g := _scene()
	var hit := VoxelQuery.VoxelHit.new()
	hit.cell = Vector3i(96, 0, 96)
	hit.id = BlockCatalog.BEDROCK
	g.motor.position = Vector3(96.5, 1, 96.5)
	check(not g.debug_dig(hit), "y=0 protetto")
	g.free()


func test_stazione_piazzata_dalla_mano() -> void:
	var g := _scene()
	_hold(g, &"workbench", 1)
	var hit := _hit_down(g, 2.0)
	check(g.apply_action(hit), "banco piazzato: %s" % g.last_edit)
	check(g._objects.at(hit.cell + hit.normal) != null, "banco nel mondo")
	check_eq(g.items.inv.count(&"workbench"), 0, "consumato")
	check(g._objects.stations_near(g.motor.position, 3.0).has("workbench"), "stazione vicina")
	g.free()


func test_l_arma_in_mano_decide_i_colpi() -> void:
	var g := _scene()
	g.items.select(0)
	g._refresh_held()
	check_eq(g.combat.weapon.id, &"sword", "spada di legno")
	_hold(g, &"pick_stone")
	g._refresh_held()
	check_eq(g.combat.weapon.id, &"tool", "attrezzo")
	g.items.select(4)
	g._refresh_held()
	check_eq(g.combat.weapon.id, &"fists", "mano vuota: pugni")
	g._apply_stats()
	check(absf(g.combat.damage_mult - 1.0) < 1e-4, "pugni senza bonus")
	g.free()


func test_nuovo_seme_sostituisce_il_mondo() -> void:
	var g := _scene()
	var old := g.world
	var session: int = g._runtime._session
	g.regenerate(42)
	var t0 := Time.get_ticks_msec()
	while g._gen_task >= 0 and Time.get_ticks_msec() - t0 < 60000:
		OS.delay_msec(50)
		g._poll_generation()
	check(g.world != old, "mondo sostituito")
	check_eq(g.world.world_seed, 42, "seme")
	check_eq(g.motor.world, g.world, "il giocatore usa il nuovo mondo")
	check_eq(g.motor.position, g.world.spawn_point(), "giocatore allo spawn")
	check(g._runtime._session > session, "nuova sessione dei chunk")
	check(g.world.climate.size() == 192 * 192 * 4, "clima dal generatore")
	g.free()


func test_interruttori_del_pannello() -> void:
	var g := _scene()
	g._on_button(&"dev_outline")
	check(not bool(g.toggles["outline"]), "contorni spenti")
	check_eq(g._touch.labels[&"dev_outline"], "Contorni OFF", "etichetta contorni")
	g._on_button(&"dev_outline")
	check(bool(g.toggles["outline"]), "contorni accesi")
	g._on_button(&"dev_shadow")
	check(not g._day.shadows_on, "ombre spente")
	g._on_button(&"dev_grass")
	check(not g._vegetation.grass_visible, "erba nascosta")
	g._on_button(&"dev_res")
	check_eq(g._view.size.y, 450 + 2, "righe 450 + bordo")
	check_eq(g._touch.labels[&"dev_res"], "Righe 450", "etichetta")
	g.free()


func test_pausa_e_preferenze_salvate() -> void:
	var g := _scene()
	g._on_button(&"dev_pause")
	check(g.paused and g.get_tree().paused, "in pausa")
	var p0 := g.motor.position
	g._physics_process(1.0 / 60.0)
	check_eq(g.motor.position, p0, "fermo in pausa")
	g._on_button(&"dev_pause")
	check(not g.get_tree().paused, "ripreso")
	# Righe e spigoli restano salvati (chiavi isoterra.rtH / isoterra.edges).
	g._on_button(&"dev_res")
	g._on_button(&"dev_edges")
	var rh := g.rt_height
	g.free()
	var g2 := _scene()
	check_eq(g2.rt_height, rh, "righe ricordate")
	check_eq(g2.toggles["edges"], false, "spigoli ricordati")
	g2._on_button(&"dev_edges")
	g2.free()


func test_ricette_predefinite_e_appunti() -> void:
	var a := AvatarRecipe.preset(0)
	var b := AvatarRecipe.preset(1)
	check(a.to_dict() != b.to_dict(), "due eroi diversi")
	check_eq(AvatarRecipe.from_json(b.to_json()).to_dict(), b.to_dict(), "JSON andata e ritorno")
	check(AvatarRecipe.from_json("non json") == null, "testo non valido")
	check(AvatarRecipe.from_json("{\"v\":9}") == null, "versione sconosciuta")
