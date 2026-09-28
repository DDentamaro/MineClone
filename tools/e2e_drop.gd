extends SceneTree
## Prova end-to-end degli oggetti a terra (D-028) con tocchi reali nello zaino:
## si sceglie la spada, "Getta", la spada cade davanti all'eroe, poi l'eroe ci
## passa sopra (spostato sul punto: lo stick non e' parte di questa prova) e la
## riprende. Uso: xvfb-run -a godot --path . --script res://tools/e2e_drop.gd -- --out=/tmp/drop.png

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://drop.png"
var _ok := true
var _log: Array[String] = []


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


func _tap_at(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 3
		e.position = p
		e.pressed = pressed
		Input.parse_input_event(e)


func _shot(name: String) -> void:
	var path := _out.replace(".png", "_%s.png" % name)
	root.get_texture().get_image().save_png(path)
	_log.append("screenshot " + path)


func _sword_count() -> int:
	return _game.items.inv.count(&"sword_wood")


func _process(_dt: float) -> bool:
	_frame += 1
	match _phase:
		0:
			if _game._runtime.is_idle() and _game._build_ms > 0 and _game._vegetation.is_idle() and _game._water.is_idle():
				_game._day.time = 0.4
				_game._day.paused = true
				_game._camera_rig.set_zoom(1.8)
				_game._camera_rig.zoom = 1.8
				_log.append("spade nello zaino all'inizio: %d" % _sword_count())
				_ok = _ok and _sword_count() == 1
				_phase = 1
				_frame = 0
		1:
			if _frame == 5:
				_tap_at(_game._touch.button_rect(&"bag").get_center())
			if _frame == 20:
				_tap_at((_game._bag.slot_rects[0] as Rect2).get_center())
			if _frame == 30:
				_ok = _ok and _game._bag.button_rects.has("Getta")
				_tap_at((_game._bag.button_rects["Getta"] as Rect2).get_center())
			if _frame == 40:
				_tap_at(_game._bag.close_rect.get_center())
			if _frame == 70:
				_shot("a_terra")
				_log.append("a terra: %d, spade nello zaino: %d" % [_game.ground.list.size(), _sword_count()])
				_ok = _ok and _game.ground.list.size() == 1 and _sword_count() == 0
				_ok = _ok and _game.ground.list[0].landed
				var st := _game.make_save_state()
				_ok = _ok and (st["ground"] as Array).size() == 1
				_phase = 2
				_frame = 0
		2:
			if _frame == 30:
				var p: Vector3 = _game.ground.list[0].p
				_game.motor.place_at(Vector3(p.x, p.y, p.z))
			if _frame == 60:
				_shot("ripresa")
				_log.append("dopo il passaggio: a terra %d, spade nello zaino %d" % [_game.ground.list.size(), _sword_count()])
				_ok = _ok and _game.ground.list.is_empty() and _sword_count() == 1
				for l in _log:
					print(l)
				print("e2e oggetti a terra %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
	return false
