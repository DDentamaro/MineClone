extends TestCase
## Ownership delle dita e gesti del TouchControls.

var _drags: Array[Vector2] = []
var _taps: Array[Vector2] = []
var _zooms: Array[float] = []
var _buttons: Array[StringName] = []


func _make() -> TouchControls:
	var tc := TouchControls.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(tc)
	tc.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tc.size = Vector2(1280, 720)
	tc._layout()
	_drags.clear()
	_taps.clear()
	_zooms.clear()
	_buttons.clear()
	tc.camera_dragged.connect(func(d: Vector2) -> void: _drags.append(d))
	tc.world_tapped.connect(func(p: Vector2) -> void: _taps.append(p))
	tc.zoom_scaled.connect(func(f: float) -> void: _zooms.append(f))
	tc.button_pressed.connect(func(id: StringName) -> void: _buttons.append(id))
	return tc


func _down(tc: TouchControls, i: int, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = true
	tc._input(e)


func _up(tc: TouchControls, i: int, p: Vector2, cancel := false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = false
	e.canceled = cancel
	tc._input(e)


func _move(tc: TouchControls, i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	tc._input(e)


func test_stick_e_camera_insieme() -> void:
	var tc := _make()
	_down(tc, 0, Vector2(200, 600))
	_move(tc, 0, Vector2(300, 600))
	check(tc.stick_vector.x > 0.99, "stick a destra (%s)" % tc.stick_vector)
	_down(tc, 1, Vector2(900, 300))
	_move(tc, 1, Vector2(950, 300))
	check_eq(_drags.size(), 1, "trascinamento camera")
	check(tc.stick_vector.x > 0.99, "lo stick non cambia")
	# Rilascio in ordine inverso.
	_up(tc, 0, Vector2(300, 600))
	check_eq(tc.stick_vector, Vector2.ZERO, "stick azzerato")
	_move(tc, 1, Vector2(1000, 300))
	check_eq(_drags.size(), 2, "la camera continua dopo il rilascio dello stick")
	_up(tc, 1, Vector2(1000, 300))
	check_eq(_taps.size(), 0, "un trascinamento non e' un tap")
	check_eq(tc.active_finger_count(), 0, "nessun dito attivo")
	tc.free()


func test_il_ruolo_non_cambia_attraversando_le_zone() -> void:
	var tc := _make()
	_down(tc, 3, Vector2(900, 200))
	_move(tc, 3, Vector2(200, 600))
	check_eq(tc.stick_vector, Vector2.ZERO, "un dito camera nella zona stick resta camera")
	check(_drags.size() >= 1, "ha ruotato la camera")
	_up(tc, 3, Vector2(200, 600))
	tc.free()


func test_tap_e_annullamento() -> void:
	var tc := _make()
	_down(tc, 0, Vector2(800, 300))
	_up(tc, 0, Vector2(803, 302))
	check_eq(_taps.size(), 1, "tap")
	_down(tc, 0, Vector2(800, 300))
	_up(tc, 0, Vector2(800, 300), true)
	check_eq(_taps.size(), 1, "un tocco annullato non e' un tap")
	tc.free()


func test_pinch_zoom_senza_tap() -> void:
	var tc := _make()
	_down(tc, 0, Vector2(700, 300))
	_down(tc, 1, Vector2(900, 300))
	_move(tc, 1, Vector2(950, 300))
	_move(tc, 1, Vector2(1000, 300))
	check(_zooms.size() >= 1 and _zooms[-1] > 1.0, "zoom in allargando (%s)" % [_zooms])
	check_eq(_drags.size(), 0, "il pinch non ruota la camera")
	_up(tc, 0, Vector2(700, 300))
	_up(tc, 1, Vector2(1000, 300))
	check_eq(_taps.size(), 0, "nessun tap dopo un pinch")
	tc.free()


func test_pulsanti() -> void:
	var tc := _make()
	var jump := tc.button_rect(&"jump").get_center()
	var mode := tc.button_rect(&"bag").get_center()
	_down(tc, 2, jump)
	check(tc.is_held(&"jump"), "salto mantenuto")
	_down(tc, 5, Vector2(200, 600))
	_move(tc, 5, Vector2(200, 650))
	check(tc.stick_vector.y > 0.9, "stick attivo mentre si tiene il salto")
	_up(tc, 2, jump)
	check(not tc.is_held(&"jump"), "salto rilasciato")
	_down(tc, 1, mode)
	check_eq(_buttons, [&"bag"] as Array[StringName], "zaino premuto una volta")
	_up(tc, 1, mode)
	check_eq(_taps.size(), 0, "i pulsanti non generano tap sul mondo")
	tc.free()


func test_reset_su_perdita_focus() -> void:
	var tc := _make()
	_down(tc, 0, Vector2(200, 600))
	_move(tc, 0, Vector2(300, 600))
	_down(tc, 1, tc.button_rect(&"jump").get_center())
	tc._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check_eq(tc.stick_vector, Vector2.ZERO, "stick azzerato")
	check(not tc.is_held(&"jump"), "salto rilasciato")
	check_eq(tc.active_finger_count(), 0, "dita dimenticate")
	# Un rilascio tardivo non produce azioni.
	_up(tc, 1, Vector2(1200, 650))
	check_eq(_buttons.size(), 0, "nessuna azione")
	tc.free()


func test_tocco_tenuto_sul_mondo() -> void:
	var tc := _make()
	var holds: Array = []
	tc.world_hold.connect(func(p: Vector2, on: bool) -> void: holds.append(on))
	_down(tc, 0, Vector2(900, 300))
	# Il tempo passa: simulato spostando l'inizio del dito indietro.
	for f in tc._fingers.values():
		f.t0 -= 300
	tc._process(0.016)
	check_eq(holds, [true], "inizio della tenuta")
	_up(tc, 0, Vector2(900, 300))
	check_eq(holds, [true, false], "fine della tenuta")
	check_eq(_taps.size(), 0, "una tenuta non e' un tap")
	tc.free()


func test_barra_magie_entra_nello_schermo_del_telefono() -> void:
	# Telefono 2400×1080 a 440 dpi: canvas 1600×720, 1 dp = 1,83 unita'
	# (~393 dp di altezza). La vecchia colonna usciva sopra lo schermo.
	for case: Array in [[Vector2(1600, 720), 1.83], [Vector2(1280, 720), 1.0], [Vector2(960, 720), 1.6], [Vector2(1560, 720), 2.4]]:
		var tc := _make()
		tc.dp_scale = case[1]
		tc.size = case[0]
		tc._layout()
		var others: Array[Rect2] = []
		for id: StringName in [&"jump", &"attack", &"heavy", &"dodge", &"magic", &"bag", &"hero", &"dev", &"camera", &"lock"]:
			others.append(tc.button_rect(id))
		var screen := Rect2(Vector2.ZERO, tc.size)
		# D-035: il pulsante Lock entra nello schermo e non copre gli altri.
		var lk := tc.button_rect(&"lock")
		check(screen.encloses(lk), "%s: Lock dentro lo schermo (%s)" % [case, lk])
		for o in others:
			if o != lk:
				check(not lk.intersects(o), "%s: Lock non copre %s" % [case, o])
		for i in TouchControls.SPELLBAR:
			var r := tc.button_rect(StringName("sp%d" % i))
			check(screen.encloses(r), "%s: slot %d dentro lo schermo (%s)" % [case, i + 1, r])
			check(r.size.x >= tc.dp(40.0) - 0.01, "%s: slot %d di almeno 40 dp" % [case, i + 1])
			for o in others:
				check(not r.intersects(o), "%s: slot %d non copre altri pulsanti (%s)" % [case, i + 1, o])
			if i > 0:
				check(not r.intersects(tc.button_rect(StringName("sp%d" % (i - 1)))), "slot separati")
		for i in TouchControls.HOTBAR:
			var h := tc.button_rect(StringName("hot%d" % i))
			check(screen.encloses(h), "%s: barra rapida %d dentro lo schermo" % [case, i + 1])
			for o in others:
				check(not h.intersects(o), "%s: barra rapida %d non sotto altri pulsanti (%s)" % [case, i + 1, o])
		# Un tocco al centro di ogni slot lo preme.
		for i in TouchControls.SPELLBAR:
			var c := tc.button_rect(StringName("sp%d" % i)).get_center()
			_buttons.clear()
			_down(tc, 1, c)
			_up(tc, 1, c)
			check(_buttons.has(StringName("sp%d" % i)), "%s: slot %d premuto" % [case, i + 1])
		tc.queue_free()
