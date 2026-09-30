extends SceneTree
## Prova end-to-end della prima persona (D-037) con tocchi reali: due tocchi sul
## pulsante camera portano in prima persona, trascinare gira lo sguardo, lo
## stick avanti cammina dove si guarda, i colpi prendono il manichino nel
## mirino, Lock gira la vista sul bersaglio, un altro tocco torna in isometrica.
## Uso: xvfb-run -a godot --path . --script res://tools/e2e_fps.gd -- --out=/tmp/fps.png

var _game: GameRoot
var _out := "user://fps.png"
var _phase := 0
var _frame := 0
var _t := 0.0
var _ok := true
var _log: Array[String] = []
var _shots := {}
var _yaw0 := 0.0
var _p0 := Vector3.ZERO
var _hits0 := 0
var _stick := Vector2(160, 560)
var _drag_at := Vector2(900, 300)


func _initialize() -> void:
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)


func _touch(i: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)


func _tap(id: StringName) -> void:
	var c := _game._touch.button_rect(id).get_center()
	_touch(4, c, true)
	_touch(4, c, false)


func _shot(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	var path := _out.replace(".png", "_%s.png" % name)
	root.get_texture().get_image().save_png(path)
	_log.append("screenshot %s" % path)


func _expect(cond: bool, what: String) -> void:
	_log.append("%s %s" % ["OK " if cond else "NO ", what])
	_ok = _ok and cond


func _next() -> void:
	_phase += 1
	_frame = 0
	_t = 0.0


func _hits() -> int:
	var n := 0
	for d in _game._dummies.dummies:
		n += d.hits
	return n


## Manichino a `dist` metri lungo lo sguardo ruotato di `deg` gradi.
func _dummy_ahead(dist: float, deg: float) -> void:
	var g := _game
	var f := CombatController.forward(g._camera_rig.yaw + deg_to_rad(deg))
	var mp := g.motor.position
	var p := Vector3(mp.x + f.x * dist, mp.y, mp.z + f.y * dist)
	p.y = VoxelQuery.field_height(g.world, p.x, p.z, mp.y + 2.0)
	g._dummies.setup(g.world)
	g._dummies.add_dummy(p)


func _process(dt: float) -> bool:
	var g := _game
	var cam := g._camera_rig
	_frame += 1
	_t += dt
	match _phase:
		0:
			if g._runtime.is_idle() and g._build_ms > 0 and g._vegetation.is_idle() and g._water.is_idle():
				g._day.time = 0.42
				g._day.paused = true
				_next()
		1:
			if _frame == 5:
				_tap(&"camera")
			if _frame == 12:
				_tap(&"camera")
			if _frame == 20:
				_expect(cam.mode == CameraRig.Mode.FPS, "due tocchi su camera: prima persona")
				_expect(g._touch.crosshair and g._fpv.visible and g._fpv.grip_count() == 1 and g._avatar.rig.first_person, "mirino, solo la mano con l'oggetto, corpo invisibile")
				_expect(g._touch.labels.get(&"camera", "") == "1ª p.", "pulsante: 1ª p.")
				_shot("inizio")
				_yaw0 = cam.yaw
				_touch(2, _drag_at, true)
			if _frame > 20 and _frame <= 32:
				_drag(2, _drag_at + Vector2(-12.0 * (_frame - 20), 0), Vector2(-12, 0))
			if _frame == 33:
				_touch(2, _drag_at + Vector2(-144, 0), false)
			if _frame == 36:
				var turned := rad_to_deg(absf(wrapf(cam.yaw - _yaw0, -PI, PI)))
				_expect(turned > 20.0, "trascinare gira lo sguardo (%.0f°)" % turned)
				_p0 = g.motor.position
				_touch(1, _stick, true)
				_drag(1, _stick + Vector2(0, -70), Vector2(0, -70))
				_next()
		2:
			if _t > 0.6 and not _shots.has("cammina"):
				_shot("cammina")
			if _t > 1.2:
				_touch(1, _stick + Vector2(0, -70), false)
				var mv := g.motor.position - _p0
				var fw := cam.look_forward()
				var along := Vector2(mv.x, mv.z).normalized().dot(Vector2(fw.x, fw.z).normalized())
				_expect(Vector2(mv.x, mv.z).length() > 1.0 and along > 0.95, "stick avanti cammina dove si guarda (%.2f m, allineamento %.2f)" % [Vector2(mv.x, mv.z).length(), along])
				var ff := rad_to_deg(absf(wrapf(g._avatar.facing - cam.yaw, -PI, PI)))
				_expect(ff < 8.0, "il corpo guarda dove guarda la camera (%.0f°)" % ff)
				_dummy_ahead(1.5, 0.0)
				_hits0 = _hits()
				_next()
		3:
			if _frame in [4, 10, 16]:
				_tap(&"attack")
			if g.combat.attack != null and g.combat.phase() == 1:
				_shot("colpo")
			if _t > 2.0:
				_expect(_hits() > _hits0, "i colpi prendono il manichino nel mirino (%d)" % (_hits() - _hits0))
				_dummy_ahead(3.0, 60.0)
				_yaw0 = cam.yaw
				_tap(&"lock")
				_next()
		4:
			if _t > 1.0:
				var d: TrainingDummy = g._dummies.dummies[0]
				var want := CombatController.heading(Vector2(d.position.x - g.motor.position.x, d.position.z - g.motor.position.z))
				var err := rad_to_deg(absf(wrapf(cam.yaw - want, -PI, PI)))
				_expect(g.lock.active() and err < 10.0, "Lock gira la vista sul bersaglio a 60° (errore %.0f°)" % err)
				_shot("lock")
				_tap(&"lock")
				_touch(2, _drag_at, true)
				_next()
		5:
			# Sguardo in basso: il corpo non si vede, solo la mano con l'arma.
			if _frame <= 10:
				_drag(2, _drag_at + Vector2(0, 16.0 * _frame), Vector2(0, 16))
			if _frame == 11:
				_touch(2, _drag_at + Vector2(0, 160), false)
			if _frame == 20:
				_expect(cam.fps_pitch < -0.3, "trascinare in giu' guarda in basso (%.2f)" % cam.fps_pitch)
				_shot("in_basso")
				cam.fps_pitch = 0.0
				g.select_weapon(0)
				_next()
		6:
			# Mani libere: si vedono i due pugni; poi un piccone in mano.
			if _t > 1.2 and not _shots.has("pugni"):
				_expect(g._fpv.grip_count() == 2, "pugni: due mani (%d)" % g._fpv.grip_count())
				_shot("pugni")
				g.items.inv.set_slot(1, ItemStack.new(&"pick_iron"))
				g.items.select(1)
			if _t > 2.6:
				_expect(g._fpv.grip_count() == 1 and g._avatar.rig.held_mesh != null, "piccone: una mano con l'attrezzo")
				_shot("piccone")
				_tap(&"camera")
				_next()
		7:
			if _frame == 8:
				_expect(cam.mode == CameraRig.Mode.ISO and not g._avatar.rig.first_person and not g._fpv.visible and not g._touch.crosshair, "terzo tocco: isometrica, corpo di nuovo visibile")
				for l in _log:
					print(l)
				print("e2e prima persona %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
	return false
