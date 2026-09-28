extends SceneTree
## Prova end-to-end del nuoto (xvfb-run): "Al lago", poi stick verso l'acqua con
## tocchi reali. Controlla ingresso in acqua, nuoto, schizzi e anelli; salva
## screenshot. Uso: xvfb-run -a godot --path . --script res://tools/e2e_swim.gd -- --out=/tmp/swim.png

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://swim.png"
var _ok := true
var _max_grains := 0
var _saw_swim := false


func _initialize() -> void:
	# Impostazioni proprie, per non toccare quelle del giocatore.
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


func _process(_dt: float) -> bool:
	_frame += 1
	var size := root.get_visible_rect().size
	match _phase:
		0:
			if _game._runtime.is_idle() and _game._build_ms > 0 and _game._vegetation.is_idle() and _game._water.is_idle():
				_game._day.time = 0.35
				_game._day.paused = true
				_ok = _game.go_to_lake()
				# Stick nella direzione del lago, espressa nella base della camera.
				var rig := _game._camera_rig
				var d := Vector3(_game.lake_dir.x, 0, _game.lake_dir.y)
				var st := Vector2(d.dot(rig.ground_right()), d.dot(rig.ground_forward()))
				var c := Vector2(size.x * 0.15, size.y * 0.75)
				_touch(0, c, true)
				_drag(0, c + Vector2(st.x, -st.y) * 60.0)
				_phase = 1
				_frame = 0
		1:
			_max_grains = maxi(_max_grains, _game._grains.count())
			if _game.motor.swimming:
				_saw_swim = true
			if _frame == 45:
				root.get_texture().get_image().save_png(_out.replace(".png", "_a.png"))
			if _frame == 120:
				_touch(0, Vector2.ZERO, false)
				print("nuoto: %s · stato %s · grani max %d · posizione %s" % [_saw_swim, _game.motor.water_state, _max_grains, _game.motor.position])
				_ok = _ok and _saw_swim and _max_grains > 0
				root.get_texture().get_image().save_png(_out)
				print("screenshot %s · e2e nuoto %s" % [_out, "OK" if _ok else "FALLITO"])
				quit(0 if _ok else 1)
	return false
