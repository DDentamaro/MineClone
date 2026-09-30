extends SceneTree
## Prova dei movimenti d'arma (D-033) con le hitbox vere dell'eroe: per ogni
## arma una catena leggera premendo come un giocatore (un tocco ogni .12 s) e un
## colpo forte, su un manichino davanti; registra la catena, quali colpi vanno
## a segno, quanto l'eroe gira verso un bersaglio fuori asse (aiuto alla mira)
## e l'altezza massima raggiunta. Screenshot a meta' di ogni colpo.
## D-034: registra anche il passo dei piedi (piede avanti rispetto a quello
## dietro a meta' colpo) e, per la lancia, l'infilzata su due manichini in fila.
## Uso: xvfb-run -a godot --path . --script res://tools/e2e_moveset.gd -- --out=/tmp/moves.png [--weapon=fists]

var _game: GameRoot
var _out := "user://moves.png"
var _only := ""
var _phase := 0
var _w := 0
var _t := 0.0
var _press_t := 0.0
var _log: Array[String] = []
var _ok := true
var _starts: Array[String] = []
var _hits := {}
var _y0 := 0.0
var _ymax := 0.0
var _face0 := 0.0
var _shots := {}
var _gap := {}
var _dist := {}
var _tips := {}
var _stag := {}


func _initialize() -> void:
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--weapon="):
			_only = a.substr(9)
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	physics_frame.connect(_sample)


func _shot(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	root.get_texture().get_image().save_png(_out.replace(".png", "_%s.png" % name))


func _setup(dist: float, off_deg: float) -> void:
	var g := _game
	for d in g._dummies.dummies:
		d.respawn()
	var gr := g._camera_rig.ground_right()
	g._avatar.facing = CombatController.heading(Vector2(gr.x, gr.z))
	g.combat.facing = g._avatar.facing
	g._dummies.dummies.clear()
	g._dummies.place_around(g.motor.position, g._avatar.facing + deg_to_rad(off_deg), 1, dist)
	g.combat.cancel()
	_starts.clear()
	_hits.clear()
	_y0 = g.motor.position.y
	_ymax = _y0
	_face0 = g._avatar.facing
	_prev_attack = null
	_prev_hits = 0
	_gap.clear()
	_tips.clear()
	_stag.clear()
	_t = 0.0
	_press_t = 0.0


## Campionato a ogni passo di fisica (gli eventi li consuma il gioco): un
## attacco nuovo va nella catena, i colpi del manichino all'attacco corrente.
var _prev_attack: AttackDefinition
var _prev_hits := 0
var _prev_t := 0.0


func _sample() -> void:
	if _phase < 3:
		return
	var c := _game.combat
	var a := c.attack
	if a != null and (a != _prev_attack or c.t < _prev_t):
		_starts.append(String(a.id))
	_prev_attack = a
	_prev_t = c.t
	var hits := 0
	for d in _game._dummies.dummies:
		hits += d.hits
	if hits > _prev_hits and _starts.size() > 0:
		var id := _starts[_starts.size() - 1]
		_hits[id] = int(_hits.get(id, 0)) + hits - _prev_hits
	_prev_hits = hits
	_ymax = maxf(_ymax, _game.motor.position.y)
	# Distanza minima (m) fra le sfere dell'arma e la capsula del manichino
	# durante la fase attiva e il seguito: < 0 = contatto.
	if a != null and (c.phase() == 1 or (c.phase() == 2 and c.phase_u() <= CombatController.FOLLOW)) and not _game._dummies.dummies.is_empty():
		var tg: TrainingDummy = _game._dummies.dummies[0]
		var gap := INF
		for hb: Array in _game._avatar.rig.hitboxes():
			var cpos: Vector3 = hb[0]
			var y := clampf(cpos.y, tg.position.y, tg.position.y + tg.height)
			gap = minf(gap, Vector3(tg.position.x, y, tg.position.z).distance_to(cpos) - float(hb[1]) - tg.radius)
		var key := String(a.id) + "#%d" % _starts.size()
		_gap[key] = minf(float(_gap.get(key, INF)), gap)
		if c.phase() == 1 and absf(c.phase_u() - 0.5) < 0.2:
			var f := CombatController.forward(_game._avatar.facing)
			var mp := _game.motor.position
			var tips := []
			for hb: Array in _game._avatar.rig.hitboxes():
				var d: Vector3 = (hb[0] as Vector3) - mp
				tips.append("(av %.2f dx %.2f su %.2f)" % [d.x * f.x + d.z * f.y, d.x * -f.y + d.z * f.x, d.y])
			_tips[key] = " ".join(tips.slice(maxi(0, tips.size() - 2)))
		var dist := Vector2(tg.position.x - _game.motor.position.x, tg.position.z - _game.motor.position.z).length()
		_dist[key] = dist
		# Passo: quanto il piede del colpo sta davanti all'altro (m, lungo lo sguardo).
		if c.phase() == 1 and a.step_foot != 0.0:
			var gl := _game._avatar.gait.legs
			var lead: GaitLegs.Leg = gl[0] if a.step_foot < 0.0 else gl[1]
			var rear: GaitLegs.Leg = gl[1] if a.step_foot < 0.0 else gl[0]
			var fw := CombatController.forward(c.facing)
			_stag[key] = maxf(float(_stag.get(key, -INF)), Vector2(lead.foot.x - rear.foot.x, lead.foot.z - rear.foot.z).dot(fw))


func _collect() -> void:
	pass


func _process(dt: float) -> bool:
	var g := _game
	if _phase > 0:
		_collect()
	match _phase:
		0:
			if g._runtime.is_idle() and g._build_ms > 0 and g._vegetation.is_idle() and g._water.is_idle():
				g._day.time = 0.4
				g._day.paused = true
				g._camera_rig.set_zoom(2.0)
				_phase = 1
		1:
			# Arma successiva.
			while _w < GameRoot.WEAPONS.size() and _only != "" and String(GameRoot.WEAPONS[_w]) != _only:
				_w += 1
			if _w >= GameRoot.WEAPONS.size():
				for l in _log:
					print(l)
				print("e2e movimenti %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
				return false
			g.select_weapon(_w)
			_phase = 2
			_t = 0.0
		2:
			_t += dt
			if _t > 0.8:
				_setup(1.5, 0.0)
				_phase = 3
		3:
			# Catena leggera: un tocco ogni .12 s per 2 s.
			_t += dt
			_press_t += dt
			if _press_t >= 0.12 and _t < 2.0:
				_press_t = 0.0
				g.combat.press_light()
			var a := g.combat.attack
			if a != null and g.combat.phase() == 1:
				_shot("%s_%s" % [GameRoot.WEAPONS[_w], a.id])
			if _t > 2.6:
				var chain := ", ".join(_starts)
				_log.append("%s catena: %s · colpi %s" % [GameRoot.WEAPONS[_w], chain, _hits])
				for k: String in _gap:
					_log.append("      %s: distanza minima %.2f m (manichino a %.2f m) punta %s" % [k, float(_gap[k]), float(_dist.get(k, 0.0)), _tips.get(k, "")])
				for k: String in _stag:
					_log.append("      %s: piede del colpo avanti di %.2f m" % [k, float(_stag[k])])
					if float(_stag[k]) < 0.04:
						_log.append("   NO   %s senza passo" % k)
						_ok = false
					elif float(_stag[k]) > 0.9:
						# D-043/D-044: gambe da 0,8 m (prima 0,3 m e limite 0,55).
						_log.append("   NO   %s piedi troppo larghi (gambe da 0,8 m)" % k)
						_ok = false
				# Il primo giro della catena deve andare tutto a segno (dopo il colpo
				# finale il manichino e' lontano: e' voluto).
				var first: Array[String] = []
				for id in _starts:
					if first.has(id):
						break
					first.append(id)
				for id in first:
					if not _hits.has(id):
						_log.append("   NO   %s non colpisce (primo giro)" % id)
						_ok = false
				_gap.clear()
				_tips.clear()
				_setup(1.5, 0.0)
				g.combat.press_heavy()
				_phase = 4
		4:
			_t += dt
			if _t > 0.12:
				g.combat.release_heavy()
			var a2 := g.combat.attack
			if a2 != null and g.combat.phase() == 1:
				_shot("%s_forte_%s" % [GameRoot.WEAPONS[_w], a2.id])
			if _t > 1.8:
				_log.append("%s forte: %s · colpi %s · salto %.2f m" % [GameRoot.WEAPONS[_w], ", ".join(_starts), _hits, _ymax - _y0])
				for k: String in _gap:
					_log.append("      %s: distanza minima %.2f m (manichino a %.2f m) punta %s" % [k, float(_gap[k]), float(_dist.get(k, 0.0)), _tips.get(k, "")])
				_gap.clear()
				if _hits.is_empty():
					_log.append("   NO   il forte non colpisce")
					_ok = false
				# Bersaglio a 40° e 2,4 m: quanto gira l'eroe da solo?
				_setup(2.4, 40.0)
				g.combat.press_light()
				_phase = 5
		5:
			_t += dt
			if _t > 0.6:
				var turned := rad_to_deg(absf(wrapf(g._avatar.facing - _face0, -PI, PI)))
				_log.append("%s aiuto alla mira: girato di %.0f° verso un bersaglio a 40°/2,4 m, colpi %s" % [GameRoot.WEAPONS[_w], turned, _hits])
				if GameRoot.WEAPONS[_w] == &"spear":
					# Infilzata su due manichini in fila (1,6 e 3,4 m).
					_setup(1.6, 0.0)
					var f := CombatController.forward(g._avatar.facing)
					var mp := g.motor.position
					var p2 := Vector3(mp.x + f.x * 3.4, mp.y, mp.z + f.y * 3.4)
					p2.y = VoxelQuery.field_height(g.world, p2.x, p2.z, mp.y + 2.0)
					g._dummies.add_dummy(p2)
					g.combat._start_attack(&"impale", g.motor, g._dummies.dummies, Vector2.ZERO)
					_phase = 6
				else:
					_w += 1
					_phase = 1
		6:
			_t += dt
			if g.combat.attack != null and g.combat.phase() == 1:
				_shot("spear_infilzata")
			if _t > 1.2:
				var hs: Array[int] = []
				for d in g._dummies.dummies:
					hs.append(d.hits)
				_log.append("spear infilzata su due in fila: colpi %s" % [hs])
				if hs.size() < 2 or hs[0] < 1 or hs[1] < 1:
					_log.append("   NO   l'infilzata non trapassa")
					_ok = false
				_w += 1
				_phase = 1
	return false
