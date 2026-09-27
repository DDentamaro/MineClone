extends TestCase
## Integrazione: scena principale con fixture, costruzione e scavo di debug.


func _scene() -> GameRoot:
	var root: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root


func _hit_down(g: GameRoot, dx: float) -> VoxelQuery.VoxelHit:
	var eye := g.motor.eye_position()
	return VoxelQuery.raycast(g.world, g.catalog.opaque_table(), eye + Vector3(dx, 0, 0), Vector3.DOWN, 20.0)


func test_avvio_allo_spawn() -> void:
	var g := _scene()
	check(g.world != null, "mondo caricato")
	check_eq(g.motor.position, Vector3(96.5, 28, 96.5), "giocatore allo spawn")
	check_eq(g.action_mode, GameRoot.ActionMode.EXPLORE, "modo iniziale")
	g.free()


func test_costruisci_e_scava() -> void:
	var g := _scene()
	g.action_mode = GameRoot.ActionMode.BUILD
	g._select_block(BlockCatalog.STONE)
	var hit := _hit_down(g, 2.0)
	check(hit != null, "suolo davanti")
	var cell := hit.cell + hit.normal
	var rev := g.world.revision
	check(g.apply_action(hit), "piazzato: %s" % g.last_edit)
	check_eq(g.world.get_block(cell), BlockCatalog.STONE, "blocco nel mondo")
	check_eq(g.world.revision, rev + 1, "un solo edit")
	# Nello stesso punto non si posa due volte (la cella e' occupata).
	var hit2 := _hit_down(g, 2.0)
	check_eq(hit2.cell, cell, "ora il raggio colpisce il nuovo blocco")
	g.action_mode = GameRoot.ActionMode.DIG_DEBUG
	check(g.apply_action(hit2), "rimosso: %s" % g.last_edit)
	check_eq(g.world.get_block(cell), BlockCatalog.AIR, "tornato aria")
	g.free()


func test_non_si_costruisce_dentro_il_giocatore_ne_lontano() -> void:
	var g := _scene()
	g.action_mode = GameRoot.ActionMode.BUILD
	var under := _hit_down(g, 0.0)
	var rev := g.world.revision
	check(not g.apply_action(under), "sovrapposto al giocatore")
	var far := _hit_down(g, 0.0)
	far.cell += Vector3i(12, 0, 0)
	check(not g.apply_action(far), "fuori portata")
	check_eq(g.world.revision, rev, "nessun edit")
	# La torcia non e' solida: si puo' posare anche nella cella del giocatore.
	g._select_block(BlockCatalog.TORCH)
	check(g.apply_action(under), "torcia sotto i piedi: %s" % g.last_edit)
	g.free()


func test_roccia_madre_non_scavabile() -> void:
	var g := _scene()
	g.action_mode = GameRoot.ActionMode.DIG_DEBUG
	var hit := VoxelQuery.VoxelHit.new()
	hit.cell = Vector3i(96, 0, 96)
	hit.id = BlockCatalog.BEDROCK
	g.motor.position = Vector3(96.5, 1, 96.5)
	check(not g.apply_action(hit), "y=0 protetto")
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
