class_name GameRoot
extends Node
## Radice della sessione: possiede mondo, attori e sessione.
## M1: mondo fixture renderizzato a chunk, giocatore con collisioni voxel,
## camera isometrica (terza persona opzionale), stick touch ed edit di debug.
## M4: eroe animato, cinque armi, combattimento con manichini d'allenamento.

## Portata di costruzione: game.reach + 1 dal punto occhi (riga 7099).
const REACH := 7.5
## Pannello sviluppatore: gli interruttori attivi del prototipo (riga 7855–7870).
const DEV_BUTTONS := [
	[&"dev_close", "Chiudi ✕"], [&"dev_seed", "Nuovo seme"], [&"dev_lake", "Al lago"], [&"dev_time", "Ora +3h"], [&"dev_res", "Righe"], [&"dev_outline", "Contorni"],
	[&"dev_edges", "Spigoli"], [&"dev_paint", "Dipinto"], [&"dev_dither", "Dither"], [&"dev_rays", "Raggi"],
	[&"dev_grass", "Erba"], [&"dev_shadow", "Ombre"], [&"dev_clouds", "Nubi"], [&"dev_dummies", "Manichini"],
	[&"dev_rot_l", "⟲ Ruota"], [&"dev_rot_r", "⟳ Ruota"], [&"dev_zin", "Zoom +"], [&"dev_zout", "Zoom −"],
	[&"dev_hitbox", "Hitbox"], [&"dev_pause", "Pausa"], [&"dev_digdebug", "Scava debug"], [&"dev_kit", "Kit di prova"], [&"dev_home", "Al falò"], [&"dev_save", "Salva"], [&"dev_load", "Carica"],
]
## Pulsanti del pannello da tenere premuti (rotazione continua come rot-l/rot-r).
const DEV_HOLD: Array[StringName] = [&"dev_rot_l", &"dev_rot_r"]
## Editor dell'eroe: un pulsante per parametro della ricetta.
const HERO_BUTTONS := [[&"hero_skin", "skin"], [&"hero_hair", "hair"], [&"hero_hairStyle", "hairStyle"], [&"hero_hat", "hat"],
	[&"hero_eyes", "eyes"], [&"hero_brows", "brows"], [&"hero_mouth", "mouth"], [&"hero_beard", "beard"], [&"hero_face", "face"],
	[&"hero_shirt", "shirt"], [&"hero_pants", "pants"], [&"hero_sleeves", "sleeves"], [&"hero_legs", "legs"], [&"hero_back", "back"],
	[&"hero_belt", "belt"], [&"hero_preset", ""], [&"hero_random", ""],
	[&"hero_copy", ""], [&"hero_paste", ""], [&"hero_close", ""]]
const HERO_LABELS := {&"hero_preset": "Eroe 1/2", &"hero_random": "Casuale", &"hero_copy": "Copia ricetta",
	&"hero_paste": "Incolla ricetta", &"hero_close": "Chiudi"}
const WEAPONS: Array[StringName] = [&"fists", &"sword", &"spear", &"hammer", &"greatsword", &"staff"]

@onready var _status: Label = %Status
@onready var _view: SubViewport = $WorldView
@onready var _screen: TextureRect = %Screen
@onready var _runtime: WorldRuntime = $WorldView/WorldRuntime
@onready var _camera_rig: CameraRig = $WorldView/CameraRig
@onready var _avatar: PlayerAvatar = $WorldView/Player
@onready var _day: DayCycle = $WorldView/DayCycle
@onready var _vegetation: VegetationRuntime = $WorldView/Vegetation
@onready var _water: FluidRuntime = $WorldView/Water
@onready var _grains: Grains = $WorldView/Grains
@onready var _water_fx: WaterEffects = $WorldView/WaterEffects
@onready var _touch: TouchControls = %TouchControls
@onready var _dummies: TrainingGround = $WorldView/Dummies
@onready var _objects: WorldObjects = $WorldView/Objects

var world: WorldData
var catalog: BlockCatalog
var edits: WorldEditService
var motor: PlayerMotor
## Scavo di debug: un tocco toglie il blocco senza attrezzi ne' bottino (pannello ⚙).
var dig_debug := false
var sandbox := SandboxController.new()
var items: PlayerItems = sandbox.items
var _held_key := ""
var _hold_active := false
var _hold_pos := Vector2.ZERO
var _mine_cycle := -1.0
var _stats := Equipment.Stats.new()
var _bag: BagPanel
var journal := ExpeditionJournal.new()
var _session: SessionOverlay
var _last_notice := ""
var _hud_tick := 0.0
## Oggetti gettati a terra (D-028).
var ground := GroundItems.new()
var last_edit := ""
var combat: CombatController
## Aggancio del bersaglio (D-035) e il suo triangolo rosso.
var lock := LockOn.new()
var _lock_marker: LockMarker
## Prima persona (D-037): la sola mano con l'oggetto, figlia della camera.
var _fpv: FirstPersonView
## Camminata laterale col Lock: un po' piu' lenta della corsa libera.
const STRAFE_SPEED := 0.78
var _texts: FloatingText
## Magia del fuoco del bastone (D-055).
var magic: FireMagic
var _pending_casts: Array = []
## Scontro nell'arena (D-058): il corpo del giocatore (vita, parata), il
## nemico con l'IA, i round e la loro interfaccia.
var player_body: FighterBody
var enemy: Fighter
var duel: ArenaDuel
var _duel_hud: DuelHud
var _guard_key := false
var _light_key := false
var paused := false
var show_hitboxes := false
## Danno dal contatto della lama (D-028); falso = forme astratte di M4.
var use_blade_hitboxes := true
var _preset_i := 0
var _hitbox_lines: DebugLines
var _cursor_lines: DebugLines
var _mouse_pos := Vector2(-1, -1)
var recipe: AvatarRecipe
var weapon_index := 1
var fx := CombatFx.new()
var _heavy_key := false
var _zoom_before_hero := -1.0
var _combo_shown := 0

var toggles := {"outline": true, "edges": true, "paint": true, "dither": false, "rays": true,
	"grass": true, "shadow": true, "clouds": true}
## Direzione verso l'acqua dall'ultimo "Al lago" (per strumenti e prove).
var lake_dir := Vector2.ZERO
var _gen_task := -1
var _gen_result: WorldData
var _gen_seed := 0
var _move_world := Vector2.ZERO
var _jump_key := false
var _args := {}
var _frames_after_build := -1
var _build_ms := 0


func _ready() -> void:
	# Il tasto indietro di Android chiude i pannelli invece di uscire dal gioco.
	get_tree().quit_on_go_back = false
	_args = _parse_user_args()
	# Preferenze del prototipo (chiavi isoterra.*): righe, spigoli, terza persona.
	var rh := int(Settings.load_value("view", "rt_h", 360))
	rt_height = rh if rh in [270, 360, 450] else 360
	toggles["edges"] = bool(Settings.load_value("view", "edges", true))
	catalog = BlockCatalog.load_default()
	var w: WorldData
	var saved := {}
	if not _args.has("seed") and not _args.has("fresh"):
		saved = SaveService.load_state()
	if not saved.is_empty():
		w = _world_from_save(saved)
		if w == null:
			saved = {}
	if w != null:
		pass
	elif _args.has("seed"):
		w = WorldFactory.generate(int(_args["seed"]), catalog)
	else:
		w = WorldFactory.from_fixture(catalog)
	if w == null:
		_status.text = "Fixture NON valida"
		return
	# D-054: partita nuova nell'arena (un salvataggio ce l'ha gia' nei blocchi).
	if saved.is_empty():
		Arena.stamp(w, catalog)
	get_viewport().size_changed.connect(_fit_view)
	_fit_view()
	_runtime.initial_build_finished.connect(_on_initial_build)
	motor = PlayerMotor.new(w)
	recipe = AvatarRecipe.load_saved()
	_avatar.set_recipe(recipe)
	weapon_index = 0
	if _args.has("weapon"):
		weapon_index = maxi(0, WEAPONS.find(StringName(_args["weapon"])))
	combat = CombatController.new(WeaponLibrary.by_id(WEAPONS[weapon_index]))
	player_body = FighterBody.new(motor, combat, 100.0)
	_avatar.set_weapon(combat.weapon)
	if _args.has("weapon"):
		select_weapon(weapon_index)
	fx.grains = _grains
	_lock_marker = LockMarker.new()
	_lock_marker.name = "LockMarker"
	_grains.get_parent().add_child(_lock_marker)
	_fpv = FirstPersonView.new()
	_fpv.name = "FirstPersonView"
	_fpv.visible = false
	_camera_rig.camera.add_child(_fpv)
	sandbox.grains = _grains
	if saved.is_empty():
		items.starter_kit()
	items.held_changed.connect(_refresh_held)
	items.inv.changed.connect(_refresh_hotbar)
	_texts = FloatingText.new()
	_texts.name = "Texts"
	_view.add_child(_texts)
	magic = FireMagic.new()
	magic.name = "Magic"
	_view.add_child(magic)
	_duel_hud = DuelHud.new()
	_duel_hud.name = "DuelHud"
	_duel_hud.visible = false
	$HUD.add_child(_duel_hud)
	$HUD.move_child(_duel_hud, 0)
	_hitbox_lines = DebugLines.new()
	_view.add_child(_hitbox_lines)
	_cursor_lines = DebugLines.new()
	_view.add_child(_cursor_lines)
	# Pausa (tasto P): si ferma il mondo, non l'interfaccia.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD.process_mode = Node.PROCESS_MODE_ALWAYS
	_bag = BagPanel.new()
	_bag.name = "Bag"
	$HUD.add_child(_bag)
	_bag.closed.connect(func() -> void:
		_touch.blocked = paused
		get_tree().paused = paused
		_refresh_held())
	_bag.message.connect(func(t: String) -> void: last_edit = t)
	_bag.dropped.connect(func(st: ItemStack) -> void:
		ground.drop(st, motor.position, Vector3(-sin(_avatar.facing), 0, -cos(_avatar.facing))))
	_bag.crafted.connect(func(id: StringName) -> void:
		if id == &"workbench":
			journal.record("craft"))
	sandbox.placed.connect(func(id: StringName) -> void:
		if id == &"workbench":
			journal.record("build"))
	_session = SessionOverlay.new()
	_session.name = "SessionOverlay"
	_session.journal = journal
	$HUD.add_child(_session)
	_session.action.connect(_session_action)
	journal.completed.connect(func(title: String) -> void:
		_session.notify("Obiettivo completato: " + title))
	_session.reduced_motion = bool(Settings.load_value("accessibility", "reduced_motion", false))
	_session.hints = bool(Settings.load_value("accessibility", "hints", true))
	_session.volume = clampi(int(Settings.load_value("audio", "volume", 80)), 0, 100)
	_apply_session_settings()
	_touch.hidden_ids[&"dev"] = not _args.has("dev")
	ground.name = "GroundItems"
	_view.add_child(ground)
	_swap_world(w)
	_camera_rig.opaque = catalog.opaque_table()
	for d: Array in DEV_BUTTONS:
		_touch.add_button(d[0], d[1], DEV_HOLD.has(d[0]), &"dev")
	for d: Array in HERO_BUTTONS:
		_touch.add_button(d[0], "", false, &"hero")
	var cam_mode: int = Settings.load_value("camera", "mode", CameraRig.Mode.ISO)
	if _args.get("cam", "") == "tps":
		cam_mode = CameraRig.Mode.TPS
	elif _args.get("cam", "") == "fps":
		cam_mode = CameraRig.Mode.FPS
	_camera_rig.set_mode(cam_mode as CameraRig.Mode)
	_camera_rig.tps_zoom = clampf(float(Settings.load_value("camera", "tps_zoom", 1.0)), CameraRig.TPS_ZOOM_MIN, CameraRig.TPS_ZOOM_MAX)
	var up := float(Settings.load_value("camera", "tps_pitch", NAN))
	if not is_nan(up):
		_camera_rig.tps_user_pitch = clampf(float(up), CameraRig.TPS_PITCH_MIN, CameraRig.TPS_PITCH_MAX)
	_apply_toggles()
	if _args.has("zoom"):
		_camera_rig.set_zoom(float(_args["zoom"]))
		_camera_rig.zoom = _camera_rig.zoom_target
	if _args.has("time"):
		_day.time = float(_args["time"])
		_day.paused = true
	if _args.has("yaw"):
		_camera_rig.yaw_target += deg_to_rad(float(_args["yaw"]))
		_camera_rig.yaw = _camera_rig.yaw_target
	_touch.left_handed = bool(Settings.load_value("input", "left_handed", false))
	_session.left_handed = _touch.left_handed
	if _args.has("dev"):
		_touch.dev_open = true
	if _args.has("lake"):
		go_to_lake()
	if _args.has("at"):
		var xz := String(_args["at"]).split(",")
		motor.place_at(Vector3(float(xz[0]), world.size_y, float(xz[1])))
		_avatar.position = motor.position
	if _args.has("nowater"):
		_water.visible = false
	_touch.camera_dragged.connect(_camera_rig.drag)
	_touch.zoom_scaled.connect(func(f: float) -> void: _camera_rig.set_zoom(_camera_rig.get_zoom() * f))
	_touch.world_tapped.connect(_on_world_tap)
	_touch.world_hold.connect(func(pos: Vector2, on: bool) -> void:
		_hold_active = on
		_hold_pos = pos)
	_touch.button_pressed.connect(_on_button)
	_touch.button_down.connect(func(id: StringName) -> void:
		if id == &"heavy":
			combat.press_heavy())
	_touch.button_up.connect(func(id: StringName) -> void:
		if id == &"heavy":
			combat.release_heavy())
	if not saved.is_empty():
		_restore(saved)
	_refresh_labels()
	_refresh_held()
	_camera_rig.update_camera(1.0, motor.position)
	_update_session_hud()
	if saved.is_empty() and not _args.has("screenshot"):
		_session.notify("Benvenuto a IsoTerra. Menu > Diario per cominciare.")


## Sostituisce il mondo corrente (avvio o nuovo seme): nuova sessione per
## runtime e vegetazione, giocatore allo spawn.
func _swap_world(w: WorldData) -> void:
	world = w
	lock.clear()
	# Come il main thread del prototipo: fluidi ripresi dai dati, code risvegliate.
	FluidSystem.init_fluid(world, world.fluid)
	edits = WorldEditService.new(world, catalog)
	edits.light = LightEngine.new(world, catalog)
	edits.chunks_changed.connect(_runtime.mark_dirty)
	edits.chunks_changed.connect(_vegetation.mark_dirty)
	var ct := WorldFactory.climate_texture(world)
	if ct != null:
		RenderingServer.global_shader_parameter_set(&"climate_tex", ct)
	RenderingServer.global_shader_parameter_set(&"world_xz", Vector2(world.size_x, world.size_z))
	RenderingServer.global_shader_parameter_set(&"slice_y", float(world.size_y))
	motor.world = world
	motor.place_at(world.spawn_point())
	_avatar.position = motor.position
	_runtime.focus = motor.position
	_build_ms = 0
	_runtime.setup(world, catalog)
	_vegetation.setup(world, catalog, world.world_seed)
	_water.setup(world)
	_grains.world = world
	_grains.clear()
	_water_fx.motor = motor
	_water_fx.water = _water
	_water_fx.grains = _grains
	_water_fx.reset()
	motor.tree_grid = _vegetation.tree_grid
	_camera_rig.world = world
	fx.world = world
	combat.world = world
	combat.opaque = catalog.opaque_table()
	_dummies.setup(world)
	_place_dummies()
	magic.world = world
	magic.clear()
	_objects.world = world
	_objects.clear()
	ground.world = world
	ground.clear()
	_objects.scatter_treasure(world.world_seed, world.spawn_point())
	_place_armory()
	_setup_duel()
	sandbox.setup(world, edits, catalog, motor, _objects, _vegetation)
	if combat != null:
		combat.cancel()


func _physics_process(dt: float) -> void:
	if motor == null or paused or _bag.is_open():
		return
	_apply_stats()
	_step_mining(dt)
	# Colpo tenuto premuto: la catena continua da sola (come J tenuto nel prototipo).
	if (_touch.is_held(&"attack") or _light_key) and combat.buffer == &"":
		if combat.state == CombatController.State.IDLE or (combat.state == CombatController.State.ATTACK and combat.phase() == 2):
			combat.press_light()
	for d in _dummies.dummies:
		if d.alive and d.position.distance_to(motor.position) < 4.5:
			_avatar.aware_t = 2.5
	# Para (D-058): tenuto = guardia; la parata perfetta e' all'ultimo istante.
	if (_guard_key or _touch.is_held(&"guard")) and player_body.alive:
		combat.press_guard()
	else:
		combat.release_guard()
	# Fermo immagine condiviso: chi colpisce e chi e' colpito si fermano insieme.
	if enemy != null:
		var hs := maxf(combat.hitstop, enemy.combat.hitstop)
		combat.hitstop = hs
		enemy.combat.hitstop = hs
	var stick := _read_stick()
	if not player_body.alive:
		stick = Vector2.ZERO
	_move_world = _camera_rig.stick_to_world(stick)
	var fps := _camera_rig.mode == CameraRig.Mode.FPS
	combat.aim_view = fps
	if not combat.is_busy():
		# In prima persona il colpo parte lungo lo sguardo.
		combat.facing = _camera_rig.yaw if fps else _avatar.facing
	var targets: Array = []
	targets.append_array(_dummies.targets())
	if _duel_on():
		targets.append(enemy.body)
	lock.step(motor.position, targets)
	var locked := lock.active()
	combat.forced = lock.target if locked else null
	_touch.lock_on = locked
	if locked:
		_avatar.aware_t = 2.5
	# Hitbox vere: la lama (o i pugni) nella posa corrente dell'eroe.
	combat.hitboxes = _avatar.rig.hitboxes() if use_blade_hitboxes else []
	combat.step(dt, motor, targets, _move_world)
	_handle_combat_events()
	var frozen := combat.hitstop > 0.0
	if not frozen:
		motor.drive_on = combat.drive_on
		motor.drive = combat.drive
		motor.move_scale = combat.move_scale * combat.weapon.move_mult
		motor.move_scale *= _stats.speed
		if locked and not combat.is_busy():
			motor.move_scale *= STRAFE_SPEED
		var before_move := motor.position
		motor.step(dt, _move_world, (_jump_key or _touch.is_held(&"jump")) and not combat.is_busy())
		journal.record("walk", Vector2(motor.position.x - before_move.x, motor.position.z - before_move.z).length())
		_avatar.position = motor.position
		_push_out_of_dummies()
		_push_out_of_enemy()
		motor.position = _objects.push_out(motor.position, PlayerMotor.RADIUS)
		for got in ground.step(dt, motor.position, items.inv):
			last_edit = "raccolto: %s%s" % [Loot.full_name(got), (" ×%d" % got.count) if got.count > 1 else ""]
			items.held_changed.emit()
		_avatar.position = motor.position
		if combat.is_busy():
			_avatar.turn_to(combat.facing, dt, PlayerAvatar.ATTACK_TURN)
		elif locked and lock.flat_dist(motor.position) > 0.2:
			# Lock: lo sguardo resta sul bersaglio, lo stick sposta di lato e indietro.
			_avatar.turn_to(lock.heading_from(motor.position), dt, PlayerAvatar.LOCK_TURN)
			if fps:
				_fps_track_lock(dt)
		elif fps:
			# Prima persona: il corpo guarda dove guarda la camera.
			_avatar.turn_to(_camera_rig.yaw, dt, PlayerAvatar.ATTACK_TURN)
		else:
			_avatar.face_towards(Vector2(motor.velocity.x, motor.velocity.z), dt)
	for d in _dummies.step(0.0 if frozen else dt):
		fx.broke(d)
	player_body.step(dt)
	# Posa dell'eroe al passo della fisica (D-028): la lama che ferisce e' quella
	# che si vede, anche quando piu' passi di fisica cadono in un fotogramma.
	_avatar.animate(0.0 if combat.hitstop > 0.0 else dt, motor, combat)
	# D-055/D-056: il fuoco parte dalla gemma nella posa appena calcolata.
	var fw := CombatController.forward(combat.facing)
	var staff := _avatar.rig.weapon != null and _avatar.rig.weapon.kind == WeaponDefinition.Kind.STAFF
	magic.set_gem(staff, _staff_gem(), Vector3(fw.x, 0, fw.y))
	for c: Array in _pending_casts:
		magic.cast(c[0], _staff_gem(), c[1], c[2], c[3], combat.damage_mult, player_body)
	_pending_casts.clear()
	var ca := combat.attack if combat.state == CombatController.State.ATTACK else null
	if ca != null and ca.cast != "" and combat.phase() == 0:
		var u := combat.t / maxf(ca.windup, 0.01)
		var cf := maxf(combat.charge_fraction(), u * 0.35) if ca.cast == "ball" else 0.0
		magic.casting(ca.cast, u, cf)
	else:
		magic.casting("", 0.0, 0.0)
	magic.step(0.0 if frozen else dt, targets)
	_step_duel(dt)


## Riquadri dei colpi (Hitbox) e cubo del cursore di costruzione.
func _draw_debug() -> void:
	_hitbox_lines.begin()
	if show_hitboxes:
		for d in _dummies.dummies:
			if d.alive:
				var hb := CombatController.hurtbox(d)
				_hitbox_lines.cylinder(Vector3(d.position.x, hb[0], d.position.z), hb[2], hb[1] - hb[0], Color(0.4, 1, 0.5) if d.flash <= 0.0 else Color(1, 0.3, 0.3))
		var a := combat.attack
		if a != null and not combat.hitboxes.is_empty() and a.shape != AttackDefinition.Shape.RADIAL and not a.plunge:
			# Hitbox della lama: gialle quando feriscono, grigie altrimenti.
			var live := combat.phase() == 1 or (combat.phase() == 2 and combat.phase_u() <= CombatController.FOLLOW)
			for hb: Array in combat.hitboxes:
				_hitbox_lines.sphere(hb[0], hb[1], Color(1, 0.9, 0.2) if live else Color(0.6, 0.6, 0.6))
		elif a != null:
			var col := Color(1, 0.9, 0.2) if combat.phase() == 1 else Color(0.6, 0.6, 0.6)
			var base := motor.position + Vector3(0, 0.05, 0)
			var f := combat._attack_facing
			match a.shape:
				AttackDefinition.Shape.ARC:
					var sweep := combat.arc_angle(combat.phase_u()) if combat.phase() == 1 else deg_to_rad(a.arc_from)
					_hitbox_lines.arc(base, a.reach, f + deg_to_rad(a.arc_from), f + deg_to_rad(a.arc_to), col, true)
					_hitbox_lines.arc(base, a.reach_min, f + deg_to_rad(a.arc_from), f + deg_to_rad(a.arc_to), col)
					if combat.phase() == 1:
						var dd := Vector3(-sin(f + deg_to_rad(sweep)), 0, -cos(f + deg_to_rad(sweep)))
						_hitbox_lines.line(base, base + dd * a.reach, Color(1, 0.3, 0.2))
				AttackDefinition.Shape.THRUST:
					var fw := Vector3(-sin(f), 0, -cos(f))
					var lf := Vector3(-sin(f + PI * 0.5), 0, -cos(f + PI * 0.5))
					var c0 := base + fw * a.reach_min
					var c1 := base + fw * a.reach
					_hitbox_lines.line(c0 + lf * a.width, c1 + lf * a.width, col)
					_hitbox_lines.line(c0 - lf * a.width, c1 - lf * a.width, col)
					_hitbox_lines.line(c1 + lf * a.width, c1 - lf * a.width, col)
					_hitbox_lines.line(c0 + lf * a.width, c0 - lf * a.width, col)
				_:
					var fw := Vector3(-sin(f), 0, -cos(f))
					_hitbox_lines.arc(base + fw * a.radial_ahead, a.radial, 0.0, TAU, col)
	_hitbox_lines.finish()
	_cursor_lines.begin()
	var ht := sandbox.harvester.target
	if _avatar.mining >= 0.0 and ht != null:
		# Bersaglio della raccolta: contorno e riquadro interno che si stringe.
		var k := clampf(sandbox.harvester.progress, 0.0, 1.0)
		if ht.kind == "block":
			var lo := Vector3(ht.cell)
			_cursor_lines.box(lo - Vector3.ONE * 0.02, lo + Vector3.ONE * 1.02, Color(1, 1, 1, 0.9))
			var q := 0.5 * (1.0 - k)
			_cursor_lines.box(lo + Vector3.ONE * (0.5 - q), lo + Vector3.ONE * (0.5 + q), Color(1, 0.8, 0.3, 0.9))
		elif ht.kind == "tree":
			_cursor_lines.cylinder(Vector3(ht.tree.x, ht.tree.y, ht.tree.z), 0.34 * ht.tree.scale + 0.1, 3.0 * ht.tree.scale * k + 0.1, Color(1, 0.8, 0.3, 0.9))
	elif _mouse_pos.x >= 0.0 and (dig_debug or (items.held_def() != null and items.held_def().kind in [ItemDefinition.Kind.BLOCK, ItemDefinition.Kind.STATION])):
		var ray := _screen_ray(_mouse_pos)
		var hit := VoxelQuery.raycast(world, catalog.opaque_table(), ray[0], ray[1], 400.0)
		if hit != null and Axes.cell_center(hit.cell).distance_to(motor.eye_position()) <= REACH:
			var c := hit.cell if dig_debug else hit.cell + hit.normal
			var e := 0.02
			_cursor_lines.box(Vector3(c) - Vector3(e, e, e), Vector3(c) + Vector3(1 + e, 1 + e, 1 + e),
				Color(1, 0.4, 0.3, 0.9) if dig_debug else Color(1, 1, 1, 0.9))
	_cursor_lines.finish()


## Prima persona col Lock: la vista gira da sola sul bersaglio agganciato
## (orizzontale e in altezza, sul petto del bersaglio).
func _fps_track_lock(dt: float) -> void:
	var eye := motor.position + Vector3(0, CameraRig.FPS_EYE, 0)
	var c := lock.target.position + Vector3(0, lock.target.height * 0.55, 0)
	# Durante i colpi la vista segue piu' piano (D-040): l'affondo passa accanto
	# al bersaglio e la direzione cambia di scatto.
	var k := 1.0 - exp(-dt * (4.0 if combat.state == CombatController.State.ATTACK else 10.0))
	_camera_rig.yaw_target = lerp_angle(_camera_rig.yaw_target, lock.heading_from(motor.position), k)
	var v := c - eye
	var want := atan2(v.y, Vector2(v.x, v.z).length())
	_camera_rig.fps_pitch = lerpf(_camera_rig.fps_pitch, clampf(want, CameraRig.FPS_PITCH_MIN, CameraRig.FPS_PITCH_MAX), k)


## Situazione per la terza persona adattiva (tpsCtx del prototipo, riga 7968)
## e salvataggio ritardato delle preferenze di camera.
var _prefs_t := 0.0


func _update_camera_context(dt: float) -> void:
	var fps := _camera_rig.mode == CameraRig.Mode.FPS
	_day.tps_sky = _camera_rig.is_persp()
	# Prima persona: il corpo sparisce (resta l'ombra), si vede solo la mano
	# con l'oggetto; mirino al centro; niente scia della lama del corpo.
	_avatar.rig.set_first_person(fps)
	_avatar.trail.visible = not fps
	_touch.crosshair = fps
	_camera_rig.sun_dir = _day.state.get("dir", Vector3(-0.3, 0.93, 0.22))
	if _camera_rig.prefs_dirty:
		_prefs_t += dt
		if _prefs_t > 1.0:
			_prefs_t = 0.0
			_camera_rig.prefs_dirty = false
			Settings.save_value("camera", "tps_zoom", _camera_rig.tps_zoom)
			if not is_nan(_camera_rig.tps_user_pitch):
				Settings.save_value("camera", "tps_pitch", _camera_rig.tps_user_pitch)


## Blocco opaco da 2 a n celle sopra i piedi (isCovered del prototipo).
func is_covered(p: Vector3, n: int) -> bool:
	var bx := floori(p.x)
	var bz := floori(p.z)
	if bx < 0 or bz < 0 or bx >= world.size_x or bz >= world.size_z:
		return false
	var op := catalog.opaque_table()
	for yy in range(floori(p.y) + 2, mini(floori(p.y) + n + 1, world.size_y)):
		if op[world.get_block_xyz(bx, yy, bz)] != 0:
			return true
	return false


## I manichini sono solidi: il giocatore ne viene spinto fuori (cilindri).
## Il nemico e' solido come i manichini: ci si separa a meta' per uno.
func _push_out_of_enemy() -> void:
	if enemy == null or not enemy.visible:
		return
	var em := enemy.motor
	if absf(em.position.y - motor.position.y) > PlayerMotor.HEIGHT:
		return
	var v := Vector2(motor.position.x - em.position.x, motor.position.z - em.position.z)
	var r := PlayerMotor.RADIUS * 2.0 + 0.1
	var l := v.length()
	if l >= r:
		return
	var n := v / l if l > 1e-4 else Vector2(1, 0)
	var push := (r - l) * 0.5
	var mp := Vector2(motor.position.x, motor.position.z) + n * push
	var ep := Vector2(em.position.x, em.position.z) - n * push
	if motor.ground(mp.x, mp.y) <= motor.position.y + 0.04:
		motor.position.x = mp.x
		motor.position.z = mp.y
	if em.ground(ep.x, ep.y) <= em.position.y + 0.04:
		em.position.x = ep.x
		em.position.z = ep.y
	_avatar.position = motor.position


func _push_out_of_dummies() -> void:
	for d in _dummies.dummies:
		if not d.alive or motor.position.y > d.position.y + d.height or motor.position.y + PlayerMotor.HEIGHT < d.position.y:
			continue
		var v := Vector2(motor.position.x - d.position.x, motor.position.z - d.position.z)
		var r := d.radius * 0.8 + PlayerMotor.RADIUS
		var l := v.length()
		if l < r:
			var n := v / l if l > 1e-4 else CombatController.forward(_avatar.facing) * -1.0
			var np := Vector2(d.position.x, d.position.z) + n * r
			# Solo se la nuova posizione non entra in un muro.
			if motor.ground(np.x, np.y) <= motor.position.y + 0.04:
				motor.position.x = np.x
				motor.position.z = np.y
			_avatar.position = motor.position


func _handle_combat_events() -> void:
	for e in combat.events:
		match String(e["type"]):
			"hit":
				journal.record("hit")
				fx.hit(e)
				_camera_rig.shake(float(e["shake"]))
				if bool(e.get("crit", false)):
					_texts.spawn((e["position"] as Vector3) + Vector3(0, 0.5, 0), "CRITICO!", Color(1, 0.85, 0.3))
				if items.wear_held(1):
					sandbox.message = "l'arma si e' rotta!"
			"impact":
				fx.impact(e)
				_camera_rig.shake((e["attack"] as AttackDefinition).shake)
			"dodge":
				journal.record("dodge")
				fx.dodge(motor.position, combat.dodge_dir)
			"blocked":
				fx.clash(e["position"], false)
				_camera_rig.shake(0.08)
			"parried_by":
				fx.clash(e["position"], true)
				_camera_rig.shake(0.3)
				_texts.spawn((e["position"] as Vector3) + Vector3(0, 0.6, 0), "PARATO!", Color(1.0, 0.5, 0.4), 30)
			"guard_break":
				_texts.spawn(motor.position + Vector3(0, 2.0, 0), "GUARDIA ROTTA", Color(1.0, 0.5, 0.4), 26)
			"cast":
				var a: AttackDefinition = e["attack"]
				var f := CombatController.forward(float(e["facing"]))
				var tg: CombatTarget = e.get("target")
				# Il lancio parte dalla gemma nella posa del colpo: si fa dopo
				# l'animazione di questo passo (vedi _physics_process).
				_pending_casts.append([a, Vector3(f.x, 0, f.y), float(e["charge"]), tg])
	combat.events.clear()
	for e in magic.events:
		match String(e["type"]):
			"spell_hit":
				journal.record("hit")
				_camera_rig.shake(float(e["shake"]))
				_texts.spawn((e["p"] as Vector3) + Vector3(0, 0.4, 0), str(roundi(float(e["damage"]))), Color(1.0, 0.62, 0.22), 34)
			"burn":
				_texts.spawn((e["p"] as Vector3) + Vector3(randf_range(-0.2, 0.2), 0.5, 0), str(roundi(float(e["damage"]))), Color(1.0, 0.45, 0.15), 24)
			"blast":
				_camera_rig.shake(float(e["shake"]))
	magic.events.clear()


## Gemma del bastone in mano (punto da cui parte la magia), o la mano.
func _staff_gem() -> Vector3:
	var rig := _avatar.rig
	if rig.socket != null and rig.weapon != null and rig.weapon.kind == WeaponDefinition.Kind.STAFF:
		return rig.socket.global_transform * Vector3(0, WeaponMeshes.STAFF_GEM_Y, 0)
	return motor.position + Vector3(0, 1.0, 0)


## Mano in prima persona: copie delle mesh della mano e dell'oggetto dell'eroe,
## animate dallo stato del combattimento (fuori dalla prima persona e
## nell'editor dell'eroe resta nascosta).
func _update_first_person(dt: float) -> void:
	var on := _camera_rig.mode == CameraRig.Mode.FPS and not _touch.hero_open
	_fpv.visible = on
	if not on:
		return
	_fpv.sync_from(_avatar.rig)
	_fpv.update(dt, combat, Vector2(motor.velocity.x, motor.velocity.z).length(), _avatar.mining, _avatar.anim_state.reach)


func _process(dt: float) -> void:
	if motor == null:
		return
	_hud_tick += dt
	if _hud_tick >= 0.1:
		_hud_tick = 0.0
		_update_session_hud()
	if paused or _bag.is_open():
		_bag.queue_redraw()
		_screenshot_tick()
		return
	var p := _avatar.get_global_transform_interpolated().origin
	_update_camera_context(dt)
	if not _pending_dead_trees.is_empty() and not _vegetation.spots.is_empty():
		_apply_dead_trees()
	_autosave_t += dt
	if _autosave_t >= AUTOSAVE_S and not _args.has("screenshot"):
		save_game()
	_lock_marker.set_target(lock.target if lock.active() else null)
	_lock_marker.update(dt)
	var lt := TrainingGround._light_at(world, p + Vector3(0, 1.1, 0))
	_avatar.set_light(lt.x, lt.y)
	_avatar.rig.set_flash(player_body.flash * 0.85, Color.WHITE)
	if enemy != null and enemy.visible:
		var el := TrainingGround._light_at(world, enemy.avatar.get_global_transform_interpolated().origin + Vector3(0, 1.1, 0))
		enemy.set_light(el.x, el.y)
	_update_duel_hud()
	_fpv.set_light(lt.x, lt.y)
	_dummies.sync_views(combat.lock_target if combat.is_busy() else null)
	_camera_rig.update_camera(dt, p)
	_update_first_person(dt)
	var grass_r := 0.0
	if _camera_rig.mode == CameraRig.Mode.TPS:
		grass_r = 46.0 + _camera_rig.tps_dist * 1.2
	elif _camera_rig.mode == CameraRig.Mode.FPS:
		grass_r = 46.0
	_vegetation.cull_grass(_camera_rig.camera.global_position, grass_r)
	_place_screen()
	_runtime.focus = p
	_update_xray(dt, p)
	_poll_generation()
	_water_fx.update(dt, _avatar.facing)
	# Q/E ruotano e Z/X zoomano in continuo come il prototipo (riga 7946).
	var rot := (1.0 if Input.is_physical_key_pressed(KEY_E) or _touch.is_held(&"dev_rot_r") else 0.0) \
		- (1.0 if Input.is_physical_key_pressed(KEY_Q) or _touch.is_held(&"dev_rot_l") else 0.0)
	_draw_debug()
	if rot != 0.0:
		_camera_rig.spin(rot * 1.6 * dt, 0.0)
	if Input.is_physical_key_pressed(KEY_Z):
		_camera_rig.set_zoom(_camera_rig.get_zoom() * exp(dt * 0.8))
	if Input.is_physical_key_pressed(KEY_X):
		_camera_rig.set_zoom(_camera_rig.get_zoom() * exp(-dt * 0.8))
	if sandbox.message != "":
		last_edit = sandbox.message
		sandbox.message = ""
	var h := items.held()
	_status.text = "%d FPS · in mano: %s%s · chunk in coda %d%s\nposizione %.1f %.1f %.1f%s" % [
		Engine.get_frames_per_second(), Loot.full_name(h) if h != null else "niente", " · SCAVO DEBUG" if dig_debug else "",
		_runtime.pending_count(), (" · mondo pronto in %d ms" % _build_ms) if _build_ms > 0 else "",
		motor.position.x, motor.position.y, motor.position.z, ("\n" + last_edit) if last_edit != "" else ""]
	if motor.water_state != "dry":
		_status.text += " · acqua: %s" % motor.water_state
	_status.text += "\n%s%s" % [combat.weapon.display_name, (" · combo %d" % combat.combo) if combat.combo > 1 else ""]
	if sandbox.harvester.target != null and sandbox.harvester.progress > 0.0:
		_status.text += " · raccolta %d%%" % int(sandbox.harvester.progress * 100.0)
	_screenshot_tick()


func _screenshot_tick() -> void:
	if _frames_after_build >= 0 and (_bag.is_open() or (_vegetation.is_idle() and _water.is_idle())):
		_frames_after_build += 1
		var total := int(_args.get("frames", "30"))
		if _args.has("bag") and not _bag.is_open() and _frames_after_build >= total - 4:
			open_bag(null, String(_args["bag"]) if String(_args["bag"]) != "1" else "bag")
		if _frames_after_build >= total:
			_take_screenshot()


func _reset_gameplay_input() -> void:
	_touch.reset()
	_jump_key = false
	_light_key = false
	_heavy_key = false
	_hold_active = false
	_move_world = Vector2.ZERO
	motor.reset_jump_input()
	combat.buffer = &""
	combat.release_heavy()
	sandbox.harvester.reset()
	_avatar.mining = -1.0


func set_paused(value: bool) -> void:
	if _session == null:
		return
	if _bag.is_open():
		_bag.close()
	_reset_gameplay_input()
	paused = value
	_touch.dev_open = false
	if _touch.hero_open:
		set_hero_editor(false)
	_touch.blocked = value
	_touch.visible = not value
	get_tree().paused = value
	_session.open("pause" if value else "")
	_refresh_labels()


func _apply_session_settings() -> void:
	_camera_rig.reduced_motion = _session.reduced_motion
	if _session.reduced_motion:
		_camera_rig.shake_amt = 0.0
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, _session.volume / 100.0)))
	AudioServer.set_bus_mute(0, _session.volume == 0)


func _session_action(id: StringName) -> void:
	match id:
		&"resume":
			set_paused(false)
		&"pause", &"journal", &"settings", &"help":
			if not paused:
				set_paused(true)
			_session.open(String(id))
		&"save":
			save_game()
		&"new_game":
			# D-054: due tocchi entro 4 s; il salvataggio si cancella e si riparte
			# da zero nell'arena.
			var now := Time.get_ticks_msec()
			if now - _new_game_armed > 4000:
				_new_game_armed = now
				_session.notify("Tocca di nuovo \"Nuova partita\": il mondo salvato verra' cancellato.")
			else:
				start_new_game()
		&"quality":
			_on_button(&"dev_res")
		&"motion":
			_session.reduced_motion = not _session.reduced_motion
			Settings.save_value("accessibility", "reduced_motion", _session.reduced_motion)
			_apply_session_settings()
		&"hints":
			_session.hints = not _session.hints
			Settings.save_value("accessibility", "hints", _session.hints)
		&"volume":
			_session.volume = (_session.volume + 20) % 120
			Settings.save_value("audio", "volume", _session.volume)
			_apply_session_settings()
		&"handed":
			_touch.left_handed = not _touch.left_handed
			_session.left_handed = _touch.left_handed
			_touch._layout()
			Settings.save_value("input", "left_handed", _touch.left_handed)
		&"developer":
			set_paused(false)
			_touch.hidden_ids[&"dev"] = false
			_touch.dev_open = true
		&"return_home":
			var base := checkpoint if checkpoint != Vector3.INF else world.spawn_point()
			var destination := Vector3.INF
			# Cerca una colonna libera accanto al falo': una costruzione successiva puo' occuparla.
			for offset in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var x: float = base.x + offset.x
				var z: float = base.z + offset.y
				var y := motor.ground(x, z, base.y + 2.0)
				if world.inside(floori(x), floori(y), floori(z)) and motor.space_free(x, z, y) and _objects.at(Vector3i(floori(x), floori(y), floori(z))) == null:
					destination = Vector3(x, y, z)
					break
			if destination != Vector3.INF:
				motor.place_at(destination)
				_avatar.position = motor.position
				lock.clear()
				combat.cancel()
				set_paused(false)
				last_edit = "Ritorno al campo."
			else:
				_session.save_text = "Punto di ritorno occupato: libera lo spazio vicino al falò."
		&"interact":
			if not paused and not _bag.is_open():
				var nearby := sandbox.nearest_usable()
				if nearby != null:
					_open_object(nearby)
	_update_session_hud()


func _update_session_hud() -> void:
	if _session == null:
		return
	_status.visible = _touch.dev_open and not paused and not _bag.is_open()
	_session.hud_visible = not _bag.is_open() and not _touch.dev_open and not _touch.hero_open
	_session.quality = rt_height
	_session.ui_density = _touch.dp(1.0)
	var held := items.held()
	_session.held_name = Loot.full_name(held) if held != null else "Mani libere"
	var minutes := int(fposmod(_day.time, 1.0) * 1440.0)
	_session.clock_text = "%02d:%02d" % [minutes / 60, minutes % 60]
	_session.mining = sandbox.harvester.progress if _hold_active and sandbox.harvester.target != null else -1.0
	var nearby := sandbox.nearest_usable() if not paused and not _bag.is_open() else null
	var names := {"chest": "Apri forziere", "treasure": "Apri tesoro", "armory": "Apri armeria", "armor_stand": "Guarda l'armatura", "workbench": "Crea al banco", "furnace": "Usa fornace", "campfire": "Riposa al falò"}
	# Il tasto F ha senso solo con la tastiera; su telefono resta l'azione.
	var key := "" if DisplayServer.is_touchscreen_available() else "F / "
	_session.context_text = (key + String(names.get(nearby.type, "Interagisci"))) if nearby != null else ""
	_session.avoid.clear()
	for id: StringName in [&"lock", &"attack", &"heavy", &"dodge", &"jump", &"guard"]:
		_session.avoid.append(_touch.button_rect(id))
	if last_edit != "" and last_edit != _last_notice:
		_last_notice = last_edit
		_session.notify(last_edit)
	_session.queue_redraw()


## Stick touch o tastiera (WASD/frecce), con zona morta e minimo del prototipo (riga 7073).
func _read_stick() -> Vector2:
	var ax := 0.0
	var ay := 0.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		ax += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		ax -= 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		ay += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		ay -= 1.0
	if _touch.stick_vector != Vector2.ZERO:
		ax = _touch.stick_vector.x
		ay = -_touch.stick_vector.y
	var v := Vector2(ax, ay)
	var l := v.length()
	if l > 1.0:
		v /= l
		l = 1.0
	if l < 0.04:
		return Vector2.ZERO
	if l < 0.13:
		v *= 0.13 / l
	return v


func _unhandled_input(event: InputEvent) -> void:
	if motor == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE and k.pressed and not k.echo:
			if not close_top_panel():
				set_paused(not paused)
			return
		if paused or _bag.is_open():
			return
		if k.physical_keycode == KEY_SPACE:
			_jump_key = k.pressed
		if k.physical_keycode == KEY_Q and not k.echo:
			_guard_key = k.pressed
		if k.physical_keycode == KEY_J and not k.echo:
			_light_key = k.pressed
		if k.physical_keycode == KEY_K and not k.echo:
			if k.pressed:
				combat.press_heavy()
			else:
				combat.release_heavy()
		if not k.pressed or k.echo:
			return
		match k.physical_keycode:
			KEY_F:
				_session_action(&"interact")
			KEY_V:
				_on_button(&"camera")
			KEY_R:
				toggle_lock()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				items.select(k.physical_keycode - KEY_1)
			KEY_I, KEY_TAB:
				_on_button(&"bag")
			KEY_N:
				_on_button(&"dev_seed")
			KEY_J:
				combat.press_light()
			KEY_P:
				_on_button(&"dev_pause")
			KEY_L, KEY_SHIFT:
				combat.press_dodge()
			KEY_H:
				_on_button(&"hero")
			KEY_M:
				_on_button(&"dev_dummies")
	elif event is InputEventMouseMotion:
		_mouse_pos = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton:
		if paused or _bag.is_open():
			return
		var mb := event as InputEventMouseButton
		# Clic destro: usa/apri l'oggetto sotto il cursore (forziere, banco, fornace, falò).
		if mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			toggle_lock()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			var ray := _screen_ray(mb.position)
			var o := _objects.pick(ray[0], ray[1])
			if o != null:
				_open_object(o)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_rig.set_zoom(_camera_rig.get_zoom() * 1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_rig.set_zoom(_camera_rig.get_zoom() / 1.1)


## Opzioni che buttano via la partita in corso: serve un secondo tocco entro 3 s.
var _confirm_id: StringName = &""
var _confirm_until := 0


func _confirm(id: StringName, text: String) -> bool:
	var now := Time.get_ticks_msec()
	if _confirm_id == id and now <= _confirm_until:
		_confirm_id = &""
		return true
	_confirm_id = id
	_confirm_until = now + 3000
	_touch.show_toast(text, Color(1.0, 0.85, 0.5))
	return false


## Lock (D-035): aggancia il bersaglio migliore attorno all'eroe o sgancia.
func toggle_lock() -> void:
	if lock.toggle(motor.position, _avatar.facing, _dummies.targets()):
		last_edit = "agganciato"
	else:
		last_edit = "sganciato" if not _dummies.targets().is_empty() else "nessun bersaglio"
	_touch.lock_on = lock.active()


func _on_button(id: StringName) -> void:
	match id:
		&"menu":
			set_paused(not paused)
		&"lock":
			toggle_lock()
		&"dev_close":
			_touch.dev_open = false
		&"dev_seed":
			if _confirm(id, "Nuovo mondo: tocca di nuovo per confermare"):
				regenerate(randi() % 1000000)
		&"dev_lake":
			go_to_lake()
		&"dev_time":
			_day.time = fmod(_day.time + 3.0 / 24.0, 1.0)
		&"dev_res":
			var opts := [270, 360, 450]
			rt_height = opts[(opts.find(rt_height) + 1) % opts.size()]
			Settings.save_value("view", "rt_h", rt_height)
			_fit_view()
		&"dev_outline", &"dev_edges", &"dev_paint", &"dev_dither", &"dev_rays", &"dev_grass", &"dev_shadow", &"dev_clouds":
			var key := String(id).substr(4)
			toggles[key] = not bool(toggles[key])
			if key == "edges":
				Settings.save_value("view", "edges", toggles[key])
			_apply_toggles()
		&"hot0", &"hot1", &"hot2", &"hot3", &"hot4", &"hot5":
			items.select(int(String(id).substr(3)))
		&"dev_digdebug":
			dig_debug = not dig_debug
		&"dev_kit":
			give_test_kit()
		&"bag":
			open_bag()
		&"dev_save":
			save_game()
		&"dev_load":
			if _confirm(id, "Carica l'ultimo salvataggio: tocca di nuovo per confermare"):
				load_game()
		&"dev_home":
			if checkpoint != Vector3.INF:
				motor.place_at(checkpoint)
				_avatar.position = motor.position
		&"camera":
			_camera_rig.toggle_mode()
			Settings.save_value("camera", "mode", _camera_rig.mode)
		&"dev_zin":
			_camera_rig.set_zoom(_camera_rig.get_zoom() * 1.25)
		&"dev_zout":
			_camera_rig.set_zoom(_camera_rig.get_zoom() / 1.25)
		&"dev_hitbox":
			show_hitboxes = not show_hitboxes
		&"dev_pause":
			set_paused(not paused)
		&"hero_preset":
			recipe = AvatarRecipe.preset(_preset_i)
			_preset_i += 1
			_apply_recipe()
		&"hero_copy":
			DisplayServer.clipboard_set(recipe.to_json())
			last_edit = "ricetta copiata negli appunti"
		&"hero_paste":
			var r := AvatarRecipe.from_json(DisplayServer.clipboard_get())
			if r == null:
				last_edit = "negli appunti non c'e' una ricetta valida"
			else:
				recipe = r
				_apply_recipe()
				last_edit = "ricetta incollata"
		&"attack":
			combat.press_light()
		&"dodge":
			combat.press_dodge()
		&"dev_dummies":
			_place_dummies()
			last_edit = "manichini davanti al giocatore"
		&"hero":
			set_hero_editor(not _touch.hero_open)
		&"hero_close":
			set_hero_editor(false)
		&"hero_random":
			recipe = AvatarRecipe.random(randi())
			_apply_recipe()
		_:
			if String(id).begins_with("hero_") and AvatarRecipe.FIELDS.has(String(id).substr(5)):
				recipe.cycle(String(id).substr(5))
				_apply_recipe()
	_refresh_labels()


## Mette in mano un'arma di ferro di prova (strumenti e prove e2e): ultimo slot
## della barra rapida.
func select_weapon(i: int) -> void:
	weapon_index = i
	var w: StringName = WEAPONS[i]
	var slot := PlayerItems.HOTBAR - 1
	if w == &"fists":
		items.inv.set_slot(slot, null)
	else:
		items.inv.set_slot(slot, Loot.make_equipment(StringName("%s_iron" % w), 0, items.rng))
	items.select(slot)
	_refresh_labels()


## L'oggetto in mano cambia: arma dei colpi, mesh in mano (con animazione) e barra.
func _refresh_held() -> void:
	_refresh_armor()
	var h := items.held()
	var key := "%s:%s" % [items.weapon_id(), (h.id if h != null else &"")]
	_refresh_hotbar()
	if key == _held_key:
		return
	_held_key = key
	var wd := WeaponLibrary.by_id(items.weapon_id())
	var mesh := WeaponMeshes.for_item(items.held_def())
	if combat.weapon != wd or mesh != null or _avatar.rig.held_mesh != null:
		combat.set_weapon(wd)
		combat.draw_t = PlayerAvatar.SWAP_TIME * 0.6
		_avatar.swap_weapon(wd, mesh)


## Armatura indossata visibile sull'eroe.
var _armor_key := ""


func _refresh_armor() -> void:
	var key := JSON.stringify(items.equipment.to_dict())
	if key == _armor_key:
		return
	_armor_key = key
	_avatar.rig.set_armor_all(items.equipment.colors(), items.equipment.styles())


func _refresh_hotbar() -> void:
	for i in PlayerItems.HOTBAR:
		var s := items.inv.get_slot(i)
		var bid := StringName("hot%d" % i)
		if s == null:
			_touch.icons.erase(bid)
			continue
		var d := s.def()
		var ic := {"id": d.id, "color": d.color, "glyph": d.glyph, "count": s.count, "wear": -1.0}
		if s.data.has("wear"):
			ic["wear"] = float(s.data["wear"]) / maxf(1.0, float(s.data.get("max_wear", d.durability)))
		if s.rarity() > 0:
			ic["rarity_color"] = Loot.RARITY_COLORS[s.rarity()]
		_touch.icons[bid] = ic
	_touch.hot_selected = items.selected
	_touch.queue_redraw()


## Statistiche dell'equipaggiamento applicate a colpi e movimento.
func _apply_stats() -> void:
	_stats = items.stats()
	combat.damage_mult = _stats.melee
	combat.crit_chance = _stats.crit


## Raggio dallo schermo (origine, direzione) nella vista del mondo.
func _screen_ray(screen_pos: Vector2) -> Array:
	var cam := _camera_rig.camera
	var sub := screen_to_view(screen_pos)
	return [cam.project_ray_origin(sub), cam.project_ray_normal(sub)]


## Tenere premuto sul mondo: raccolta con l'oggetto in mano.
func _step_mining(dt: float) -> void:
	var busy := combat.is_busy() or motor.swimming or dig_debug
	if not _hold_active or busy:
		if _avatar.mining >= 0.0:
			_avatar.mining = -1.0
			sandbox.harvester.reset()
		return
	var ray := _screen_ray(_hold_pos)
	var t := sandbox.mine(dt, ray[0], ray[1], _stats.dig)
	for e in sandbox.handle_events():
		if e["type"] in ["broken", "felled", "picked"]:
			if e["type"] != "broken" or e.get("drop", &"") != &"":
				journal.record("harvest", float(e.get("n", 1)))
		if e["type"] == "felled":
			var ts: Vegetation.TreeSpot = e["tree"]
			RenderingServer.global_shader_parameter_set(&"tree_hit", Vector3(ts.seed_value, _day.clock, 1.0))
	if t == null:
		_avatar.mining = -1.0
		return
	var before := _avatar.mining
	_avatar.mining = maxf(0.0, _avatar.mining) + dt * 2.2
	var v := Vector2(t.point.x - motor.position.x, t.point.z - motor.position.z)
	if v.length() > 0.1:
		_avatar.turn_to(atan2(-v.x, -v.y), dt, PlayerAvatar.ATTACK_TURN)
	# Un colpo a ogni ciclo dell'animazione: schegge e albero scosso.
	if before >= 0.0 and floorf(before + 0.65) != floorf(_avatar.mining + 0.65):
		var col := Color(0.55, 0.38, 0.2) if t.kind != "block" else catalog.get_def(t.id).top_color
		sandbox.chips(t.point, col)
		if t.kind == "tree":
			var d := Vector2(t.point.x - motor.position.x, t.point.z - motor.position.z).normalized()
			RenderingServer.global_shader_parameter_set(&"tree_hit", Vector3(t.tree.seed_value, _day.clock, 0.6))
			RenderingServer.global_shader_parameter_set(&"tree_hit_dir", d)


# ---------------------------------------------------------------- salvataggio

const AUTOSAVE_S := 60.0
var _autosave_t := 0.0
var _pending_dead_trees: Array = []


## Mondo di un salvataggio: rigenerato dal seme (la fixture per il 1931), poi
## blocchi e acqua salvati sopra, luce ricalcolata.
func _world_from_save(st: Dictionary) -> WorldData:
	var ws: Dictionary = st.get("world", {})
	var seed_value := int(ws.get("seed", 1931))
	var w := WorldFactory.from_fixture(catalog) if seed_value == 1931 else WorldFactory.generate(seed_value, catalog)
	if w == null:
		return null
	# D-054: dove sta l'arena (i blocchi veri vengono dal salvataggio).
	var c := Arena.locate(w)
	if not SaveService.apply_world_state(w, ws, catalog):
		return null
	var mid := w.surface_height(c.x, c.y)
	if w.get_block_xyz(c.x, mid, c.y) == BlockCatalog.MARBLE:
		w.arena = Vector3i(c.x, mid + 1, c.y)
	return w


func make_save_state() -> Dictionary:
	return {"v": 1, "world": SaveService.world_state(world),
		"player": {"pos": motor.position, "facing": _avatar.facing}, "items": items.to_dict(),
		"objects": _objects.to_array(), "ground": ground.to_array(), "dead_trees": _vegetation.dead_indices() if _pending_dead_trees.is_empty() else _pending_dead_trees,
		"checkpoint": checkpoint, "time": _day.time, "journal": journal.to_dict()}


## Tocco di conferma di "Nuova partita" (ms), -1 se non armato.
var _new_game_armed := -100000
## Vero dopo "Nuova partita": niente salvataggi automatici mentre si ricarica.
var _no_save := false


## D-054: cancella il salvataggio e ricarica la scena: senza salvataggio si
## parte dal mondo nuovo con l'arena, la spada di legno e il diario vuoto.
func start_new_game() -> void:
	_no_save = true
	SaveService.delete_all()
	get_tree().paused = false
	get_tree().reload_current_scene()


func save_game() -> bool:
	if _no_save:
		return false
	var ok := SaveService.save(make_save_state())
	_autosave_t = 0.0
	last_edit = "partita salvata" if ok else "salvataggio NON riuscito"
	if _session != null:
		_session.save_text = "Partita salvata" if ok else "Salvataggio fallito: riprova prima di chiudere."
	return ok


## Ripristina giocatore, oggetti, alberi e ora da un salvataggio (mondo gia' in uso).
func _restore(st: Dictionary) -> void:
	journal.load_dict(st.get("journal", {}))
	var pl: Dictionary = st.get("player", {})
	var pos: Vector3 = pl.get("pos", world.spawn_point())
	motor.place_at(pos)
	_avatar.position = motor.position
	_avatar.facing = float(pl.get("facing", 0.0))
	_avatar.rotation.y = _avatar.facing
	items.load_dict(st.get("items", {}))
	_objects.load_array(st.get("objects", []))
	# Salvataggi di prima dell'armeria: la si aggiunge accanto allo spawn.
	_place_armory()
	ground.load_array(st.get("ground", []))
	checkpoint = st.get("checkpoint", Vector3.INF)
	_day.time = float(st.get("time", _day.time))
	_place_dummies()
	# Gli alberi si costruiscono su un thread: si abbattono appena pronti.
	_pending_dead_trees = st.get("dead_trees", [])
	if not _vegetation.spots.is_empty():
		_apply_dead_trees()
	_held_key = ""
	_armor_key = ""


func _apply_dead_trees() -> void:
	if _pending_dead_trees.is_empty():
		return
	_vegetation.kill_indices(_pending_dead_trees)
	_pending_dead_trees = []


## Ricarica l'ultimo salvataggio (pannello ⚙ "Carica").
func load_game() -> bool:
	var st := SaveService.load_state()
	if st.is_empty():
		last_edit = "nessun salvataggio"
		return false
	var w := _world_from_save(st)
	if w == null:
		last_edit = "salvataggio non valido"
		return false
	_swap_world(w)
	_restore(st)
	last_edit = "partita caricata"
	return true


## Tasto indietro (Android) o Esc: chiude il pannello aperto, uno alla volta.
func close_top_panel() -> bool:
	if _bag.is_open():
		_bag.close()
	elif paused:
		if _session.page != "pause":
			_session.open("pause")
		else:
			set_paused(false)
	elif _touch.dev_open:
		_touch.dev_open = false
	elif _touch.hero_open:
		set_hero_editor(false)
	else:
		return false
	_refresh_labels()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not close_top_panel():
			set_paused(true)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if motor != null and _session != null and not _args.has("screenshot"):
			if _bag.is_open():
				_reset_gameplay_input()
			else:
				set_paused(true)
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED) and world != null and not _args.has("screenshot") and not _no_save:
		save_game()


## Oggetti di prova per strumenti ed e2e (pannello ⚙ "Kit di prova").
func give_test_kit() -> void:
	for pair in [[&"wood", 32], [&"stone", 32], [&"stick", 16], [&"copper_ingot", 12], [&"iron_ingot", 12], [&"gold_ingot", 6], [&"dirt", 16], [&"torch", 8]]:
		items.inv.add_item(pair[0], pair[1])
	for id in [&"pick_iron", &"axe_iron", &"workbench", &"furnace", &"chest", &"campfire"]:
		var d := ItemLibrary.get_item(id)
		items.inv.add(Loot.make_equipment(id, 1, items.rng) if d.is_equipment() else ItemStack.new(id))
	last_edit = "kit di prova nello zaino"


## Armeria: nell'arena al centro con gli espositori delle armature (D-054),
## altrimenti vicino allo spawn come prima.
func _place_armory() -> void:
	if Arena.has(world):
		_objects.place_arena(world.arena)
	else:
		_objects.place_armory(world.spawn_point())


## Manichini: nell'arena uno a forma di personaggio a nord del centro, girato
## verso lo spawn (D-054); altrimenti tre di paglia davanti al giocatore.
func _place_dummies() -> void:
	if Arena.has(world):
		# D-058: nell'arena c'e' il nemico vero al posto del manichino.
		_dummies.setup(world)
	else:
		_dummies.place_around(motor.position, _avatar.facing)


## Scontro nell'arena (D-058): nei mondi con l'arena c'e' sempre un nemico.
func _setup_duel() -> void:
	if not Arena.has(world):
		if enemy != null:
			enemy.queue_free()
			enemy = null
		duel = null
		if _duel_hud != null:
			_duel_hud.visible = false
		return
	if enemy == null:
		enemy = Fighter.new()
		enemy.name = "Enemy"
		_view.add_child(enemy)
	enemy.setup(world, _objects, TrainingGround.sparring_recipe(), catalog)
	duel = ArenaDuel.new(world.arena, world.world_seed)
	_duel_hud.visible = not _args.has("screenshot")
	_next_round()


func _duel_on() -> bool:
	return duel != null and enemy != null and duel.active()


## Round nuovo: vita piena, giocatore a sud e nemico a nord del centro.
func _next_round() -> void:
	duel.start_round(WEAPONS)
	var c := duel.center
	enemy.set_weapon(duel.enemy_weapon)
	enemy.place(Vector3(c.x, c.y, c.z - 5.0), PI)
	enemy.ai = FighterAI.new(duel.level, world.world_seed + duel.round_n * 101)
	player_body.reset()
	combat.cancel()
	combat.release_guard()
	combat.posture = 0.0
	combat.forget_targets()
	lock.clear()
	magic.clear()
	motor.place_at(Vector3(c.x, c.y, c.z + 5.0))
	_avatar.position = motor.position
	_avatar.facing = 0.0
	_avatar.rotation.y = 0.0


func _step_duel(dt: float) -> void:
	if duel == null or enemy == null:
		return
	enemy.step(dt, player_body, combat, magic.shots, duel.center, 0.0, duel.active())
	_handle_enemy_events()
	_push_out_of_enemy()
	for e in player_body.events:
		match String(e["type"]):
			"damage":
				_texts.spawn((e["p"] as Vector3) + Vector3(randf_range(-0.2, 0.2), 0.5, 0), str(roundi(float(e["damage"]))), Color(1.0, 0.35, 0.3), 30)
				_camera_rig.shake(0.18)
			"parry":
				_texts.spawn((e["p"] as Vector3) + Vector3(0, 0.7, 0), "PARATA!", GamePalette.ACCENT, 34)
			"block":
				_texts.spawn((e["p"] as Vector3) + Vector3(0, 0.6, 0), "parato", Color(0.8, 0.85, 0.9), 22)
	player_body.events.clear()
	for e in enemy.body.events:
		match String(e["type"]):
			"damage":
				_texts.spawn((e["p"] as Vector3) + Vector3(randf_range(-0.2, 0.2), 0.5, 0), str(roundi(float(e["damage"]))), Color(1.0, 0.95, 0.8), 28)
			"parry":
				_texts.spawn((e["p"] as Vector3) + Vector3(0, 0.7, 0), "PARATA!", Color(1.0, 0.5, 0.4), 30)
	enemy.body.events.clear()
	match duel.step(dt, player_body, enemy.body):
		"fight":
			# Lock automatico sul rivale: col telefono e' la cosa piu' comoda.
			if not lock.active():
				lock.toggle(motor.position, _avatar.facing, [enemy.body])
		"win", "lose":
			lock.clear()
		"next":
			_next_round()


func _handle_enemy_events() -> void:
	for e in enemy.events:
		match String(e["type"]):
			"hit":
				fx.hit(e)
				_camera_rig.shake(float(e["shake"]) * 0.7)
			"impact":
				fx.impact(e)
				_camera_rig.shake((e["attack"] as AttackDefinition).shake * 0.6)
			"dodge":
				fx.dodge(enemy.motor.position, enemy.combat.dodge_dir)
			"blocked":
				fx.clash(e["position"], false)
			"parried_by":
				fx.clash(e["position"], true)
				_camera_rig.shake(0.3)
			"blast":
				_camera_rig.shake(float(e["shake"]) * 0.7)
	enemy.events.clear()


func _update_duel_hud() -> void:
	if duel == null or enemy == null or _duel_hud == null:
		return
	_duel_hud.player_hp = player_body.hp / player_body.max_hp
	_duel_hud.enemy_hp = enemy.body.hp / enemy.body.max_hp
	_duel_hud.player_posture = combat.posture / CombatController.POSTURE_MAX
	_duel_hud.enemy_posture = enemy.combat.posture / CombatController.POSTURE_MAX
	_duel_hud.enemy_name = "%s, livello %d" % [ArenaDuel._weapon_name(duel.enemy_weapon), duel.level + 1]
	_duel_hud.score = "Round %d   ·   Tu %d - %d Avversario" % [duel.round_n, duel.wins, duel.losses]
	_duel_hud.banner = duel.banner
	_duel_hud.banner_sub = duel.banner_sub
	_duel_hud.queue_redraw()


## Apre l'interfaccia dell'oggetto toccato.
func _open_object(o: WorldObjects.Obj) -> void:
	if not sandbox.can_use(o):
		last_edit = "Avvicinati all'oggetto: deve essere raggiungibile."
		return
	if o.type == "treasure":
		journal.record("treasure")
	match o.type:
		"chest", "treasure", "armory", "armor_stand":
			open_bag(o, "chest")
		"workbench", "furnace":
			open_bag(null, "craft")
		"campfire":
			set_checkpoint(o)


## Zaino (o forziere, o craft) a tutto schermo: il mondo si ferma.
func open_bag(chest: WorldObjects.Obj = null, tab: String = "bag") -> void:
	if _bag.is_open():
		_bag.close()
		return
	_reset_gameplay_input()
	_touch.blocked = true
	_hold_active = false
	get_tree().paused = true
	_bag.recipe = recipe
	_bag.open(items, _objects.stations_near(motor.position, 3.2), chest, tab)


## Falò: punto di ritorno (checkpoint). Il salvataggio arriva con SaveService.
var checkpoint := Vector3.INF


func set_checkpoint(o: WorldObjects.Obj) -> void:
	checkpoint = Vector3(o.cell) + Vector3(0.5, 0, 1.5)
	journal.record("camp")
	var saved := save_game()
	last_edit = "falò: punto di ritorno fissato e partita salvata" if saved else "Punto di ritorno fissato, ma salvataggio fallito: riprova dal menu."
	_texts.spawn(Vector3(o.cell) + Vector3(0.5, 1.4, 0.5), "RIPOSO")


## Editor dell'eroe: pulsanti della ricetta e camera ravvicinata.
var _mode_before_hero := CameraRig.Mode.ISO


func set_hero_editor(open: bool) -> void:
	if open == _touch.hero_open:
		return
	_touch.hero_open = open
	if open:
		_touch.dev_open = false
		# In prima persona l'eroe non si vede: l'editor lo mostra in terza persona.
		_mode_before_hero = _camera_rig.mode
		if _camera_rig.mode == CameraRig.Mode.FPS:
			_camera_rig.set_mode(CameraRig.Mode.TPS)
		_zoom_before_hero = _camera_rig.get_zoom()
		_camera_rig.set_zoom(CameraRig.ISO_ZOOM_MAX if _camera_rig.mode == CameraRig.Mode.ISO else 0.4)
	else:
		if _zoom_before_hero > 0.0:
			_camera_rig.set_zoom(_zoom_before_hero)
		if _mode_before_hero != _camera_rig.mode:
			_camera_rig.set_mode(_mode_before_hero)
	_refresh_labels()


func _apply_recipe() -> void:
	_avatar.set_recipe(recipe)
	recipe.save()
	_refresh_labels()


static func _dev_label(key: String) -> String:
	for d: Array in DEV_BUTTONS:
		if d[0] == StringName("dev_" + key):
			return d[1]
	return key


func _apply_toggles() -> void:
	var rs := RenderingServer
	rs.global_shader_parameter_set(&"outline_on", 1.0 if toggles["outline"] else 0.0)
	rs.global_shader_parameter_set(&"edges_on", 1.0 if toggles["edges"] else 0.0)
	rs.global_shader_parameter_set(&"paint_mode", 1.0 if toggles["paint"] else 0.0)
	rs.global_shader_parameter_set(&"dither_amount", 1.0 if toggles["dither"] else 0.0)
	rs.global_shader_parameter_set(&"rays_on", 1.0 if toggles["rays"] else 0.0)
	rs.global_shader_parameter_set(&"cloud_shadow_on", 1.0 if toggles["clouds"] else 0.0)
	_day.shadows_on = toggles["shadow"]
	_vegetation.set_grass_visible(toggles["grass"])
	_refresh_labels()


## "Al lago" (water-trip, riga ~8045): riva asciutta accanto ad acqua profonda
## almeno 1,5, a quota simile al pelo dell'acqua, lontana dagli alberi, la piu'
## vicina al centro della mappa.
func go_to_lake() -> bool:
	var w := world
	var best := Vector3.ZERO
	var heading := 0.0
	var score := INF
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for z in range(2, w.size_z - 2):
		for x in range(2, w.size_x - 2):
			if w.water_level[z * w.size_x + x] == 0:
				continue
			var q := FluidSystem.sample_water(w, x + 0.5, FluidSystem.field_height(w, x + 0.5, z + 0.5), z + 0.5)
			if not bool(q["wet"]) or float(q["depth"]) < 1.5:
				continue
			for d in dirs:
				var xx := x + d.x
				var zz := z + d.y
				if w.water_level[zz * w.size_x + xx] != 0:
					continue
				var g := float(FluidSystem.field_height(w, xx + 0.5, zz + 0.5))
				if absf(g - float(q["level"])) > 1.3:
					continue
				if not _vegetation.trees_near(xx + 0.5, zz + 0.5, 1).all(func(t: Vegetation.TreeSpot) -> bool:
						return Vector2(t.x - (xx + 0.5), t.z - (zz + 0.5)).length() >= 1.0):
					continue
				var dd := Vector2(xx - w.size_x / 2.0, zz - w.size_z / 2.0).length()
				if dd < score:
					score = dd
					best = Vector3(xx + 0.5, g, zz + 0.5)
					heading = atan2(-d.x, -d.y)
					lake_dir = Vector2(-d.x, -d.y)
	if score == INF:
		last_edit = "nessun lago adatto"
		return false
	motor.place_at(best)
	motor.reset_water()
	_avatar.position = best
	_avatar.facing = heading
	_avatar.rotation.y = heading
	combat.cancel()
	_water_fx.reset()
	last_edit = "al lago %s" % best
	return true


## Genera un mondo nuovo in background; quello attuale resta giocabile finche'
## il nuovo non e' pronto.
func regenerate(seed_value: int) -> void:
	if _gen_task >= 0:
		return
	_gen_seed = seed_value
	var cat := catalog
	_gen_task = WorkerThreadPool.add_task(func() -> void:
		var nw := WorldFactory.generate(seed_value, cat)
		Arena.stamp(nw, cat)
		_gen_result = nw)
	last_edit = "generazione mondo, seme %d…" % seed_value


func _poll_generation() -> void:
	if _gen_task < 0 or not WorkerThreadPool.is_task_completed(_gen_task):
		return
	WorkerThreadPool.wait_for_task_completion(_gen_task)
	_gen_task = -1
	if _gen_result != null:
		journal.load_dict({})
		checkpoint = Vector3.INF
		_swap_world(_gen_result)
		last_edit = "mondo del seme %d" % _gen_seed
	_gen_result = null


func _refresh_labels() -> void:
	_touch.labels[&"camera"] = ["Iso", "3ª p.", "1ª p."][_camera_rig.mode]
	_touch.labels[&"dev"] = "Chiudi" if _touch.dev_open else "Opzioni"
	_touch.labels[&"dev_res"] = "Righe %d" % rt_height
	for key: String in toggles:
		_touch.labels[StringName("dev_" + key)] = "%s %s" % [_dev_label(key), "ON" if toggles[key] else "OFF"]
	_touch.labels[&"dev_digdebug"] = "Scava debug %s" % ("ON" if dig_debug else "OFF")
	for d: Array in HERO_BUTTONS:
		_touch.labels[d[0]] = recipe.label(d[1]) if d[1] != "" else HERO_LABELS[d[0]]
	_touch.labels[&"dev_hitbox"] = "Hitbox %s" % ("ON" if show_hitboxes else "OFF")
	_touch.labels[&"dev_pause"] = "Riprendi" if paused else "Pausa"
	_touch.queue_redraw()


func _on_world_tap(screen_pos: Vector2) -> void:
	if paused or _bag.is_open():
		return
	# Pannello delle opzioni aperto: un tocco sul mondo lo chiude e basta.
	if _touch.dev_open:
		_touch.dev_open = false
		_refresh_labels()
		return
	var ray := _screen_ray(screen_pos)
	if dig_debug:
		var hit := VoxelQuery.raycast(world, catalog.opaque_table(), ray[0], ray[1], 400.0)
		if hit != null:
			debug_dig(hit)
		return
	match sandbox.tap(ray[0], ray[1]):
		"attack":
			combat.press_light()
		"open":
			_open_object(sandbox.opened)


## Posa l'oggetto in mano sulla faccia colpita; separata dall'input per i test.
func apply_action(hit: VoxelQuery.VoxelHit) -> bool:
	var ok := sandbox.place(hit)
	last_edit = sandbox.message
	return ok


## Scavo di debug: toglie il blocco senza attrezzi ne' bottino.
func debug_dig(hit: VoxelQuery.VoxelHit) -> bool:
	if Axes.cell_center(hit.cell).distance_to(motor.eye_position()) > REACH or hit.cell.y == 0:
		last_edit = "fuori portata"
		return false
	var r2 := edits.set_block(hit.cell, BlockCatalog.AIR, &"debug_dig")
	last_edit = "rimosso %s in %s" % [catalog.get_def(hit.id).display_name, hit.cell] if r2.ok() else "rifiutato"
	return r2.ok()


## Altezza del render target a bassa risoluzione (RT_H del prototipo: 270/360/450).
var rt_height := 360
var _occl := 0.0

## Punti del corpo usati per stimare quanto il giocatore e' coperto (BODY, riga 7928).
const BODY: Array[Vector3] = [Vector3(0, .15, 0), Vector3(0, .5, 0), Vector3(0, .85, 0), Vector3(0, 1.15, 0),
	Vector3(.2, .4, .2), Vector3(-.2, .4, -.2), Vector3(.2, .9, -.2), Vector3(-.2, .9, .2), Vector3(0, 1.3, 0),
	Vector3(.22, .6, 0), Vector3(-.22, .6, 0), Vector3(0, .3, .22)]


## Il render target ha un pixel di bordo per lato: l'immagine viene spostata
## del resto sub-pixel della camera e il bordo resta fuori dallo schermo.
func _fit_view() -> void:
	var s := get_viewport().get_visible_rect().size
	var h := rt_height
	var b := _camera_rig.border_px
	_view.size = Vector2i(maxi(1, roundi(h * s.x / s.y)) + 2 * b, h + 2 * b)
	_place_screen()


func _view_scale() -> float:
	return get_viewport().get_visible_rect().size.y / float(rt_height)


func _place_screen() -> void:
	var k := _view_scale()
	var b := float(_camera_rig.border_px)
	var sub := _camera_rig.subpixel
	_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen.size = Vector2(_view.size) * k
	_screen.position = Vector2(-(b + sub.x), -(b - sub.y)) * k


## Da coordinate dello schermo (canvas) a pixel del render target.
func screen_to_view(p: Vector2) -> Vector2:
	return (p - _screen.position) / _view_scale()


func view_to_screen(p: Vector2) -> Vector2:
	return p * _view_scale() + _screen.position


## Frazione dei punti del corpo nascosti alla camera da blocchi o alberi
## (coverage del prototipo, riga 7929).
func coverage(p: Vector3) -> float:
	var d := _camera_rig.view_dir()
	var hit := 0
	var opaque := catalog.opaque_table()
	var near := _vegetation.trees_near(p.x, p.z, 2)
	for b in BODY:
		var o := p + b + d * 0.35
		var h := VoxelQuery.raycast(world, opaque, o, d, 40.0) != null
		if not h:
			for t in near:
				var hh := 4.0 * t.scale
				var tx := t.x - o.x
				var tz := t.z - o.z
				var along := (tx * d.x + tz * d.z) / maxf(1e-4, d.x * d.x + d.z * d.z)
				if along < 0.2:
					continue
				var q := o + d * along
				var rr := (q.x - t.x) * (q.x - t.x) + (q.z - t.z) * (q.z - t.z)
				if rr < 0.35 * 0.35 * t.scale and q.y > t.y and q.y < t.y + hh * 0.7:
					h = true
					break
		if h:
			hit += 1
	return float(hit) / BODY.size()


func _update_xray(dt: float, p: Vector3) -> void:
	# In prima persona non c'e' nulla fra la camera e l'eroe: niente raggi X.
	var target := coverage(p) if _camera_rig.mode != CameraRig.Mode.FPS else 0.0
	var tau := 0.10 if target > _occl else 0.22
	_occl += (target - _occl) * (1.0 - exp(-dt / tau))
	if _occl < 0.01:
		_occl = 0.0
	var cam := _camera_rig.camera
	var vs := Vector2(_view.size)
	var feet := p + Vector3(0, 0.1, 0)
	var head := p + Vector3(0, 1.35, 0)
	var rs := RenderingServer
	rs.global_shader_parameter_set(&"xray_amt", _occl)
	rs.global_shader_parameter_set(&"xray_a", cam.unproject_position(feet) / vs)
	rs.global_shader_parameter_set(&"xray_b", cam.unproject_position(head) / vs)
	rs.global_shader_parameter_set(&"xray_r", 34.0 * vs.y / 270.0)
	rs.global_shader_parameter_set(&"xray_depth", -(cam.global_transform.affine_inverse() * feet).z)
	rs.global_shader_parameter_set(&"xray_floor", p.y + 0.35)


func _on_initial_build(ms: int) -> void:
	_build_ms = ms
	print("Mondo costruito: %d chunk in %d ms (%s)" % [world.chunk_count(), ms, _runtime.stats])
	if _args.has("kit"):
		give_test_kit()
		_refresh_hotbar()
	if _args.has("armor"):
		for slot in Equipment.SLOTS:
			items.equipment.equip(Loot.make_equipment(StringName("%s_%s" % [slot, _args["armor"]]), 2, items.rng))
		_refresh_held()
	if _args.has("screenshot"):
		_frames_after_build = 0


func _take_screenshot() -> void:
	_frames_after_build = -1
	var path: String = _args["screenshot"]
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("Screenshot %s (%dx%d): %d" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit()


## Argomenti dopo "--" sulla riga di comando:
## --screenshot=file.png --cam=tps --frames=N --zoom=0.55 --yaw=gradi --time=0..1
## --seed=N (genera il mondo invece di usare la fixture) --dev (pannello aperto) --lake
## --weapon=fists|sword|spear|hammer|greatsword
static func _parse_user_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		if a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
		else:
			out[a.substr(2)] = "1"
	return out
