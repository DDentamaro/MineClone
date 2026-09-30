extends SceneTree
## Prova end-to-end della terza persona fissa (D-042) con tocchi reali: un
## tocco sul pulsante camera porta in terza persona; camminando la camera non
## gira da sola e resta alla stessa distanza; due dita zoomano; un muro fra
## camera ed eroe non la fa avvicinare, si apre coi raggi X.
## Uso: xvfb-run -a godot --path . --script res://tools/e2e_tps.gd -- --out=/tmp/tps.png

var _game: GameRoot
var _out := "user://tps.png"
var _phase := 0
var _frame := 0
var _t := 0.0
var _ok := true
var _log: Array[String] = []
var _yaw0 := 0.0
var _d0 := 0.0
var _stick := Vector2(160, 560)


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


func _drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	Input.parse_input_event(e)


func _tap(id: StringName) -> void:
	var c := _game._touch.button_rect(id).get_center()
	_touch(4, c, true)
	_touch(4, c, false)


func _shot(name: String) -> void:
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


func _dist() -> float:
	return _game._camera_rig.camera.global_position.distance_to(_game.motor.position + Vector3(0, 1.15, 0))


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
			if _frame == 60:
				_expect(cam.mode == CameraRig.Mode.TPS and g._touch.labels.get(&"camera", "") == "3ª p.", "un tocco su camera: terza persona")
				_expect(not g._touch.button_rect(&"tps_auto").has_area(), "niente pulsante Auto")
				_yaw0 = cam.yaw
				_d0 = _dist()
				_shot("inizio")
				# Stick a destra: l'eroe cammina di lato.
				_touch(1, _stick, true)
				_drag(1, _stick + Vector2(70, 0))
				_next()
		2:
			if _t > 2.0:
				_touch(1, _stick + Vector2(70, 0), false)
				var turned := rad_to_deg(absf(wrapf(cam.yaw - _yaw0, -PI, PI)))
				_expect(turned < 1.0, "camminando la camera non gira da sola (%.1f°)" % turned)
				_expect(absf(_dist() - _d0) < 0.6, "distanza costante (%.2f → %.2f)" % [_d0, _dist()])
				_shot("cammina")
				# Pinch: due dita che si allontanano.
				_touch(2, Vector2(700, 360), true)
				_touch(3, Vector2(800, 360), true)
				_next()
		3:
			if _frame <= 10:
				_drag(3, Vector2(800 + 20 * _frame, 360))
			if _frame == 11:
				_touch(2, Vector2(700, 360), false)
				_touch(3, Vector2(1000, 360), false)
			if _frame == 50:
				_expect(cam.tps_zoom > 1.3 and _dist() < _d0 * 0.8, "due dita avvicinano la camera (zoom %.2f, %.2f m)" % [cam.tps_zoom, _dist()])
				_shot("zoom")
				cam.set_zoom(1.0)
				# Muro di pietra fra la camera e l'eroe.
				var mp := g.motor.position
				var vd := cam.view_dir()
				var flat := Vector2(vd.x, vd.z).normalized()
				var side := Vector2(-flat.y, flat.x)
				for k in range(-3, 4):
					for h in range(0, 5):
						var c := Vector2(mp.x, mp.z) + flat * 2.0 + side * k
						g.edits.set_block(Vector3i(floori(c.x), floori(mp.y) + h, floori(c.y)), BlockCatalog.STONE)
				_next()
		4:
			if _t > 1.5:
				_expect(absf(_dist() - CameraRig.TPS_DIST) < 0.6, "col muro la camera non si avvicina (%.2f m)" % _dist())
				_expect(g._occl > 0.3, "il muro si apre coi raggi X (%.2f)" % g._occl)
				_shot("muro")
				for l in _log:
					print(l)
				print("e2e terza persona %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
	return false
