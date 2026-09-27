class_name GameRoot
extends Node
## Radice della sessione: possiede mondo, attori e sessione.
## M1: mondo fixture renderizzato a chunk, giocatore con collisioni voxel,
## camera isometrica (terza persona opzionale), stick touch ed edit di debug.
## M4: eroe animato, cinque armi, combattimento con manichini d'allenamento.

enum ActionMode { EXPLORE, BUILD, DIG_DEBUG }

const PLACEABLE: Array[int] = [BlockCatalog.DIRT, BlockCatalog.STONE, BlockCatalog.SAND, BlockCatalog.WOOD, BlockCatalog.TORCH]
const MODE_LABELS := {ActionMode.EXPLORE: "Esplora", ActionMode.BUILD: "Costruisci", ActionMode.DIG_DEBUG: "Scava (debug)"}
const MODE_BUTTON := {ActionMode.EXPLORE: "Esplora", ActionMode.BUILD: "Costr.", ActionMode.DIG_DEBUG: "Scava"}
## Portata di costruzione: game.reach + 1 dal punto occhi (riga 7099).
const REACH := 7.5
## Pannello sviluppatore: gli interruttori attivi del prototipo (riga 7855–7870).
const DEV_BUTTONS := [
	[&"dev_seed", "Nuovo seme"], [&"dev_lake", "Al lago"], [&"dev_time", "Ora +3h"], [&"dev_res", "Righe"], [&"dev_outline", "Contorni"],
	[&"dev_edges", "Spigoli"], [&"dev_paint", "Dipinto"], [&"dev_dither", "Dither"], [&"dev_rays", "Raggi"],
	[&"dev_grass", "Erba"], [&"dev_shadow", "Ombre"], [&"dev_clouds", "Nubi"], [&"dev_dummies", "Manichini"],
]
## Editor dell'eroe: un pulsante per parametro della ricetta.
const HERO_BUTTONS := [[&"hero_skin", "skin"], [&"hero_hair", "hair"], [&"hero_hair_style", "hair_style"],
	[&"hero_shirt", "shirt"], [&"hero_pants", "pants"], [&"hero_build", "build"], [&"hero_random", ""], [&"hero_close", ""]]
const WEAPONS: Array[StringName] = [&"fists", &"sword", &"spear", &"hammer", &"greatsword"]

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

var world: WorldData
var catalog: BlockCatalog
var edits: WorldEditService
var motor: PlayerMotor
var action_mode: ActionMode = ActionMode.EXPLORE
var block_index := 0
var last_edit := ""
var combat: CombatController
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
	_args = _parse_user_args()
	catalog = BlockCatalog.load_default()
	var w: WorldData
	if _args.has("seed"):
		w = WorldFactory.generate(int(_args["seed"]), catalog)
	else:
		w = WorldFactory.from_fixture(catalog)
	if w == null:
		_status.text = "Fixture NON valida"
		return
	get_viewport().size_changed.connect(_fit_view)
	_fit_view()
	_runtime.initial_build_finished.connect(_on_initial_build)
	motor = PlayerMotor.new(w)
	recipe = AvatarRecipe.load_saved()
	_avatar.set_recipe(recipe)
	weapon_index = maxi(0, WEAPONS.find(StringName(Settings.load_value("combat", "weapon", "sword"))))
	if _args.has("weapon"):
		weapon_index = maxi(0, WEAPONS.find(StringName(_args["weapon"])))
	combat = CombatController.new(WeaponLibrary.by_id(WEAPONS[weapon_index]))
	_avatar.set_weapon(combat.weapon)
	fx.grains = _grains
	_swap_world(w)
	_camera_rig.opaque = catalog.opaque_table()
	for d: Array in DEV_BUTTONS:
		_touch.add_button(d[0], d[1], false, &"dev")
	for d: Array in HERO_BUTTONS:
		_touch.add_button(d[0], "", false, &"hero")
	var cam_mode: int = Settings.load_value("camera", "mode", CameraRig.Mode.ISO)
	if _args.get("cam", "") == "tps":
		cam_mode = CameraRig.Mode.TPS
	_camera_rig.set_mode(cam_mode as CameraRig.Mode)
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
	_touch.button_pressed.connect(_on_button)
	_touch.button_down.connect(func(id: StringName) -> void:
		if id == &"heavy":
			combat.press_heavy())
	_touch.button_up.connect(func(id: StringName) -> void:
		if id == &"heavy":
			combat.release_heavy())
	_refresh_labels()
	_camera_rig.update_camera(1.0, motor.position)


## Sostituisce il mondo corrente (avvio o nuovo seme): nuova sessione per
## runtime e vegetazione, giocatore allo spawn.
func _swap_world(w: WorldData) -> void:
	world = w
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
	_dummies.setup(world)
	_dummies.place_around(motor.position, _avatar.facing)
	if combat != null:
		combat.cancel()


func _physics_process(dt: float) -> void:
	if motor == null:
		return
	var stick := _read_stick()
	_move_world = _camera_rig.stick_to_world(stick)
	if not combat.is_busy():
		combat.facing = _avatar.facing
	combat.step(dt, motor, _dummies.targets(), _move_world)
	_handle_combat_events()
	var frozen := combat.hitstop > 0.0
	if not frozen:
		motor.drive_on = combat.drive_on
		motor.drive = combat.drive
		motor.move_scale = combat.move_scale * combat.weapon.move_mult
		motor.step(dt, _move_world, (_jump_key or _touch.is_held(&"jump")) and not combat.is_busy())
		_avatar.position = motor.position
		_push_out_of_dummies()
		if combat.is_busy():
			_avatar.turn_to(combat.facing, dt, PlayerAvatar.ATTACK_TURN)
		else:
			_avatar.face_towards(Vector2(motor.velocity.x, motor.velocity.z), dt)
	for d in _dummies.step(0.0 if frozen else dt):
		fx.broke(d)


## I manichini sono solidi: il giocatore ne viene spinto fuori (cilindri).
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
				fx.hit(e)
				_camera_rig.shake(float(e["shake"]))
			"impact":
				fx.impact(e)
				_camera_rig.shake((e["attack"] as AttackDefinition).shake)
			"dodge":
				fx.dodge(motor.position, combat.dodge_dir)
	combat.events.clear()


func _process(dt: float) -> void:
	if motor == null:
		return
	var p := _avatar.get_global_transform_interpolated().origin
	_avatar.animate(0.0 if combat.hitstop > 0.0 else dt, motor, combat)
	var lt := TrainingGround._light_at(world, p + Vector3(0, 1.1, 0))
	_avatar.set_light(lt.x, lt.y)
	_dummies.sync_views(combat.lock_target if combat.is_busy() else null)
	_camera_rig.update_camera(dt, p)
	_place_screen()
	_runtime.focus = p
	_update_xray(dt, p)
	_poll_generation()
	_water_fx.update(dt, _avatar.facing)
	# Q/E ruotano e Z/X zoomano in continuo come il prototipo (riga 7946).
	var rot := (1.0 if Input.is_physical_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_Q) else 0.0)
	if rot != 0.0:
		_camera_rig.spin(rot * 1.6 * dt, 0.0)
	if Input.is_physical_key_pressed(KEY_Z):
		_camera_rig.set_zoom(_camera_rig.get_zoom() * exp(dt * 0.8))
	if Input.is_physical_key_pressed(KEY_X):
		_camera_rig.set_zoom(_camera_rig.get_zoom() * exp(-dt * 0.8))
	_status.text = "%d FPS · %s · %s · chunk in coda %d%s\nposizione %.1f %.1f %.1f%s" % [
		Engine.get_frames_per_second(), MODE_LABELS[action_mode], catalog.get_def(PLACEABLE[block_index]).display_name,
		_runtime.pending_count(), (" · mondo pronto in %d ms" % _build_ms) if _build_ms > 0 else "",
		motor.position.x, motor.position.y, motor.position.z, ("\n" + last_edit) if last_edit != "" else ""]
	if motor.water_state != "dry":
		_status.text += " · acqua: %s" % motor.water_state
	_status.text += "\n%s%s" % [combat.weapon.display_name, (" · combo %d" % combat.combo) if combat.combo > 1 else ""]
	if _frames_after_build >= 0 and _vegetation.is_idle() and _water.is_idle():
		_frames_after_build += 1
		if _frames_after_build >= int(_args.get("frames", "30")):
			_take_screenshot()


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
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_SPACE:
			_jump_key = k.pressed
		if k.physical_keycode == KEY_K and not k.echo:
			if k.pressed:
				combat.press_heavy()
			else:
				combat.release_heavy()
		if not k.pressed or k.echo:
			return
		match k.physical_keycode:
			KEY_F:
				_on_button(&"mode")
			KEY_V:
				_on_button(&"camera")
			KEY_B:
				_on_button(&"block")
			KEY_T:
				_select_block(BlockCatalog.TORCH)
			KEY_1:
				_select_block(BlockCatalog.DIRT)
			KEY_2:
				_select_block(BlockCatalog.STONE)
			KEY_3:
				_select_block(BlockCatalog.WOOD)
			KEY_N:
				_on_button(&"dev_seed")
			KEY_J:
				combat.press_light()
			KEY_L, KEY_SHIFT:
				combat.press_dodge()
			KEY_R:
				_on_button(&"weapon")
			KEY_H:
				_on_button(&"hero")
			KEY_M:
				_on_button(&"dev_dummies")
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_rig.set_zoom(_camera_rig.get_zoom() * 1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_rig.set_zoom(_camera_rig.get_zoom() / 1.1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_jump_key = false


func _on_button(id: StringName) -> void:
	match id:
		&"dev_seed":
			regenerate(randi() % 1000000)
		&"dev_lake":
			go_to_lake()
		&"dev_time":
			_day.time = fmod(_day.time + 3.0 / 24.0, 1.0)
		&"dev_res":
			var opts := [270, 360, 450]
			rt_height = opts[(opts.find(rt_height) + 1) % opts.size()]
			_fit_view()
		&"dev_outline", &"dev_edges", &"dev_paint", &"dev_dither", &"dev_rays", &"dev_grass", &"dev_shadow", &"dev_clouds":
			var key := String(id).substr(4)
			toggles[key] = not bool(toggles[key])
			_apply_toggles()
		&"mode":
			action_mode = ((action_mode + 1) % ActionMode.size()) as ActionMode
		&"block":
			block_index = (block_index + 1) % PLACEABLE.size()
		&"camera":
			_camera_rig.toggle_mode()
			Settings.save_value("camera", "mode", _camera_rig.mode)
		&"attack":
			combat.press_light()
		&"dodge":
			combat.press_dodge()
		&"weapon":
			select_weapon((weapon_index + 1) % WEAPONS.size())
		&"dev_dummies":
			_dummies.place_around(motor.position, _avatar.facing)
			last_edit = "manichini davanti al giocatore"
		&"hero":
			set_hero_editor(not _touch.hero_open)
		&"hero_close":
			set_hero_editor(false)
		&"hero_random":
			recipe = AvatarRecipe.random(randi())
			_apply_recipe()
		&"hero_skin", &"hero_hair", &"hero_hair_style", &"hero_shirt", &"hero_pants", &"hero_build":
			recipe.cycle(String(id).substr(5))
			_apply_recipe()
	_refresh_labels()


func select_weapon(i: int) -> void:
	weapon_index = i
	combat.set_weapon(WeaponLibrary.by_id(WEAPONS[i]))
	_avatar.set_weapon(combat.weapon)
	Settings.save_value("combat", "weapon", String(WEAPONS[i]))
	last_edit = "arma: %s" % combat.weapon.display_name
	_refresh_labels()


## Editor dell'eroe: pulsanti della ricetta e camera ravvicinata.
func set_hero_editor(open: bool) -> void:
	if open == _touch.hero_open:
		return
	_touch.hero_open = open
	if open:
		_touch.dev_open = false
		_zoom_before_hero = _camera_rig.get_zoom()
		_camera_rig.set_zoom(CameraRig.ISO_ZOOM_MAX if _camera_rig.mode == CameraRig.Mode.ISO else 0.4)
	elif _zoom_before_hero > 0.0:
		_camera_rig.set_zoom(_zoom_before_hero)
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


func _select_block(id: int) -> void:
	block_index = maxi(0, PLACEABLE.find(id))
	_refresh_labels()


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
		_gen_result = WorldFactory.generate(seed_value, cat))
	last_edit = "generazione mondo, seme %d…" % seed_value


func _poll_generation() -> void:
	if _gen_task < 0 or not WorkerThreadPool.is_task_completed(_gen_task):
		return
	WorkerThreadPool.wait_for_task_completion(_gen_task)
	_gen_task = -1
	if _gen_result != null:
		_swap_world(_gen_result)
		last_edit = "mondo del seme %d" % _gen_seed
	_gen_result = null


func _refresh_labels() -> void:
	_touch.labels[&"mode"] = MODE_BUTTON[action_mode]
	_touch.labels[&"block"] = catalog.get_def(PLACEABLE[block_index]).display_name.capitalize()
	_touch.labels[&"camera"] = "Iso" if _camera_rig.mode == CameraRig.Mode.ISO else "3ª p."
	_touch.labels[&"dev_res"] = "Righe %d" % rt_height
	for key: String in toggles:
		_touch.labels[StringName("dev_" + key)] = "%s %s" % [_dev_label(key), "ON" if toggles[key] else "OFF"]
	_touch.labels[&"weapon"] = combat.weapon.display_name if combat != null else "Arma"
	for d: Array in HERO_BUTTONS:
		_touch.labels[d[0]] = recipe.label(d[1]) if d[1] != "" else ("Casuale" if d[0] == &"hero_random" else "Chiudi")
	_touch.queue_redraw()


func _on_world_tap(screen_pos: Vector2) -> void:
	if action_mode == ActionMode.EXPLORE:
		# In esplorazione un tocco sul mondo e' un colpo.
		combat.press_light()
		return
	var cam := _camera_rig.camera
	var sub := screen_to_view(screen_pos)
	var origin := cam.project_ray_origin(sub)
	var dir := cam.project_ray_normal(sub)
	var hit := VoxelQuery.raycast(world, catalog.opaque_table(), origin, dir, 400.0)
	if hit == null:
		return
	apply_action(hit)


## Azione su un blocco colpito; separata dall'input per i test.
func apply_action(hit: VoxelQuery.VoxelHit) -> bool:
	var eye := motor.eye_position()
	if action_mode == ActionMode.BUILD:
		var cell := hit.cell + hit.normal
		var id := PLACEABLE[block_index]
		if Axes.cell_center(hit.cell).distance_to(eye) > REACH:
			last_edit = "troppo lontano"
			return false
		if catalog.is_solid(id) and motor.overlaps_cell(cell):
			last_edit = "occupato dal giocatore"
			return false
		if not edits.can_place(cell, id):
			last_edit = "non posabile"
			return false
		var r := edits.set_block(cell, id, &"build")
		last_edit = "posato %s in %s" % [catalog.get_def(id).display_name, cell] if r.ok() else "rifiutato"
		return r.ok()
	if action_mode == ActionMode.DIG_DEBUG:
		if Axes.cell_center(hit.cell).distance_to(eye) > REACH or hit.cell.y == 0:
			last_edit = "fuori portata"
			return false
		var r2 := edits.set_block(hit.cell, BlockCatalog.AIR, &"debug_dig")
		last_edit = "rimosso %s in %s" % [catalog.get_def(hit.id).display_name, hit.cell] if r2.ok() else "rifiutato"
		return r2.ok()
	return false


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
	var target := coverage(p)
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
