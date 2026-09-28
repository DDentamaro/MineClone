class_name SpellRuntime
extends RefCounted
## Forme degli incantesimi del libro (M5, magia ampliata — D-027), dal roster
## RMNDWN K122: raggi con coerenza, getti sostenuti con danno integrato e spinta
## come forza, aree nel punto mirato (colonne, punte, sisma, pioggia, ciclone,
## vuoto, ascensione), onde, colpi d'aria ravvicinati, muri e colonne di terra
## fatti di veri voxel che poi crollano, zone di fango dalle pozze.

const TICK := 0.10
const MUD_MAX := 10
const MUD_DUR := 7.5

## Il proprietario, tenuto debole: MagicSystem tiene questo runtime, e un
## riferimento forte all'indietro sarebbe un ciclo che non si libera mai.
var m: MagicSystem:
	get:
		return _owner.get_ref() as MagicSystem
var _owner: WeakRef


class Effect:
	extends RefCounted
	var spell: SpellDefinition
	var p := Vector3.ZERO
	var dir := Vector3.FORWARD
	## Mano al rilascio e punto mirato (RMNDWN `F.o` e `F.aim`).
	var o := Vector3.ZERO
	var aim := Vector3.ZERO
	var t := 0.0
	var dur := 1.0
	var hit_at := 0.0
	var done := false
	var hits := {}
	var acc := 0.0
	var buf := {}
	var ring := 0


class Struct:
	extends RefCounted
	var spell: SpellDefinition
	var cells: Array[Vector3i] = []
	var t := 0.0
	var dur := 6.0
	## Strati ancora da alzare e il loro istante (il muro sale dal suolo).
	var layers: Array = []
	var times: Array[float] = []
	## La colonna porta su il giocatore.
	var carry := false


var effects: Array[Effect] = []
var structs: Array[Struct] = []
## Zone di fango: {p, r, t, dur}.
var muds: Array[Dictionary] = []


func _init(owner: MagicSystem) -> void:
	_owner = weakref(owner)


func clear() -> void:
	effects.clear()
	for st in structs:
		_crumble(st)
	structs.clear()
	muds.clear()


## Punto a terra sotto la mira (le forme ad area nascono dal suolo).
func ground_at(p: Vector3) -> Vector3:
	if m.world == null:
		return Vector3(p.x, 0, p.z)
	return Vector3(p.x, VoxelQuery.field_height(m.world, p.x, p.z, p.y + 2.0), p.z)


## Sfera contro il corpo (capsula verticale del bersaglio).
static func in_sphere(tg: CombatTarget, c: Vector3, r: float) -> bool:
	var y := clampf(c.y, tg.position.y, tg.position.y + tg.height)
	return Vector3(tg.position.x, y, tg.position.z).distance_to(c) <= r + tg.radius


func cast(s: SpellDefinition, _i: int, hand: Vector3, d: Vector3, motor: PlayerMotor) -> void:
	var flat := Vector3(d.x, 0, d.z).normalized() if Vector2(d.x, d.z).length() > 1e-3 else MagicSystem._fwd(m.face)
	match s.kind:
		"jet":
			_effect(s, hand, d, s.fx_life, 0.0)
		"column", "spikes", "rain", "cyclone", "vacuum", "updraft", "quake":
			# Le forme che nascono dal suolo mirano a terra + 5 cm (RMNDWN L20330).
			var c := ground_at(m.aim) + Vector3(0, 0.05, 0)
			_effect(s, c, flat, s.fx_life, s.hit_at)
			m.events.append({"type": "area", "kind": s.kind, "el": s.el, "p": c, "r": s.area, "h": s.height, "dur": s.fx_life, "spell": s,
				"dir": flat, "at": s.hit_at})
		"wave":
			# La marea parte dai piedi e arriva sulla mira a 5,6 m/s (al massimo 2 s).
			var goal := ground_at(m.aim)
			var start := ground_at(motor.position) + flat * 0.55
			var e := _effect(s, start, flat, s.fx_life, minf(start.distance_to(goal) / s.speed, s.life))
			e.aim = goal
			e.dur = maxf(s.fx_life, e.hit_at + 0.6)
		"lash", "slash", "push":
			# Colpi d'aria a distanza: frusta fino alla mira, taglio e spinta sulla mira.
			var e2 := _effect(s, m.aim if s.kind != "lash" else hand, d, s.fx_life, s.hit_at)
			e2.aim = m.aim
			e2.o = hand
			m.events.append({"type": "air_cast", "kind": s.kind, "el": s.el, "from": hand, "to": m.aim, "dir": d, "spell": s, "at": s.hit_at})
		"spray":
			var e3 := _effect(s, motor.position, flat, s.fx_life, 0.5)
			e3.p = motor.position
			m.events.append({"type": "area", "kind": s.kind, "el": s.el, "p": motor.position, "r": s.area, "h": 1.0, "dur": s.fx_life, "spell": s,
				"dir": flat, "at": 0.5})
		"buff":
			m.apply_status(m.player, s.status)
			m.statuses[m.player][s.status]["t"] = s.fx_life
			m.events.append({"type": "buff", "el": s.el, "p": motor.position, "spell": s})
		"wall":
			# Muraglia al 60% tra la mano e la mira (RMNDWN struct wall at .6).
			var at := hand.lerp(m.aim, 0.6)
			_wall(s, ground_at(Vector3(at.x, motor.position.y, at.z)), flat, motor)
		"pillar":
			_pillar(s, motor)


func _effect(s: SpellDefinition, p: Vector3, d: Vector3, dur: float, hit_at: float) -> Effect:
	var e := Effect.new()
	e.spell = s
	e.p = p
	e.dir = d
	e.o = m.player.position + Vector3(0, 1.0, 0)
	e.aim = m.aim
	e.dur = dur
	e.hit_at = hit_at
	effects.append(e)
	return e


# ---------------------------------------------------------------- colpo al contatto

## elementResolveHit (RMNDWN L20833): un solo evento all'istante del contatto.
## Con un'area: tutti i corpi nella sfera `area` sul punto, danno pieno. La
## frusta: capsula mano → mira, raggio .08, solo il primo corpo.
func resolve(e: Effect, targets: Array) -> void:
	var s := e.spell
	if s.kind == "lash":
		var best: CombatTarget = null
		var best_u := INF
		var seg := e.aim - e.o
		var l2 := maxf(seg.length_squared(), 1e-6)
		for o in targets:
			var tg := o as CombatTarget
			if tg == null or not tg.alive:
				continue
			var c := tg.position + Vector3(0, tg.height * 0.5, 0)
			var u := clampf((c - e.o).dot(seg) / l2, 0.0, 1.0)
			var q := e.o + seg * u
			if in_sphere(tg, q, maxf(0.06, s.r)) and u < best_u:
				best_u = u
				best = tg
		if best != null:
			var dn := Vector2(seg.x, seg.z).normalized()
			m.spell_hit(best, s, s.dmg, dn, e.o + seg * best_u)
		world_touch(s, e.aim, 0.0)
		m.events.append({"type": "contact", "el": s.el, "kind": s.kind, "p": e.aim, "r": 0.3, "spell": s})
		return
	var c := e.p
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive or not in_sphere(tg, c, s.area):
			continue
		var rad := Vector2(tg.position.x - c.x, tg.position.z - c.z)
		var rn := rad.normalized() if rad.length() > 0.05 else Vector2(e.dir.x, e.dir.z).normalized()
		var dn: Vector2
		match s.kind:
			"push", "wave":
				dn = Vector2(e.dir.x, e.dir.z).normalized()
			"vacuum":
				# Knockback negativo verso il centro: la direzione resta radiale.
				dn = rn
			"cyclone":
				dn = (rn + Vector2(-rn.y, rn.x) * 0.48).normalized()
			"updraft":
				dn = Vector2.ZERO
			_:
				var cv := Vector2(tg.position.x - e.o.x, tg.position.z - e.o.z)
				dn = cv.normalized() if cv.length() > 0.05 else rn
		m.spell_hit(tg, s, s.dmg, dn, tg.position + Vector3(0, tg.height * 0.5, 0), 0.0 if s.kind == "updraft" else 1.0)
	world_touch(s, c, s.area)
	m.events.append({"type": "contact", "el": s.el, "kind": s.kind, "p": c, "r": s.area, "spell": s})


# ---------------------------------------------------------------- strutture di terra

## Muro di terra perpendicolare alla direzione, 5 celle × 3 di altezza: veri
## blocchi che fermano corpi, dardi e raggi. Sale dal suolo strato per strato
## in 0,75 s (rise .5 del viaggio di 1,5 s) e crolla a 3,5 s.
func _wall(s: SpellDefinition, c: Vector3, f: Vector3, motor: PlayerMotor) -> void:
	var right := Vector3(-f.z, 0, f.x)
	var half := int(round(s.width * 0.5))
	var hgt := maxi(1, int(round(s.height)))
	var layers: Array = []
	for k in hgt:
		layers.append([] as Array[Vector3i])
	for i in range(-half, half + 1):
		var q := c + right * float(i)
		var gy := int(VoxelQuery.field_height(m.world, q.x, q.z, c.y + 2.0))
		# Angoli in alto arrotondati: |x| <= w/2·(1 − .35·(y/h)^1.7).
		for k in hgt:
			if absf(float(i)) > s.width * 0.5 * (1.0 - 0.35 * pow(float(k + 1) / hgt, 1.7)) + 0.35:
				continue
			(layers[k] as Array[Vector3i]).append(Vector3i(floori(q.x), gy + k, floori(q.z)))
	_rising(s, layers, 0.75, 0.0, false)


## Colonna sotto il giocatore (earth_pillar, support): sale con smoother5 dopo
## 0,11 s in 1,32 s portando su il giocatore, regge 2,8 s poi crolla.
func _pillar(s: SpellDefinition, motor: PlayerMotor) -> void:
	var p := motor.position
	var gy := int(VoxelQuery.field_height(m.world, p.x, p.z, p.y + 0.5))
	var hgt := maxi(1, int(round(s.height)))
	var layers: Array = []
	for k in hgt:
		layers.append([Vector3i(floori(p.x), gy + k, floori(p.z))] as Array[Vector3i])
	_rising(s, layers, 1.32, 0.11, true)


## Struttura che sale: lo strato k compare quando la curva smoother5 del sollevamento
## supera (k + 1)/n.
func _rising(s: SpellDefinition, layers: Array, rise: float, delay: float, carry: bool) -> void:
	var st := Struct.new()
	st.spell = s
	st.dur = s.fx_life
	st.carry = carry
	st.layers = layers
	var n := layers.size()
	for k in n:
		# Inversa di smoother5 per bisezione: istante in cui la quota arriva allo strato.
		var target := float(k + 1) / n
		var lo := 0.0
		var hi := 1.0
		for it in 20:
			var mid := (lo + hi) * 0.5
			if _smoother5(mid) < target:
				lo = mid
			else:
				hi = mid
		st.times.append(delay + rise * hi if k > 0 else delay)
	structs.append(st)
	m.events.append({"type": "rise", "el": "earth", "spell": s, "rise": rise, "delay": delay, "layers": layers})


static func _smoother5(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func _step_struct(st: Struct, motor: PlayerMotor) -> void:
	while not st.layers.is_empty() and st.t >= st.times[0]:
		var cells: Array[Vector3i] = st.layers.pop_front()
		st.times.pop_front()
		var placed := _place(st.spell, cells, motor, st.carry)
		st.cells.append_array(placed)
		if st.carry and not placed.is_empty() and motor != null:
			var top := float(placed[placed.size() - 1].y + 1)
			if motor.position.y < top and Vector2(motor.position.x - (placed[0].x + 0.5), motor.position.z - (placed[0].z + 0.5)).length() < 0.9:
				motor.position.y = top
				motor.velocity.y = maxf(0.0, motor.velocity.y)
				motor.on_ground = true


func _place(s: SpellDefinition, cells: Array[Vector3i], motor: PlayerMotor, allow_player: bool = false) -> Array[Vector3i]:
	var placed: Array[Vector3i] = []
	if m.world == null or m.edits == null:
		return placed
	var list: Array[WorldEditService.Edit] = []
	for c in cells:
		if not m.world.inside(c.x, c.y, c.z) or m.world.get_block(c) != BlockCatalog.AIR:
			continue
		if not allow_player and motor != null and motor.overlaps_cell(c):
			continue
		if _body_in(c):
			continue
		list.append(WorldEditService.Edit.new(c, BlockCatalog.DIRT))
		placed.append(c)
	if list.is_empty() or not m.edits.try_apply(list, &"spell_struct").ok():
		return [] as Array[Vector3i]
	m.events.append({"type": "struct", "el": "earth", "cells": placed, "spell": s})
	return placed


## Un bersaglio occupa la cella (i muri non intrappolano ne' sollevano i corpi).
func _body_in(c: Vector3i) -> bool:
	for o in m._targets_cache:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var nx := clampf(tg.position.x, c.x, c.x + 1.0)
		var nz := clampf(tg.position.z, c.z, c.z + 1.0)
		if Vector2(tg.position.x - nx, tg.position.z - nz).length() < tg.radius and tg.position.y < c.y + 1.0 and tg.position.y + tg.height > c.y:
			return true
	return false


func _crumble(st: Struct) -> void:
	if m.world == null or m.edits == null:
		return
	var list: Array[WorldEditService.Edit] = []
	for c in st.cells:
		if m.world.get_block(c) == BlockCatalog.DIRT:
			list.append(WorldEditService.Edit.new(c, BlockCatalog.AIR))
	if not list.is_empty():
		m.edits.try_apply(list, &"spell_crumble")
	if not st.cells.is_empty():
		var mid := Vector3(st.cells[st.cells.size() / 2]) + Vector3(0.5, 0.5, 0.5)
		m.events.append({"type": "crumble", "p": mid, "cells": st.cells})
		m.events.append({"type": "mark", "kind": "crater", "p": ground_at(mid), "r": 0.9})


## Celle delle strutture ancora in piedi (non vanno salvate: sono di passaggio).
func struct_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for st in structs:
		out.append_array(st.cells)
	return out


# ---------------------------------------------------------------- mondo

## Tocco sul mondo di una magia: fuoco accende, acqua bagna e lascia una pozza
## (fango), terra lascia un cratere, aria soffia. I segni sono quelli di K122.
func world_touch(s: SpellDefinition, p: Vector3, area: float) -> void:
	if m.world == null:
		return
	var g := ground_at(p)
	var near_ground := absf(p.y - g.y) < 1.2
	match s.el:
		"fire":
			m.ignite_around(p, 1)
			if near_ground:
				m.events.append({"type": "mark", "kind": "scorch", "p": g, "r": maxf(0.7, area * 1.5)})
		"water":
			m.wet_around(p, 1)
			if near_ground:
				var r := maxf(0.9, area * 1.6)
				add_mud(g, r)
				m.events.append({"type": "mark", "kind": "puddle", "p": g, "r": r})
		"earth":
			if near_ground:
				m.events.append({"type": "mark", "kind": "crater", "p": g, "r": maxf(0.6, area * 1.6)})
		"air":
			m.wind = {"x": p.x, "z": p.z, "dx": 0.0, "dz": 0.0, "t": 0.5, "pow": 0.4, "r": maxf(2.0, area)}
			m._blow_fire(p, 1.6 + area, Vector2.ZERO)


## Pozza di fango (RMNDWN MUD): chi ci sta dentro si bagna e rallenta.
func add_mud(p: Vector3, r: float) -> void:
	for md in muds:
		if (md["p"] as Vector3).distance_to(p) < float(md["r"]) * 0.5:
			md["t"] = 0.0
			md["r"] = maxf(float(md["r"]), r)
			return
	if muds.size() >= MUD_MAX:
		muds.pop_front()
	muds.append({"p": p, "r": r, "t": 0.0, "dur": MUD_DUR})


# ---------------------------------------------------------------- passo

func step(dt: float, motor: PlayerMotor, targets: Array, hand: Vector3) -> void:
	var i := effects.size() - 1
	while i >= 0:
		var e := effects[i]
		e.t += dt
		_step_effect(e, dt, motor, targets, hand)
		if e.t >= e.dur:
			effects.remove_at(i)
		i -= 1
	var k := structs.size() - 1
	while k >= 0:
		structs[k].t += dt
		_step_struct(structs[k], motor)
		if structs[k].t >= structs[k].dur:
			_crumble(structs[k])
			structs.remove_at(k)
		k -= 1
	var j := muds.size() - 1
	while j >= 0:
		var md := muds[j]
		md["t"] = float(md["t"]) + dt
		if float(md["t"]) >= float(md["dur"]):
			muds.remove_at(j)
		else:
			var all: Array = []
			all.append_array(targets)
			all.append(m.player)
			for o in all:
				var tg := o as CombatTarget
				if tg != null and tg.alive and Vector2(tg.position.x - md["p"].x, tg.position.z - md["p"].z).length() < float(md["r"]) \
						and absf(tg.position.y - md["p"].y) < 1.0:
					m.apply_status(tg, "mud")
					if not m.has_status(tg, "wet"):
						m.apply_status(tg, "wet")
		j -= 1


func _step_effect(e: Effect, dt: float, _motor: PlayerMotor, targets: Array, hand: Vector3) -> void:
	var s := e.spell
	if s.kind == "jet":
		_step_jet(e, dt, targets, hand)
		return
	if not e.done and e.t >= e.hit_at:
		e.done = true
		if s.kind == "spray":
			# Braci (difesa): accendono il suolo attorno, non feriscono.
			world_touch(s, e.p, s.area)
		else:
			resolve(e, targets)
		if s.el == "water" and s.area > 0.0:
			var r := maxf(0.9, s.area * 1.6)
			add_mud(e.p if s.kind != "wave" else e.aim, r)
	# Aspetto che continua dopo il contatto: vento sull'erba e sulle braci.
	match s.kind:
		"cyclone", "updraft", "vacuum":
			m.wind = {"x": e.p.x, "z": e.p.z, "dx": 0.0, "dz": 0.0, "t": 0.3, "pow": -0.35 if s.kind == "vacuum" else 0.45, "r": maxf(0.8, s.area * 1.5)}
			if s.kind == "cyclone":
				m._blow_fire(e.p, s.area * 1.4, Vector2.ZERO)
		"rain":
			e.acc += dt
			if e.acc >= 0.5 and e.t < s.emit:
				e.acc = 0.0
				m.wet_around(e.p, int(maxf(1.0, s.area * 0.6)))
		"wave":
			e.acc += dt
			if e.acc >= 0.2 and e.t <= e.hit_at + 0.2:
				e.acc = 0.0
				var u := clampf(e.t / maxf(e.hit_at, 0.05), 0.0, 1.0)
				var fp := e.p.lerp(e.aim, u)
				m.wet_around(fp, 1)
				m.events.append({"type": "wave", "el": s.el, "p": fp, "dir": e.dir, "w": s.width, "h": s.height})


## Getto sostenuto (SUSTAIN_TUNE + VOLSPEC.jet, RMNDWN L20905–L21130): cono
## dalla mano lungo la mira, raggio r0 → r1 fino a `reach`; ferisce solo mentre
## emette (0,08 s → `emit`). Danno e stagger si accumulano (dps·dt) e si
## scaricano ogni 0,1 s, quindi non dipendono dal frame rate; la spinta e' una
## accelerazione continua (m/s²) con velocita' massima; stati a ogni tick.
func _step_jet(e: Effect, dt: float, targets: Array, hand: Vector3) -> void:
	var s := e.spell
	var f := MagicSystem._fwd(m.face)
	e.p = hand
	e.dir = (f + Vector3(0, -0.06, 0)).normalized()
	if e.t < 0.08 or e.t > s.emit:
		return
	var reach := s.reach
	if m.world != null and m.catalog != null:
		var h := VoxelQuery.raycast(m.world, m.catalog.opaque_table(), hand, e.dir, reach)
		if h != null:
			reach = h.distance
			e.acc += dt
			if e.acc >= 0.3:
				e.acc = 0.0
				world_touch(s, hand + e.dir * reach, 0.4)
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var c := tg.position + Vector3(0, tg.height * 0.5, 0)
		var along := (c - hand).dot(e.dir)
		if along < 0.0 or along > reach:
			continue
		var q := hand + e.dir * along
		var rad := lerpf(s.r0, s.r1, along / maxf(s.reach, 1e-3))
		if not in_sphere(tg, q, rad):
			continue
		e.buf[tg] = float(e.buf.get(tg, 0.0)) + s.dps * dt
		if s.push > 0.0:
			tg.push(Vector3(e.dir.x, 0, e.dir.z) * s.push * dt, 3.8 if s.id == &"water_hydrant" else 4.2)
		var key := "tick_%d" % tg.get_instance_id()
		e.buf[key] = float(e.buf.get(key, 0.0)) + dt
		if float(e.buf[key]) >= TICK:
			var span := float(e.buf[key])
			e.buf[key] = 0.0
			var amount := float(e.buf[tg])
			e.buf[tg] = 0.0
			m.spell_hit(tg, s, amount, Vector2(e.dir.x, e.dir.z), q, 0.0, 0.0, true, s.poise * span)
			if s.id == &"water_hydrant":
				m.apply_status(tg, "slow")
			if s.push >= 12.0:
				m.apply_status(tg, "pushed")
