class_name FireMagic
extends Node3D
## Magia del fuoco del bastone (D-055), resa come in RMNDWN (D-056): il fuoco
## e' solo gas caldo a grani (`FireGas`), niente mesh.
## - Gemma: braci sempre accese finche' si impugna il bastone; nella
##   preparazione la portata monta (la carica si legge dalla densita').
## - Cerchio di rune a grani davanti alla gemma: si traccia come sotto un
##   compasso durante la preparazione, resta acceso al lancio e poi si sfalda.
## - Dardo ("bolt"): testa piccola di grani legati che si staccano in fretta,
##   scia corta e stretta; al contatto un anello e qualche brace.
## - Palla ("ball"): si forma sulla gemma durante la carica (testa legata
##   all'ancora della gemma che al lancio diventa il corpo del proiettile),
##   lenta, al contatto, a terra o a fine corsa si apre a fungo (anello radiale
##   corto, poi solo galleggiamento) e lascia braci a terra.
## - Bruciatura: fiammelle che salgono da chi e' stato preso.
## La logica sta qui (niente nodi per la fisica); gli eventi vanno al gioco
## per scossa della camera e numeri del danno.

const BOLT_SPEED := 19.0
const BOLT_LIFE := 0.95
const BOLT_R := 0.2
const BOLT_TURN := 5.0
const BALL_SPEED := 11.0
const BALL_LIFE := 1.6
const BALL_R := 0.3
const BALL_TURN := 2.0
## Raggio dell'esplosione: base e in piu' a carica piena.
const BLAST := 1.9
const BLAST_CHARGE := 1.1
## Bruciatura: durata, intervallo e danno per colpo.
const BURN_TIME := 3.0
const BURN_TICK := 0.5
const BURN_DMG := 2.0

## Parametri del gas (RMNDWN VARIANTS fire, HTML 23239-23290), con grani piu'
## grossi: la vista qui e' piu' larga del render target di 424 px.
const BOLT_GAS := {"buoy": 6.5, "turb": 1.7, "drag": 1.9, "cool": 1.5, "eddy": 0.8, "size": 0.075, "L": 0.6, "D": 0.16}
const BALL_GAS := {"buoy": 7.0, "turb": 1.4, "drag": 2.0, "cool": 0.72, "eddy": 0.95, "size": 0.08, "L": 1.3, "D": 0.62}
## Palla in formazione sulla gemma: fiamma corta, che non faccia una colonna.
const CHARGE_GAS := {"buoy": 6.0, "turb": 1.4, "drag": 2.2, "cool": 1.3, "eddy": 0.6, "size": 0.06, "L": 0.45, "D": 0.3}
const GEM_GAS := {"buoy": 5.5, "turb": 1.0, "drag": 2.0, "cool": 0.75, "eddy": 0.0, "size": 0.039, "L": 0.46, "D": 0.1}
const BURN_GAS := {"buoy": 5.0, "turb": 1.2, "drag": 2.2, "cool": 0.8, "eddy": 0.3, "size": 0.045, "L": 0.5, "D": 0.3}
const EMBER_GAS := {"buoy": 5.5, "turb": 1.2, "drag": 2.0, "cool": 0.9, "eddy": 0.4, "size": 0.045, "L": 0.35, "D": 0.12}
## Testa: raggio, trattenuta, rotazione, guscio, quota della corsa al rilascio,
## grani alla nascita, portata in volo.
const BOLT_HEAD := {"r": 0.16, "hold": 0.10, "spin": 3.2, "shell": 0.45, "retain": 0.14, "seed": 70, "rate": 600.0}
const BALL_HEAD := {"r": 0.30, "hold": 0.42, "spin": 1.2, "shell": 0.28, "retain": 0.26, "seed": 120, "rate": 480.0}
## Cerchio: raggio, poligono, tacche, rotazione, portata, vita dei grani, quanto
## resta acceso dopo il lancio.
const BOLT_GLYPH := {"r": 0.28, "poly": 3, "ticks": 8, "spin": 1.18, "rate": 1300.0, "life": 0.31, "max": 220, "keep": 0.22}
const BALL_GLYPH := {"r": 0.46, "poly": 4, "ticks": 16, "spin": 0.53, "rate": 2100.0, "life": 0.47, "max": 380, "keep": 0.35}
## Colpo: anello (grani, velocita'), ejecta, lunghezza e spinta della fiamma,
## taglia dei grani, braci a terra (numero, raggio, vita).
const BOLT_HIT := {"ring": 18, "ring_v": 6.0, "ejecta": 9, "len": 1.3, "buoy": 1.3, "size": 1.2, "res": 7, "res_r": 0.55, "res_life": 0.9}
const BALL_HIT := {"ring": 28, "ring_v": 7.5, "ejecta": 14, "len": 2.4, "buoy": 1.5, "size": 0.85, "res": 16, "res_r": 1.15, "res_life": 1.8}

class Shot:
	extends RefCounted
	var kind := "bolt"
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var t := 0.0
	var life := 1.0
	var r := 0.2
	var damage := 10.0
	var knock := 2.0
	var launch := 0.0
	var shake := 0.1
	var charge := 0.0
	var target: CombatTarget
	var anchor: FireGas.Anchor
	var gas: Dictionary
	var head: Dictionary
	var acc := 0.0
	var phase := 0.0
	var light: OmniLight3D
	var dead := false


var world: WorldData:
	set(w):
		world = w
		if gas != null:
			gas.world = w
var gas: FireGas
var shots: Array[Shot] = []
var burns := {}
var events: Array[Dictionary] = []
## Secondi dall'ultima esplosione (INF se nessuna).
var blast_age := INF
## Gemma del bastone impugnato (aggiornata dal gioco a ogni passo).
var gem_on := false
var gem := Vector3.ZERO
var gem_dir := Vector3.FORWARD
var _cast_kind := ""
var _cast_u := 0.0
var _cast_cf := 0.0
var _glyph: FireGas.Glyph
var _charge: FireGas.Anchor
## Cerchi gia' lanciati: [cerchio, secondi prima dello sfaldamento].
var _launched: Array = []
## Dopo il lancio la gemma brucia ancora un poco piu' forte.
var _after := 0.0
var _acc := {}
## Braci a terra dopo un colpo: {p, t, life, key}.
var _sources: Array[Dictionary] = []
var _lights: Array[Dictionary] = []


func _init() -> void:
	gas = FireGas.new()
	gas.name = "FireGas"
	add_child(gas)


func clear() -> void:
	for s in shots:
		_free(s)
	shots.clear()
	for l in _lights:
		if is_instance_valid(l["light"]):
			(l["light"] as Node).queue_free()
	_lights.clear()
	_sources.clear()
	_launched.clear()
	burns.clear()
	_glyph = null
	_charge = null
	_cast_kind = ""
	gas.clear()


## Il gioco dice dove sta la gemma (o che il bastone non c'e').
func set_gem(on: bool, p: Vector3, dir: Vector3) -> void:
	gem_on = on
	gem = p
	if dir.length() > 1e-3:
		gem_dir = dir.normalized()


## Preparazione di un lancio in corso: tipo ("bolt"/"ball", "" se nessuna),
## avanzamento della preparazione 0..1 e carica 0..1.
func casting(kind: String, u: float, cf: float) -> void:
	if kind == "":
		if _glyph != null:
			gas.glyph_end(_glyph)
			_glyph = null
		if _charge != null:
			_charge.alive = false
			_charge = null
		_cast_kind = ""
		return
	_cast_kind = kind
	_cast_u = u
	_cast_cf = cf
	var Y: Dictionary = BALL_GLYPH if kind == "ball" else BOLT_GLYPH
	if _glyph == null:
		_glyph = _new_glyph(Y, gem_dir)
	_glyph.prog = clampf(u / 0.72, 0.0, 1.0)
	_glyph.lvl = maxf(0.25, _glyph.prog)
	if kind == "ball":
		_glyph.r = float(Y["r"]) * (0.8 + 0.4 * cf)
		if _charge == null:
			_charge = FireGas.Anchor.new()
			_charge.spin = BALL_HEAD["spin"]
			_charge.retain = BALL_HEAD["retain"]
		_charge.p = gem
		_charge.v = Vector3.ZERO
		_charge.r = 0.08 + 0.2 * cf


func _new_glyph(Y: Dictionary, n: Vector3) -> FireGas.Glyph:
	var y := gas.glyph_new(_glyph_center(Y), n, Y["r"], Y["poly"], Y["ticks"], Y["spin"])
	y.rate = Y["rate"]
	y.life = Y["life"]
	y.max_n = Y["max"]
	y.size = 0.032
	return y


func _glyph_center(Y: Dictionary) -> Vector3:
	return gem + gem_dir * (0.18 if Y == BALL_GLYPH else 0.14)


## Lancio dalla gemma `origin` verso `dir` (o verso il bersaglio agganciato).
func cast(a: AttackDefinition, origin: Vector3, dir: Vector3, charge: float, target: CombatTarget, damage_mult: float = 1.0) -> Shot:
	var s := Shot.new()
	s.kind = a.cast
	s.p = origin
	s.charge = charge
	s.target = target if target != null and target.alive else null
	var aim := dir.normalized()
	if s.target != null:
		aim = (_chest(s.target) - origin).normalized()
	s.damage = a.damage * damage_mult * (1.0 + charge * a.charge_bonus)
	s.knock = a.knockback * (1.0 + charge * 0.5)
	s.launch = a.launch
	s.shake = a.shake * (1.0 + charge * 0.6)
	var ball := s.kind == "ball"
	s.gas = BALL_GAS if ball else BOLT_GAS
	s.head = BALL_HEAD if ball else BOLT_HEAD
	s.phase = randf() * TAU
	if ball:
		s.v = aim * (BALL_SPEED + charge * 3.0)
		s.life = BALL_LIFE
		s.r = BALL_R + charge * 0.15
	else:
		s.v = aim * BOLT_SPEED
		s.life = BOLT_LIFE
		s.r = BOLT_R
	s.anchor = FireGas.Anchor.new()
	s.anchor.p = origin
	s.anchor.v = s.v
	s.anchor.r = float(s.head["r"]) * ((0.8 + 0.5 * charge) if ball else 1.0)
	s.anchor.spin = s.head["spin"]
	s.anchor.retain = s.head["retain"]
	# Cio' che si e' accumulato sulla gemma diventa il corpo del proiettile.
	if _charge != null:
		for g in gas.list:
			if g.m == FireGas.HELD and g.anchor == _charge:
				g.anchor = s.anchor
				g.hold = maxf(g.hold, float(s.head["hold"]) * randf_range(0.55, 1.45))
		_charge = null
	# La testa nasce piena in un fotogramma.
	var n := int(s.head["seed"]) + (int(80 * charge) if ball else 0)
	for i in n:
		gas.held(s.anchor, s.gas, s.head["hold"], s.head["shell"])
	s.light = OmniLight3D.new()
	s.light.light_color = Color(1.0, 0.55, 0.2)
	s.light.light_energy = 1.4 if ball else 0.8
	s.light.omni_range = 3.5 if ball else 2.2
	s.light.shadow_enabled = false
	add_child(s.light)
	s.light.global_position = origin
	shots.append(s)
	# Il cerchio resta acceso ancora un poco, poi si sfalda.
	var Y: Dictionary = BALL_GLYPH if ball else BOLT_GLYPH
	if _glyph == null:
		_glyph = _new_glyph(Y, aim)
	_glyph.prog = 1.0
	_glyph.lvl = 0.55
	_launched.append([_glyph, float(Y["keep"])])
	_glyph = null
	_after = 0.5
	return s


func step(dt: float, targets: Array) -> void:
	blast_age += dt
	for s in shots:
		if s.dead:
			continue
		s.t += dt
		# Un poco di guida verso il bersaglio agganciato.
		if s.target != null and s.target.alive:
			var want := (_chest(s.target) - s.p).normalized()
			var turn := (BOLT_TURN if s.kind == "bolt" else BALL_TURN) * dt
			s.v = s.v.normalized().slerp(want, clampf(turn, 0.0, 1.0)) * s.v.length()
		s.p += s.v * dt
		s.anchor.p = s.p
		s.anchor.v = s.v
		var gt := gas.gate(float(s.gas["D"]), s.phase)
		s.light.global_position = s.p
		s.light.light_energy = (1.4 if s.kind == "ball" else 0.8) * (0.8 + 0.4 * gt)
		# Portata della testa, con lo sfarfallio della sua taglia.
		var rate := float(s.head["rate"]) * ((0.7 + 0.5 * s.charge) if s.kind == "ball" else 1.0)
		s.acc += rate * gt * dt
		while s.acc >= 1.0:
			s.acc -= 1.0
			gas.held(s.anchor, s.gas, s.head["hold"], s.head["shell"])
		var hit: CombatTarget = null
		for o in targets:
			var tg := o as CombatTarget
			if tg != null and tg.alive and CombatController.sphere_capsule(s.p, s.r, tg):
				hit = tg
				break
		if hit != null:
			_hit_shot(s, hit, targets)
		elif _solid(s.p) or s.t >= s.life:
			if s.kind == "ball":
				_explode(s, targets)
			else:
				_fizzle(s)
	for i in range(shots.size() - 1, -1, -1):
		if shots[i].dead:
			_free(shots[i])
			shots.remove_at(i)
	_step_gem(dt)
	_step_glyphs(dt)
	_step_sources(dt)
	_step_burns(dt)
	_step_lights(dt)
	gas.step(dt)


## Braci della gemma: sempre accese col bastone in mano, piu' fitte in
## preparazione (e un poco dopo il lancio).
func _step_gem(dt: float) -> void:
	_after = maxf(0.0, _after - dt)
	if not gem_on:
		if _charge != null:
			_charge.alive = false
			_charge = null
		return
	var rate := 14.0
	if _cast_kind != "":
		rate = 240.0 * (0.22 + 0.78 * clampf(_cast_u, 0.0, 1.0))
	elif _after > 0.0:
		rate = 120.0
	var f := GEM_GAS.duplicate()
	f["floor"] = _floor_at(gem)
	for i in _emit("gem", rate * gas.gate(0.1, 0.0), dt):
		var a := randf() * TAU
		var rr := 0.07 * sqrt(randf())
		gas.ember(gem + Vector3(cos(a) * rr, -0.04 + randf() * 0.06, sin(a) * rr), f, 0.22)
	# Palla in formazione: grani legati all'ancora della gemma, che finita la
	# trattenuta salgono come fiamma sopra il bastone.
	if _charge != null:
		_charge.p = gem
		var k := 0.3 + 0.7 * _cast_cf
		for i in _emit("charge", 520.0 * k * gas.gate(0.62 * k, 0.0), dt):
			gas.held(_charge, CHARGE_GAS, 0.3, BALL_HEAD["shell"])


func _step_glyphs(dt: float) -> void:
	if _glyph != null:
		_glyph.c = _glyph_center(BALL_GLYPH if _cast_kind == "ball" else BOLT_GLYPH)
		_glyph.n = gem_dir
	for i in range(_launched.size() - 1, -1, -1):
		var e: Array = _launched[i]
		var y: FireGas.Glyph = e[0]
		e[1] = float(e[1]) - dt
		if gem_on:
			y.c = gem + y.n * 0.15
		if float(e[1]) <= 0.0:
			gas.glyph_end(y)
			_launched.remove_at(i)


func _hit_shot(s: Shot, tg: CombatTarget, targets: Array) -> void:
	if s.kind == "ball":
		_explode(s, targets)
		return
	var dir := Vector3(s.v.x, 0, s.v.z).normalized()
	tg.take_hit(dir * s.knock + Vector3(0, s.launch, 0), s.damage)
	_burn(tg)
	events.append({"type": "spell_hit", "p": s.p, "damage": s.damage, "shake": s.shake, "target": tg})
	_bloom(s, BOLT_HIT, s.v.normalized())
	s.dead = true


func _explode(s: Shot, targets: Array) -> void:
	var radius := BLAST + BLAST_CHARGE * s.charge
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var c := _chest(tg)
		var d := c.distance_to(s.p) - tg.radius
		if d > radius:
			continue
		var k := clampf(1.0 - maxf(d, 0.0) / radius * 0.5, 0.5, 1.0)
		var dir := Vector3(c.x - s.p.x, 0, c.z - s.p.z)
		dir = dir.normalized() if dir.length() > 0.05 else Vector3(s.v.x, 0, s.v.z).normalized()
		tg.take_hit(dir * s.knock * k + Vector3(0, s.launch * k, 0), s.damage * k)
		_burn(tg)
		events.append({"type": "spell_hit", "p": c, "damage": s.damage * k, "shake": 0.0, "target": tg})
	events.append({"type": "blast", "p": s.p, "shake": s.shake, "radius": radius})
	_bloom(s, BALL_HIT, s.v.normalized())
	blast_age = 0.0
	s.dead = true


## Impatto a fiore (RMNDWN impact "bloom"): l'anello corto e radiale, poi solo
## galleggiamento, cosi' la fiamma si apre a fungo; ejecta che salgono; braci
## che restano accese a terra. La testa si libera dove si trova.
func _bloom(s: Shot, H: Dictionary, axis: Vector3) -> void:
	s.anchor.alive = false
	var big := 1.0 + 0.5 * s.charge
	var f: Dictionary = s.gas.duplicate()
	f["L"] = float(f["L"]) * float(H["len"])
	f["buoy"] = float(f["buoy"]) * float(H["buoy"])
	f["floor"] = _floor_at(s.p)
	var ring := f.duplicate()
	ring["drag"] = 4.0
	var nr := int(int(H["ring"]) * big)
	for i in nr:
		var a := TAU * i / nr + randf() * 0.1
		var d := Vector3(cos(a), 0.15, sin(a))
		gas.puff(s.p + d * 0.1, d * float(H["ring_v"]) * randf_range(0.8, 1.25) * big, ring, float(H["size"]))
	if s.kind == "ball":
		# Il volume della palla si apre: sbuffo radiale, poi sale.
		for i in int(120 + 80 * s.charge):
			var d := FireGas._rand_dir()
			d.y = absf(d.y) * 0.8 + 0.2
			gas.puff(s.p + d * 0.15, d * randf_range(1.0, 3.0) * 2.2 * (0.8 + 0.4 * s.charge), f, float(H["size"]))
	for i in int(H["ejecta"]) * 3:
		var d := (FireGas._rand_dir() - axis * 0.5 + Vector3.UP).normalized()
		gas.puff(s.p, d * randf_range(1.1, 2.6) * big + Vector3(0, 1.5, 0), f, 1.0)
	for i in int(H["res"]):
		var a := randf() * TAU
		var r := float(H["res_r"]) * big * randf_range(0.25, 1.0)
		var q := Vector3(s.p.x + cos(a) * r, s.p.y, s.p.z + sin(a) * r)
		q.y = _floor_at(q) + 0.03
		if q.y < -1e8:
			continue
		_sources.append({"p": q, "t": 0.0, "life": float(H["res_life"]) * randf_range(0.6, 1.2), "key": "res%d" % randi()})
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.omni_range = (BLAST + BLAST_CHARGE * s.charge) * 2.2 if s.kind == "ball" else 2.5
	l.shadow_enabled = false
	add_child(l)
	l.global_position = s.p + Vector3(0, 0.3, 0)
	var e0 := 2.2 if s.kind == "ball" else 1.0
	l.light_energy = e0
	_lights.append({"light": l, "t": 0.0, "life": 0.45 if s.kind == "ball" else 0.2, "e0": e0})


func _fizzle(s: Shot) -> void:
	s.anchor.alive = false
	s.dead = true


## Bruciatura: chi e' preso dal fuoco perde punti per qualche secondo.
func _burn(tg: CombatTarget) -> void:
	burns[tg] = {"t": BURN_TIME, "tick": BURN_TICK}


func _step_burns(dt: float) -> void:
	for tg: CombatTarget in burns.keys():
		var b: Dictionary = burns[tg]
		if not tg.alive:
			burns.erase(tg)
			continue
		b["t"] = float(b["t"]) - dt
		b["tick"] = float(b["tick"]) - dt
		# Fiammelle che salgono dal colpito.
		var f := BURN_GAS.duplicate()
		f["floor"] = tg.position.y
		for i in _emit("burn%d" % tg.get_instance_id(), 90.0 * gas.gate(0.3, 1.0), dt):
			var p := tg.position + Vector3(randf_range(-tg.radius, tg.radius), randf_range(0.1, tg.height * 0.85), randf_range(-tg.radius, tg.radius))
			gas.ember(p, f, 0.3)
		if float(b["tick"]) <= 0.0:
			b["tick"] = BURN_TICK
			tg.take_hit(Vector3.ZERO, BURN_DMG)
			events.append({"type": "burn", "p": _chest(tg), "damage": BURN_DMG, "target": tg})
		if float(b["t"]) <= 0.0:
			burns.erase(tg)


## Braci a terra: ogni tizzone ha la sua fiammella che si spegne piano.
func _step_sources(dt: float) -> void:
	for i in range(_sources.size() - 1, -1, -1):
		var e := _sources[i]
		e["t"] = float(e["t"]) + dt
		var u := float(e["t"]) / float(e["life"])
		if u >= 1.0:
			_acc.erase(e["key"])
			_sources.remove_at(i)
			continue
		var f := EMBER_GAS.duplicate()
		f["floor"] = (e["p"] as Vector3).y - 0.03
		for k in _emit(e["key"], 34.0 * (1.0 - u) * gas.gate(0.12, float(i)), dt):
			gas.ember(e["p"], f, 0.12)


func _step_lights(dt: float) -> void:
	for i in range(_lights.size() - 1, -1, -1):
		var e := _lights[i]
		e["t"] = float(e["t"]) + dt
		var u := float(e["t"]) / float(e["life"])
		var l: OmniLight3D = e["light"]
		if u >= 1.0:
			l.queue_free()
			_lights.remove_at(i)
			continue
		l.light_energy = float(e["e0"]) * (1.0 - u) * (1.0 - u)


## Quanti grani emettere questo passo a `rate` al secondo (accumulatore per chiave).
func _emit(key: String, rate: float, dt: float) -> int:
	var a: float = float(_acc.get(key, 0.0)) + rate * dt
	var n := int(a)
	_acc[key] = a - n
	return n


## Quota del primo blocco pieno sotto `p` (fino a 6 blocchi).
func _floor_at(p: Vector3) -> float:
	if world == null:
		return -1e9
	var x := floori(p.x)
	var z := floori(p.z)
	var y := floori(p.y)
	for k in 7:
		if world.is_solid_at(x, y - k, z):
			return float(y - k + 1)
	return -1e9


func _solid(p: Vector3) -> bool:
	return world != null and world.is_solid_at(floori(p.x), floori(p.y), floori(p.z))


func _free(s: Shot) -> void:
	if s.anchor != null:
		s.anchor.alive = false
	if s.light != null and is_instance_valid(s.light):
		s.light.queue_free()


static func _chest(tg: CombatTarget) -> Vector3:
	return tg.position + Vector3(0, tg.height * 0.55, 0)
