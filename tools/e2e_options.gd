extends SceneTree
## Prova end-to-end delle Opzioni: aperte e chiuse col pulsante, anche con la
## scala dp di un telefono (--phone); misura il tempo dei fotogrammi con il
## pannello aperto e controlla che il gioco non si blocchi (lo stick muove
## l'eroe, un secondo tocco su Opzioni chiude, il tocco sul mondo chiude).
## Uso: xvfb-run -a godot --path . --script res://tools/e2e_options.gd -- --out=/tmp/opt.png [--phone]

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://options.png"
var _ok := true
var _phone := false
var _log: Array[String] = []
var _ms: Array[float] = []
var _last := 0
var _p0 := Vector3.ZERO
var _seed0 := 0


func _initialize() -> void:
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--phone":
			_phone = true
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
	_touch(3, c, true)
	_touch(3, c, false)


func _shot(name: String) -> void:
	var path := _out.replace(".png", "_%s.png" % name)
	root.get_texture().get_image().save_png(path)
	_log.append("screenshot " + path)


func _check(cond: bool, what: String) -> void:
	_log.append(("ok   " if cond else "NO   ") + what)
	_ok = _ok and cond


func _process(_dt: float) -> bool:
	_frame += 1
	var now := Time.get_ticks_usec()
	if _last > 0 and _phase >= 1:
		_ms.append((now - _last) / 1000.0)
	_last = now
	match _phase:
		0:
			if _game._runtime.is_idle() and _game._build_ms > 0 and _game._vegetation.is_idle() and _game._water.is_idle():
				# D-036: ⚙ e' nascosto (strumenti dal Menu o con --dev); questa prova
				# li chiede esplicitamente (in _initialize GameRoot non e' ancora pronto).
				_game._touch.hidden_ids[&"dev"] = false
				if _phone:
					_game._touch.dp_scale = 1.83
					_game._touch._layout()
				_phase = 1
				_frame = 0
		1:
			if _frame == 20:
				var closed := _ms.duplicate()
				closed.sort()
				_log.append("fotogramma col pannello chiuso: mediana %.1f ms" % closed[closed.size() / 2])
				_ms.clear()
				_tap(&"dev")
			if _frame == 30:
				_check(_game._touch.dev_open, "opzioni aperte")
				_shot("open")
				var screen := Rect2(Vector2.ZERO, _game._touch.size)
				var inside := true
				for d: Array in GameRoot.DEV_BUTTONS:
					inside = inside and screen.encloses(_game._touch.button_rect(d[0]))
				_check(inside, "tutte le opzioni dentro lo schermo")
				# Un tocco su "Nuovo seme" da solo non rigenera il mondo.
				_seed0 = _game.world.world_seed
				_tap(&"dev_seed")
				# Lo stick muove ancora l'eroe col pannello aperto.
				_p0 = _game.motor.position
				var s := Vector2(_game._touch.size.x * 0.15, _game._touch.size.y * 0.8)
				_touch(1, s, true)
				_drag(1, s + Vector2(0, -60))
			if _frame > 30 and _frame < 60:
				_drag(1, Vector2(_game._touch.size.x * 0.15, _game._touch.size.y * 0.8) + Vector2(0, -60 - _frame % 2))
			if _frame == 60:
				_touch(1, Vector2(_game._touch.size.x * 0.15, _game._touch.size.y * 0.8), false)
				var moved := _game.motor.position.distance_to(_p0)
				_check(moved < 0.05, "col pannello aperto lo stick non muove l'eroe (%.2f m)" % moved)
				_check(_game.world.world_seed == _seed0, "un solo tocco su Nuovo seme non rigenera")
				var open := _ms.duplicate()
				open.sort()
				_log.append("fotogramma col pannello aperto: mediana %.1f ms, massimo %.1f ms" % [open[open.size() / 2], open[open.size() - 1]])
				_check(open[open.size() - 1] < 2000.0, "nessun fotogramma bloccato")
				_check(not _game.paused and not _game.get_tree().paused, "gioco non in pausa")
				_tap(&"dev")
			if _frame == 70:
				_check(not _game._touch.dev_open, "un secondo tocco su Opzioni chiude")
				_tap(&"dev")
			if _frame == 80:
				_check(_game._touch.dev_open, "riaperte")
				_tap(&"dev_close")
			if _frame == 90:
				_check(not _game._touch.dev_open, "Chiudi chiude")
				_tap(&"dev")
			if _frame == 100:
				# Tocco fuori dal pannello (in basso a sinistra, sulla zona dello stick).
				var q := Vector2(_game._touch.size.x * 0.1, _game._touch.size.y - 4.0)
				_touch(3, q, true)
				_touch(3, q, false)
			if _frame == 110:
				_check(not _game._touch.dev_open, "un tocco fuori dal pannello chiude")
				_shot("closed")
				for l in _log:
					print(l)
				print("e2e opzioni %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
	return false
