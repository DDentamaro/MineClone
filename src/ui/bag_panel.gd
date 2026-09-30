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
signal crafted(id: StringName)

const TABS := [["bag", "Inventario"], ["craft", "Craft"], ["chest", "Forziere"]]
const EQ_NAMES := {"head": "Testa", "chest": "Busto", "legs": "Gambe", "feet": "Piedi"}

var items: PlayerItems
## Ricetta dell'eroe per la miniatura dell'inventario (D-030).
var recipe: AvatarRecipe
## Miniatura: mondo a parte con l'eroe vestito e armato, ruotabile col dito.
var _pv: SubViewport
var _pv_rig: AvatarRig
var _pv_cam: Camera3D
var _pv_yaw := 0.5
var _pv_key := ""
var _pv_rect := Rect2()
var _pv_drag := false
var _pv_an := AvatarAnimator.new()
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
## Slot del forziere/armeria nell'ultimo disegno (indice -> Rect2).
var chest_rects := {}


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
	if p_tab == "equip":
		p_tab = "bag"
	if items != p_items and p_items != null:
		p_items.held_changed.connect(refresh_preview)
	items = p_items
	stations = p_stations
	chest = p_chest
	tab = p_tab if p_chest != null or p_tab != "chest" else "bag"
	_sel_inv = null
	_sel_i = -1
	_scroll = 0.0
	_finger = -1
	_sel_eq = ""
	visible = true
	refresh_preview()
	if _pv != null:
		_pv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	queue_redraw()


func close() -> void:
	visible = false
	if _pv != null:
		_pv.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
			_pv_drag = tab == "bag" and _pv_rect.has_point(st.position)
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
		if sd.index == _finger and _pv_drag:
			_pv_yaw += sd.relative.x * 0.012
			_pose_preview()
		elif sd.index == _finger and tab == "craft":
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
	GamePalette.box(self, r, accent and on, 6)
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


## Testo a capo automatico entro `width`; restituisce l'altezza occupata.
func _text_wrap(p: Vector2, text: String, size_dp: float, col: Color, width: float) -> float:
	var fs := int(dp(size_dp))
	draw_multiline_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, width, fs, -1, col)
	return _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, fs).y


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
	button_rects.clear()
	slot_rects.clear()
	chest_rects.clear()
	if not visible or items == null:
		return
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
	_hits.append([Rect2(Vector2.ZERO, s), func() -> void: pass])
	var m := dp(16.0)
	var panel := Rect2(m, m, s.x - 2.0 * m, s.y - 2.0 * m)
	GamePalette.box(self, panel, false, 12)
	# Schede e chiusura.
	var th := dp(40.0)
	var x := panel.position.x + m
	for t: Array in TABS:
		if t[0] == "chest" and chest == null:
			continue
		var label: String = t[1]
		if t[0] == "chest" and chest != null and chest.type == "treasure":
			label = "Tesoro"
		if t[0] == "chest" and chest != null and chest.type == "armory":
			label = "Armeria"
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
		"craft":
			_draw_craft(body)
		"chest":
			_draw_chest(body)


func _slot_size(body: Rect2, cols: int, rows: int, frac: float) -> float:
	return minf((body.size.x * frac - dp(6.0) * (cols - 1)) / cols, (body.size.y - dp(6.0) * (rows - 1) - dp(30.0)) / rows)


## Disegna uno slot; `on_tap` lo rende toccabile.
func _slot(r: Rect2, st: ItemStack, selected: bool, on_tap: Callable, hotbar: bool = false) -> void:
	GamePalette.box(self, r, selected, 6)
	if hotbar:
		draw_line(r.position + Vector2(dp(8), 0), r.position + Vector2(r.size.x - dp(8), 0), GamePalette.ACCENT, dp(2))
	if st != null:
		var d := st.def()
		var inner := r.grow(-r.size.x * 0.18)
		GameIcons.item(self, inner, d)
		if st.rarity() > 0:
			draw_rect(inner.grow(dp(2.0)), Loot.RARITY_COLORS[st.rarity()], false, dp(2.0))
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
		elif chest != null and inv == chest.inv:
			chest_rects[i] = r
		if inv == items.inv and i == items.selected:
			# Lo slot in mano: bordo dorato e scritta, come nella barra in basso.
			draw_rect(r.grow(dp(3.0)), Color(1, 0.78, 0.25), false, dp(3.0))
		_slot(r, inv.get_slot(i), _sel_inv == inv and _sel_i == i, func() -> void: on_tap.call(inv, idx), i < hotbar_rows * cols)
		if inv == items.inv and i == items.selected:
			_text(r.position + Vector2(dp(3.0), dp(11.0)), "in mano", 9, Color(1, 0.85, 0.4))


## Tocco su uno slot: seleziona, oppure sposta/unisce/scambia con il selezionato.
func _tap_slot(inv: Inventory, i: int) -> void:
	_sel_eq = ""
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


func _process(_dt: float) -> void:
	# La miniatura gira piano finche' non la si tocca.
	if visible and tab == "bag" and _pv_rig != null and not _pv_drag:
		_pv_yaw += _dt * 0.35
		_pose_preview()
		queue_redraw()


## Miniatura dell'eroe (come l'inventario di Minecraft): stessa ricetta,
## armatura e oggetto in mano dell'eroe in gioco.
func refresh_preview() -> void:
	if recipe == null or items == null:
		return
	if _pv == null:
		_pv = SubViewport.new()
		_pv.own_world_3d = true
		_pv.transparent_bg = true
		_pv.size = Vector2i(300, 380)
		_pv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_pv)
		var sun := DirectionalLight3D.new()
		sun.look_at_from_position(Vector3.ZERO, Vector3(-0.35, -0.75, -0.55), Vector3.UP)
		_pv.add_child(sun)
		_pv_cam = Camera3D.new()
		_pv_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		# D-043: eroe alto due blocchi, inquadratura piu' alta.
		_pv_cam.size = 2.35
		_pv.add_child(_pv_cam)
		_pv_cam.look_at_from_position(Vector3(0, 1.75, 4.0), Vector3(0, 1.0, 0), Vector3.UP)
		_pv_cam.current = true
		_pv_rig = AvatarRig.new()
		_pv.add_child(_pv_rig)
	var key := recipe.to_json()
	if key != _pv_key:
		_pv_key = key
		_pv_rig.build(recipe)
	_pv_rig.set_armor_all(items.equipment.colors())
	_pv_rig.set_weapon(WeaponLibrary.by_id(items.weapon_id()), WeaponMeshes.for_item(items.held_def()))
	_pose_preview()
	queue_redraw()


func _pose_preview() -> void:
	if _pv_rig == null or _pv_rig.bones.is_empty():
		return
	var s := AvatarAnimator.State.new()
	s.weapon = _pv_rig.weapon
	_pv_rig.apply_pose(_pv_an.target_pose(0.0, s))
	_pv_rig.rotation.y = _pv_yaw


## Inventario (D-030): a sinistra la miniatura con i quattro pezzi d'armatura
## e la mano, sotto le statistiche; al centro zaino e barra rapida; a destra
## l'oggetto o lo slot scelto. Tocca un oggetto e poi uno slot dell'armatura
## o la mano per metterlo, come in Minecraft.
var _sel_eq := ""
var eq_rects := {}


func _draw_bag(body: Rect2) -> void:
	eq_rects.clear()
	_text(body.position + Vector2(0, dp(16.0)), "Tocca un oggetto, poi uno slot dell'eroe (armatura o mano) o dello zaino. La prima riga è la barra rapida: lo slot dorato è in mano.", 12, Color(0.85, 0.9, 0.85))
	var top := body.position.y + dp(28.0)
	var h := body.end.y - top
	# Colonna dell'eroe.
	var ss := minf(dp(54.0), (h * 0.66) / 4.0 - dp(6.0))
	var pv_w := minf(body.size.x * 0.20, (h * 0.66) * 0.79)
	var col_x := body.position.x
	var names := {"head": "Testa", "chest": "Busto", "legs": "Gambe", "feet": "Piedi", "hand": "Mano"}
	var i := 0
	for k in Equipment.SLOTS:
		var r := Rect2(col_x, top + i * (ss + dp(6.0)), ss, ss)
		_eq_slot_box(k, r, items.equipment.get_slot(k), names[k])
		i += 1
	_pv_rect = Rect2(col_x + ss + dp(6.0), top, pv_w, 4 * (ss + dp(6.0)) - dp(6.0))
	draw_rect(_pv_rect, Color(0.12, 0.16, 0.17, 0.95))
	if _pv != null:
		draw_texture_rect(_pv.get_texture(), _pv_rect, false)
	draw_rect(_pv_rect, Color(0.4, 0.5, 0.46, 0.8), false, dp(1.0))
	var hr := Rect2(_pv_rect.end.x - ss, _pv_rect.end.y + dp(6.0), ss, ss)
	_eq_slot_box("hand", hr, items.held(), names["hand"])
	_text(Vector2(col_x, hr.position.y + ss * 0.55), "trascina l'eroe per girarlo", 10, Color(0.6, 0.65, 0.62), hr.position.x - col_x - dp(4.0))
	# Statistiche compatte sotto.
	var st := items.stats()
	var lines := ["Difesa %.1f" % st.defense, "Danno ×%.2f" % st.melee, "Critico %d%%" % roundi(st.crit * 100.0),
		"Scavo ×%.2f" % st.dig, "Passo ×%.2f" % st.speed]
	var sy := hr.end.y + dp(18.0)
	var sw := _pv_rect.end.x - col_x
	for j in lines.size():
		_text(Vector2(col_x + (j % 2) * sw * 0.5, sy + (j / 2) * dp(17.0)), lines[j], 12, Color(0.88, 0.92, 0.88), sw * 0.5)
	# Zaino.
	var cols := 6
	var gx := _pv_rect.end.x + dp(14.0)
	var gw := body.size.x * 0.40
	var cell := minf((gw - dp(6.0) * (cols - 1)) / cols, (h - dp(6.0) * 4) / 5.0)
	_grid(items.inv, Vector2(gx, top), cols, cell, _tap_slot, 1)
	var ix := gx + cols * (cell + dp(6.0)) + dp(8.0)
	var info := Rect2(ix, top, body.end.x - ix, h)
	if _sel_eq != "":
		_draw_eq_info(info)
	else:
		_draw_info(info)


## Slot dell'eroe: tocco = metti l'oggetto scelto (se ci va) o mostra lo slot.
func _eq_slot_box(k: String, r: Rect2, st: ItemStack, label: String) -> void:
	eq_rects[k] = r
	var sel := _sel_eq == k
	_slot(r, st, sel, Callable())
	if st == null:
		_text_center(r, label, 10, Color(0.55, 0.6, 0.58))
	var key := k
	_hits.append([r, func() -> void: _tap_eq(key)])


func _tap_eq(k: String) -> void:
	var st: ItemStack = _sel_inv.get_slot(_sel_i) if _sel_inv != null and _sel_i >= 0 else null
	if st != null and _sel_inv == items.inv:
		if k == "hand" and PlayerItems.can_wield(st):
			items.wield_from(items.inv, _sel_i)
			message.emit("in mano: %s" % Loot.full_name(items.held()))
			_sel_i = -1
			_sel_inv = null
			return
		if k != "hand" and st.def().kind == ItemDefinition.Kind.ARMOR and st.def().slot == k:
			items.wear_from(items.inv, _sel_i)
			message.emit("indossato: %s" % Loot.full_name(st))
			_sel_i = -1
			_sel_inv = null
			return
		if k != "hand":
			message.emit("%s non va su %s" % [Loot.full_name(st), {"head": "la testa", "chest": "il busto", "legs": "le gambe", "feet": "i piedi"}[k]])
			return
	_sel_i = -1
	_sel_inv = null
	_sel_eq = "" if _sel_eq == k else k


## Pannello dello slot dell'eroe: cosa c'e' (e "Togli"), cosa ci va dallo zaino.
func _draw_eq_info(r: Rect2) -> void:
	draw_rect(r, Color(0.1, 0.12, 0.13, 0.9))
	var x := r.position.x + dp(10.0)
	var w := r.size.x - dp(20.0)
	var names := {"head": "Testa", "chest": "Busto", "legs": "Gambe", "feet": "Piedi", "hand": "Mano"}
	var cur: ItemStack = items.held() if _sel_eq == "hand" else items.equipment.get_slot(_sel_eq)
	var y := r.position.y + dp(24.0)
	_text(Vector2(x, y), "%s: %s" % [names[_sel_eq], Loot.full_name(cur) if cur != null else ("mani nude" if _sel_eq == "hand" else "vuoto")], 15,
		Loot.RARITY_COLORS[cur.rarity()] if cur != null else Color(0.8, 0.8, 0.8), w)
	y += dp(12.0)
	if cur != null:
		for line in Loot.describe(cur):
			y += dp(18.0)
			_text(Vector2(x, y), "• " + line, 13, Color(0.9, 0.92, 0.88), w)
	y += dp(14.0)
	if cur != null and _sel_eq != "hand":
		var sn := _sel_eq
		_button(Rect2(x, y, w, dp(36.0)), "Togli", func() -> void:
			if not items.unequip_to_bag(sn):
				message.emit("zaino pieno"), true, false)
		y += dp(44.0)
	_text(Vector2(x, y + dp(12.0)), "Dallo zaino:", 13, Color(0.85, 0.88, 0.85))
	y += dp(22.0)
	var now := items.stats()
	var rh := dp(50.0)
	var any := false
	for i in items.inv.size():
		var st := items.inv.get_slot(i)
		if st == null:
			continue
		var ok: bool = (_sel_eq == "hand" and PlayerItems.can_wield(st) and st.def().is_equipment() and i != items.selected) \
			or (_sel_eq != "hand" and st.def().kind == ItemDefinition.Kind.ARMOR and st.def().slot == _sel_eq)
		if not ok:
			continue
		if y + rh > r.end.y:
			_text(Vector2(x, r.end.y - dp(6.0)), "…e altri nello zaino", 11, Color(0.65, 0.7, 0.68))
			break
		any = true
		var row := Rect2(x, y, w, rh)
		draw_rect(row, Color(0.12, 0.15, 0.15, 0.9))
		_slot(Rect2(row.position + Vector2(dp(3.0), dp(3.0)), Vector2(rh - dp(6.0), rh - dp(6.0))), st, false, Callable())
		_text_fit(row.position + Vector2(rh + dp(2.0), dp(19.0)), Loot.full_name(st), 13, Loot.RARITY_COLORS[st.rarity()], w - rh - dp(90.0))
		var then := _stats_if(st, null) if _sel_eq == "hand" else _stats_if(items.held(), st)
		var parts: Array[String] = []
		for df: Array in stat_diff(now, then):
			parts.append(("▲ " if df[1] else "▼ ") + String(df[0]))
		_text_fit(row.position + Vector2(rh + dp(2.0), dp(37.0)), "  ".join(parts) if not parts.is_empty() else "uguale", 11, Color(0.75, 0.85, 0.75), w - rh - dp(90.0))
		var idx := i
		var hand := _sel_eq == "hand"
		_button(Rect2(row.end.x - dp(82.0), row.position.y + dp(7.0), dp(78.0), rh - dp(14.0)), "Impugna" if hand else "Indossa", func() -> void:
			if hand:
				items.wield_from(items.inv, idx)
			else:
				items.wear_from(items.inv, idx)
			message.emit("%s: %s" % ["in mano" if hand else "indossato", Loot.full_name(st)]), true, true)
		y += rh + dp(6.0)
	if not any:
		_text_wrap(Vector2(x, y + dp(4.0)), "Niente nello zaino per questo slot. Armi e armature si trovano nell'armeria vicino all'inizio e nei tesori, o si creano al banco (scheda Craft).", 12, Color(0.65, 0.7, 0.68), w)


## Statistiche se `held` fosse in mano e `armor` indossata (null = come ora).
func _stats_if(held: ItemStack, armor: ItemStack) -> Equipment.Stats:
	var eq := Equipment.new()
	eq.load_dict(items.equipment.to_dict())
	if armor != null:
		eq.equip(armor.duplicate_stack())
	return PlayerItems.stats_for(eq, held)


## Differenze leggibili fra due gruppi di statistiche: [testo, migliore?].
static func stat_diff(a: Equipment.Stats, b: Equipment.Stats) -> Array:
	var out := []
	var rows := [["difesa", a.defense, b.defense, "%+.1f", false], ["danno", a.melee, b.melee, "×%.2f", true],
		["critico", a.crit * 100.0, b.crit * 100.0, "%+d%%", false], ["scavo", a.dig, b.dig, "×%.2f", true], ["passo", a.speed, b.speed, "×%.2f", true]]
	for r: Array in rows:
		var d: float = float(r[2]) - float(r[1])
		if absf(d) < 1e-3:
			continue
		var txt: String = ("%s %s" % [r[0], String(r[3]) % float(r[2])]) if r[4] else ("%s %s" % [r[0], String(r[3]) % (roundi(d) if String(r[3]).contains("d") else d)])
		out.append([txt, d > 0.0])
	return out


## Azioni per l'oggetto `i` di `inv`: [testo, azione, in evidenza].
func _actions(inv: Inventory, i: int) -> Array:
	var st := inv.get_slot(i)
	var d := st.def()
	var out := []
	var from_bag := inv == items.inv
	if PlayerItems.can_wield(st):
		if from_bag and i == items.selected:
			out.append(["In mano ✓", Callable(), false])
		else:
			out.append(["Impugna", func() -> void:
				items.wield_from(inv, i)
				message.emit("in mano: %s" % Loot.full_name(items.held()))
				_sel_i = -1, true])
	if d.kind == ItemDefinition.Kind.ARMOR:
		out.append(["Indossa", func() -> void:
			items.wear_from(inv, i)
			message.emit("indossato: %s" % Loot.full_name(st))
			_sel_i = -1, true])
	if chest != null and not from_bag:
		out.append(["Prendi", func() -> void:
			_transfer(inv, i, items.inv)
			_sel_i = -1, false])
	if chest != null and from_bag:
		out.append(["Metti qui", func() -> void:
			_transfer(inv, i, chest.inv)
			_sel_i = -1, false])
	if from_bag and chest == null:
		if i >= PlayerItems.HOTBAR and PlayerItems.can_wield(st):
			out.append(["In barra", func() -> void:
				var free := -1
				for k in PlayerItems.HOTBAR:
					if items.inv.get_slot(k) == null:
						free = k
						break
				Inventory.move(items.inv, i, items.inv, free if free >= 0 else items.selected)
				items.held_changed.emit()
				_sel_i = -1, false])
		if st.count > 1:
			out.append(["Dividi", func() -> void:
				var room := -1
				for k in inv.size():
					if inv.get_slot(k) == null:
						room = k
						break
				if room >= 0:
					inv.set_slot(room, inv.take(i, st.count / 2))
					items.held_changed.emit(), false])
		out.append(["Getta", func() -> void:
			var o := inv.take(i)
			items.held_changed.emit()
			if o != null:
				dropped.emit(o)
			message.emit("gettato a terra: %s (resta 5 minuti)" % d.display_name)
			_sel_i = -1, false])
	return out


## Sposta (tutto quello che entra) da un inventario all'altro.
func _transfer(from: Inventory, i: int, to: Inventory) -> void:
	var st := from.get_slot(i)
	if st == null:
		return
	var left := to.add(st.duplicate_stack())
	if left == 0:
		from.set_slot(i, null)
	else:
		st.count = left
		from.changed.emit()
		message.emit("non c'è spazio")
	items.held_changed.emit()


## Come si usa: una riga per tipo di oggetto.
static func usage_hint(d: ItemDefinition) -> String:
	match d.kind:
		ItemDefinition.Kind.WEAPON:
			return "Arma: si usa in mano. \"Impugna\" la mette nella barra rapida e la sceglie; i colpi si fanno con Colpo e Forte."
		ItemDefinition.Kind.TOOL:
			return "Attrezzo: in mano, tieni premuto sul mondo per scavare o abbattere; colpisce anche, ma piano."
		ItemDefinition.Kind.ARMOR:
			return "Armatura: \"Indossa\" la mette addosso e conta sempre, anche senza averla in mano."
		ItemDefinition.Kind.BLOCK:
			return "Blocco: in mano, tocca il mondo per posarlo."
		ItemDefinition.Kind.STATION:
			return "Stazione: in mano, tocca il suolo per piazzarla; tocca la stazione per usarla."
	return "Materiale: serve nelle ricette (scheda Craft)."


func _draw_info(r: Rect2) -> void:
	draw_rect(r, Color(0.1, 0.12, 0.13, 0.9))
	if _sel_inv == null or _sel_i < 0 or _sel_inv.get_slot(_sel_i) == null:
		_text(r.position + Vector2(dp(10.0), dp(24.0)), "Nessun oggetto selezionato", 15, Color(0.7, 0.7, 0.7))
		_text_wrap(r.position + Vector2(dp(10.0), dp(48.0)), "Tocca un oggetto: qui compaiono le sue statistiche e i pulsanti per impugnarlo, indossarlo, spostarlo o gettarlo.", 12, Color(0.65, 0.7, 0.68), r.size.x - dp(20.0))
		return
	var st := _sel_inv.get_slot(_sel_i)
	var d := st.def()
	var x := r.position.x + dp(10.0)
	var w := r.size.x - dp(20.0)
	var y := r.position.y + dp(26.0)
	_text(Vector2(x, y), Loot.full_name(st), 17, Loot.RARITY_COLORS[st.rarity()], w)
	y += dp(22.0)
	if d.is_equipment():
		_text(Vector2(x, y), Loot.RARITY_NAMES[st.rarity()], 13, Loot.RARITY_COLORS[st.rarity()])
		y += dp(20.0)
	for line in Loot.describe(st):
		_text(Vector2(x, y), "• " + line, 14, Color(0.9, 0.92, 0.88), w)
		y += dp(19.0)
	y += _text_wrap(Vector2(x, y + dp(4.0)), usage_hint(d), 12, Color(0.7, 0.8, 0.95), w) + dp(12.0)
	# Confronto con l'equipaggiamento attuale.
	var now := items.stats()
	var then: Equipment.Stats = null
	if PlayerItems.can_wield(st) and d.is_equipment():
		then = _stats_if(st, null)
	elif d.kind == ItemDefinition.Kind.ARMOR:
		then = _stats_if(items.held(), st)
	if then != null:
		var diffs := stat_diff(now, then)
		var what := "Se lo impugni:" if d.kind != ItemDefinition.Kind.ARMOR else "Se lo indossi:"
		_text(Vector2(x, y), what + ("  nessuna differenza" if diffs.is_empty() else ""), 13, Color(0.85, 0.88, 0.85))
		y += dp(18.0)
		for df: Array in diffs:
			_text(Vector2(x + dp(8.0), y), df[0], 13, Color(0.55, 0.95, 0.55) if df[1] else Color(1.0, 0.55, 0.5))
			y += dp(17.0)
	var acts := _actions(_sel_inv, _sel_i)
	var bw := (r.size.x - dp(30.0)) * 0.5
	var bh := dp(40.0)
	var rows := ceili(acts.size() / 2.0)
	for k in acts.size():
		var a: Array = acts[k]
		var bx := r.position.x + dp(10.0) + (k % 2) * (bw + dp(10.0))
		var by := r.end.y - dp(10.0) - (rows - k / 2) * (bh + dp(8.0)) + dp(8.0)
		var cb: Callable = a[1]
		_button(Rect2(bx, by, bw, bh), a[0], cb, cb.is_valid(), a[2])


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
					crafted.emit(made.id)
					message.emit("creato: %s%s" % [Loot.full_name(made), (" (%s)" % Loot.RARITY_NAMES[made.rarity()]) if made.rarity() > 0 else ""])
					items.held_changed.emit()
				else:
					message.emit("non c'e' spazio nello zaino"), ok, ok)
		y += rh + dp(4.0)


func _draw_chest(body: Rect2) -> void:
	if chest == null or chest.inv == null:
		return
	var cols := 6
	var left_w := body.size.x * 0.6
	var cell := minf((left_w - dp(6.0) * (cols - 1)) / cols, dp(58.0))
	var title: String = {"treasure": "Tesoro", "armory": "Armeria"}.get(chest.type, "Forziere")
	var hint := "tocca un'arma e premi \"Impugna\" per averla subito in mano" if chest.type == "armory" else "tocca un oggetto per vedere cosa farne"
	_text(body.position + Vector2(0, dp(16.0)), "%s — %s" % [title, hint], 13, Color(0.85, 0.9, 0.85))
	_grid(chest.inv, body.position + Vector2(0, dp(26.0)), cols, cell, _tap_select)
	var y2 := body.position.y + dp(26.0) + 3 * (cell + dp(6.0)) + dp(22.0)
	_text(Vector2(body.position.x, y2 - dp(6.0)), "Zaino (la prima riga è la barra rapida)", 13, Color(0.8, 0.85, 0.8))
	var bcell := minf((left_w - dp(6.0) * 11) / 12.0, cell)
	_grid(items.inv, Vector2(body.position.x, y2), cols * 2, bcell, _tap_select)
	var info := Rect2(body.position.x + left_w + dp(10.0), body.position.y + dp(26.0), body.size.x - left_w - dp(10.0), body.size.y - dp(26.0) - dp(52.0))
	_draw_info(info)
	var all := Rect2(info.position.x, info.end.y + dp(8.0), info.size.x, dp(44.0))
	_button(all, "Prendi tutto", func() -> void:
		for i in chest.inv.size():
			_transfer(chest.inv, i, items.inv), true, false)


## Tocco su uno slot di forziere/zaino nella scheda del forziere: solo selezione.
func _tap_select(inv: Inventory, i: int) -> void:
	if _sel_inv == inv and _sel_i == i:
		_sel_i = -1
		_sel_inv = null
	elif inv.get_slot(i) != null:
		_sel_inv = inv
		_sel_i = i


