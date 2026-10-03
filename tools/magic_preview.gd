extends SceneTree
## Anteprima della magia del fuoco (D-055) nel gioco vero: l'eroe col bastone
## davanti all'avversario dell'arena lancia un dardo di fuoco, poi carica e
## lancia una palla di fuoco. Foto nei momenti chiave e riepilogo dei colpi.
## Uso: xvfb-run -a godot --path . --script res://tools/magic_preview.gd -- --out=/tmp/magia.png [--iso]

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://magia.png"
var _iso := false
var _t := 0.0
var _hp0 := 0.0
var _log: Array[String] = []
var _shots := {}
var _peak := 0
var _gas_ms := 0.0


func _initialize() -> void:
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--iso":
			_iso = true
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)


## La foto si prende al fotogramma dopo: quello gia' disegnato e' del passo prima.
var _pending: Array[String] = []


func _shot(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	_pending.append(name)


func _flush() -> void:
	for name in _pending:
		root.get_texture().get_image().save_png(_out.replace(".png", "_%s.png" % name))
	_pending.clear()


func _process(dt: float) -> bool:
	_frame += 1
	_flush()
	var g := _game
	if g.magic != null:
		_peak = maxi(_peak, g.magic.gas.count())
	match _phase:
		0:
			if g._runtime.is_idle() and g._build_ms > 0 and g._vegetation.is_idle() and g._water.is_idle():
				g._day.time = 0.4
				g._day.paused = true
				for n: Node in root.find_children("*", "CanvasLayer", true, false):
					(n as CanvasLayer).visible = false
				g.select_weapon(GameRoot.WEAPONS.find(&"staff"))
				# A 5 m dall'avversario, girati verso di lui.
				# A 5 m dall'avversario, di lato rispetto all'armeria, girati verso di lui.
				var d: TrainingDummy = g._dummies.dummies[0]
				var c: Vector3 = Vector3(g.world.arena.x + 0.5, d.position.y, g.world.arena.z + 0.5)
				var to_c: Vector3 = (c - d.position).normalized()
				var side: Vector3 = Vector3(-to_c.z, 0, to_c.x)
				g.motor.place_at(d.position + side * 5.0)
				var face: float = CombatController.heading(Vector2(-side.x, -side.z))
				g._avatar.facing = face
				g._avatar.rotation.y = face
				g.combat.facing = face
				if _iso:
					g._camera_rig.set_zoom(1.3)
				else:
					g._camera_rig.set_mode(CameraRig.Mode.TPS)
					g._camera_rig.set_zoom(1.0)
					g._camera_rig.tps_user_pitch = 0.3
					g._camera_rig.yaw_target = face + PI * 0.35
				_phase = 1
				_frame = 0
		1:
			if _frame == 60:
				_hp0 = g._dummies.dummies[0].hp
				g.combat.press_light()
				_t = 0.0
				_phase = 2
		2:
			_t += dt
			if g.combat.attack != null and g.combat.phase() == 0 and _t > 0.08:
				_shot("1_lancio")
			if not g.magic.shots.is_empty():
				var s: FireMagic.Shot = g.magic.shots[0]
				if s.t > 0.05:
					_shot("2_dardo")
			if _t > 1.2:
				var d: TrainingDummy = g._dummies.dummies[0]
				_log.append("dardo: danno %.0f (bruciatura compresa)" % (_hp0 - d.hp))
				_hp0 = d.hp
				_t = 0.0
				g.combat.press_heavy()
				_phase = 3
		3:
			_t += dt
			if _t > 0.5:
				_shot("3_carica")
			if _t > 1.0:
				g.combat.release_heavy()
				_t = 0.0
				_phase = 4
		4:
			_t += dt
			if not g.magic.shots.is_empty():
				var s: FireMagic.Shot = g.magic.shots[0]
				if s.t > 0.15:
					_shot("4_palla")
			if g.magic.blast_age > 0.12 and g.magic.blast_age < 1.0:
				_shot("5_esplosione")
			if g.magic.blast_age > 0.6 and g.magic.blast_age < 2.0:
				_shot("7_fungo")
			if _t > 0.6 and g.magic.burns.size() > 0:
				_shot("6_bruciatura")
			if _t > 3.0:
				var d: TrainingDummy = g._dummies.dummies[0]
				_log.append("palla di fuoco: danno %.0f (bruciatura compresa), avversario %s" % [_hp0 - d.hp, "in piedi" if d.alive else "a terra"])
				_log.append("grani al massimo: %d (tetto %d)" % [_peak, FireGas.CAP])
				for l in _log:
					print(l)
				return true
	return false
