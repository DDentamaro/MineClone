class_name SessionOverlay
extends Control
## HUD, diario e pausa; input touch nativo, mouse emulato e navigazione tastiera.
## Le azioni sono emesse solo al rilascio sul medesimo controllo.

signal action(id: StringName)

var journal: ExpeditionJournal
var page := ""
var held_name := "Mani libere"
var clock_text := ""
var context_text := ""
var mining := -1.0
var show_objective := true
var left_handed := false
var reduced_motion := false
var quality := 360
var volume := 80
var hints := true
var hud_visible := true
var ui_density := 1.0
## Rettangoli (schermo) dei comandi touch da non coprire con l'indicazione.
var avoid: Array[Rect2] = []
var save_text := "Salvataggio automatico ogni 60 secondi"
var _toast := ""
var _toast_time := 0.0
var _buttons: Array[Dictionary] = []
var _pressed: StringName = &""
var _finger := -1
var _focus := 0
var _font: Font
var _scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font


func open(value: String) -> void:
	page = value
	_pressed = &""
	_finger = -1
	_focus = 0
	_buttons.clear()
	queue_redraw()


func notify(text: String) -> void:
	_toast = text
	_toast_time = 4.0
	queue_redraw()


func _process(dt: float) -> void:
	var was_visible := _toast_time > 0.0
	_toast_time = maxf(0.0, _toast_time - dt)
	if was_visible and _toast_time <= 0.0:
		queue_redraw()


func _text(at: Vector2, value: String, font_size: int, color: Color = GamePalette.INK, width: float = -1) -> void:
	draw_string(_font, at * _scale, value, HORIZONTAL_ALIGNMENT_LEFT, width * _scale if width > 0 else -1, maxi(10, roundi(font_size * _scale)), color)


func _box(rect: Rect2, selected: bool = false) -> void:
	GamePalette.box(self, Rect2(rect.position * _scale, rect.size * _scale), selected)


func _button(rect: Rect2, label: String, id: StringName, accent: bool = false) -> void:
	var selected := accent or (page != "" and _focus == _buttons.size()) or _pressed == id
	_box(rect, selected)
	_text(rect.position + Vector2(18, rect.size.y * 0.5 + 6), label, 17, GamePalette.ACCENT if selected else GamePalette.INK, rect.size.x - 32)
	_buttons.append({"rect": Rect2(rect.position * _scale, rect.size * _scale), "id": id})


func _draw() -> void:
	if _font == null or journal == null or size.x < 1.0 or size.y < 1.0:
		return
	_buttons.clear()
	_scale = minf(size.x / 960.0, size.y / 620.0)
	_scale = minf(_scale, 1.25)
	var s := size / _scale
	if page != "":
		# Telefoni in orizzontale ad alta densita': menu piu' corto a due colonne,
		# cosi' i pulsanti tengono la loro misura fisica invece di rimpicciolirsi.
		var compact_scale := minf(ui_density, minf(size.x / 660.0, size.y / 390.0))
		if compact_scale > _scale * 1.2:
			_scale = compact_scale
			_draw_compact_menu(size / _scale)
		else:
			_draw_menu(s)
		return
	if not hud_visible:
		return
	# Scheda compatta; la telemetria di debug si vede solo negli strumenti sviluppatore.
	var x := s.x - 312.0 if left_handed else 20.0
	_box(Rect2(x, 20, 292, 92))
	_text(Vector2(x + 16, 45), "ISOTERRA", 21, GamePalette.ACCENT)
	_text(Vector2(x + 178, 45), clock_text, 14, GamePalette.MUTED, 102)
	_text(Vector2(x + 16, 75), held_name, 16, GamePalette.INK, 260)
	_text(Vector2(x + 16, 97), "ESPLORA  /  CREA  /  SCOPRI", 10, GamePalette.MUTED)
	if hints and show_objective:
		var goal := journal.current()
		_box(Rect2(x, 124, 292, 100))
		_text(Vector2(x + 16, 147), "DIARIO   %d / %d" % [journal.completed_count(), ExpeditionJournal.GOALS.size()], 11, GamePalette.ACCENT)
		_text(Vector2(x + 16, 171), "La tua avventura continua" if goal.is_empty() else String(goal["title"]), 16, GamePalette.INK, 260)
		var fraction := 1.0 if goal.is_empty() else float(journal.counts.get(goal["id"], 0.0)) / float(goal["target"])
		draw_rect(Rect2(Vector2(x + 16, 184) * _scale, Vector2(260, 3) * _scale), GamePalette.EDGE)
		draw_rect(Rect2(Vector2(x + 16, 184) * _scale, Vector2(260 * fraction, 3) * _scale), GamePalette.ACCENT)
		var clues := {"walk": "WASD / stick: esplora 24 metri", "harvest": "Tieni premuto su alberi o blocchi", "craft": "Zaino > Craft: banco da lavoro", "build": "Impugna il banco e tocca il terreno", "hit": "J / Colpo: colpisci i manichini", "dodge": "Maiusc / Schiva: esegui una capriola", "camp": "Crea un falò e interagisci", "treasure": "Cerca i forzieri oltre il campo"}
		_text(Vector2(x + 16, 210), String(clues.get(goal.get("id", ""), "Menu > Diario per i traguardi")), 12, GamePalette.MUTED, 260)
	if context_text != "":
		# Sotto i piedi dell'eroe (al centro dello schermo) e sopra gli avvisi:
		# a meta' schermo copriva il personaggio.
		var ch := maxf(48, 48 * ui_density / _scale)
		var cr := Rect2(s.x * 0.5 - 148, s.y - 180 - ch, 296, ch)
		# Si sposta a sinistra finche' non copre piu' i pulsanti (Lock, Colpo...).
		while cr.position.x > 20.0 and _covers(cr):
			cr.position.x -= 16.0
		# Schermo stretto: nessun posto a sinistra, allora sale sopra i pulsanti.
		if _covers(cr):
			cr.position.x = s.x * 0.5 - 148
			while cr.position.y > 130.0 and _covers(cr):
				cr.position.y -= 16.0
		_button(cr, context_text, &"interact", true)
	if mining >= 0.0:
		# In alto al centro: non si sovrappone all'indicazione dell'oggetto vicino.
		var r := Rect2(s.x * 0.5 - 110, 24, 220, 34)
		_box(r)
		_text(r.position + Vector2(12, 23), "Raccolta   %d%%" % roundi(mining * 100), 14)
		draw_rect(Rect2((r.position + Vector2(1, 30)) * _scale, Vector2(218 * mining, 3) * _scale), GamePalette.ACCENT)
	if _toast_time > 0.0:
		var r := Rect2(s.x * 0.5 - 220, s.y - 170, 440, 44)
		_box(r)
		_text(r.position + Vector2(16, 28), _toast, 15, GamePalette.INK, 408)


func _draw_menu(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.05, 0.06, 0.82))
	var p := Vector2((s.x - 600) * 0.5, (s.y - 548) * 0.5)
	_box(Rect2(p, Vector2(600, 548)))
	_text(p + Vector2(28, 38), "ISOTERRA  /  " + {"pause": "PAUSA", "journal": "DIARIO", "settings": "IMPOSTAZIONI", "help": "COMANDI"}.get(page, "PAUSA"), 22, GamePalette.ACCENT)
	_text(p + Vector2(28, 64), "Il mondo ti aspetta. Nessuna azione di gioco è attiva.", 14, GamePalette.MUTED)
	if page == "pause":
		_button(Rect2(p + Vector2(28, 92), Vector2(544, 54)), "Riprendi l'avventura", &"resume", true)
		_button(Rect2(p + Vector2(28, 158), Vector2(264, 54)), "Diario degli obiettivi", &"journal")
		_button(Rect2(p + Vector2(308, 158), Vector2(264, 54)), "Comandi", &"help")
		_button(Rect2(p + Vector2(28, 224), Vector2(264, 54)), "Impostazioni", &"settings")
		_button(Rect2(p + Vector2(308, 224), Vector2(264, 54)), "Salva partita", &"save")
		_button(Rect2(p + Vector2(28, 290), Vector2(544, 54)), "Torna al falò / punto di partenza", &"return_home")
		_text(p + Vector2(28, 381), save_text, 15, GamePalette.MUTED, 544)
		_text(p + Vector2(28, 410), "Esc / P riprende  ·  Frecce e Invio navigano", 14, GamePalette.MUTED)
		_text(p + Vector2(28, 443), "Progresso esplorazione: %d di %d obiettivi" % [journal.completed_count(), ExpeditionJournal.GOALS.size()], 15)
		_button(Rect2(p + Vector2(28, 472), Vector2(544, 48)), "Strumenti sviluppatore", &"developer")
	elif page == "journal":
		for i in ExpeditionJournal.GOALS.size():
			var goal: Dictionary = ExpeditionJournal.GOALS[i]
			var y := 91.0 + i * 46.0
			var done := journal.done(goal)
			_text(p + Vector2(28, y + 12), ("OK" if done else "%02d" % (i + 1)), 13, GamePalette.SUCCESS if done else GamePalette.ACCENT)
			_text(p + Vector2(66, y + 12), String(goal["title"]), 15, GamePalette.SUCCESS if done else GamePalette.INK)
			_text(p + Vector2(66, y + 30), String(goal["hint"]), 12, GamePalette.MUTED, 506)
		_button(Rect2(p + Vector2(28, 472), Vector2(544, 48)), "Indietro", &"pause")
	elif page == "settings":
		var opts := [
			["Dettaglio del mondo: %d righe" % quality, &"quality"],
			["Volume effetti: %d%%" % volume, &"volume"],
			["Movimento ridotto: " + ("sì" if reduced_motion else "no"), &"motion"],
			["Controlli mancini: " + ("sì" if left_handed else "no"), &"handed"],
			["Suggerimenti e obiettivi: " + ("sì" if hints else "no"), &"hints"],
		]
		for i in opts.size():
			_button(Rect2(p + Vector2(28, 92 + i * 64), Vector2(544, 52)), opts[i][0], opts[i][1])
		_text(p + Vector2(28, 438), "Le preferenze vengono salvate automaticamente.", 14, GamePalette.MUTED)
		_button(Rect2(p + Vector2(28, 472), Vector2(544, 48)), "Indietro", &"pause")
	else:
		var lines := [
			["MUOVITI", "WASD / frecce o stick  ·  Spazio / Salto"],
			["COMBATTI", "J: colpo  ·  K tenuto: carica  ·  L / Maiusc: schiva"],
			["AGGANCIA", "R / tasto centrale / Lock: aggancia o sgancia il bersaglio"],
			["RACCOGLI / COSTRUISCI", "Tieni sul mondo: raccogli  ·  Tocca con blocco: posa"],
			["INTERAGISCI", "F / clic destro / indicazione sullo schermo"],
			["ZAINO / CAMERA", "I / Tab: zaino  ·  1–6: oggetto  ·  V: camera"],
			["GUARDA INTORNO", "Trascina / Q–E: ruota  ·  Rotella / pinch: zoom"],
		]
		for i in lines.size():
			_text(p + Vector2(28, 106 + i * 49), lines[i][0], 11, GamePalette.ACCENT)
			_text(p + Vector2(28, 126 + i * 49), lines[i][1], 14, GamePalette.INK, 544)
		_button(Rect2(p + Vector2(28, 472), Vector2(544, 48)), "Indietro", &"pause")


func _covers(r: Rect2) -> bool:
	var sr := Rect2(r.position * _scale, r.size * _scale)
	for a in avoid:
		if sr.intersects(a):
			return true
	return false


func _at(pos: Vector2) -> StringName:
	for button: Dictionary in _buttons:
		if (button["rect"] as Rect2).has_point(pos):
			return button["id"]
	return &""


func _draw_compact_menu(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.05, 0.06, 0.82))
	var p := (s - Vector2(620, 360)) * .5
	_box(Rect2(p, Vector2(620, 360)))
	_text(p + Vector2(24, 33), "ISOTERRA  /  " + {"pause": "PAUSA", "journal": "DIARIO", "settings": "IMPOSTAZIONI", "help": "COMANDI"}.get(page, "PAUSA"), 20, GamePalette.ACCENT)
	_text(p + Vector2(24, 57), "Il mondo è in pausa", 13, GamePalette.MUTED)
	if page == "pause":
		_button(Rect2(p + Vector2(24, 74), Vector2(572, 48)), "Riprendi l'avventura", &"resume", true)
		var actions := [["Diario", &"journal"], ["Comandi", &"help"], ["Impostazioni", &"settings"], ["Salva partita", &"save"], ["Torna al campo", &"return_home"], ["Strumenti sviluppatore", &"developer"]]
		for i in actions.size():
			_button(Rect2(p + Vector2(24 + (i % 2) * 294, 134 + (i / 2) * 60), Vector2(278, 48)), actions[i][0], actions[i][1])
		_text(p + Vector2(24, 333), save_text, 13, GamePalette.MUTED, 572)
	elif page == "settings":
		var actions := [["Dettaglio: %d righe" % quality, &"quality"], ["Effetti: %d%%" % volume, &"volume"], ["Movimento ridotto: " + ("sì" if reduced_motion else "no"), &"motion"], ["Mancini: " + ("sì" if left_handed else "no"), &"handed"], ["Suggerimenti: " + ("sì" if hints else "no"), &"hints"], ["Indietro", &"pause"]]
		for i in actions.size():
			_button(Rect2(p + Vector2(24 + (i % 2) * 294, 86 + (i / 2) * 72), Vector2(278, 56)), actions[i][0], actions[i][1])
		_text(p + Vector2(24, 329), "Preferenze salvate automaticamente", 13, GamePalette.MUTED)
	else:
		var clues := ["Esplora 24 metri con WASD / stick", "Tieni su alberi o blocchi", "Zaino > Craft: banco (4 legno)", "Impugna il banco e tocca il terreno", "Colpisci 3 volte un manichino", "Maiusc, L o Schiva", "Crea, posa e usa un falò", "Trova e apri un tesoro"]
		var help := [["Movimento", "WASD / frecce / stick"], ["Salto", "Spazio / Salto"], ["Combattimento", "J: colpo · K: carica · L: schiva"], ["Prima persona", "V / Iso: cambia camera"], ["Raccogli / posa", "Tieni premuto / tocca il mondo"], ["Zaino / interazioni", "I: zaino · F: interagisci vicino"], ["Camera", "Trascina · Q/E · rotella/pinch"], ["Lock", "R / clic centrale / Lock"]]
		for i in 8:
			var pos := p + Vector2(24 + (i % 2) * 294, 90 + (i / 2) * 50)
			var title: String = help[i][0]
			var hint: String = help[i][1]
			var color := GamePalette.ACCENT
			if page == "journal":
				var goal: Dictionary = ExpeditionJournal.GOALS[i]
				title = ("OK · " if journal.done(goal) else "%d · " % (i + 1)) + String(goal["title"])
				hint = clues[i]
				color = GamePalette.SUCCESS if journal.done(goal) else GamePalette.ACCENT
			_text(pos, title, 14, color, 278)
			_text(pos + Vector2(0, 19), hint, 12, GamePalette.MUTED, 278)
		_button(Rect2(p + Vector2(24, 288), Vector2(572, 48)), "Indietro", &"pause")


func _input(event: InputEvent) -> void:
	if not hud_visible and page == "":
		return
	if event is InputEventKey and page != "":
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE, KEY_P:
					action.emit(&"resume" if page == "pause" else &"pause")
				KEY_DOWN, KEY_TAB, KEY_RIGHT:
					_focus = (_focus + 1) % maxi(1, _buttons.size())
				KEY_UP, KEY_LEFT:
					_focus = posmod(_focus - 1, maxi(1, _buttons.size()))
				KEY_ENTER, KEY_SPACE:
					if not _buttons.is_empty():
						action.emit(_buttons[_focus % _buttons.size()]["id"])
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var id := _at(event.position)
		if event.pressed and _finger == -1 and id != &"":
			_finger = event.index
			_pressed = id
		elif not event.pressed and event.index == _finger:
			var activate: bool = id != &"" and id == _pressed and not event.canceled
			_finger = -1
			_pressed = &""
			if activate:
				action.emit(id)
			get_viewport().set_input_as_handled()
		if page != "" or id != &"" or _finger == event.index:
			get_viewport().set_input_as_handled()
	elif page != "" and (event is InputEventMouseButton or event is InputEventScreenDrag):
		# Su desktop i clic arrivano gia' come tocchi (emulazione del progetto).
		get_viewport().set_input_as_handled()
	queue_redraw()
