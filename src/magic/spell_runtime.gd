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


func cast(s: SpellDefinition, _i: int, hand: Vector3, d: Vector3, motor: PlayerMotor) -> void:
	var flat := Vector3(d.x, 0, d.z).normalized() if Vector2(d.x, d.z).length() > 1e-3 else MagicSystem._fwd(m.face)
	match s.kind:
		"beam":
			beam(s, hand, d)
		"jet":
			_effect(s, hand, d, s.fx_life, 0.0)
		"column", "spikes", "rain", "cyclone", "vacuum", "updraft", "quake":
			var c := ground_at(m.aim)
			var ha := minf(0.72, s.fx_life * 0.38) if s.kind != "quake" else 0.0
			_effect(s, c, flat, s.fx_life, ha)
			m.events.append({"type": "area", "kind": s.kind, "el": s.el, "p": c, "r": s.area, "h": s.height, "dur": s.fx_life, "spell": s})
		"wave":
			var e := _effect(s, ground_at(motor.position) + flat * 0.8, flat, s.life, 0.0)
			e.dur = s.life
		"lash", "slash", "push":
			_close(s, motor, flat)
		"spray":
			var e2 := _effect(s, motor.position, flat, s.fx_life, minf(0.72, s.fx_life * 0.38))
			e2.p = motor.position
			m.events.append({"type": "area", "kind": s.kind, "el": s.el, "p": motor.position, "r": s.area, "h": 1.0, "dur": s.fx_life, "spell": s})
		"buff":
			m.apply_status(m.player, s.status)
			m.statuses[m.player][s.status]["t"] = s.fx_life
			m.events.append({"type": "buff", "el": s.el, "p": motor.position, "spell": s})
		"wall":
			# Tra il caster e la mira, a non piu' di 3 unita': una difesa, non una trappola.
			var dist := clampf(Vector2(m.aim.x - motor.position.x, m.aim.z - motor.position.z).length() - 1.2, 1.6, 3.0)
			_wall(s, ground_at(motor.position + flat * dist), flat, motor)
		"pillar":
			_pillar(s, motor)


func _effect(s: SpellDefinition, p: Vector3, d: Vector3, dur: float, hit_at: float) -> Effect:
	var e := Effect.new()
	e.spell = s
	e.p = p
	e.dir = d
	e.dur = dur
	e.hit_at = hit_at
	effects.append(e)
	return e


# ---------------------------------------------------------------- raggi

## Raggio (famiglia "raggio" del Karma): esiste tutto in un istante lungo la
## traiettoria, trapassa i corpi, si ferma sul primo blocco; il danno scala con
## la coerenza alla distanza (t = distanza / velocita').
func beam(s: SpellDefinition, from: Vector3, d: Vector3) -> Dictionary:
	var length := s.speed * s.life
	var stop := length
	if m.world != null and m.catalog != null:
		var h := VoxelQuery.raycast(m.world, m.catalog.opaque_table(), from, d, length)
		if h != null:
			stop = h.distance
	var hit_list := []
	for o in m._targets_cache:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var c := tg.position + Vector3(0, tg.height * 0.5, 0)
		var along := (c - from).dot(d)
		if along < 0.0 or along > stop + tg.radius:
			continue
		var q := from + d * along
		var coh := MagicSystem.coherence(s, along / maxf(s.speed, 1e-3))
		var rad := s.r * (1.0 + s.scatter * (1.0 - exp(-s.decoh * along / maxf(s.speed, 1e-3))))
		# Cilindro del bersaglio contro il raggio: distanza orizzontale e quota.
		if Vector2(q.x - tg.position.x, q.z - tg.position.z).length() > tg.radius + rad:
			continue
		if q.y < tg.position.y - rad or q.y > tg.position.y + tg.height + rad:
			continue
		m.spell_hit(tg, s, s.dmg * coh, Vector2(d.x, d.z).normalized(), q)
		hit_list.append(tg)
	var end := from + d * stop
	m.events.append({"type": "beam", "el": s.el, "from": from, "to": end, "r": s.r, "spell": s})
	if stop < length:
		world_touch(s, end, 0.5)
	return {"hits": hit_list, "end": end}


# ---------------------------------------------------------------- colpi d'aria ravvicinati

func _close(s: SpellDefinition, motor: PlayerMotor, f: Vector3) -> void:
	var from := motor.position
	var reach := 4.5 if s.kind == "lash" else (3.4 if s.kind == "slash" else 5.0)
	var half := deg_to_rad(8.0 if s.kind == "lash" else (55.0 if s.kind == "slash" else 38.0))
	for o in m._targets_cache:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var v := Vector3(tg.position.x - from.x, 0, tg.position.z - from.z)
		var dist := v.length()
		if dist > reach + tg.radius or absf(tg.position.y - from.y) > 2.0:
			continue
		var ang := absf(Vector2(f.x, f.z).angle_to(Vector2(v.x, v.z))) if dist > 0.05 else 0.0
		if ang > half + atan2(tg.radius, maxf(dist, 0.1)):
			continue
		var dn := Vector2(v.x, v.z).normalized() if dist > 0.05 else Vector2(f.x, f.z)
		m.spell_hit(tg, s, s.dmg, dn, tg.position + Vector3(0, tg.height * 0.6, 0))
		if s.kind == "push":
			m.apply_status(tg, "pushed")
	m.events.append({"type": "close", "kind": s.kind, "el": s.el, "p": from + Vector3(0, 1.0, 0), "dir": f, "r": reach, "spell": s})
	m.wind = {"x": from.x + f.x * 2.0, "z": from.z + f.z * 2.0, "dx": f.x, "dz": f.z, "t": 0.6, "pow": 0.4, "r": reach * 0.6}
	m._blow_fire(from + f * reach * 0.5, reach * 0.5, Vector2(f.x, f.z))


# ---------------------------------------------------------------- strutture di terra

## Muro di terra perpendicolare alla direzione, 5 celle × 3 di altezza: veri
## blocchi che fermano corpi, dardi e raggi, e crollano dopo `fx_life`.
func _wall(s: SpellDefinition, c: Vector3, f: Vector3, motor: PlayerMotor) -> void:
	var right := Vector3(-f.z, 0, f.x)
	var cells: Array[Vector3i] = []
	var half := int(round(s.width * 0.5))
	var hgt := maxi(1, int(round(s.height)))
	for i in range(-half, half + 1):
		var q := c + right * float(i)
		var gy := int(VoxelQuery.field_height(m.world, q.x, q.z, c.y + 2.0))
		for k in hgt:
			cells.append(Vector3i(floori(q.x), gy + k, floori(q.z)))
	_raise(s, cells, motor)


## Colonna sotto il giocatore (earth_pillar, support): lo solleva di 3 blocchi.
func _pillar(s: SpellDefinition, motor: PlayerMotor) -> void:
	var p := motor.position
	var gy := int(VoxelQuery.field_height(m.world, p.x, p.z, p.y + 0.5))
	var hgt := maxi(1, int(round(s.height)))
	var cells: Array[Vector3i] = []
	for k in hgt:
		cells.append(Vector3i(floori(p.x), gy + k, floori(p.z)))
	var st := _raise(s, cells, motor, true)
	if st != null and not st.cells.is_empty():
		motor.position.y = float(gy + st.cells.size())
		motor.velocity = Vector3.ZERO
		motor.on_ground = true


func _raise(s: SpellDefinition, cells: Array[Vector3i], motor: PlayerMotor, allow_player: bool = false) -> Struct:
	if m.world == null or m.edits == null:
		return null
	var list: Array[WorldEditService.Edit] = []
	var placed: Array[Vector3i] = []
	for c in cells:
		if not m.world.inside(c.x, c.y, c.z) or m.world.get_block(c) != BlockCatalog.AIR:
			continue
		if not allow_player and motor.overlaps_cell(c):
			continue
		if _body_in(c):
			continue
		list.append(WorldEditService.Edit.new(c, BlockCatalog.DIRT))
		placed.append(c)
	if list.is_empty():
		return null
	if not m.edits.try_apply(list, &"spell_struct").ok():
		return null
	var st := Struct.new()
	st.spell = s
	st.cells = placed
	st.dur = s.fx_life
	structs.append(st)
	m.events.append({"type": "struct", "el": "earth", "cells": placed, "spell": s})
	return st


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


func _step_effect(e: Effect, dt: float, motor: PlayerMotor, targets: Array, hand: Vector3) -> void:
	var s := e.spell
	match s.kind:
		"jet":
			_step_jet(e, dt, motor, targets, hand)
		"column", "spikes", "spray":
			if not e.done and e.t >= e.hit_at:
				e.done = true
				var c := motor.position if s.kind == "spray" else e.p
				for o in targets:
					var tg := o as CombatTarget
					if tg == null or not tg.alive:
						continue
					var v := Vector2(tg.position.x - c.x, tg.position.z - c.z)
					if v.length() > s.area + tg.radius or absf(tg.position.y - c.y) > maxf(2.0, s.height):
						continue
					var dn := v.normalized() if v.length() > 0.05 else Vector2(e.dir.x, e.dir.z)
					var lift := 9.0 if s.id == &"water_geyser" else (5.0 if s.kind == "spikes" else -1.0)
					m.spell_hit(tg, s, s.dmg, dn, tg.position + Vector3(0, 0.5, 0), 1.0, lift)
				world_touch(s, c, s.area)
		"quake":
			# Quattro anelli di faglia che si allargano ogni 0,25 s.
			var rings := 4
			while e.ring < rings and e.t >= e.ring * 0.25:
				var r0 := 0.95 + 0.95 * e.ring
				for o in targets:
					var tg := o as CombatTarget
					if tg == null or not tg.alive or e.hits.has(tg):
						continue
					var v := Vector2(tg.position.x - e.p.x, tg.position.z - e.p.z)
					if v.length() <= r0 + tg.radius and absf(tg.position.y - e.p.y) < 2.0:
						e.hits[tg] = true
						m.spell_hit(tg, s, s.dmg, v.normalized() if v.length() > 0.05 else Vector2(0, -1), tg.position, 1.0, 4.0)
				m.events.append({"type": "ring", "el": "earth", "p": e.p, "r": r0})
				m.events.append({"type": "mark", "kind": "crater", "p": e.p + Vector3(e.dir.x, 0, e.dir.z) * r0 * 0.5, "r": 0.8})
				e.ring += 1
		"rain":
			e.acc += dt
			while e.acc >= 0.25:
				e.acc -= 0.25
				var per := s.dmg * 0.25 / maxf(s.fx_life, 0.25)
				_area_tick(e, targets, per, 0.15)
				m.wet_around(e.p, int(maxf(1.0, s.area * 0.6)))
			if not e.done and e.t > 0.4:
				e.done = true
				add_mud(e.p, s.area)
				m.events.append({"type": "mark", "kind": "puddle", "p": e.p, "r": s.area})
		"cyclone":
			e.acc += dt
			while e.acc >= 0.25:
				e.acc -= 0.25
				_area_tick(e, targets, s.dmg * 0.25 / maxf(s.fx_life, 0.25), 0.1)
			for o in targets:
				var tg := o as CombatTarget
				if tg == null or not tg.alive:
					continue
				var v := Vector3(tg.position.x - e.p.x, 0, tg.position.z - e.p.z)
				if v.length() > s.area * 1.6 or absf(tg.position.y - e.p.y) > s.height:
					continue
				var rad := v.normalized() if v.length() > 0.05 else e.dir
				var tan := Vector3(-rad.z, 0, rad.x)
				tg.push((rad * 0.52 + tan * 0.48) * s.knock * MagicSystem.KNOCK_SCALE * 1.4 * dt + Vector3(0, 6.0 * dt, 0), 5.0)
			m.wind = {"x": e.p.x, "z": e.p.z, "dx": 0.0, "dz": 0.0, "t": 0.3, "pow": 0.45, "r": s.area * 1.5}
			m._blow_fire(e.p, s.area * 1.4, Vector2.ZERO)
		"vacuum":
			for o in targets:
				var tg := o as CombatTarget
				if tg == null or not tg.alive:
					continue
				var v := Vector3(e.p.x - tg.position.x, 0, e.p.z - tg.position.z)
				if v.length() > s.area * 2.5 or v.length() < 0.25:
					continue
				tg.push(v.normalized() * absf(s.knock) * MagicSystem.KNOCK_SCALE * 1.6 * dt, 4.5)
				if not e.hits.has(tg):
					e.hits[tg] = true
					m.apply_status(tg, "pushed")
			m.wind = {"x": e.p.x, "z": e.p.z, "dx": 0.0, "dz": 0.0, "t": 0.3, "pow": -0.35, "r": s.area * 2.0}
		"updraft":
			for o in targets:
				var tg := o as CombatTarget
				if tg == null or not tg.alive:
					continue
				if Vector2(tg.position.x - e.p.x, tg.position.z - e.p.z).length() > s.area + tg.radius:
					continue
				if tg.position.y < e.p.y + s.height:
					tg.push(Vector3(0, 30.0 * dt, 0), 2.0)
				if not e.hits.has(tg) and e.t >= e.hit_at:
					e.hits[tg] = true
					m.apply_status(tg, "pushed")
		"wave":
			var front := s.speed * e.t
			for o in targets:
				var tg := o as CombatTarget
				if tg == null or not tg.alive or e.hits.has(tg):
					continue
				var v := Vector3(tg.position.x - e.p.x, 0, tg.position.z - e.p.z)
				var along := v.dot(e.dir)
				var side := absf(v.dot(Vector3(-e.dir.z, 0, e.dir.x)))
				if along <= front + tg.radius and along >= front - 1.0 and side <= s.width * 0.5 + tg.radius and absf(tg.position.y - e.p.y) < 1.8:
					e.hits[tg] = true
					m.spell_hit(tg, s, s.dmg, Vector2(e.dir.x, e.dir.z), tg.position + Vector3(0, 0.5, 0))
			e.acc += dt
			if e.acc >= 0.2:
				e.acc = 0.0
				var fp := e.p + e.dir * front
				m.wet_around(fp, 1)
				m.events.append({"type": "wave", "el": s.el, "p": fp, "dir": e.dir, "w": s.width, "h": s.height})


func _area_tick(e: Effect, targets: Array, dmg: float, knock_mul: float) -> void:
	var s := e.spell
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var v := Vector2(tg.position.x - e.p.x, tg.position.z - e.p.z)
		if v.length() > s.area + tg.radius or absf(tg.position.y - e.p.y) > maxf(2.0, s.height):
			continue
		m.spell_hit(tg, s, dmg, v.normalized() if v.length() > 0.05 else Vector2(0, -1), tg.position, knock_mul, 0.2, true)


## Getto sostenuto (SUSTAIN_TUNE): il danno si accumula in un buffer (dps·dt)
## e si scarica ogni 0,1 s, quindi non dipende dal frame rate; la spinta e' una
## forza continua con velocita' massima. La direzione segue lo sguardo.
func _step_jet(e: Effect, dt: float, motor: PlayerMotor, targets: Array, hand: Vector3) -> void:
	var s := e.spell
	var f := MagicSystem._fwd(m.face)
	e.p = hand
	e.dir = (f + Vector3(0, -0.06, 0)).normalized()
	var reach := s.reach
	if m.world != null and m.catalog != null:
		var h := VoxelQuery.raycast(m.world, m.catalog.opaque_table(), hand, e.dir, reach)
		if h != null:
			reach = h.distance
			e.acc += dt
			if e.acc >= 0.3:
				e.acc = 0.0
				world_touch(s, hand + e.dir * reach, 0.4)
	var r0 := maxf(0.08, s.width * 0.5)
	var r1 := maxf(r0, s.area)
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var c := tg.position + Vector3(0, tg.height * 0.5, 0)
		var along := (c - hand).dot(e.dir)
		if along < 0.0 or along > reach:
			continue
		var q := hand + e.dir * along
		var rad := lerpf(r0, r1, along / maxf(reach, 1e-3))
		if Vector2(q.x - tg.position.x, q.z - tg.position.z).length() > rad + tg.radius or q.y < tg.position.y - 0.3 or q.y > tg.position.y + tg.height + 0.3:
			continue
		e.buf[tg] = float(e.buf.get(tg, 0.0)) + s.dps * dt
		if s.push > 0.0:
			tg.push(Vector3(e.dir.x, 0, e.dir.z) * s.push * dt * 0.5, 4.8)
		var key := "tick_%d" % tg.get_instance_id()
		e.buf[key] = float(e.buf.get(key, 0.0)) + dt
		if float(e.buf[key]) >= TICK:
			e.buf[key] = 0.0
			var amount := float(e.buf[tg])
			e.buf[tg] = 0.0
			m.spell_hit(tg, s, amount, Vector2(e.dir.x, e.dir.z), q, 0.0, 0.0, true)
			if s.id == &"water_hydrant":
				m.apply_status(tg, "slow")
