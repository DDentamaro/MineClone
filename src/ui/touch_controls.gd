class_name TouchControls
extends Control
## Controlli touch con ownership delle dita (piano §6). Ogni dito riceve un
## ruolo al contatto (stick, camera, pulsante) e lo tiene fino al rilascio o
## all'annullamento; attraversare un'altra area non cambia il ruolo.
##
## - Stick flottante: zona in basso a sinistra (40% larghezza, sotto il 35%
##   dell'altezza), come nel prototipo (riga 7837).
## - Camera: altrove. Oltre 8 px di trascinamento ruota la camera; un tocco
##   breve (< 450 ms, <= 8 px) senza pinch e' un "tap" sul mondo.
## - Pinch: due dita camera -> zoom.
## - Pulsanti disegnati qui (i Button di Godot non gestiscono il multitouch).
##
## Con "emulate_touch_from_mouse" anche il mouse del desktop passa di qui.

signal camera_dragged(delta: Vector2)
signal zoom_scaled(factor: float)
signal world_tapped(position: Vector2)
signal button_pressed(id: StringName)
## Inizio e fine della pressione di qualsiasi pulsante (per i tasti tenuti).
signal button_down(id: StringName)
signal button_up(id: StringName)

const TAP_MAX_MOVE := 8.0
const TAP_MAX_MS := 450
## Raggio di escursione dello stick in dp (prototipo: 40 px).
const STICK_RADIUS_DP := 44.0
## Lato minimo delle aree toccabili (piano §6: almeno 48 dp).
const BUTTON_DP := 64.0
const SMALL_BUTTON_DP := 52.0

enum Role { STICK, CAMERA, BUTTON }


class Finger:
	extends RefCounted
	var role: Role
	var start := Vector2.ZERO
	var last := Vector2.ZERO
	var t0 := 0
	var moved := 0.0
	var button: StringName = &""


class VButton:
	extends RefCounted
	var id: StringName
	var label: String
	var rect := Rect2()
	var hold := false
	var held := false
	## &"main" sempre visibile, &"dev" col pannello sviluppatore aperto,
	## &"hero" con l'editor dell'eroe aperto.
	var group: StringName = &"main"


var stick_vector := Vector2.ZERO
var stick_center := Vector2.ZERO
var left_handed := false
var labels := {}
## Pannello sviluppatore (comandi tecnici del prototipo) aperto.
var dev_open := false:
	set(v):
		dev_open = v
		queue_redraw()
## Editor dell'eroe aperto.
var hero_open := false:
	set(v):
		hero_open = v
		queue_redraw()
const DEV_BUTTON_W_DP := 118.0
const DEV_BUTTON_H_DP := 48.0

var _fingers := {} # index -> Finger
var _buttons: Array[VButton] = []
var _pinch_d0 := 0.0
var _pinch_used := false
var _font: Font


func _init() -> void:
	add_button(&"jump", "Salto", true)
	add_button(&"attack", "Colpo", false)
	add_button(&"heavy", "Forte", true)
	add_button(&"dodge", "Schiva", false)
	add_button(&"magic", "Magia", true)
	add_button(&"mode", "Modo", false)
	add_button(&"weapon", "Arma", false)
	add_button(&"spell", "Fuoco", false)
	add_button(&"hero", "Eroe", false)
	add_button(&"block", "Blocco", false)
	add_button(&"camera", "Camera", false)
	add_button(&"dev", "⚙", false)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	resized.connect(_layout)
	_layout()


func add_button(id: StringName, label: String, hold: bool, group: StringName = &"main") -> void:
	var b := VButton.new()
	b.id = id
	b.label = label
	b.hold = hold
	b.group = group
	_buttons.append(b)
	if is_inside_tree():
		_layout()


func _visible(b: VButton) -> bool:
	match b.group:
		&"dev":
			return dev_open
		&"hero":
			return hero_open
	return true


func set_button_label(id: StringName, text: String) -> void:
	for b in _buttons:
		if b.id == id:
			b.label = text
	queue_redraw()


func has_button(id: StringName) -> bool:
	for b in _buttons:
		if b.id == id:
			return true
	return false


func is_held(id: StringName) -> bool:
	for b in _buttons:
		if b.id == id:
			return b.held
	return false


func button_rect(id: StringName) -> Rect2:
	for b in _buttons:
		if b.id == id:
			return b.rect
	return Rect2()


func active_finger_count() -> int:
	return _fingers.size()


## dp -> unita' del canvas (che e' scalato con stretch "canvas_items").
func dp(v: float) -> float:
	var win := Vector2(DisplayServer.window_get_size())
	var vp := get_viewport_rect().size if is_inside_tree() else size
	var units_per_px := vp.y / win.y if win.y > 0 else 1.0
	var px_per_dp := maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	return v * px_per_dp * units_per_px


func _layout() -> void:
	var s := size
	var big := dp(BUTTON_DP) * 1.3
	var small := dp(SMALL_BUTTON_DP)
	var m := dp(20.0)
	var med := big * 0.78
	# Riga in alto dal bordo verso il centro: camera, blocco, modo, arma, eroe.
	var row: Array[StringName] = [&"camera", &"block", &"mode", &"weapon", &"spell", &"hero"]
	var dw := dp(DEV_BUTTON_W_DP)
	var dh := dp(DEV_BUTTON_H_DP)
	var cursor := {}
	for b in _buttons:
		var r := Rect2()
		if b.group != &"main":
			var c: Vector2 = cursor.get(b.group, Vector2(m, m + small + m + dh))
			if c.x + dw > s.x - m:
				c = Vector2(m, c.y + dh + m * 0.4)
			r = Rect2(c.x, c.y, dw, dh)
			cursor[b.group] = Vector2(c.x + dw + m * 0.4, c.y)
			b.rect = r
			continue
		var attack_x := s.x - m - big - m * 0.4 - big
		if b.id == &"jump":
			r = Rect2(s.x - m - big, s.y - m - big, big, big)
		elif b.id == &"attack":
			r = Rect2(attack_x, s.y - m - big, big, big)
		elif b.id == &"heavy":
			r = Rect2(attack_x + (big - med) * 0.5, s.y - m - big - m * 0.4 - med, med, med)
		elif b.id == &"dodge":
			r = Rect2(s.x - m - big + (big - med) * 0.5, s.y - m - big - m * 0.4 - med, med, med)
		elif b.id == &"magic":
			r = Rect2(attack_x - m * 0.4 - med, s.y - m - med, med, med)
		elif b.id == &"dev":
			r = Rect2(m, m + small * 0.9, small * 0.8, small * 0.8)
		else:
			var i := row.find(b.id)
			r = Rect2(s.x - m - small - i * (small + m * 0.5), m, small, small)
		if left_handed and b.id != &"dev":
			r.position.x = s.x - r.position.x - r.size.x
		b.rect = r
	queue_redraw()


func in_stick_zone(p: Vector2) -> bool:
	var zone_x := p.x < size.x * 0.4 if not left_handed else p.x > size.x * 0.6
	return zone_x and p.y > size.y * 0.35


func _input(event: InputEvent) -> void:
	var handled := false
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			handled = _touch_down(st.index, st.position)
		else:
			handled = _touch_up(st.index, st.position, st.canceled)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		handled = _touch_move(sd.index, sd.position)
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()


func _touch_down(index: int, p: Vector2) -> bool:
	if _fingers.has(index):
		_touch_up(index, p, true)
	var f := Finger.new()
	f.start = p
	f.last = p
	f.t0 = Time.get_ticks_msec()
	for b in _buttons:
		if _visible(b) and b.rect.has_point(p):
			if b.id == &"dev":
				dev_open = not dev_open
			f.role = Role.BUTTON
			f.button = b.id
			b.held = true
			button_down.emit(b.id)
			if not b.hold:
				button_pressed.emit(b.id)
			_fingers[index] = f
			queue_redraw()
			return true
	if in_stick_zone(p) and not _has_role(Role.STICK):
		f.role = Role.STICK
		stick_center = p
		stick_vector = Vector2.ZERO
	else:
		f.role = Role.CAMERA
		if _count_role(Role.CAMERA) >= 1:
			_pinch_used = true
			_pinch_d0 = 0.0
	_fingers[index] = f
	queue_redraw()
	return true


func _touch_move(index: int, p: Vector2) -> bool:
	var f: Finger = _fingers.get(index)
	if f == null:
		return false
	var delta := p - f.last
	f.last = p
	f.moved = maxf(f.moved, p.distance_to(f.start))
	match f.role:
		Role.STICK:
			var d := p - stick_center
			var r := dp(STICK_RADIUS_DP)
			var l := d.length()
			stick_vector = d / l * minf(1.0, l / r) if l > 0.0 else Vector2.ZERO
		Role.CAMERA:
			var cams := _fingers_with_role(Role.CAMERA)
			if cams.size() >= 2:
				var dd := cams[0].last.distance_to(cams[1].last)
				if _pinch_d0 > 0.0 and dd > 0.0:
					zoom_scaled.emit(dd / _pinch_d0)
				_pinch_d0 = dd
			elif f.moved > TAP_MAX_MOVE:
				camera_dragged.emit(delta)
		Role.BUTTON:
			pass
	queue_redraw()
	return true


func _touch_up(index: int, p: Vector2, canceled: bool) -> bool:
	var f: Finger = _fingers.get(index)
	if f == null:
		return false
	_fingers.erase(index)
	match f.role:
		Role.STICK:
			stick_vector = Vector2.ZERO
		Role.CAMERA:
			var quick := Time.get_ticks_msec() - f.t0 < TAP_MAX_MS
			if not canceled and not _pinch_used and quick and f.moved <= TAP_MAX_MOVE:
				world_tapped.emit(p)
			if _count_role(Role.CAMERA) == 0:
				_pinch_used = false
			_pinch_d0 = 0.0
		Role.BUTTON:
			for b in _buttons:
				if b.id == f.button:
					b.held = _button_still_held(b.id)
					if not b.held:
						button_up.emit(b.id)
	queue_redraw()
	return true


## Azzera tutti gli input mantenuti (perdita di focus, pausa, menu, morte).
func reset() -> void:
	_fingers.clear()
	stick_vector = Vector2.ZERO
	_pinch_used = false
	_pinch_d0 = 0.0
	for b in _buttons:
		if b.held:
			b.held = false
			button_up.emit(b.id)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset()


func _button_still_held(id: StringName) -> bool:
	for f: Finger in _fingers.values():
		if f.role == Role.BUTTON and f.button == id:
			return true
	return false


func _has_role(r: Role) -> bool:
	return _count_role(r) > 0


func _count_role(r: Role) -> int:
	return _fingers_with_role(r).size()


func _fingers_with_role(r: Role) -> Array[Finger]:
	var out: Array[Finger] = []
	for f: Finger in _fingers.values():
		if f.role == r:
			out.append(f)
	return out


func _draw() -> void:
	if _font == null:
		return
	var fs := int(dp(15.0))
	for b in _buttons:
		if not _visible(b):
			continue
		var c := b.rect.get_center()
		var r := b.rect.size.x * 0.5
		if b.group != &"main":
			draw_rect(b.rect, Color(0.08, 0.1, 0.12, 0.72 if not b.held else 0.9))
			draw_rect(b.rect, Color(0.63, 0.89, 0.78, 0.8), false, dp(1.5))
			r = b.rect.size.y * 0.5 * 2.2
		else:
			draw_circle(c, r, Color(0.08, 0.1, 0.12, 0.55 if not b.held else 0.8))
			draw_arc(c, r, 0.0, TAU, 40, Color(0.63, 0.89, 0.78, 0.8), dp(2.0), true)
		var text: String = labels.get(b.id, b.label)
		# Riduce il corpo del testo finche' l'etichetta sta dentro il cerchio.
		var size_px := fs
		var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px)
		while ts.x > r * 1.7 and size_px > 8:
			size_px -= 1
			ts = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px)
		draw_string(_font, c + Vector2(-ts.x * 0.5, ts.y * 0.3), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px, Color.WHITE)
	if _has_role(Role.STICK):
		var r := dp(STICK_RADIUS_DP)
		draw_circle(stick_center, r * 1.25, Color(0, 0, 0, 0.25))
		draw_arc(stick_center, r * 1.25, 0.0, TAU, 40, Color(1, 1, 1, 0.5), dp(2.0), true)
		draw_circle(stick_center + stick_vector * r, r * 0.5, Color(1, 1, 1, 0.6))
