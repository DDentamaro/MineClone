class_name BagPanel
extends Control
## Zaino, equipaggiamento, craft e forziere (M5). Disegnato e gestito qui come
## i TouchControls: i Control di Godot non ricevono i tocchi senza l'emulazione
## del mouse, che resta spenta per il multitouch. Un tocco = pressione e
## rilascio sullo stesso riquadro; nella lista delle ricette si scorre trascinando.

signal closed
signal message(text: String)
## Oggetto gettato dallo zaino: lo posa a terra il gioco (GroundItems).
signal dropped(stack: ItemStack)

const TABS := [["bag", "Zaino"], ["equip", "Equipaggiamento"], ["magic", "Magie"], ["craft", "Craft"], ["chest", "Forziere"]]
const EQ_NAMES := {"head": "Testa", "chest": "Busto", "legs": "Gambe", "feet": "Piedi"}

var items: PlayerItems
## Libro e barra delle magie (scheda "Magie", pergamene).
var magic: MagicSystem
var _sel_spell: StringName = &""
## Slot della barra da riempire (aperto da uno slot vuoto o tenendo premuto), -1 nessuno.
var target_slot := -1
## Riquadri per le prove e2e: magia -> riga del libro, slot della barra.
var spell_rects := {}
var bar_rects: Array[Rect2] = []
var chest: WorldObjects.Obj
var stations: Array = []
var tab := "bag"
var rng := RandomNumberGenerator.new()
var _sel_inv: Inventory
var _sel_i := -1
var _hits: Array = []
var _down_pos := Vector2(-1, -1)
var _down_idx := -1
var _finger := -1
var _drag_y := 0.0
var _scroll := 0.0
var _scroll_max := 0.0
var _font: Font
## Riquadri dell'ultimo disegno (per le prove e2e): schede, pulsanti "Crea" per
## prodotto, chiusura.
var tab_rects := {}
var craft_rects := {}
var close_rect := Rect2()
## Pulsanti dell'ultimo disegno per testo (e2e): "Getta", "Indossa", ...
var button_rects := {}
## Slot dello zaino del giocatore nell'ultimo disegno (indice -> Rect2).
var slot_rects := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false
	rng.randomize()


func dp(v: float) -> float:
	var win := Vector2(DisplayServer.window_get_size())
	var vp := get_viewport_rect().size if is_inside_tree() else size
	var units_per_px := vp.y / win.y if win.y > 0 else 1.0
	return v * maxf(1.0, DisplayServer.screen_get_dpi() / 160.0) * units_per_px


func open(p_items: PlayerItems, p_stations: Array, p_chest: WorldObjects.Obj = null, p_tab: String = "bag") -> void:
	items = p_items
	stations = p_stations
	chest = p_chest
	tab = p_tab if p_chest != null or p_tab != "chest" else "bag"
	_sel_inv = null
	_sel_i = -1
	_scroll = 0.0
	_finger = -1
	visible = true
	queue_redraw()


func close() -> void:
	target_slot = -1
	visible = false
	chest = null
	closed.emit()


func is_open() -> bool:
	return visible


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		# Conta il primo dito appoggiato (qualunque indice); gli altri si ignorano.
		if st.pressed and _finger >= 0 and _finger != st.index:
			get_viewport().set_input_as_handled()
			return
		if not st.pressed and st.index != _finger:
			get_viewport().set_input_as_handled()
			return
		if st.pressed:
			_finger = st.index
			_down_pos = st.position
			_drag_y = st.position.y
			_down_idx = _hit_at(st.position)
		else:
			if st.position.distance_to(_down_pos) < dp(14.0) and _hit_at(st.position) == _down_idx and _down_idx >= 0:
				var h: Array = _hits[_down_idx]
				(h[1] as Callable).call()
				queue_redraw()
			_down_idx = -1
			_finger = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _finger and tab == "craft":
			_scroll = clampf(_scroll - (sd.position.y - _drag_y), 0.0, _scroll_max)
			_drag_y = sd.position.y
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode in [KEY_ESCAPE, KEY_I, KEY_TAB]:
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if tab == "craft" and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_scroll = clampf(_scroll + (-dp(40.0) if mb.button_index == MOUSE_BUTTON_WHEEL_UP else dp(40.0)), 0.0, _scroll_max)
			queue_redraw()
		get_viewport().set_input_as_handled()


func _hit_at(p: Vector2) -> int:
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i][0] as Rect2).has_point(p):
			return i
	return -1


func _button(r: Rect2, text: String, action: Callable, on: bool = true, accent: bool = false) -> void:
	draw_rect(r, Color(0.16, 0.22, 0.2, 0.95) if on else Color(0.12, 0.12, 0.13, 0.8))
	draw_rect(r, Color(1, 0.85, 0.45) if accent else Color(0.63, 0.89, 0.78, 0.9 if on else 0.3), false, dp(1.5))
	_text_center(r, text, 15, Color.WHITE if on else Color(0.6, 0.6, 0.6))
	if on:
		_hits.append([r, action])
		button_rects[text] = r


func _text_center(r: Rect2, text: String, size_dp: float, col: Color) -> void:
	var fs := int(dp(size_dp))
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	while ts.x > r.size.x - dp(6.0) and fs > 8:
		fs -= 1
		ts = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(_font, r.get_center() + Vector2(-ts.x * 0.5, ts.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Testo che rimpicciolisce fino a stare in `width` (invece di essere tagliato).
func _text_fit(p: Vector2, text: String, size_dp: float, col: Color, width: float) -> void:
	var fs := int(dp(size_dp))
	while fs > 8 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, width, fs, col)


func _text(p: Vector2, text: String, size_dp: float, col: Color, width: float = -1.0) -> void:
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, width, int(dp(size_dp)), col)


# ---------------------------------------------------------------- disegno

func _draw() -> void:
	_hits.clear()
	tab_rects.clear()
	craft_rects.clear()
	spell_rects.clear()
	bar_rects.clear()
	button_rects.clear()
	slot_rects.clear()
	if not visible or items == null:
		return
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
	_hits.append([Rect2(Vector2.ZERO, s), func() -> void: pass])
	var m := dp(16.0)
	var panel := Rect2(m, m, s.x - 2.0 * m, s.y - 2.0 * m)
	draw_rect(panel, Color(0.07, 0.09, 0.1, 0.94))
	draw_rect(panel, Color(0.63, 0.89, 0.78, 0.7), false, dp(2.0))
	# Schede e chiusura.
	var th := dp(40.0)
	var x := panel.position.x + m
	for t: Array in TABS:
		if t[0] == "chest" and chest == null:
			continue
		var label: String = t[1]
		if t[0] == "chest" and chest != null and chest.type == "treasure":
			label = "Tesoro"
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(dp(15.0))).x + dp(28.0)
		var key: String = t[0]
		tab_rects[key] = Rect2(x, panel.position.y + m * 0.6, w, th)
		_button(Rect2(x, panel.position.y + m * 0.6, w, th), label, func() -> void:
			tab = key
			_sel_i = -1
			_scroll = 0.0, true, tab == key)
		x += w + dp(8.0)
	close_rect = Rect2(panel.end.x - m - dp(96.0), panel.position.y + m * 0.6, dp(96.0), th)
	_button(close_rect, "Chiudi ✕", close)
	var body := Rect2(panel.position.x + m, panel.position.y + m * 0.6 + th + m * 0.6, panel.size.x - 2.0 * m, panel.size.y - th - m * 2.0)
	match tab:
		"bag":
			_draw_bag(body)
		"equip":
			_draw_equip(body)
		"magic":
			_draw_magic(body)
		"craft":
			_draw_craft(body)
		"chest":
			_draw_chest(body)


func _slot_size(body: Rect2, cols: int, rows: int, frac: float) -> float:
	return minf((body.size.x * frac - dp(6.0) * (cols - 1)) / cols, (body.size.y - dp(6.0) * (rows - 1) - dp(30.0)) / rows)


## Disegna uno slot; `on_tap` lo rende toccabile.
func _slot(r: Rect2, st: ItemStack, selected: bool, on_tap: Callable, hotbar: bool = false) -> void:
	draw_rect(r, Color(0.13, 0.16, 0.17, 0.95) if not hotbar else Color(0.16, 0.19, 0.14, 0.95))
	draw_rect(r, Color(1, 0.9, 0.5) if selected else Color(0.4, 0.5, 0.46, 0.8), false, dp(2.5 if selected else 1.0))
	if st != null:
		var d := st.def()
		var inner := r.grow(-r.size.x * 0.18)
		draw_rect(inner, d.color)
		if st.rarity() > 0:
			draw_rect(inner.grow(dp(2.0)), Loot.RARITY_COLORS[st.rarity()], false, dp(2.0))
		_text_center(inner, d.glyph, 13, Color.WHITE)
		if st.count > 1:
			_text(r.position + Vector2(r.size.x - dp(22.0), r.size.y - dp(5.0)), str(st.count), 13, Color.WHITE)
		if st.data.has("wear"):
			var k := float(st.data["wear"]) / maxf(1.0, float(st.data.get("max_wear", d.durability)))
			draw_rect(Rect2(r.position + Vector2(dp(4.0), r.size.y - dp(6.0)), Vector2((r.size.x - dp(8.0)) * k, dp(3.0))), Color(1.0 - k, 0.3 + 0.6 * k, 0.2))
	if on_tap.is_valid():
		_hits.append([r, on_tap])


func _grid(inv: Inventory, origin: Vector2, cols: int, cell: float, on_tap: Callable, hotbar_rows: int = 0) -> void:
	for i in inv.size():
		var r := Rect2(origin + Vector2((i % cols) * (cell + dp(6.0)), (i / cols) * (cell + dp(6.0))), Vector2(cell, cell))
		var idx := i
		if inv == items.inv:
			slot_rects[i] = r
		_slot(r, inv.get_slot(i), _sel_inv == inv and _sel_i == i, func() -> void: on_tap.call(inv, idx), i < hotbar_rows * cols)


## Tocco su uno slot: seleziona, oppure sposta/unisce/scambia con il selezionato.
func _tap_slot(inv: Inventory, i: int) -> void:
	if _sel_i >= 0 and _sel_inv != null and not (_sel_inv == inv and _sel_i == i):
		Inventory.move(_sel_inv, _sel_i, inv, i)
		_sel_i = -1
		_sel_inv = null
		items.held_changed.emit()
		return
	if _sel_inv == inv and _sel_i == i:
		_sel_i = -1
		_sel_inv = null
		return
	if inv.get_slot(i) != null:
		_sel_inv = inv
		_sel_i = i


func _draw_bag(body: Rect2) -> void:
	var cols := 6
	var cell := _slot_size(body, cols, 5, 0.58)
	_text(body.position + Vector2(0, dp(16.0)), "Barra rapida (prima riga) e zaino — tocca un oggetto, poi uno slot per spostarlo", 13, Color(0.8, 0.85, 0.8))
	_grid(items.inv, body.position + Vector2(0, dp(26.0)), cols, cell, _tap_slot, 1)
	var info := Rect2(body.position.x + cols * (cell + dp(6.0)) + dp(10.0), body.position.y + dp(26.0), body.size.x - cols * (cell + dp(6.0)) - dp(10.0), body.size.y - dp(26.0))
	_draw_info(info)


func _draw_info(r: Rect2) -> void:
	draw_rect(r, Color(0.1, 0.12, 0.13, 0.9))
	if _sel_inv == null or _sel_i < 0 or _sel_inv.get_slot(_sel_i) == null:
		_text(r.position + Vector2(dp(10.0), dp(24.0)), "Nessun oggetto selezionato", 15, Color(0.7, 0.7, 0.7))
		return
	var st := _sel_inv.get_slot(_sel_i)
	var d := st.def()
	var y := r.position.y + dp(26.0)
	_text(Vector2(r.position.x + dp(10.0), y), Loot.full_name(st), 17, Loot.RARITY_COLORS[st.rarity()], r.size.x - dp(20.0))
	y += dp(22.0)
	if d.is_equipment():
		_text(Vector2(r.position.x + dp(10.0), y), Loot.RARITY_NAMES[st.rarity()], 13, Loot.RARITY_COLORS[st.rarity()])
		y += dp(20.0)
	for line in Loot.describe(st):
		_text(Vector2(r.position.x + dp(10.0), y), "• " + line, 14, Color(0.9, 0.92, 0.88), r.size.x - dp(20.0))
		y += dp(19.0)
	var bw := (r.size.x - dp(30.0)) * 0.5
	var bh := dp(40.0)
	var by := r.end.y - bh - dp(10.0)
	var inv := _sel_inv
	var i := _sel_i
	if d.kind == ItemDefinition.Kind.SCROLL and magic != null:
		var known := magic.known.has(d.spell)
		_button(Rect2(r.position.x + dp(10.0), by - bh - dp(8.0), bw, bh), "Già nota" if known else "Impara", func() -> void:
			if learn_scroll(inv, i):
				_sel_i = -1, not known, true)
	if d.kind == ItemDefinition.Kind.ARMOR and inv == items.inv:
		_button(Rect2(r.position.x + dp(10.0), by - bh - dp(8.0), bw, bh), "Indossa", func() -> void:
			items.equip_from(i)
			_sel_i = -1, true, true)
	if inv == items.inv and i >= PlayerItems.HOTBAR:
		_button(Rect2(r.position.x + dp(20.0) + bw, by - bh - dp(8.0), bw, bh), "In barra", func() -> void:
			var free := -1
			for k in PlayerItems.HOTBAR:
				if items.inv.get_slot(k) == null:
					free = k
					break
			Inventory.move(items.inv, i, items.inv, free if free >= 0 else items.selected)
			items.held_changed.emit()
			_sel_i = -1)
	if st.count > 1:
		_button(Rect2(r.position.x + dp(10.0), by, bw, bh), "Dividi", func() -> void:
			var half := st.count / 2
			var room := -1
			for k in inv.size():
				if inv.get_slot(k) == null:
					room = k
					break
			if room >= 0:
				var part := inv.take(i, half)
				inv.set_slot(room, part)
				items.held_changed.emit())
	_button(Rect2(r.position.x + dp(20.0) + bw, by, bw, bh), "Getta", func() -> void:
		var out := inv.take(i)
		items.held_changed.emit()
		if out != null:
			dropped.emit(out)
		message.emit("gettato a terra: %s (resta 5 minuti)" % d.display_name)
		_sel_i = -1)


func _draw_equip(body: Rect2) -> void:
	var cell := minf(dp(70.0), body.size.y / 5.5)
	var y := body.position.y + dp(10.0)
	for k in Equipment.SLOTS:
		var r := Rect2(body.position.x, y, cell, cell)
		var name: String = k
		_slot(r, items.equipment.get_slot(k), false, func() -> void:
			if not items.unequip_to_bag(name):
				message.emit("zaino pieno"))
		var st := items.equipment.get_slot(k)
		_text(Vector2(r.end.x + dp(12.0), r.position.y + cell * 0.45), EQ_NAMES[k], 14, Color(0.75, 0.8, 0.78))
		_text(Vector2(r.end.x + dp(12.0), r.position.y + cell * 0.8), Loot.full_name(st) if st != null else "—", 15,
			Loot.RARITY_COLORS[st.rarity()] if st != null else Color(0.5, 0.5, 0.5), body.size.x * 0.4)
		y += cell + dp(8.0)
	var h := items.held()
	var sx := body.position.x + body.size.x * 0.55
	_text(Vector2(sx, body.position.y + dp(24.0)), "In mano: %s" % (Loot.full_name(h) if h != null else "niente"), 16,
		Loot.RARITY_COLORS[h.rarity()] if h != null else Color.WHITE, body.size.x * 0.44)
	var st := items.stats()
	var lines := [
		"Difesa  %.1f" % st.defense,
		"Danno corpo a corpo  ×%.2f" % st.melee,
		"Critico  %d%%" % roundi(st.crit * 100.0),
		"Output delle magie  +%d" % roundi(st.mana_max),
		"Dissipazione della pressione  +%.1f" % st.mana_regen,
		"Danno delle magie  ×%.2f" % st.arcane,
		"Velocità di scavo  ×%.2f" % st.dig,
		"Velocità di movimento  ×%.2f" % st.speed,
	]
	var yy := body.position.y + dp(56.0)
	for l: String in lines:
		_text(Vector2(sx, yy), l, 15, Color(0.9, 0.93, 0.9))
		yy += dp(24.0)
	_text(Vector2(sx, body.end.y - dp(10.0)), "Tocca un pezzo indossato per toglierlo", 12, Color(0.6, 0.65, 0.62))


func _draw_craft(body: Rect2) -> void:
	var st_names := {"": "a mano", "workbench": "banco da lavoro", "furnace": "fornace"}
	var here: Array[String] = ["a mano"]
	for k in stations:
		if st_names.has(k):
			here.append(st_names[k])
	_text(body.position + Vector2(0, dp(16.0)), "Stazioni vicine: %s" % ", ".join(here), 13, Color(0.8, 0.85, 0.8))
	var list: Array = Recipes.all().duplicate()
	list.sort_custom(func(a: Recipes.Recipe, b: Recipes.Recipe) -> bool:
		var ca := Recipes.can_craft(a, items.inv, stations)
		var cb := Recipes.can_craft(b, items.inv, stations)
		if ca != cb:
			return ca
		return (a.station == "" or stations.has(a.station)) and not (b.station == "" or stations.has(b.station)))
	var rh := dp(46.0)
	var top := body.position.y + dp(26.0)
	var view := Rect2(body.position.x, top, body.size.x, body.end.y - top)
	_scroll_max = maxf(0.0, list.size() * (rh + dp(4.0)) - view.size.y)
	var y := top - _scroll
	for r: Recipes.Recipe in list:
		if y + rh < top or y > view.end.y:
			y += rh + dp(4.0)
			continue
		var d := ItemLibrary.get_item(r.out)
		var ok := Recipes.can_craft(r, items.inv, stations)
		var row := Rect2(view.position.x, y, view.size.x, rh)
		draw_rect(row, Color(0.12, 0.15, 0.15, 0.9) if ok else Color(0.1, 0.1, 0.11, 0.8))
		draw_rect(Rect2(row.position + Vector2(dp(6.0), dp(6.0)), Vector2(rh - dp(12.0), rh - dp(12.0))), d.color)
		_text(row.position + Vector2(rh + dp(4.0), dp(20.0)), "%s%s" % [d.display_name, " ×%d" % r.count if r.count > 1 else ""], 15,
			Color.WHITE if ok else Color(0.65, 0.65, 0.65), view.size.x * 0.4)
		var parts: Array[String] = []
		for k: StringName in r.inputs:
			parts.append("%s %d/%d" % [ItemLibrary.get_item(k).display_name, items.inv.count(k), int(r.inputs[k])])
		var need := "" if r.station == "" or stations.has(r.station) else "  (serve: %s)" % st_names[r.station]
		_text(row.position + Vector2(rh + dp(4.0), dp(38.0)), ", ".join(parts) + need, 12,
			Color(0.75, 0.9, 0.75) if ok else Color(0.85, 0.6, 0.55), view.size.x * 0.62)
		var rec := r
		var br := Rect2(row.end.x - dp(92.0), row.position.y + dp(6.0), dp(86.0), rh - dp(12.0))
		if br.position.y >= top and br.end.y <= view.end.y:
			craft_rects[r.out] = br
			_button(br, "Crea", func() -> void:
				var made := Recipes.craft(rec, items.inv, stations, rng)
				if made != null:
					message.emit("creato: %s%s" % [Loot.full_name(made), (" (%s)" % Loot.RARITY_NAMES[made.rarity()]) if made.rarity() > 0 else ""])
					items.held_changed.emit()
				else:
					message.emit("non c'e' spazio nello zaino"), ok, ok)
		y += rh + dp(4.0)


func _draw_chest(body: Rect2) -> void:
	if chest == null or chest.inv == null:
		return
	var cols := 6
	var cell := minf(_slot_size(body, cols, 8, 0.62), dp(58.0))
	_text(body.position + Vector2(0, dp(16.0)), ("Tesoro" if chest.type == "treasure" else "Forziere") + " — tocca un oggetto per spostarlo dall'altra parte", 13, Color(0.8, 0.85, 0.8))
	var transfer := func(from: Inventory, i: int, to: Inventory) -> void:
		var st := from.get_slot(i)
		if st == null:
			return
		var left := to.add(st.duplicate_stack())
		if left == 0:
			from.set_slot(i, null)
		else:
			st.count = left
			from.changed.emit()
		items.held_changed.emit()
	_grid(chest.inv, body.position + Vector2(0, dp(26.0)), cols, cell, func(inv: Inventory, i: int) -> void: transfer.call(inv, i, items.inv))
	var y2 := body.position.y + dp(26.0) + 3 * (cell + dp(6.0)) + dp(22.0)
	_text(Vector2(body.position.x, y2 - dp(6.0)), "Zaino", 13, Color(0.8, 0.85, 0.8))
	_grid(items.inv, Vector2(body.position.x, y2), cols * 2, cell * 0.9, func(inv: Inventory, i: int) -> void: transfer.call(inv, i, chest.inv))
	var all := Rect2(body.end.x - dp(170.0), body.position.y + dp(26.0), dp(170.0), dp(44.0))
	_button(all, "Prendi tutto", func() -> void:
		for i in chest.inv.size():
			transfer.call(chest.inv, i, items.inv), true, true)


## Pergamena: impara la magia (consuma la pergamena) e la mette nel primo slot libero.
func learn_scroll(inv: Inventory, i: int) -> bool:
	var st := inv.get_slot(i)
	if st == null or magic == null or st.def().kind != ItemDefinition.Kind.SCROLL:
		return false
	var id := st.def().spell
	if not magic.learn(id):
		return false
	inv.take(i, 1)
	var free := magic.bar.find(&"")
	if free >= 0:
		magic.equip(id, free)
	items.held_changed.emit()
	message.emit("imparata: %s (Output %d)" % [SpellDefinition.by_id(id).display_name, int(magic.output_cap())])
	return true


const SCHOOLS := ["fire", "water", "air", "earth", "karma"]


func _draw_magic(body: Rect2) -> void:
	if magic == null:
		return
	var cap := magic.output_cap()
	var hint := "Tocca una magia per vederla, poi \"Metti nello slot\"." if target_slot < 0 else "Scegli la magia per lo slot %d." % (target_slot + 1)
	_text(body.position + Vector2(0, dp(16.0)), "Output %d  ·  Pressione %d%%%s  ·  conosciute %d/%d  —  %s" % [
		int(cap), int(magic.pressure * 100.0), " (satura)" if magic.saturated else "", magic.known.size(), SpellDefinition.all().size(), hint],
		13, Color(0.85, 0.9, 0.85))
	# Barra: 5 slot con icona e nome.
	var bh := dp(50.0)
	var gw := body.size.x * 0.66
	var bw := minf(dp(170.0), (gw - dp(6.0) * 4) / 5.0)
	var by := body.position.y + dp(26.0)
	for k in MagicSystem.BAR:
		var r := Rect2(body.position.x + k * (bw + dp(6.0)), by, bw, bh)
		bar_rects.append(r)
		var sp := SpellDefinition.by_id(magic.bar[k]) if magic.bar[k] != &"" else null
		draw_rect(r, Color(0.13, 0.16, 0.17, 0.95))
		if sp != null:
			var ir := Rect2(r.position + Vector2(dp(4.0), dp(4.0)), Vector2(bh - dp(8.0), bh - dp(8.0)))
			SpellIcons.draw(self, ir, sp, sp.output > cap)
			_text(r.position + Vector2(bh, dp(21.0)), sp.display_name, 13, Color.WHITE, r.size.x - bh - dp(4.0))
			_text(r.position + Vector2(bh, dp(39.0)), "slot %d · Output %d" % [k + 1, int(sp.output)], 11,
				Color(0.95, 0.5, 0.45) if sp.output > cap else Color(0.7, 0.8, 0.75))
		else:
			_text_center(r, "slot %d vuoto" % (k + 1), 12, Color(0.55, 0.6, 0.57))
		var border := Color(0.4, 0.5, 0.46, 0.8)
		var bwid := 1.0
		if k == target_slot:
			border = Color(0.55, 0.95, 1.0)
			bwid = 3.0
		elif k == magic.bar_index:
			border = Color(1, 0.9, 0.5)
			bwid = 2.5
		draw_rect(r, border, false, dp(bwid))
		var slot := k
		_hits.append([r, func() -> void:
			if _sel_spell != &"" and magic.known.has(_sel_spell):
				_equip(_sel_spell, slot)
			else:
				target_slot = slot
				if magic.bar[slot] != &"":
					_sel_spell = magic.bar[slot]])
	# Libro: una colonna per scuola, righe per livello e Output.
	var top := by + bh + dp(12.0)
	var cw := (gw - dp(6.0) * 4) / 5.0
	var rows := 0
	var cols := {}
	for el: String in SCHOOLS:
		var l: Array[SpellDefinition] = []
		for sp in SpellDefinition.all():
			if sp.el == el:
				l.append(sp)
		l.sort_custom(func(a: SpellDefinition, b: SpellDefinition) -> bool: return a.tier < b.tier or (a.tier == b.tier and a.output < b.output))
		cols[el] = l
		rows = maxi(rows, l.size())
	var rh := minf(dp(40.0), (body.end.y - top - dp(22.0)) / rows - dp(3.0))
	for c in SCHOOLS.size():
		var el: String = SCHOOLS[c]
		var x := body.position.x + c * (cw + dp(6.0))
		_text(Vector2(x, top + dp(12.0)), {"fire": "Fuoco", "water": "Acqua", "air": "Aria", "earth": "Terra", "karma": "Karma"}[el], 13, SpellDefinition.EL_COLOR[el])
		var y := top + dp(20.0)
		for sp: SpellDefinition in cols[el]:
			var r := Rect2(x, y, cw, rh)
			spell_rects[sp.id] = r
			var known := magic.known.has(sp.id)
			draw_rect(r, Color(0.12, 0.15, 0.15, 0.95) if known else Color(0.08, 0.08, 0.09, 0.85))
			SpellIcons.draw(self, Rect2(r.position + Vector2(dp(2.0), dp(2.0)), Vector2(rh - dp(4.0), rh - dp(4.0))), sp, known and sp.output > cap, not known)
			var col := Color.WHITE if known and sp.output <= cap else (Color(0.95, 0.6, 0.5) if known else Color(0.5, 0.5, 0.5))
			_text_fit(r.position + Vector2(rh + dp(2.0), rh * 0.5 + dp(5.0)), sp.display_name, 12, col, r.size.x - rh - dp(30.0))
			_text(r.position + Vector2(r.size.x - dp(26.0), rh * 0.5 + dp(5.0)), str(int(sp.output)), 11, col)
			if sp.id == _sel_spell:
				draw_rect(r, Color(1, 0.9, 0.5), false, dp(2.0))
			elif magic.bar.has(sp.id):
				draw_rect(r, Color(0.63, 0.89, 0.78, 0.8), false, dp(1.0))
			var id := sp.id
			_hits.append([r, func() -> void: _sel_spell = id])
			y += rh + dp(3.0)
	_draw_spell_info(Rect2(body.position.x + gw + dp(10.0), by, body.size.x - gw - dp(10.0), body.end.y - by))


func _equip(id: StringName, slot: int) -> void:
	if magic.equip(id, slot):
		magic.select(slot)
		message.emit("slot %d: %s" % [slot + 1, SpellDefinition.by_id(id).display_name])
		target_slot = -1


func _draw_spell_info(r: Rect2) -> void:
	draw_rect(r, Color(0.1, 0.12, 0.13, 0.9))
	var sp := SpellDefinition.by_id(_sel_spell) if _sel_spell != &"" else null
	var x := r.position.x + dp(10.0)
	var w := r.size.x - dp(20.0)
	if sp == null:
		_text(Vector2(x, r.position.y + dp(24.0)), "Nessuna magia selezionata", 15, Color(0.7, 0.7, 0.7))
		_text(Vector2(x, r.position.y + dp(48.0)), "Tocca una magia del libro. Le magie di livello 2+ si imparano dalle pergamene dei tesori.", 12, Color(0.65, 0.7, 0.68), w)
		return
	var cap := magic.output_cap()
	var known := magic.known.has(sp.id)
	var isz := dp(54.0)
	SpellIcons.draw(self, Rect2(Vector2(x, r.position.y + dp(10.0)), Vector2(isz, isz)), sp, known and sp.output > cap, not known)
	_text(Vector2(x + isz + dp(10.0), r.position.y + dp(32.0)), sp.display_name, 17, sp.color().lightened(0.2), w - isz - dp(10.0))
	_text(Vector2(x + isz + dp(10.0), r.position.y + dp(54.0)), "%s · livello %d%s" % [sp.school_name(), sp.tier, " · due mani" if sp.two_handed() else ""], 13, Color(0.85, 0.88, 0.85))
	var y := r.position.y + isz + dp(34.0)
	var lines: Array[String] = ["Output %d / %d" % [int(sp.output), int(cap)], "raccolta %.2f s · recupero %.2f s" % [sp.cast_dur, sp.recover]]
	if sp.dmg > 0.0:
		lines.append("danno %d%s" % [int(sp.dmg), (" ×%d" % sp.salvo_n) if sp.salvo_n > 1 else ""])
	if sp.dps > 0.0:
		lines.append("%d danni/s" % int(sp.dps))
	if sp.burst_r > 0.0:
		lines.append("scoppio %d (raggio %.1f)" % [int(sp.burst_dmg), sp.burst_r])
	if sp.decoh > 0.0:
		lines.append("coerenza: cala con la distanza (min %d%%)" % int(sp.coh_floor * 100.0))
	if sp.note != "":
		lines.append(sp.note)
	for l in lines:
		_text(Vector2(x, y), l, 13, Color(0.9, 0.92, 0.88), w)
		y += dp(19.0)
	var bh := dp(42.0)
	var bottom := r.end.y - dp(10.0)
	if not known:
		_text(Vector2(x, bottom - bh * 0.4), "Sconosciuta: serve la pergamena", 14, Color(0.95, 0.65, 0.5), w)
		return
	if sp.output > cap:
		_text(Vector2(x, bottom - bh * 2.0 - dp(40.0)), "Output insufficiente: equipaggiamento (Mente, oro) o altre magie studiate", 12, Color(0.95, 0.6, 0.5), w)
	var id := sp.id
	if target_slot >= 0:
		var slot := target_slot
		_button(Rect2(x, bottom - bh, w, bh), "Metti nello slot %d" % (slot + 1), func() -> void: _equip(id, slot), true, true)
		bottom -= bh + dp(8.0)
	# Cinque pulsanti: uno per slot.
	_text(Vector2(x, bottom - bh - dp(8.0)), "Metti nello slot:", 13, Color(0.8, 0.85, 0.8))
	var sw := (w - dp(6.0) * 4) / 5.0
	for k in MagicSystem.BAR:
		var slot := k
		var here := magic.bar[k] == id
		_button(Rect2(x + k * (sw + dp(6.0)), bottom - bh, sw, bh), str(k + 1) + (" ✓" if here else ""), func() -> void: _equip(id, slot), not here, k == target_slot)
