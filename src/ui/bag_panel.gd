class_name BagPanel
extends Control
## Zaino, equipaggiamento, craft e forziere (M5). Disegnato e gestito qui come
## i TouchControls: i Control di Godot non ricevono i tocchi senza l'emulazione
## del mouse, che resta spenta per il multitouch. Un tocco = pressione e
## rilascio sullo stesso riquadro; nella lista delle ricette si scorre trascinando.

signal closed
signal message(text: String)

const TABS := [["bag", "Zaino"], ["equip", "Equipaggiamento"], ["craft", "Craft"], ["chest", "Forziere"]]
const EQ_NAMES := {"head": "Testa", "chest": "Busto", "legs": "Gambe", "feet": "Piedi"}

var items: PlayerItems
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


func _text_center(r: Rect2, text: String, size_dp: float, col: Color) -> void:
	var fs := int(dp(size_dp))
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	while ts.x > r.size.x - dp(6.0) and fs > 8:
		fs -= 1
		ts = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(_font, r.get_center() + Vector2(-ts.x * 0.5, ts.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text(p: Vector2, text: String, size_dp: float, col: Color, width: float = -1.0) -> void:
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, width, int(dp(size_dp)), col)


# ---------------------------------------------------------------- disegno

func _draw() -> void:
	_hits.clear()
	tab_rects.clear()
	craft_rects.clear()
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
		inv.take(i)
		items.held_changed.emit()
		message.emit("gettato: %s" % d.display_name)
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
		"Mana massimo  +%d" % roundi(st.mana_max),
		"Rigenerazione mana  +%.1f/s" % st.mana_regen,
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
