extends SceneTree
## Prova end-to-end della locomozione dell'eroe del prototipo (D-028): stick
## vero (tocco e trascinamento), corsa, arresto con assestamento, salto,
## colpo. Salva una tavola di fotogrammi ravvicinati (--out) e controlla che i
## piedi piantati non scivolino mentre il corpo avanza.
## Uso: xvfb-run -a godot --path . --script res://tools/e2e_walk.gd -- --out=/tmp/walk.png

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://walk.png"
var _ok := true
var _log: Array[String] = []
var _frames: Array[Image] = []
var _labels: Array[String] = []
var _slide := 0.0
var _prev: Array = [null, null]
var _steps := 0
var _start := Vector3.ZERO


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


func _grab(label: String) -> void:
	# Ritaglio attorno all'eroe (centro dello schermo).
	var img := root.get_texture().get_image()
	var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
	var w := 300
	var h := 330
	_frames.append(img.get_region(Rect2i(c.x - w / 2, c.y - h / 2 - 50, w, h)))
	_labels.append(label)


func _track_feet() -> void:
	var g := _game._avatar.gait
	for k in 2:
		var l: GaitLegs.Leg = g.legs[k]
		if l.planted:
			if _prev[k] != null:
				_slide = maxf(_slide, (_prev[k] as Vector3).distance_to(l.foot))
			_prev[k] = l.foot
		else:
			if _prev[k] != null:
				_steps += 1
			_prev[k] = null


func _process(_dt: float) -> bool:
	_frame += 1
	var stick := Vector2(160, 560)
	match _phase:
		0:
			if _game._runtime.is_idle() and _game._build_ms > 0 and _game._vegetation.is_idle() and _game._water.is_idle():
				_game._day.time = 0.4
				_game._day.paused = true
				_game._camera_rig.set_zoom(3.2)
				_game._camera_rig.zoom = 3.2
				_game._dummies.place_around(_game.motor.position + Vector3(0, 0, -30), 0.0)
				_phase = 1
				_frame = 0
		1:
			if _frame == 20:
				_grab("fermo")
				_start = _game.motor.position
				_touch(1, stick, true)
			if _frame == 22:
				_drag(1, stick + Vector2(70, 0), Vector2(70, 0))
			if _frame > 22:
				_track_feet()
			if _frame in [34, 37, 40, 43, 46, 49]:
				_grab("corsa %d" % ((_frame - 34) / 3 + 1))
			if _frame == 70:
				_touch(1, stick + Vector2(70, 0), false)
				_log.append("corsa: %.2f m, passi %d, scivolamento massimo del piede d'appoggio %.4f m" % [_game.motor.position.distance_to(_start), _steps, _slide])
				_ok = _ok and _game.motor.position.distance_to(_start) > 2.0 and _steps >= 4 and _slide < 0.001
			if _frame in [74, 80]:
				_grab("arresto %d" % ((_frame - 74) / 6 + 1))
			if _frame == 100:
				_grab("assestato")
				var g := _game._avatar.gait
				_ok = _ok and g.legs[0].planted and g.legs[1].planted
				_touch(2, _game._touch.button_rect(&"jump").get_center(), true)
			if _frame == 106:
				_grab("salto")
				_touch(2, _game._touch.button_rect(&"jump").get_center(), false)
			if _frame == 130:
				_touch(3, _game._touch.button_rect(&"attack").get_center(), true)
				_touch(3, _game._touch.button_rect(&"attack").get_center(), false)
			if _frame in [134, 138]:
				_grab("colpo %d" % ((_frame - 134) / 4 + 1))
			if _frame == 160:
				_save_sheet()
				for l in _log:
					print(l)
				print("e2e passo %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
	return false


func _save_sheet() -> void:
	var cols := 6
	var rows := ceili(_frames.size() / float(cols))
	var fw := _frames[0].get_width()
	var fh := _frames[0].get_height()
	var sheet := Image.create(fw * cols, fh * rows, false, _frames[0].get_format())
	for i in _frames.size():
		sheet.blit_rect(_frames[i], Rect2i(0, 0, fw, fh), Vector2i((i % cols) * fw, (i / cols) * fh))
	sheet.save_png(_out)
	_log.append("tavola %s: %s" % [_out, ", ".join(_labels)])
