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
## Dito fermo sul mondo oltre HOLD_MS (scavo): inizio, posizione aggiornata, fine.
signal world_hold(position: Vector2, active: bool)
## Pulsante tenuto a lungo (barra delle magie: apre il libro su quello slot).
signal button_long(id: StringName)

const TAP_MAX_MOVE := 8.0
const TAP_MAX_MS := 450
const HOLD_MS := 180
## Slot della barra rapida (in basso al centro).
const HOTBAR := 6
## Barra delle magie (RMNDWN: 5 equipaggiate).
const SPELLBAR := 5
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
	var holding := false
	var long_sent := false


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
## Icone della barra rapida: id -> {color, glyph, count, wear (0..1 o -1), rarity}.
var icons := {}
var hot_selected := 0
## Barra delle magie: id -> {spell: SpellDefinition, blocked, locked}; la scelta e la Pressione (0..1,25).
var spell_icons := {}
## Magia scelta, disegnata nel pulsante Magia col suo nome; motivo del blocco ("" = pronta).
var magic_spell: SpellDefinition
var magic_blocked := ""
## Scritta breve al centro (nome della magia al cambio): testo, colore, tempo rimasto.
var _toast := ""
var _toast_col := Color.WHITE
var _toast_t := 0.0
const LONG_MS := 450
var spell_selected := 0
## Fase del lancio (0 nessuna, 1 raccolta, 2 recupero) e avanzamento 0..1.
var cast_phase := 0
var cast_u := 0.0
var pressure := 0.0
var saturated := false
## Pulsanti nascosti in questo momento (es. "Auto" fuori dalla terza persona).
var hidden_ids := {}
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
	add_button(&"hero", "Eroe", false)
	add_button(&"bag", "Zaino", false)
	for i in HOTBAR:
		add_button(StringName("hot%d" % i), "", false, &"hotbar")
	for i in SPELLBAR:
		add_button(StringName("sp%d" % i), "", false, &"spellbar")
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
	if hidden_ids.get(b.id, false):
		return false
	# Opzioni aperte: pannello modale, restano solo i suoi pulsanti e "Chiudi".
	if dev_open and b.group != &"dev" and b.id != &"dev":
		return false
	match b.group:
		&"hotbar", &"spellbar":
			return not hero_open
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


## Unita' del canvas per dp imposte (test di schermi di telefono); 0 = dallo schermo.
var dp_scale := 0.0


## dp -> unita' del canvas (che e' scalato con stretch "canvas_items").
func dp(v: float) -> float:
	if dp_scale > 0.0:
		return v * dp_scale
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
	var row: Array[StringName] = [&"camera", &"tps_auto", &"bag", &"hero", &"dev"]
	var dw := dp(DEV_BUTTON_W_DP)
	var dh := dp(DEV_BUTTON_H_DP)
	var cursor := {}
	# Barra rapida in basso, fra il bordo e il pulsante Magia: al centro se c'e'
	# posto, altrimenti piu' stretta (su un telefono finiva sotto la Magia).
	var magic_left := s.x - m - big - m * 0.4 - big - m * 0.4 - med
	var hot_right := magic_left - m * 0.5
	var hs := minf(dp(50.0), (hot_right - m - (HOTBAR - 1) * dp(4.0)) / HOTBAR)
	var hot_w := HOTBAR * hs + (HOTBAR - 1) * dp(4.0)
	var hx0 := clampf(s.x * 0.5 - hot_w * 0.5, m, hot_right - hot_w)
	var spells := _spell_row(s, m, big, med, small)
	_layout_dev_panel(s, m, small)
	for b in _buttons:
		var r := Rect2()
		if b.group == &"hotbar":
			var i := int(String(b.id).substr(3))
			b.rect = Rect2(hx0 + i * (hs + dp(4.0)), s.y - m * 0.6 - hs, hs, hs)
			continue
		if b.group == &"spellbar":
			r = spells[int(String(b.id).substr(2))]
			if left_handed:
				r.position.x = s.x - r.position.x - r.size.x
			b.rect = r
			continue
		if b.group == &"dev":
			continue
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
		else:
			var i := row.find(b.id)
			if i < 0:
				b.rect = Rect2(-1000, -1000, 0, 0)
				continue
			r = Rect2(s.x - m - small - i * (small + m * 0.5), m, small, small)
		if left_handed:
			r.position.x = s.x - r.position.x - r.size.x
		b.rect = r
	queue_redraw()


## Barra delle magie: una riga di 5 slot sopra i pulsanti d'azione, allineata
## al bordo. Il lato scende (fino a 40 dp) finche' la riga non entra fra lo
## stick e il bordo e fra la riga in alto e i pulsanti d'azione: su un telefono
## in orizzontale (circa 390 dp di altezza) la vecchia colonna usciva dallo
## schermo e gli slot in alto non si potevano premere.
func _spell_row(s: Vector2, m: float, big: float, med: float, small: float) -> Array[Rect2]:
	var gap := dp(6.0)
	var label_h := dp(22.0)
	var bottom := s.y - m - big - m * 0.4 - med - m * 0.5
	var top_limit := m + small + m * 0.5 + label_h
	var right := s.x - m * 0.5
	var left_limit := s.x * 0.42
	var ss := dp(56.0)
	ss = minf(ss, (right - left_limit - gap * (SPELLBAR - 1)) / SPELLBAR)
	ss = minf(ss, bottom - top_limit)
	ss = maxf(ss, dp(40.0))
	var out: Array[Rect2] = []
	var x0 := right - SPELLBAR * ss - (SPELLBAR - 1) * gap
	for i in SPELLBAR:
		out.append(Rect2(x0 + i * (ss + gap), bottom - ss, ss, ss))
	return out


## Pannello delle Opzioni (modale): sotto la riga in alto, dentro lo schermo.
var dev_panel := Rect2()
const DEV_TITLE_DP := 30.0


## Griglia delle opzioni che entra sempre nel pannello: colonne larghe almeno
## 84 dp (fino a 118), righe alte fino a 48 dp (almeno 30). Su un telefono in
## orizzontale il vecchio flusso di pulsanti da 118×48 dp usciva dal bordo in
## basso e copriva stick e pulsanti: ogni tocco premeva un'opzione a caso.
func _layout_dev_panel(s: Vector2, m: float, small: float) -> void:
	var top := m + small + m * 0.5
	dev_panel = Rect2(m * 0.5, top, s.x - m, s.y - top - m * 0.5)
	var list: Array[VButton] = []
	for b in _buttons:
		if b.group == &"dev" and not hidden_ids.get(b.id, false):
			list.append(b)
	if list.is_empty():
		return
	var gap := dp(6.0)
	var inner := dev_panel.grow(-dp(8.0))
	inner.position.y += dp(DEV_TITLE_DP)
	inner.size.y -= dp(DEV_TITLE_DP)
	var cols := maxi(2, int((inner.size.x + gap) / (dp(DEV_BUTTON_W_DP) + gap)))
	var rows := ceili(float(list.size()) / cols)
	var bh := (inner.size.y - gap * (rows - 1)) / rows
	while bh < dp(30.0) and (inner.size.x - gap * cols) / (cols + 1) >= dp(84.0):
		cols += 1
		rows = ceili(float(list.size()) / cols)
		bh = (inner.size.y - gap * (rows - 1)) / rows
	bh = minf(bh, dp(DEV_BUTTON_H_DP))
	var bw := (inner.size.x - gap * (cols - 1)) / cols
	for i in list.size():
		var c := i % cols
		var r := i / cols
		list[i].rect = Rect2(inner.position.x + c * (bw + gap), inner.position.y + r * (bh + gap), bw, bh)


func in_stick_zone(p: Vector2) -> bool:
	var zone_x := p.x < size.x * 0.4 if not left_handed else p.x > size.x * 0.6
	return zone_x and p.y > size.y * 0.35


## Vero mentre un pannello a tutto schermo (zaino) ha l'input.
var blocked := false


func _input(event: InputEvent) -> void:
	if blocked:
		return
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
	var on_button := false
	for b in _buttons:
		if _visible(b) and b.rect.has_point(p):
			on_button = true
			break
	# Pannello modale: un tocco fra i suoi pulsanti non fa nulla; fuori dal
	# pannello diventa un tocco sul mondo (che lo chiude), mai stick o camera.
	if dev_open and not on_button:
		f.role = Role.BUTTON
		f.button = &"" if dev_panel.has_point(p) else &"__outside"
		_fingers[index] = f
		return true
	for b in _buttons:
		if _visible(b) and b.rect.has_point(p):
			if b.id == &"dev":
				dev_open = not dev_open
			f.role = Role.BUTTON
			f.button = b.id
			b.held = true
			# Il dito si registra prima dei segnali: se il pulsante apre un pannello
			# (reset dei tocchi), il dito sparisce davvero.
			_fingers[index] = f
			button_down.emit(b.id)
			if not b.hold:
				button_pressed.emit(b.id)
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


func show_toast(text: String, col: Color = Color.WHITE) -> void:
	_toast = text
	_toast_col = col
	_toast_t = 1.3
	queue_redraw()


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if _toast_t > 0.0:
		_toast_t -= _dt
		queue_redraw()
	for f: Finger in _fingers.values():
		if f.role == Role.BUTTON and not blocked and not f.long_sent and now - f.t0 >= LONG_MS and String(f.button).begins_with("sp"):
			f.long_sent = true
			button_long.emit(f.button)
	for f: Finger in _fingers.values():
		if f.role == Role.CAMERA and not f.holding and not _pinch_used and f.moved <= TAP_MAX_MOVE \
				and now - f.t0 >= HOLD_MS and _count_role(Role.CAMERA) == 1:
			f.holding = true
			world_hold.emit(f.last, true)


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
			if f.holding:
				# Il dito che scava puo' scorrere sul bersaglio senza ruotare la camera.
				world_hold.emit(p, true)
				queue_redraw()
				return true
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
			# Tocco breve e fermo nella zona dello stick: e' un tocco sul mondo
			# (oggetti, forzieri, armeria in basso a sinistra dello schermo).
			if not canceled and Time.get_ticks_msec() - f.t0 < TAP_MAX_MS and p.distance_to(f.start) <= TAP_MAX_MOVE:
				world_tapped.emit(p)
		Role.CAMERA:
			var quick := Time.get_ticks_msec() - f.t0 < TAP_MAX_MS
			if f.holding:
				world_hold.emit(p, false)
			elif not canceled and not _pinch_used and quick and f.moved <= TAP_MAX_MOVE:
				world_tapped.emit(p)
			if _count_role(Role.CAMERA) == 0:
				_pinch_used = false
			_pinch_d0 = 0.0
		Role.BUTTON:
			if f.button == &"__outside" and not canceled:
				world_tapped.emit(p)
			for b in _buttons:
				if b.id == f.button:
					b.held = _button_still_held(b.id)
					if not b.held:
						button_up.emit(b.id)
	queue_redraw()
	return true


## Azzera tutti gli input mantenuti (perdita di focus, pausa, menu, morte).
func reset() -> void:
	for f: Finger in _fingers.values():
		if f.holding:
			world_hold.emit(f.last, false)
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
	if dev_open:
		# Pannello modale: il gioco si vede sotto, velato; titolo e suggerimento.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		draw_rect(dev_panel, Color(0.05, 0.06, 0.07, 0.86))
		draw_rect(dev_panel, Color(0.63, 0.89, 0.78, 0.7), false, dp(1.5))
		_outlined(dev_panel.position + Vector2(dp(10.0), dp(21.0)), "Opzioni", 15.0, Color.WHITE, false)
		var hint := "tocca fuori dal pannello per chiudere"
		var hs := int(dp(11.0))
		var tw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		_outlined(Vector2(dev_panel.end.x - dp(10.0) - tw, dev_panel.position.y + dp(20.0)), hint, 11.0, Color(0.8, 0.85, 0.82), false)
	for b in _buttons:
		if not _visible(b):
			continue
		var c := b.rect.get_center()
		var r := b.rect.size.x * 0.5
		if b.group == &"hotbar":
			_draw_hot_slot(b)
			continue
		if b.group == &"spellbar":
			_draw_spell_slot(b)
			continue
		if b.id == &"magic" and magic_spell != null:
			_draw_magic_button(b)
			continue
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
	_draw_after()


func _draw_hot_slot(b: VButton) -> void:
	var i := int(String(b.id).substr(3))
	var sel := i == hot_selected
	draw_rect(b.rect, Color(0.08, 0.1, 0.12, 0.8 if sel else 0.55))
	draw_rect(b.rect, Color(1, 0.9, 0.5, 1) if sel else Color(0.63, 0.89, 0.78, 0.6), false, dp(3.0 if sel else 1.5))
	var ic: Dictionary = icons.get(b.id, {})
	if ic.is_empty():
		return
	var inner := b.rect.grow(-b.rect.size.x * 0.2)
	draw_rect(inner, ic["color"])
	var rc: Color = ic.get("rarity_color", Color(0, 0, 0, 0))
	if rc.a > 0.0:
		draw_rect(inner.grow(dp(2.0)), rc, false, dp(2.0))
	var g: String = ic.get("glyph", "")
	var fs := int(dp(13.0))
	var ts := _font.get_string_size(g, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string_outline(_font, inner.get_center() + Vector2(-ts.x * 0.5, ts.y * 0.3), g, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, int(dp(3.0)), Color(0, 0, 0, 0.8))
	draw_string(_font, inner.get_center() + Vector2(-ts.x * 0.5, ts.y * 0.3), g, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)
	var n: int = ic.get("count", 1)
	if n > 1:
		var t := str(n)
		var p := b.rect.position + b.rect.size - Vector2(dp(4.0), dp(4.0))
		var tsz := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_RIGHT, -1, fs)
		draw_string_outline(_font, p - Vector2(tsz.x, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(dp(3.0)), Color(0, 0, 0, 0.9))
		draw_string(_font, p - Vector2(tsz.x, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var wr: float = ic.get("wear", -1.0)
	if wr >= 0.0:
		var bar := Rect2(b.rect.position + Vector2(dp(4.0), b.rect.size.y - dp(6.0)), Vector2((b.rect.size.x - dp(8.0)) * wr, dp(3.0)))
		draw_rect(bar, Color(1.0 - wr, 0.3 + 0.6 * wr, 0.2))


## Colore dell'elemento sul bordo sinistro dello slot (RMNDWN #spellBar).
const EL_EDGE := {"fire": Color("#ff8a2a"), "water": Color("#6bb8ff"), "earth": Color("#a58a58"), "air": Color("#d8e6ea"), "karma": Color("#a86bff")}


func _draw_spell_slot(b: VButton) -> void:
	var i := int(String(b.id).substr(2))
	var sel := i == spell_selected
	var ic: Dictionary = spell_icons.get(b.id, {})
	var rect := b.rect
	if sel:
		rect = rect.grow(dp(3.0))
	if b.held:
		rect = rect.grow(-dp(2.0))
	draw_rect(rect, Color(0.19, 0.16, 0.06, 0.86) if sel else Color(0.04, 0.05, 0.045, 0.78))
	if ic.is_empty():
		var fs := int(dp(20.0))
		var ts := _font.get_string_size("+", HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(_font, rect.get_center() + Vector2(-ts.x * 0.5, ts.y * 0.3), "+", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(0.7, 0.8, 0.75, 0.6))
	else:
		var sp: SpellDefinition = ic["spell"]
		var dim: bool = ic.get("blocked", false) or ic.get("locked", false)
		SpellIcons.draw(self, rect.grow(-dp(5.0)), sp, dim, ic.get("locked", false))
		# Bordo sinistro nel colore dell'elemento.
		var edge: Color = EL_EDGE.get(sp.el, Color.WHITE)
		draw_rect(Rect2(rect.position, Vector2(dp(3.5), rect.size.y)), Color(edge, 0.45 if dim else 1.0))
		# Fase del lancio sullo slot scelto: raccolta che si riempie, recupero che si svuota.
		if sel and cast_phase > 0:
			var track := Rect2(rect.position + Vector2(dp(3.5), rect.size.y - dp(4.0)), Vector2(rect.size.x - dp(3.5), dp(4.0)))
			draw_rect(track, Color(1, 1, 1, 0.14))
			var col := Color("#8fd3ff") if cast_phase == 1 else Color("#c94f45")
			draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(cast_u, 0.0, 1.0), track.size.y)), col)
	var border := Color("#c9a23f") if sel else Color(0.63, 0.89, 0.78, 0.45)
	if sel and cast_phase == 1:
		border = Color("#8fd3ff")
	draw_rect(rect, border, false, dp(3.0 if sel else 1.5))
	# Numero dello slot in alto a sinistra.
	var ns := int(dp(11.0))
	var np := rect.position + Vector2(dp(6.0), dp(13.0))
	draw_string_outline(_font, np, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, ns, int(dp(2.5)), Color(0, 0, 0, 0.9))
	draw_string(_font, np, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color(1, 1, 1, 0.9))


## Sopra la barra: nome della magia scelta con livello e Output, e la barra
## della Pressione (viola, rossa se il nucleo e' saturo).
func _draw_spell_header() -> void:
	var r0 := button_rect(&"sp0")
	var r4 := button_rect(&"sp%d" % (SPELLBAR - 1))
	if r0.size.x <= 0.0 or hero_open or dev_open or magic_spell == null:
		return
	var left := minf(r0.position.x, r4.position.x)
	var right := maxf(r0.end.x, r4.end.x)
	var y := r0.position.y - dp(6.0)
	var bar := Rect2(left, y - dp(4.0), right - left, dp(4.0))
	draw_rect(bar, Color(0, 0, 0, 0.45))
	var p := clampf(pressure, 0.0, 1.0)
	if p > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color("#ff6a5a") if saturated else Color("#a86bff"))
	var text := magic_spell.display_name + "  ·  T%d · Output %d" % [magic_spell.tier, int(magic_spell.output)]
	var col := Color.WHITE
	if magic_blocked != "":
		text = magic_spell.display_name + "  ·  " + magic_blocked
		col = Color(1.0, 0.6, 0.5)
	var fs := int(dp(12.0))
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := Vector2(right - ts.x, bar.position.y - dp(4.0))
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(dp(3.0)), Color(0, 0, 0, 0.85))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _outlined(p: Vector2, text: String, size_dp: float, col: Color, center: bool = true) -> void:
	var fs := int(dp(size_dp))
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := p - Vector2(ts.x * 0.5 if center else 0.0, 0)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(dp(3.0)), Color(0, 0, 0, 0.85))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Pulsante Magia: icona della magia scelta nel cerchio e la raccolta in corso.
func _draw_magic_button(b: VButton) -> void:
	var c := b.rect.get_center()
	var r := b.rect.size.x * 0.5
	draw_circle(c, r, Color(0.08, 0.1, 0.12, 0.55 if not b.held else 0.8))
	var q := r * 1.05
	SpellIcons.draw(self, Rect2(c - Vector2(q, q) * 0.5, Vector2(q, q)), magic_spell, magic_blocked != "")
	draw_arc(c, r, 0.0, TAU, 40, magic_spell.color().lightened(0.3), dp(2.5), true)
	# Raccolta in corso: arco azzurro dentro il cerchio (il nome e' sopra la barra).
	if cast_phase == 1:
		draw_arc(c, r - dp(4.0), -PI * 0.5, -PI * 0.5 + TAU * clampf(cast_u, 0.0, 1.0), 40, Color("#8fd3ff"), dp(3.0), true)


## Pressione del nucleo come arco attorno al pulsante Magia (rosso se saturo).
func _draw_pressure() -> void:
	var r := button_rect(&"magic")
	if r.size.x <= 0.0 or hero_open or dev_open:
		return
	var c := r.get_center()
	var rad := r.size.x * 0.5 + dp(5.0)
	draw_arc(c, rad, -PI * 0.5, PI * 1.5, 40, Color(0, 0, 0, 0.35), dp(4.0), true)
	var p := clampf(pressure, 0.0, 1.0)
	if p > 0.005:
		var col := Color(1.0, 0.25, 0.2) if saturated else Color(0.4 + 0.6 * p, 0.85 - 0.5 * p, 1.0 - 0.7 * p)
		draw_arc(c, rad, -PI * 0.5, -PI * 0.5 + TAU * p, 40, col, dp(4.0), true)


func _draw_after() -> void:
	_draw_pressure()
	_draw_spell_header()
	if _toast_t > 0.0 and _toast != "":
		var a := clampf(_toast_t / 0.3, 0.0, 1.0)
		_outlined(Vector2(size.x * 0.5, size.y * 0.24), _toast, 20.0, Color(_toast_col, a))
	if _has_role(Role.STICK):
		var r := dp(STICK_RADIUS_DP)
		draw_circle(stick_center, r * 1.25, Color(0, 0, 0, 0.25))
		draw_arc(stick_center, r * 1.25, 0.0, TAU, 40, Color(1, 1, 1, 0.5), dp(2.0), true)
		draw_circle(stick_center + stick_vector * r, r * 0.5, Color(1, 1, 1, 0.6))
