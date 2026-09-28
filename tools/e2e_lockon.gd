extends SceneTree
## Prova end-to-end dell'aggancio (D-035) con tocchi reali: Lock aggancia un
## manichino fuori dal cono della mira assistita, compare il triangolo rosso,
## lo stick a destra fa girare l'eroe attorno al bersaglio guardandolo
## (camminata laterale), i colpi e una magia vanno sul bersaglio agganciato,
## due magie d'acqua per vedere la nuova palette, Lock di nuovo sgancia.
## Uso: xvfb-run -a godot --path . --script res://tools/e2e_lockon.gd -- --out=/tmp/lock.png

var _game: GameRoot
var _out := "user://lock.png"
var _phase := 0
var _frame := 0
var _t := 0.0
var _ok := true
var _log: Array[String] = []
var _target: TrainingDummy
var _hits0 := 0
var _err_max := 0.0
var _p0 := Vector3.ZERO
var _stick := Vector2(160, 560)
var _shots := {}


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


func _drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	Input.parse_input_event(e)


func _tap(id: StringName) -> void:
	var c := _game._touch.button_rect(id).get_center()
	_touch(4, c, true)
	_touch(4, c, false)


func _shot(name: String) -> void:
	_shots[name] = true
	var path := _out.replace(".png", "_%s.png" % name)
	root.get_texture().get_image().save_png(path)
	_log.append("screenshot %s" % path)


func _expect(cond: bool, what: String) -> void:
	_log.append("%s %s" % ["OK " if cond else "NO ", what])
	_ok = _ok and cond


func _hits() -> int:
	return _target.hits if _target != null else 0


func _next() -> void:
	_phase += 1
	_frame = 0
	_t = 0.0


func _process(dt: float) -> bool:
	var g := _game
	_frame += 1
	_t += dt
	match _phase:
		0:
			if g._runtime.is_idle() and g._build_ms > 0 and g._vegetation.is_idle() and g._water.is_idle():
				g._day.time = 0.45
				g._day.paused = true
				g._camera_rig.set_zoom(1.6)
				var gr := g._camera_rig.ground_right()
				g._avatar.facing = CombatController.heading(Vector2(gr.x, gr.z))
				# Un manichino a 65° (fuori dal cono della mira assistita) e uno lontano.
				var mp := g.motor.position
				g._dummies.place_around(mp, g._avatar.facing + deg_to_rad(65.0), 1, 3.2)
				var f2 := CombatController.forward(g._avatar.facing - deg_to_rad(80.0))
				var p2 := Vector3(mp.x + f2.x * 7.0, mp.y, mp.z + f2.y * 7.0)
				p2.y = VoxelQuery.field_height(g.world, p2.x, p2.z, mp.y + 2.0)
				g._dummies.add_dummy(p2)
				_target = g._dummies.dummies[0]
				_next()
		1:
			if _frame == 10:
				_tap(&"lock")
			if _frame == 14:
				_expect(g.lock.active() and g.lock.target == _target, "Lock aggancia il manichino vicino a 65°")
				_expect(g._touch.lock_on, "pulsante Lock acceso")
			if _frame == 40:
				_expect(g._lock_marker.visible, "triangolo rosso visibile")
				var err := rad_to_deg(absf(wrapf(g._avatar.facing - g.lock.heading_from(g.motor.position), -PI, PI)))
				_expect(err < 10.0, "l'eroe si gira sul bersaglio da fermo (%.0f°)" % err)
				_shot("agganciato")
				_p0 = g.motor.position
				_touch(1, _stick, true)
				_drag(1, _stick + Vector2(70, 0))
				_next()
		2:
			# Camminata laterale: lo stick a destra, lo sguardo resta sul bersaglio.
			if _t > 0.5:
				var err := rad_to_deg(absf(wrapf(g._avatar.facing - g.lock.heading_from(g.motor.position), -PI, PI)))
				_err_max = maxf(_err_max, err)
			if _t > 0.8 and not _shots.has("laterale"):
				_shot("laterale")
			if _t > 1.2:
				_touch(1, _stick + Vector2(70, 0), false)
				var moved := Vector2(g.motor.position.x - _p0.x, g.motor.position.z - _p0.z).length()
				_expect(moved > 1.0, "si e' spostato di lato (%.2f m)" % moved)
				_expect(_err_max < 20.0, "sguardo sul bersaglio durante la camminata (errore massimo %.0f°)" % _err_max)
				_expect(g.lock.active(), "ancora agganciato")
				# Il manichino torna a 1,8 m, 70° di lato: il colpo deve girarsi da solo.
				var f := CombatController.forward(g._avatar.facing + deg_to_rad(70.0))
				var mp := g.motor.position
				var p := Vector3(mp.x + f.x * 1.8, mp.y, mp.z + f.y * 1.8)
				p.y = VoxelQuery.field_height(g.world, p.x, p.z, mp.y + 2.0)
				_target.position = p
				_target.home = p
				_hits0 = _hits()
				_next()
		3:
			# Colpi: tre tocchi su Colpo, vanno sul bersaglio agganciato.
			if _frame in [2, 6, 10]:
				_tap(&"attack")
			if g.combat.attack != null and g.combat.phase() == 1 and not _shots.has("colpo"):
				_shot("colpo")
			if _t > 2.2:
				_expect(_hits() > _hits0, "i colpi prendono il bersaglio agganciato (%d)" % (_hits() - _hits0))
				_hits0 = _hits()
				var m := g.magic
				m.equip(&"fire_bolt", 4)
				m.select(4)
				m.pressure = 0.0
				m.saturated = false
				g._refresh_spellbar()
				_tap(&"magic")
				_next()
		4:
			if _frame == 3:
				_log.append("   magia: fase %d, bersaglio a %.1f m, agganciato %s" % [g.magic.phase, g.lock.flat_dist(g.motor.position) if g.lock.active() else -1.0, g.lock.active()])
			if _t > 2.0:
				_expect(_hits() > _hits0, "la magia prende il bersaglio agganciato (%d)" % (_hits() - _hits0))
				var m := g.magic
				m.equip(&"water_hydrant", 4)
				m.select(4)
				m.pressure = 0.0
				m.saturated = false
				g._refresh_spellbar()
				_tap(&"magic")
				_next()
		5:
			if _t > 0.9 and not _shots.has("acqua_idrante"):
				_shot("acqua_idrante")
			if _t > 1.6:
				var m := g.magic
				m.equip(&"water_rain", 4)
				m.select(4)
				m.pressure = 0.0
				m.saturated = false
				g._refresh_spellbar()
				_tap(&"magic")
				_next()
		6:
			if _t > 1.3 and not _shots.has("acqua_diluvio"):
				_shot("acqua_diluvio")
			if _t > 2.4:
				if not g.lock.active():
					# Il manichino si e' rotto sotto le magie: l'aggancio e' caduto
					# da solo. Si riaggancia per provare lo sgancio col pulsante.
					_log.append("   aggancio caduto col manichino rotto (%s): si riaggancia" % (not _target.alive))
					_tap(&"lock")
				_next()
		7:
			if _frame == 4:
				_expect(g.lock.active(), "agganciato prima dello sgancio")
				_tap(&"lock")
			if _frame == 8:
				_expect(not g.lock.active() and not g._touch.lock_on, "Lock di nuovo: sganciato")
			if _frame == 14:
				_expect(not g._lock_marker.visible, "triangolo nascosto")
				for l in _log:
					print(l)
				print("e2e aggancio %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
	return false
