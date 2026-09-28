extends SceneTree
## Prova end-to-end della magia ampliata (D-027) con tocchi reali: la barra
## delle magie apre il libro (slot vuoto), nel libro si sceglie una magia e la
## si mette nello slot 5, poi una serie di magie del libro sui manichini con
## uno screenshot per forma (raggio, getto, colonne, onda, muro, ciclone,
## meteorite, pioggia, sisma, orbe, tridente, raffica). Uso:
## xvfb-run -a godot --path . --script res://tools/e2e_magic.gd -- --out=/tmp/magic.png

## Magia e secondi dopo il lancio per lo screenshot.
const PLAN := [
	[&"giudizio", 0.04], [&"fire_jet", 0.5], [&"fire_columns", 0.45], [&"water_tide", 0.7], [&"earth_wall", 0.4],
	[&"air_cyclone", 0.9], [&"fire_meteor", 0.55], [&"water_rain", 0.9], [&"earth_quake", 0.7], [&"orbe", 0.3],
	[&"tridente", 0.08], [&"fire_volley", 0.45], [&"zoltraak", 0.04], [&"air_updraft", 1.1],
]

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://magic.png"
var _ok := true
var _shots := {}
var _log: Array[String] = []
var _step := 0
var _cast_t := -1.0
var _clock := 0.0
var _hits0 := 0
var _seen := {}
var _total := 0


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


func _tap_at(p: Vector2) -> void:
	_touch(3, p, true)
	_touch(3, p, false)


func _tap(id: StringName) -> void:
	_tap_at(_game._touch.button_rect(id).get_center())


func _shot(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	var path := _out.replace(".png", "_%s.png" % name)
	root.get_texture().get_image().save_png(path)
	_log.append("screenshot " + path)


func _process(dt: float) -> bool:
	_frame += 1
	_clock += dt
	var m := _game.magic
	if m != null:
		for e in m.events:
			_seen[String(e["type"])] = int(_seen.get(String(e["type"]), 0)) + 1
			if e["type"] == "text" or e["type"] == "cancel":
				_log.append("  [%d %s] %s (fps %d, fase %d, a terra %s)" % [_step, e["type"], e.get("text", ""), Engine.get_frames_per_second(), m.phase, _game.motor.on_ground])
	match _phase:
		0:
			if _game._runtime.is_idle() and _game._build_ms > 0 and _game._vegetation.is_idle() and _game._water.is_idle():
				_game._day.time = 0.62
				_game._day.paused = true
				_game._camera_rig.set_zoom(1.25)
				_game._camera_rig.zoom = 1.25
				# Tutto il libro noto, Output largo: si provano le forme, non la progressione.
				for sp in SpellDefinition.all():
					m.known[sp.id] = true
				_game.dev_output = 400.0
				_phase = 1
				_frame = 0
		1:
			# Slot vuoto della barra -> apre il libro.
			if _frame == 10:
				_ok = _ok and _game._touch.spell_icons.size() == 4
				_tap(&"sp4")
			if _frame == 30:
				_ok = _ok and _game._bag.is_open() and _game._bag.tab == "magic"
				_log.append("libro aperto: %s" % _game._bag.tab)
				_tap_at((_game._bag.spell_rects[&"giudizio"] as Rect2).get_center())
			if _frame == 40:
				_tap_at(_game._bag.bar_rects[4].get_center())
			if _frame == 50:
				_shot("book")
				_ok = _ok and m.bar[4] == &"giudizio"
				_log.append("slot 5: %s" % m.bar[4])
				_tap_at(_game._bag.close_rect.get_center())
			if _frame == 70:
				_ok = _ok and not _game._bag.is_open()
				_tap(&"sp4")
			if _frame == 80:
				_ok = _ok and m.bar_index == 4
				_hits0 = _count_hits()
				_phase = 2
				_frame = 0
		2:
			_cast_step(m)
	return false


func _cast_step(m: MagicSystem) -> void:
	if _step >= PLAN.size():
		_finish(m)
		return
	var id: StringName = PLAN[_step][0]
	var wait: float = PLAN[_step][1]
	var btn := _game._touch.button_rect(&"magic").get_center()
	if _frame == 1:
		m.equip(id, 4)
		m.select(4)
		m.pressure = 0.0
		m.saturated = false
		_game.dev_output = 400.0
		for d in _game._dummies.dummies:
			d.respawn()
		_game._dummies.place_around(_game.motor.position, _game._avatar.facing, 3, 5.0)
		_game._refresh_spellbar()
		_cast_t = -1.0
		_hits0 = _count_hits()
	# Si tiene premuto fino all'impegno, poi si rilascia (il lancio parte al 100%).
	if _frame == 4:
		_touch(5, btn, true)
	if _frame > 4 and _cast_t < 0.0 and _game._touch.is_held(&"magic") and (m.committed or m.phase == MagicSystem.Phase.RECOVER):
		_touch(5, btn, false)
	if _frame > 4 and _cast_t < 0.0 and m.phase == MagicSystem.Phase.RECOVER:
		_cast_t = _clock
	if m.phase == MagicSystem.Phase.GATHER and m.w > 0.6:
		_shot("gather_%s" % id)
	if _cast_t > 0.0 and _clock >= _cast_t + wait and not _shots.has(String(id)):
		_shot(String(id))
		_log.append("%s: strutture %d, effetti %d" % [id, m.runtime.structs.size(), m.runtime.effects.size()])
		if id == &"earth_wall":
			_ok = _ok and m.runtime.structs.size() == 1
	if (_cast_t > 0.0 and _clock >= _cast_t + wait + 1.2) or _frame > 600:
		if _cast_t < 0.0:
			_log.append("%s: NON lanciata" % id)
			_ok = false
		_total += _count_hits() - _hits0
		_log.append("%s: colpi %d" % [id, _count_hits() - _hits0])
		_step += 1
		_frame = 0


func _finish(m: MagicSystem) -> void:
	var h := _total
	_log.append("colpi sui manichini: %d" % h)
	_log.append("eventi: %s" % [_seen])
	_ok = _ok and h >= 12
	for k in ["beam", "area", "wave", "struct", "burst_ring", "mark", "ring"]:
		if not _seen.has(k):
			_log.append("manca l'evento %s" % k)
			_ok = false
	var st := _game.make_save_state()
	_ok = _ok and st.has("magic") and (st["magic"]["bar"] as Array)[4] == "air_updraft"
	_shot("hud")
	for l in _log:
		print(l)
	print("e2e magia %s" % ("OK" if _ok else "FALLITO"))
	quit(0 if _ok else 1)


func _count_hits() -> int:
	var n := 0
	for d in _game._dummies.dummies:
		n += d.hits
	return n
