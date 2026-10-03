extends TestCase
## Integrazione: scena principale con fixture, costruzione e scavo di debug.


func test_pausa_e_zaino_azzerano_gli_input() -> void:
	var g := _scene()
	g._light_key = true
	g._jump_key = true
	g._hold_active = true
	g.combat.press_heavy()
	g.set_paused(true)
	check(g.paused and g._touch.blocked, "la pausa ferma gioco e tocchi")
	check_eq(g._session.page, "pause", "menu di pausa vero")
	check(not g._light_key and not g._jump_key and not g._hold_active, "nessun input di gioco tenuto")
	check(not g.combat.heavy_held and g.combat.buffer == &"", "nessun colpo forte in coda")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_J
	event.pressed = true
	g._unhandled_input(event)
	check_eq(g.combat.buffer, &"", "in pausa il tasto colpo e' ignorato")
	g.set_paused(false)
	g.open_bag()
	g._unhandled_input(event)
	check_eq(g.combat.buffer, &"", "nello zaino il tasto colpo e' ignorato")
	g._bag.close()
	check(not g.get_tree().paused and not g._touch.blocked, "chiudere lo zaino riprende il gioco")
	g.free()


func test_diario_salvato_col_mondo_e_banco_posato() -> void:
	var g := _scene()
	g.journal.record("harvest", 2)
	_hold(g, &"workbench")
	check(g.apply_action(_hit_down(g, 2.0)), "banco posato")
	check_eq(g.journal.counts.get("build", 0), 1.0, "la posa conta per l'obiettivo")
	var state := g.make_save_state()
	check_eq(state["journal"]["harvest"], 2.0, "avanzamento parziale nel salvataggio")
	var decoded := SaveService.decode(SaveService.encode(state))
	check_eq(decoded["journal"], state["journal"], "il diario sopravvive alla codifica")
	g.free()


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
	# D-054: partita nuova nell'arena, sul ring a sud dell'armeria.
	check(Arena.has(g.world), "arena nel mondo")
	check_eq(g.motor.position, g.world.spawn_point(), "giocatore allo spawn")
	check_eq(g.motor.position, Arena.spawn_in(g.world), "spawn sul ring")
	check_eq(g.world.get_block_xyz(floori(g.motor.position.x), floori(g.motor.position.y) - 1, floori(g.motor.position.z)), BlockCatalog.MARBLE, "in piedi sul marmo")
	check_eq(g.items.inv.get_slot(0).id, &"sword_wood", "spada di legno iniziale")
	check_eq(g._objects.list.filter(func(o: WorldObjects.Obj) -> bool: return o.type == "treasure").size(), 10, "forzieri del tesoro nel mondo")
	var arm := g._objects.list.filter(func(o: WorldObjects.Obj) -> bool: return o.type == "armory")
	check_eq(arm.size(), 1, "armeria")
	if arm.size() == 1:
		var o: WorldObjects.Obj = arm[0]
		check_eq(o.cell, g.world.arena, "armeria al centro dell'arena")
		check_eq(o.inv.total_items(), WorldObjects.ARMORY_ITEMS.size(), "armeria piena")
		check_eq(o.shown.size(), 5, "le cinque armi esposte (col bastone), ben separate")
	var stands := g._objects.list.filter(func(o: WorldObjects.Obj) -> bool: return o.type == "armor_stand")
	check_eq(stands.size(), 2, "espositori del cuoio e del ferro")
	for st: WorldObjects.Obj in stands:
		check(st.rig != null, "manichino sull'espositore")
		check(st.inv.total_items() >= 4, "set completo sull'espositore")
	check_eq(g._dummies.dummies.size(), 1, "un avversario nell'arena")
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


## D-037: in prima persona il corpo sparisce (resta l'ombra), si vede solo la
## mano con l'oggetto, il mirino compare, il corpo guarda
## dove guarda la camera e il colpo parte lungo lo sguardo anche camminando di lato.
func test_prima_persona_nel_gioco() -> void:
	var g := _scene()
	g._camera_rig.set_mode(CameraRig.Mode.FPS)
	g._camera_rig.yaw_target = 1.2
	for i in 20:
		g._process(1.0 / 60.0)
		g._physics_process(1.0 / 60.0)
	for gi in g._avatar.rig._instances:
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			check(false, "corpo invisibile alla camera (solo ombra): %s" % gi.name)
			break
	check(g._fpv.visible and g._fpv.grip_count() == 1, "si vede solo la mano con l'oggetto")
	check(g._touch.crosshair, "mirino")
	check(absf(wrapf(g._avatar.facing - 1.2, -PI, PI)) < 0.05, "l'eroe guarda dove guarda la camera (%.2f)" % g._avatar.facing)
	g._refresh_labels()
	check_eq(g._touch.labels[&"camera"], "1ª p.", "etichetta del pulsante")
	g.combat.aim_view = true
	g.combat.facing = 1.2
	g.combat._start_attack(g.combat.weapon.light_start, g.motor, [], Vector2(1, 0))
	check(absf(wrapf(g.combat.facing - 1.2, -PI, PI)) < 1e-4, "colpo lungo lo sguardo, non verso lo stick")
	g._camera_rig.set_mode(CameraRig.Mode.ISO)
	g._process(1.0 / 60.0)
	check(not g._touch.crosshair and not g._fpv.visible, "in isometrica niente mirino ne' mano")
	for gi in g._avatar.rig._instances:
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			check(false, "in isometrica il corpo torna visibile: %s" % gi.name)
			break
	g.free()
