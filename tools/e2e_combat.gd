extends SceneTree
## Prova end-to-end del combattimento (xvfb-run) con tocchi reali sui pulsanti:
## catena di quattro colpi di spada sui manichini, cambio arma al martello,
## colpo forte caricato tenendo premuto, capriola, editor dell'eroe.
## Salva screenshot a meta' dei colpi. Uso:
## xvfb-run -a godot --path . --script res://tools/e2e_combat.gd -- --out=/tmp/combat.png

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://combat.png"
var _ok := true
var _shots := {}
var _hits := 0
var _impacts := 0
var _max_combo := 0
var _log: Array[String] = []


func _initialize() -> void:
	# Impostazioni proprie, per non toccare quelle del giocatore.
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
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


func _button(id: StringName) -> Vector2:
	return _game._touch.button_rect(id).get_center()


func _tap(id: StringName) -> void:
	_touch(3, _button(id), true)
	_touch(3, _button(id), false)


func _shot(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	var path := _out.replace(".png", "_%s.png" % name)
	root.get_texture().get_image().save_png(path)
	_log.append("screenshot " + path)


func _process(_dt: float) -> bool:
	_frame += 1
	var c := _game.combat
	if c != null:
		_max_combo = maxi(_max_combo, c.combo)
		for d in _game._dummies.dummies:
			pass
	match _phase:
		0:
			if _game._runtime.is_idle() and _game._build_ms > 0 and _game._vegetation.is_idle() and _game._water.is_idle():
				_game._day.time = 0.35
				_game._day.paused = true
				_game.select_weapon(1)
				_game.show_hitboxes = true
				_game._camera_rig.set_zoom(1.7)
				_game._camera_rig.zoom = 1.7
				_game._dummies.place_around(_game.motor.position, _game._avatar.facing, 3, 2.6)
				_phase = 1
				_frame = 0
		1:
			# Catena: un tocco ogni 16 frame (entra nel buffer del colpo in corso).
			if _frame in [20, 36, 52, 68]:
				_tap(&"attack")
			if c.attack != null and c.phase() == 1 and c.phase_u() > 0.45:
				_shot("swing_%s" % c.attack.id)
			if _frame == 150:
				_hits = _count_hits()
				_log.append("spada: colpi a segno %d, combo massima %d" % [_hits, _max_combo])
				_ok = _ok and _hits >= 3 and _max_combo >= 3
				_game.show_hitboxes = false
				_tap(&"weapon")
				_tap(&"weapon")
				_phase = 2
				_frame = 0
		2:
			if _frame == 10:
				_ok = _ok and c.weapon.id == &"hammer"
				_log.append("arma: %s" % c.weapon.id)
				for d in _game._dummies.dummies:
					d.respawn()
				_touch(4, _button(&"heavy"), true)
			if c.charging:
				_shot("charge")
			if _frame == 55:
				_touch(4, _button(&"heavy"), false)
			if c.attack != null and c.phase() >= 1 and c.attack.id == &"quake":
				_shot("quake")
			if _frame == 150:
				var h := _count_hits()
				_log.append("martello caricato: colpi %d" % h)
				_ok = _ok and h >= 1
				_tap(&"dodge")
				_phase = 3
				_frame = 0
		3:
			if c.state == CombatController.State.DODGE and c.dodge_u() > 0.4:
				_shot("dodge")
			if _frame == 60:
				_ok = _ok and _shots.has("dodge")
				_tap(&"hero")
			if _frame == 70:
				_tap(&"hero_hair_style")
				_tap(&"hero_shirt")
			if _frame == 110:
				_shot("hero")
				_ok = _ok and _game._touch.hero_open
				_tap(&"hero_close")
			if _frame == 130:
				_phase = 4
				_frame = 0
				_game.magic.mana = MagicSystem.MANA_MAX
				_game._dummies.place_around(_game.motor.position, _game._avatar.facing, 3, 4.5)
				_hits = _count_hits()
		4:
			# Magia: acqua (bagna) poi fuoco sullo stesso manichino (vapore), terra, aria.
			var m := _game.magic
			var plan := {10: 1, 70: 0, 130: 2, 190: 3}
			if plan.has(_frame):
				m.select(plan[_frame])
				m.mana = MagicSystem.MANA_MAX
				_touch(5, _button(&"magic"), true)
			if _frame in [40, 100, 160, 215]:
				_touch(5, _button(&"magic"), false)
			if m.phase == MagicSystem.Phase.GATHER and m.w > 0.8:
				_shot("gather_%s" % m.spell().id)
			for d in m.darts:
				if d.t > 0.12:
					_shot("dart_%s" % d.spell.id)
			for e in m.events:
				if e["type"] == "text":
					_log.append("scritta: %s" % e["text"])
			if _frame == 300:
				_shot("magic_end")
				var h := _count_hits() - _hits
				_log.append("magia: colpi sui manichini %d, celle in fiamme %d, crateri %d" % [h, m.fire.size(), m.crater_items])
				_ok = _ok and h >= 2
				for l in _log:
					print(l)
				print("e2e combattimento %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
	return false


func _count_hits() -> int:
	var n := 0
	for d in _game._dummies.dummies:
		n += d.hits
	return n
