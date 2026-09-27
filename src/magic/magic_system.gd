class_name MagicSystem
extends RefCounted
## Magia del giocatore (M4): regole del prototipo (HTML 7977–8322, inventario §8)
## senza nodi, deterministica con il suo generatore.
##
## - Lancio: nessuna → raccolta → recupero. Costo pagato all'inizio della
##   raccolta (a terra); impegno al 35% di `cast_dur`; rilascio prima
##   dell'impegno dopo 0,2 s = annullato con il 60% del mana; tocco breve =
##   lancio automatico; il dardo parte al 100% (al rilascio o dopo cast_dur + 1,6 s).
## - Mira: bersaglio agganciato al 55% dell'altezza, altrimenti 7 unita' avanti.
## - Dardi balistici (gravita' 18 × grav, attrito), compensazione balistica,
##   collisione con bersagli (4 campioni), voxel (DDA), tronchi. L'aria trapassa.
## - Stati (bruciatura, bagnato, lento, spinto) e `status_react`: fuoco su bagnato
##   = vapore e niente danno; acqua su bruciante = shock termico ×1,25; aria su
##   bagnato = spinta ×1,8.
## - Mondo: fuoco su erba/legno/foglie con automa a tick 0,25 s, bagnato che
##   spegne e impedisce l'accensione, cratere del masso, vento che soffia le braci.
##
## Differenza voluta (D-024): si lancia con la mano sinistra, l'arma resta in pugno.

const MG := 18.0
const MANA_MAX := 100.0
const REGEN := 9.0
const COMMIT := 0.35
const TAP := 0.2
const HOLD_EXTRA := 1.6
const AIM_DIST := 7.0
const LOCK_RANGE := 14.0
const LOCK_CONE := 1.2

const SOFT := {BlockCatalog.DIRT: true, BlockCatalog.GRASS: true, BlockCatalog.SAND: true}
const FLAM := {BlockCatalog.GRASS: .55, BlockCatalog.WOOD: .30, BlockCatalog.LEAVES: .85}
const BURN_LIFE := {BlockCatalog.GRASS: 3.2, BlockCatalog.WOOD: 7.5, BlockCatalog.LEAVES: 2.5}
const BURN_TO := {BlockCatalog.GRASS: BlockCatalog.DIRT, BlockCatalog.WOOD: BlockCatalog.AIR, BlockCatalog.LEAVES: BlockCatalog.AIR}
const FIRE_MAX := 110
const STDEF := {
	"burn": {"dur": 4.0, "tick": .45, "dps": 3.5, "max": 3, "gap": .9, "tag": "BRUCIA"},
	"wet": {"dur": 6.0, "tag": "BAGNATO"},
	"slow": {"dur": 2.5, "tag": "LENTO"},
	"pushed": {"dur": .85, "tag": "SPINTO"},
}

enum Phase { NONE, GATHER, RECOVER }


class Dart:
	extends RefCounted
	var spell: SpellDefinition
	var p := Vector3.ZERO
	var prev := Vector3.ZERO
	var v := Vector3.ZERO
	var t := 0.0
	var hits := {}
	var bounces := 0
	var acc := 0
	var dead := false


class FireCell:
	extends RefCounted
	var cell: Vector3i
	var id := 0
	var t := 0.0
	var life := 1.0
	var gen := 0
	var kids := 0


var world: WorldData
var edits: WorldEditService
var catalog: BlockCatalog
var tree_grid := {}
var spell_index := 0
var mana := MANA_MAX
var phase: Phase = Phase.NONE
var t := 0.0
## Avanzamento della raccolta 0..1.
var w := 0.0
var committed := false
var auto_fire := false
var held := false
var aim := Vector3.ZERO
var face := 0.0
var lock_target: CombatTarget
var darts: Array[Dart] = []
## CombatTarget -> {nome: {t, st, tick, since}}
var statuses := {}
## Vector3i -> FireCell
var fire := {}
## Vector3i -> secondi rimasti
var wet := {}
## Vento dell'ultima spina d'aria: {x, z, dx, dz, t}.
var wind := {}
## Blocchi presi dai crateri (l'inventario arriva in M5).
var crater_items := 0
## Eventi per gli effetti: {type, ...}.
var events: Array[Dictionary] = []
## Hitstop chiesto dai colpi dei dardi (lo consuma il GameRoot).
var hitstop := 0.0
var daylight := 1.0
var rng := RandomNumberGenerator.new()

var _tap := false
var _fire_tick := 0.0
var _fire_edits: Array[WorldEditService.Edit] = []
var _flush_t := 0.0


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


func spell() -> SpellDefinition:
	return SpellDefinition.all()[spell_index]


func select(i: int) -> void:
	spell_index = posmod(i, SpellDefinition.all().size())
	if phase == Phase.GATHER:
		phase = Phase.NONE


func press() -> void:
	_tap = true
	held = true


func release() -> void:
	held = false


func is_casting() -> bool:
	return phase != Phase.NONE


func reset() -> void:
	phase = Phase.NONE
	darts.clear()
	statuses.clear()
	fire.clear()
	wet.clear()
	wind = {}
	_fire_edits.clear()
	mana = MANA_MAX


static func _fwd(f: float) -> Vector3:
	return Vector3(-sin(f), 0, -cos(f))


## Un passo. `facing` e' la direzione del giocatore; `hand` il punto di lancio;
## `can_start` falso se il corpo a corpo e' occupato.
func step(dt: float, motor: PlayerMotor, targets: Array, facing: float, hand: Vector3, can_start: bool = true) -> void:
	var s := spell()
	_targets_cache = targets
	_player_pos = motor.position
	mana = minf(MANA_MAX, mana + REGEN * dt * (1.0 if phase == Phase.NONE else 0.3))
	var tap := _tap
	_tap = false
	match phase:
		Phase.NONE:
			face = facing
			if (held or tap) and motor.on_ground and can_start and not motor.swimming:
				if mana < s.cost:
					if tap:
						events.append({"type": "text", "p": motor.position + Vector3(0, 1.6, 0), "text": "MANA"})
				else:
					phase = Phase.GATHER
					t = 0.0
					w = 0.0
					committed = false
					auto_fire = tap and not held
					mana -= s.cost
					lock_target = _pick_target(motor.position, facing, targets)
					aim = _resolve_aim(motor, facing)
					events.append({"type": "gather", "el": s.el})
		Phase.GATHER:
			t += dt
			w = minf(1.0, t / s.cast_dur)
			if lock_target != null and not lock_target.alive:
				lock_target = null
			aim = _resolve_aim(motor, facing)
			if w >= COMMIT:
				committed = true
			if not held and not auto_fire and not committed:
				if t < TAP:
					auto_fire = true
				else:
					phase = Phase.NONE
					mana = minf(MANA_MAX, mana + s.cost * 0.6)
					events.append({"type": "cancel"})
			elif w >= 1.0 and (not held or auto_fire or t > s.cast_dur + HOLD_EXTRA):
				_release(s, hand, motor)
			var d := aim - motor.position
			if Vector2(d.x, d.z).length() > 0.05:
				face = atan2(-d.x, -d.z)
		Phase.RECOVER:
			t += dt
			if t >= s.recover:
				phase = Phase.NONE
	_step_darts(dt, motor, targets)
	_step_fire(dt, motor, targets)
	_step_status(dt)


func _pick_target(from: Vector3, facing: float, targets: Array) -> CombatTarget:
	var best: CombatTarget = null
	var score := INF
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var v := Vector2(tg.position.x - from.x, tg.position.z - from.z)
		var d := v.length()
		if d > LOCK_RANGE or d < 0.3:
			continue
		var ang := absf(wrapf(atan2(-v.x, -v.y) - facing, -PI, PI))
		if ang > LOCK_CONE:
			continue
		var sc := d + ang * 4.0
		if sc < score:
			score = sc
			best = tg
	return best


func _resolve_aim(motor: PlayerMotor, facing: float) -> Vector3:
	if lock_target != null and lock_target.alive:
		return lock_target.position + Vector3(0, lock_target.height * 0.55, 0)
	return motor.position + _fwd(facing) * AIM_DIST + Vector3(0, 0.55, 0)


func _release(s: SpellDefinition, hand: Vector3, motor: PlayerMotor) -> void:
	var d := aim - hand
	var l := d.length()
	d = d / l if l > 1e-4 else _fwd(face)
	if s.el != "air" and l < 1.2:
		d = _fwd(face)
	var o := hand + d * 0.12
	var dart := Dart.new()
	dart.spell = s
	dart.p = o
	dart.prev = o
	dart.v = d * s.speed
	# Compensazione balistica: il dardo arriva dove si mira.
	if s.grav > 0.0:
		var dist := Vector2(aim.x - o.x, aim.z - o.z).length()
		var tt := dist / s.speed
		dart.v.y += 0.5 * MG * s.grav * tt
	darts.append(dart)
	phase = Phase.RECOVER
	t = 0.0
	events.append({"type": "release", "el": s.el, "p": o, "dir": d})


func _step_darts(dt: float, motor: PlayerMotor, targets: Array) -> void:
	var opaque := catalog.opaque_table() if catalog != null else PackedByteArray()
	var i := darts.size() - 1
	while i >= 0:
		var P := darts[i]
		var S := P.spell
		P.t += dt
		P.prev = P.p
		P.v.y -= MG * S.grav * dt
		if S.drag > 0.0:
			P.v *= exp(-S.drag * dt)
		P.p += P.v * dt
		var seg := P.p - P.prev
		var dist := maxf(seg.length(), 1e-6)
		var dir := seg / dist
		var done := false
		# 1) bersagli: sfera contro cilindro su 4 campioni del segmento.
		var rr := S.r + S.wide * 0.5
		for o in targets:
			var tg := o as CombatTarget
			if tg == null or not tg.alive or P.hits.has(tg):
				continue
			var hit := false
			for k in 4:
				var q := P.prev + seg * (k / 3.0)
				if Vector2(q.x - tg.position.x, q.z - tg.position.z).length() < tg.radius + rr \
						and q.y > tg.position.y - rr and q.y < tg.position.y + tg.height + rr:
					hit = true
					break
			if not hit:
				continue
			P.hits[tg] = true
			_hit_target(P, tg)
			if S.el != "air":
				_impact(P, P.p, -dir, {"kind": "target"})
				done = true
				break
		if done:
			darts.remove_at(i)
			i -= 1
			continue
		# 2) voxel lungo il segmento.
		if world != null:
			var h := VoxelQuery.raycast(world, opaque, P.prev, dir, dist + S.r)
			if h != null:
				var q := P.prev + dir * maxf(0.0, h.distance - S.r * 0.5)
				var n := Vector3(h.normal)
				if S.el == "earth" and P.bounces < 1 and not SOFT.has(h.id) and P.v.length() > 5.0:
					P.bounces += 1
					var vn := P.v.dot(n)
					P.v = (P.v - 2.0 * vn * n) * 0.45
					P.p = q
					events.append({"type": "burst", "el": "earth", "p": q, "n": n, "k": 0.5})
					i -= 1
					continue
				_impact(P, q, n, {"kind": "block", "cell": h.cell, "id": h.id})
				darts.remove_at(i)
				i -= 1
				continue
		# 3) tronchi.
		var tree := _tree_at(P.p, S.r)
		if tree != null:
			var e := Vector3(P.p.x - tree.x, 0, P.p.z - tree.z)
			var el := Vector2(e.x, e.z).normalized() if e.length() > 1e-4 else Vector2(0, 1)
			events.append({"type": "shake_tree", "tree": tree, "dir": -el, "k": 1.0})
			_impact(P, P.p, e.normalized() if e.length() > 1e-4 else Vector3.UP, {"kind": "tree"})
			darts.remove_at(i)
			i -= 1
			continue
		# 4) aria: vento lungo il passaggio, braci soffiate.
		if S.el == "air":
			wind = {"x": P.p.x, "z": P.p.z, "dx": dir.x, "dz": dir.z, "t": 0.7, "pow": 0.30, "r": 1.7}
			if P.acc > 0:
				P.acc -= 1
			else:
				P.acc = 2
				_blow_fire(P.p, 1.4, Vector2(dir.x, dir.z))
				_shake_near(P.p, Vector2(dir.x, dir.z))
		var outside := world != null and not world.inside(floori(P.p.x), floori(P.p.y), floori(P.p.z)) and P.p.y >= 0.0
		if P.t >= S.life or outside or (world != null and P.p.y < 0.0):
			if S.el == "fire" or S.el == "air":
				events.append({"type": "burst", "el": S.el, "p": P.p, "n": dir, "k": 0.45})
			else:
				_impact(P, P.p, Vector3.UP, {"kind": "air"})
			darts.remove_at(i)
		i -= 1


## La spina d'aria scuote gli alberi entro 1,8 dal suo passaggio.
func _shake_near(p: Vector3, d: Vector2) -> void:
	var cx := int(p.x / 8.0)
	var cz := int(p.z / 8.0)
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			for ts: Vegetation.TreeSpot in tree_grid.get(Vector2i(gx, gz), []):
				if not ts.dead and Vector2(ts.x - p.x, ts.z - p.z).length() < 1.8:
					events.append({"type": "shake_tree", "tree": ts, "dir": d.normalized(), "k": 0.5})


func _tree_at(p: Vector3, r: float) -> Vegetation.TreeSpot:
	if tree_grid.is_empty():
		return null
	var cx := int(p.x / 8.0)
	var cz := int(p.z / 8.0)
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			for ts: Vegetation.TreeSpot in tree_grid.get(Vector2i(gx, gz), []):
				if ts.dead:
					continue
				var rr := 0.30 * ts.scale + r
				if Vector2(p.x - ts.x, p.z - ts.z).length() < rr and p.y > ts.y and p.y < ts.y + 4.0 * ts.scale * 0.78:
					return ts
	return null


func _hit_target(P: Dart, tg: CombatTarget) -> void:
	var S := P.spell
	var mul := status_react(tg, S.el)
	var crit := rng.randf() < 0.10
	var amount := S.dmg * rng.randf_range(0.9, 1.1) * (1.5 if crit else 1.0) * mul
	var hv := Vector2(P.v.x, P.v.z)
	var d := hv.normalized() if hv.length() > 1e-4 else Vector2(0, -1)
	var knock := S.knock * (1.8 if S.el == "air" and has_status(tg, "wet") else 1.0)
	tg.take_hit(Vector3(d.x * knock, 1.2, d.y * knock), maxf(amount, 1.0 if mul > 0.0 else 0.0))
	hitstop = maxf(hitstop, 0.03)
	events.append({"type": "hit", "el": S.el, "p": P.p, "target": tg, "damage": amount, "crit": crit})
	if mul > 0.0 and S.status != "":
		apply_status(tg, S.status)
	if S.el == "air":
		wind = {"x": tg.position.x, "z": tg.position.z, "dx": d.x, "dz": d.y, "t": 0.6, "pow": 0.35, "r": 1.8}


func _impact(P: Dart, p: Vector3, n: Vector3, info: Dictionary) -> void:
	var S := P.spell
	var el := S.el
	events.append({"type": "impact", "el": el, "p": p, "n": n})
	# Area: stato e danno ridotto sugli altri bersagli vicini.
	for o in _targets_cache:
		var tg := o as CombatTarget
		if tg == null or not tg.alive or P.hits.has(tg):
			continue
		var dd := Vector2(tg.position.x - p.x, tg.position.z - p.z)
		if dd.length() > S.area + tg.radius:
			continue
		P.hits[tg] = true
		var mul := status_react(tg, el)
		var dn := dd.normalized() if dd.length() > 1e-4 else Vector2.ZERO
		tg.take_hit(Vector3(dn.x, 0.4, dn.y) * S.knock * 0.6, maxf(1.0, S.dmg * 0.35 * mul))
		if mul > 0.0 and S.status != "":
			apply_status(tg, S.status)
	if world == null:
		return
	if info.get("kind") == "tree":
		if el == "fire":
			ignite_around(p, 1)
		return
	var cell: Vector3i = info.get("cell", Vector3i(floori(p.x), floori(p.y), floori(p.z)))
	match el:
		"fire":
			if info.get("kind") == "block" and FLAM.has(int(info.get("id", 0))):
				ignite(cell, true, 0)
			ignite_around(p, 1)
		"water":
			wet_around(p, 1)
			_lava_quench(cell)
		"earth":
			if info.get("kind") == "block" and SOFT.has(int(info.get("id", 0))) and P.v.length() > 4.0:
				_crater(cell, int(info["id"]))
			else:
				events.append({"type": "burst", "el": "earth", "p": p, "n": n, "k": 0.5})
		_:
			wind = {"x": p.x, "z": p.z, "dx": -n.x, "dz": -n.z, "t": 0.5, "pow": 0.4, "r": 2.0}
			_blow_fire(p, 1.6, Vector2(P.v.x, P.v.z))


var _targets_cache: Array = []
var _player_pos := Vector3.ZERO


func _crater(cell: Vector3i, id: int) -> void:
	# Mai sotto i piedi del giocatore.
	var hw := PlayerMotor.RADIUS
	if cell.x + 1 > _player_pos.x - hw and cell.x < _player_pos.x + hw and cell.z + 1 > _player_pos.z - hw \
			and cell.z < _player_pos.z + hw and cell.y >= floori(_player_pos.y) - 1:
		return
	if edits != null:
		var r := edits.set_block(cell, BlockCatalog.AIR, &"crater")
		if not r.ok():
			return
	crater_items += 1
	events.append({"type": "crater", "p": Vector3(cell) + Vector3(0.5, 1.0, 0.5), "id": id})
	events.append({"type": "text", "p": Vector3(cell) + Vector3(0.5, 1.4, 0.5), "text": "CRATERE"})


func _lava_quench(c: Vector3i) -> void:
	var list: Array[WorldEditService.Edit] = []
	for dy in range(-1, 2):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var q := c + Vector3i(dx, dy, dz)
				if world.inside(q.x, q.y, q.z) and world.get_block(q) == BlockCatalog.LAVA:
					list.append(WorldEditService.Edit.new(q, BlockCatalog.DARKSTONE))
					events.append({"type": "steam", "p": Vector3(q) + Vector3(0.5, 1.1, 0.5), "n": 8})
	if not list.is_empty() and edits != null:
		edits.try_apply(list, &"lava_quench")


# ---------------------------------------------------------------- fuoco e bagnato

## Cella solida in superficie sotto (px, pz) (surfaceCell del prototipo).
func surface_cell(px: float, pz: float, y_ref: float) -> Vector3i:
	var x := floori(px)
	var z := floori(pz)
	var gy := VoxelQuery.field_height(world, x + 0.5, z + 0.5, y_ref)
	return Vector3i(x, maxi(0, int(gy) - 1), z)


func ignite(c: Vector3i, force: bool, gen: int) -> bool:
	if world == null or not world.inside(c.x, c.y, c.z):
		return false
	var id := world.get_block(c)
	if not FLAM.has(id):
		return false
	if fire.has(c) or wet.has(c):
		return false
	if fire.size() >= FIRE_MAX and not force:
		return false
	var f := FireCell.new()
	f.cell = c
	f.id = id
	f.life = float(BURN_LIFE[id]) * rng.randf_range(0.8, 1.2)
	f.gen = gen
	fire[c] = f
	return true


func ignite_around(p: Vector3, r: int) -> void:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var c := surface_cell(p.x + dx, p.z + dz, p.y + 1.0)
			var center := dx == 0 and dz == 0
			if rng.randf() < (0.9 if center else 0.5):
				ignite(c, false, 0 if center else 1)


func wet_around(p: Vector3, r: int) -> void:
	var ext := 0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var c := surface_cell(p.x + dx, p.z + dz, p.y + 1.0)
			wet[c] = 45.0
			for dy in range(-1, 3):
				var k := c + Vector3i(0, dy, 0)
				if fire.has(k):
					fire.erase(k)
					events.append({"type": "steam", "p": Vector3(k) + Vector3(0.5, 1.05, 0.5), "n": 6})
					ext += 1
	events.append({"type": "puddle", "p": p, "r": float(r) + 0.6})
	if ext > 0:
		events.append({"type": "text", "p": p + Vector3(0, 0.6, 0), "text": "SPENTO"})


func _blow_fire(p: Vector3, r: float, dir_xz: Vector2) -> void:
	var d := dir_xz.normalized() if dir_xz.length() > 1e-4 else Vector2(1, 0)
	for c: Vector3i in fire.keys():
		var f: FireCell = fire[c]
		if Vector2(c.x + 0.5 - p.x, c.z + 0.5 - p.z).length() > r:
			continue
		if f.id == BlockCatalog.GRASS and rng.randf() < 0.55:
			fire.erase(c)
			events.append({"type": "smoke", "p": Vector3(c) + Vector3(0.5, 1.05, 0.5), "dir": d})
		else:
			f.life += 0.6
			events.append({"type": "embers", "p": Vector3(c) + Vector3(0.5, 1.05, 0.5), "dir": d})
			var nc := c + Vector3i(roundi(d.x), 0, roundi(d.y))
			for dy in range(-1, 2):
				if rng.randf() < 0.35 and ignite(nc + Vector3i(0, dy, 0), false, maxi(0, f.gen - 1)):
					break


func _step_fire(dt: float, _motor: PlayerMotor, targets: Array) -> void:
	if world == null:
		return
	for c: Vector3i in wet.keys():
		var nt: float = float(wet[c]) - dt * (1.0 + daylight * 1.5)
		if nt <= 0.0:
			wet.erase(c)
		else:
			wet[c] = nt
	# Chi sta nel fuoco brucia.
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var b := Vector3i(floori(tg.position.x), floori(tg.position.y), floori(tg.position.z))
		for dy in range(-1, 2):
			if fire.has(b + Vector3i(0, dy, 0)):
				apply_status(tg, "burn")
				break
	_fire_tick += dt
	if _fire_tick >= 0.25:
		_fire_tick -= 0.25
		var wd: Dictionary = wind if not wind.is_empty() and float(wind["t"]) > 0.0 else {}
		for c: Vector3i in fire.keys():
			if not fire.has(c):
				continue
			var f: FireCell = fire[c]
			f.t += 0.25
			if world.get_block(c) != f.id:
				fire.erase(c)
				continue
			if f.t >= f.life:
				fire.erase(c)
				_fire_edits.append(WorldEditService.Edit.new(c, BURN_TO[f.id]))
				events.append({"type": "ash", "p": Vector3(c) + Vector3(0.5, 1.02, 0.5)})
				continue
			if fire.size() >= FIRE_MAX:
				continue
			var max_kids := 2 if f.id == BlockCatalog.GRASS else 3
			if f.kids >= max_kids:
				continue
			var decay := pow(0.78 if f.id == BlockCatalog.GRASS else 0.88, f.gen)
			var nb: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			if f.id != BlockCatalog.GRASS:
				nb.append_array([Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)] as Array[Vector2i])
			for d in nb:
				if f.kids >= max_kids:
					break
				var bias := 0.0
				if not wd.is_empty():
					bias = maxf(0.0, (d.x * float(wd["dx"]) + d.y * float(wd["dz"])) / Vector2(d).length()) * 2.5
				for dy in range(-1, 2):
					var q := c + Vector3i(d.x, dy, d.y)
					if not world.inside(q.x, q.y, q.z):
						continue
					var id := world.get_block(q)
					if not FLAM.has(id):
						continue
					if rng.randf() < float(FLAM[id]) * 0.13 * decay * (1.0 + bias) * (1.3 if f.id == BlockCatalog.WOOD else 1.0):
						if ignite(q, false, f.gen + 1):
							f.kids += 1
					break
			if f.id == BlockCatalog.WOOD:
				for dy in [1, -1]:
					var q := c + Vector3i(0, dy, 0)
					if world.inside(q.x, q.y, q.z) and FLAM.has(world.get_block(q)) and rng.randf() < 0.14 * decay:
						if ignite(q, false, f.gen + 1):
							f.kids += 1
	_flush_t += dt
	if not _fire_edits.is_empty() and (_flush_t >= 0.4 or _fire_edits.size() >= 14):
		if edits != null:
			edits.try_apply(_fire_edits, &"fire")
		else:
			for e in _fire_edits:
				world.blocks[world.index(e.cell.x, e.cell.y, e.cell.z)] = e.id
		_fire_edits = []
		_flush_t = 0.0
	if not wind.is_empty():
		wind["t"] = float(wind["t"]) - dt
		if float(wind["t"]) <= 0.0:
			wind = {}


# ---------------------------------------------------------------- stati

func has_status(tg: CombatTarget, n: String) -> bool:
	return statuses.has(tg) and (statuses[tg] as Dictionary).has(n)


func apply_status(tg: CombatTarget, n: String) -> void:
	if not statuses.has(tg):
		statuses[tg] = {}
	var s: Dictionary = statuses[tg]
	var D: Dictionary = STDEF[n]
	if n == "burn":
		if s.has("burn"):
			var cur: Dictionary = s["burn"]
			cur["t"] = D["dur"]
			if float(cur["since"]) >= float(D["gap"]) and int(cur["st"]) < int(D["max"]):
				cur["st"] = int(cur["st"]) + 1
				cur["since"] = 0.0
		else:
			s["burn"] = {"t": D["dur"], "st": 1, "tick": 0.0, "since": 0.0}
			events.append({"type": "text", "p": tg.position + Vector3(0, tg.height + 0.3, 0), "text": D["tag"]})
	else:
		if not s.has(n):
			events.append({"type": "text", "p": tg.position + Vector3(0, tg.height + 0.3, 0), "text": D["tag"]})
		s[n] = {"t": D["dur"]}


## L'unico punto in cui un elemento sa dell'altro: moltiplicatore del danno.
func status_react(tg: CombatTarget, el: String) -> float:
	if not statuses.has(tg):
		return 1.0
	var s: Dictionary = statuses[tg]
	var head := tg.position + Vector3(0, tg.height * 0.6, 0)
	if el == "fire" and s.has("wet"):
		s.erase("wet")
		events.append({"type": "steam", "p": head, "n": 10})
		events.append({"type": "text", "p": head + Vector3(0, 0.7, 0), "text": "VAPORE"})
		return 0.0
	if el == "water" and s.has("burn"):
		s.erase("burn")
		events.append({"type": "steam", "p": head, "n": 12})
		events.append({"type": "text", "p": head + Vector3(0, 0.7, 0), "text": "SHOCK TERMICO"})
		return 1.25
	return 1.0


func _step_status(dt: float) -> void:
	for tg: CombatTarget in statuses.keys():
		var s: Dictionary = statuses[tg]
		if not tg.alive:
			statuses.erase(tg)
			continue
		for n: String in s.keys():
			var st: Dictionary = s[n]
			var D: Dictionary = STDEF[n]
			st["t"] = float(st["t"]) - dt
			if n == "burn":
				st["since"] = float(st["since"]) + dt
				st["tick"] = float(st["tick"]) + dt
				if float(st["tick"]) >= float(D["tick"]):
					st["tick"] = float(st["tick"]) - float(D["tick"])
					tg.take_hit(Vector3.ZERO, float(D["dps"]) * float(D["tick"]) * int(st["st"]))
			if float(st["t"]) <= 0.0:
				s.erase(n)
		if s.is_empty():
			statuses.erase(tg)


## Etichetta degli stati di un bersaglio (per il riquadro di stato).
func status_tag(tg: CombatTarget) -> String:
	if not statuses.has(tg):
		return ""
	var tags: Array[String] = []
	for n: String in statuses[tg]:
		var st: Dictionary = statuses[tg][n]
		tags.append(String(STDEF[n]["tag"]) + ("×%d" % int(st["st"]) if n == "burn" and int(st["st"]) > 1 else ""))
	return " ".join(tags)
