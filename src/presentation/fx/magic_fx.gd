class_name MagicFx
extends RefCounted
## Effetti della magia con il pool di grani (M4, disegno proprio): raccolta a
## spirale verso la mano sinistra, nucleo e scia dei dardi per elemento,
## esplosioni, vapore, pozze, braci e fumo delle celle che bruciano, fiamme e
## gocce sui bersagli con uno stato.

const FLAME_CELLS := 26

var grains: Grains
var world: WorldData
var _rng := RandomNumberGenerator.new()
var _acc := {}
## Lampi di rilascio e d'impatto per le luci puntiformi: {p, col, r, t, life}.
var _flashes: Array[Dictionary] = []
var _clock := 0.0
const LIGHT := {"fire": Color(1.0, .55, .20, 3.4), "water": Color(.30, .55, .85, 1.5), "karma": Color(.70, .50, 1.0, 2.2)}
const FLASH := {"fire": Vector3(1, .6, .25), "water": Vector3(.35, .6, .95), "air": Vector3(.8, .9, 1), "earth": Vector3(.7, .55, .35), "karma": Vector3(.75, .55, 1)}
## Segni di materia (K122): al massimo 16, fusi se vicini; vita per tipo.
const MARK_MAX := 16
const MARK_LIFE := {"scorch": 12.0, "puddle": 7.5, "crater": 10.0}
var _marks: Array[Dictionary] = []


func _g(p: Vector3, v: Vector3, el: String, mode: int, life: float, size: float, grav: float = 0.0, drag: float = 0.0, t0: float = 1.0) -> Grains.Grain:
	if grains == null:
		return null
	var g := Grains.Grain.new()
	g.p = p
	g.v = v
	g.el = el
	g.mode = mode
	g.life = life
	g.s = size
	g.g = grav
	g.drag = drag
	g.t0 = t0
	return grains.add(g)


## Quanti grani emettere questo frame a `rate` al secondo (accumulatore per chiave).
func _emit(key: String, rate: float, dt: float, cap: int = 12) -> int:
	var a: float = float(_acc.get(key, 0.0)) + rate * dt
	var n := mini(int(a), cap)
	_acc[key] = a - int(a)
	return n


func _r3() -> Vector3:
	return Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))


func update(dt: float, m: MagicSystem, hand: Vector3, player: Vector3) -> void:
	var s := m.spell()
	_clock += dt
	var i0 := _flashes.size() - 1
	while i0 >= 0:
		_flashes[i0]["t"] = float(_flashes[i0]["t"]) + dt
		if float(_flashes[i0]["t"]) >= float(_flashes[i0]["life"]):
			_flashes.remove_at(i0)
		i0 -= 1
	# Raccolta: l'elemento arriva a spirale dalla zona attorno alla mano.
	if m.phase == MagicSystem.Phase.GATHER:
		var n := _emit("gather", 90.0 + 160.0 * m.w, dt)
		for i in n:
			var a := _rng.randf() * TAU
			var rad := _rng.randf_range(0.5, 0.9) * (1.0 - m.w * 0.5)
			var p := hand + Vector3(cos(a) * rad, _rng.randf_range(-0.4, 0.3), sin(a) * rad)
			if s.el == "earth" and world != null:
				p.y = VoxelQuery.field_height(world, p.x, p.z, hand.y) + 0.05
			var to := hand - p
			var tang := Vector3(-to.z, 0, to.x).normalized() * 1.2
			var life := _rng.randf_range(0.18, 0.3)
			var g := _g(p, to / life + tang, s.el, 1 if s.el == "earth" else 0, life, 0.035 if s.el != "air" else 0.022, 0.0, 0.0, 0.8)
			if g != null and s.el == "air":
				g.length = 0.1
		# Cerchio magico ai piedi per le magie del libro, piu' largo con l'Output.
		if not s.is_legacy():
			_circle(dt, s, player, m.w)
		# Massa nel palmo: tre strati che si sommano (nucleo chiaro al centro).
		for i in 3:
			_g(hand + _r3() * 0.05 * (0.5 + m.w), Vector3.ZERO, s.el, 1 if s.el == "earth" else 0, 0.05,
				(0.09 + 0.12 * m.w) * [1.0, 0.7, 0.45][i], 0.0, 0.0, [0.75, 0.9, 1.0][i] * (0.8 + 0.2 * m.w))
	# Dardi.
	for d in m.darts:
		_dart(dt, d)
	# Celle in fiamme: solo le piu' vicine al giocatore fanno fiamme.
	if not m.fire.is_empty():
		var cells: Array = m.fire.keys()
		cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return Vector2(a.x - player.x, a.z - player.z).length_squared() < Vector2(b.x - player.x, b.z - player.z).length_squared())
		for i in mini(cells.size(), FLAME_CELLS):
			var c: Vector3i = cells[i]
			var f: MagicSystem.FireCell = m.fire[c]
			var top := c.y + 1.0
			var n := _emit("f%d" % i, 22.0 if f.id == BlockCatalog.GRASS else 30.0, dt, 8)
			for j in n:
				var g := _g(Vector3(c.x + _rng.randf(), top + 0.03, c.z + _rng.randf()), Vector3(_rng.randf_range(-.25, .25), _rng.randf_range(0.6, 1.3), _rng.randf_range(-.25, .25)),
					"fire", 0, _rng.randf_range(0.3, 0.75), _rng.randf_range(0.04, 0.085), -0.4, 1.2)
				if g != null:
					g.length = _rng.randf_range(0.05, 0.13)
					g.cool = 1.3
			var sm := _emit("s%d" % i, 3.0 if f.id == BlockCatalog.GRASS else 6.0, dt, 3)
			for j in sm:
				_g(Vector3(c.x + 0.5, top + 0.3, c.z + 0.5) + _r3() * 0.3, Vector3(_rng.randf_range(-.2, .2), _rng.randf_range(0.5, 1.0), _rng.randf_range(-.2, .2)), "smoke", 1, _rng.randf_range(0.8, 2.0), 0.05, 0.0, 0.6, 0.5)
	# Stati sui bersagli.
	for tg: CombatTarget in m.statuses:
		var st: Dictionary = m.statuses[tg]
		if st.has("burn"):
			var n := _emit("b%d" % tg.get_instance_id(), 18.0 * int(st["burn"]["st"]), dt, 4)
			for i in n:
				var p := tg.position + Vector3(_rng.randf_range(-1, 1) * tg.radius, _rng.randf_range(0.2, tg.height * 0.9), _rng.randf_range(-1, 1) * tg.radius)
				_g(p, Vector3(_rng.randf_range(-.3, .3), _rng.randf_range(0.6, 1.4), _rng.randf_range(-.3, .3)), "fire", 0, _rng.randf_range(0.3, 0.7), 0.03, 0.0, 1.5, 0.95)
		if st.has("wet"):
			var n := _emit("w%d" % tg.get_instance_id(), 6.0, dt, 2)
			for i in n:
				var p := tg.position + Vector3(_rng.randf_range(-1, 1) * tg.radius, _rng.randf_range(0.3, tg.height * 0.8), _rng.randf_range(-1, 1) * tg.radius)
				var g := _g(p, Vector3(0, -0.2, 0), "water", 1, 0.7, 0.025, MagicSystem.MG * 0.6, 0.0, 0.75)
				if g != null:
					g.ground = true
					g.stick = true
	for e in m.runtime.effects:
		_effect(dt, e, hand)
	for i in range(_marks.size() - 1, -1, -1):
		_marks[i]["t"] = float(_marks[i]["t"]) + dt
		if float(_marks[i]["t"]) >= float(MARK_LIFE[_marks[i]["kind"]]):
			_marks.remove_at(i)
	for e in m.events:
		_event(e)


func _dart(dt: float, d: MagicSystem.Dart) -> void:
	var S := d.spell
	var el := S.el
	var sp := maxf(d.v.length(), 1e-4)
	var dir := d.v / sp
	if el != "earth":
		for i in 3:
			var g := _g(d.p + _r3() * S.r * 0.3, dir, el, 0, 0.06, S.r * [1.7, 1.1, 0.7][i], 0.0, 0.0, 1.0 if i == 2 else 0.85)
			if g != null and el == "air":
				g.length = S.r * 4.0
	else:
		for i in 5:
			var a := d.t * 9.0 + i * 1.26
			_g(d.p + Vector3(cos(a), sin(a * 1.3), sin(a)) * S.r * 0.55, Vector3.ZERO, el, 1, 0.05, S.r * 0.75, 0.0, 0.0, 0.55 + 0.2 * (i % 2))
	match el:
		"fire":
			for i in _emit("pf", 90.0, dt):
				_g(d.p + _r3() * S.r, -dir * 1.5 + _r3() * 1.2 + Vector3(0, 0.8, 0), "fire", 0, _rng.randf_range(0.3, 0.65), 0.025, -0.6, 2.0, 0.9)
			for i in _emit("ps", 18.0, dt):
				_g(d.p + Vector3(0, 0.05, 0), _r3() * 0.3 + Vector3(0, 0.6, 0), "smoke", 1, _rng.randf_range(0.6, 1.2), 0.04, 0.0, 1.0, 0.5)
		"water":
			for i in _emit("pw", 60.0, dt):
				var g := _g(d.p + _r3() * S.r, d.v * 0.15 + _r3() * 0.8, "water", 1, _rng.randf_range(0.4, 1.0), 0.022, MagicSystem.MG, 0.0, 0.75)
				if g != null:
					g.ground = true
					g.stick = true
		"earth":
			for i in _emit("pe", 40.0, dt):
				var g := _g(d.p + _r3() * S.r, Vector3(_rng.randf_range(-.6, .6), -0.2, _rng.randf_range(-.6, .6)), "earth", 1, _rng.randf_range(0.4, 0.9), 0.03, MagicSystem.MG * 0.4, 0.0, 0.5)
				if g != null:
					g.ground = true
		_:
			var perp := Vector3(-dir.z, 0, dir.x)
			for i in _emit("pa", 140.0, dt, 20):
				var g := _g(d.p + perp * _rng.randf_range(-1, 1) * maxf(S.wide, 0.4) + Vector3(0, _rng.randf_range(-.12, .12), 0),
					dir * sp * 0.25 + _r3() * 1.5, "air", 0, _rng.randf_range(0.12, 0.28), 0.016, 0.0, 2.0, 0.8)
				if g != null:
					g.length = 0.26


func burst(el: String, p: Vector3, n: Vector3, k: float = 1.0) -> void:
	var count := int(roundf((22 if el == "earth" else 18 if el == "air" else 26) * k))
	for i in count:
		var v := (n * _rng.randf_range(1.5, 4.5) + _r3() * 3.0)
		var g := _g(p, v, el, 1 if el == "earth" or el == "water" else 0, _rng.randf_range(0.3, 0.7),
			_rng.randf_range(0.03, 0.06), MagicSystem.MG * (0.6 if el == "earth" or el == "water" else 0.1), 1.5, 1.0)
		if g != null:
			g.ground = el == "earth" or el == "water"
			if el == "air":
				g.length = 0.18


func steam(p: Vector3, n: int) -> void:
	for i in n:
		_g(p + Vector3(_rng.randf_range(-.3, .3), 0.05, _rng.randf_range(-.3, .3)), Vector3(_rng.randf_range(-.3, .3), _rng.randf_range(0.6, 1.2), _rng.randf_range(-.3, .3)),
			"steam", 1, _rng.randf_range(0.5, 1.2), 0.045, -0.3, 1.0, 0.8)


## Fino a 6 luci puntiformi (magicRender del prototipo, HTML 8294–8300):
## sfera in mano, dardi, lampi, le 3 celle in fiamme piu' vicine.
func lights(m: MagicSystem, hand: Vector3, player: Vector3) -> Array:
	var out := []
	var s := m.spell()
	if m.phase == MagicSystem.Phase.GATHER and LIGHT.has(s.el):
		var c: Color = LIGHT[s.el]
		var k := 0.35 + 0.65 * m.w + 0.08 * sin(_clock * 23.0)
		out.append([hand, Vector3(c.r, c.g, c.b) * k, c.a * (0.6 + 0.4 * m.w)])
	for d in m.darts:
		if LIGHT.has(d.spell.el):
			var c: Color = LIGHT[d.spell.el]
			out.append([d.p, Vector3(c.r, c.g, c.b), c.a])
	for f in _flashes:
		var k := 1.0 - float(f["t"]) / float(f["life"])
		out.append([f["p"], (f["col"] as Vector3) * k * 1.3, f["r"]])
	if not m.fire.is_empty() and out.size() < 6:
		var cells: Array = m.fire.keys()
		cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return Vector2(a.x - player.x, a.z - player.z).length_squared() < Vector2(b.x - player.x, b.z - player.z).length_squared())
		for i in mini(3, cells.size()):
			if out.size() >= 6:
				break
			var c: Vector3i = cells[i]
			var fl := 0.8 + 0.2 * sin(_clock * 17.0 + c.x * 3.0 + c.z * 5.0)
			out.append([Vector3(c.x + 0.5, c.y + 1.3, c.z + 0.5), Vector3(1.0, 0.55, 0.2) * fl, 3.0])
	return out.slice(0, 6)


func _event(e: Dictionary) -> void:
	match String(e["type"]):
		"beam":
			_beam(e)
		"area":
			_area_start(e)
		"close":
			_close(e)
		"wave":
			_wave(e)
		"burst_ring", "ring":
			_ring(e["el"], e["p"], float(e["r"]))
		"arc":
			_arc(e["from"], e["to"])
		"struct":
			for c: Vector3i in e["cells"]:
				for i in 3:
					var g := _g(Vector3(c) + Vector3(_rng.randf(), _rng.randf(), _rng.randf()), _r3() * 1.2 + Vector3(0, 1.0, 0), "earth", 1,
						_rng.randf_range(0.4, 0.9), _rng.randf_range(0.03, 0.06), MagicSystem.MG * 0.5, 0.5, 0.5)
					if g != null:
						g.ground = true
		"crumble":
			for c: Vector3i in e["cells"]:
				for i in 4:
					var g := _g(Vector3(c) + Vector3(_rng.randf(), _rng.randf(), _rng.randf()), _r3() * 1.6, "earth", 1,
						_rng.randf_range(0.6, 1.4), _rng.randf_range(0.04, 0.08), MagicSystem.MG, 0.3, _rng.randf_range(0.3, 0.6))
					if g != null:
						g.ground = true
						g.stick = true
		"mark":
			_mark(String(e["kind"]), e["p"], float(e["r"]))
		"buff":
			for i in 40:
				var a := _rng.randf() * TAU
				var p: Vector3 = e["p"] + Vector3(cos(a) * 0.6, _rng.randf_range(0.1, 1.7), sin(a) * 0.6)
				var g := _g(p, Vector3(-sin(a), 0.4, cos(a)) * 2.0, "karma", 0, _rng.randf_range(0.3, 0.6), 0.02, 0.0, 1.0, 0.9)
				if g != null:
					g.length = 0.12
		"impact":
			burst(e["el"], e["p"], e["n"], 1.0)
			_flashes.append({"p": e["p"], "col": FLASH[e["el"]], "r": 2.2 if e["el"] == "earth" else 3.2, "t": 0.0, "life": 0.35 if e["el"] == "fire" else 0.22})
		"burst":
			burst(e["el"], e["p"], e["n"], float(e.get("k", 1.0)))
		"release":
			burst(e["el"], e["p"], e["dir"], 0.35)
			_flashes.append({"p": e["p"], "col": FLASH[e["el"]] * 0.9, "r": 1.6, "t": 0.0, "life": 0.12})
		"steam":
			steam(e["p"], int(e.get("n", 8)))
		"puddle":
			var p: Vector3 = e["p"]
			for i in 14:
				var a := _rng.randf() * TAU
				var dd := _rng.randf() * float(e["r"]) * 0.8
				var q := p + Vector3(cos(a) * dd, 0, sin(a) * dd)
				if world != null:
					q.y = VoxelQuery.field_height(world, q.x, q.z, p.y + 1.0) + 0.02
				_g(q, Vector3.ZERO, "water", 1, _rng.randf_range(2.0, 5.0), _rng.randf_range(0.04, 0.09), 0.0, 0.0, 0.35)
		"crater":
			var p: Vector3 = e["p"]
			for i in 18:
				var g := _g(p + Vector3(_rng.randf_range(-.5, .5), 0, _rng.randf_range(-.5, .5)), Vector3(_rng.randf_range(-2.2, 2.2), _rng.randf_range(1.5, 4.5), _rng.randf_range(-2.2, 2.2)),
					"earth", 1, _rng.randf_range(0.5, 1.3), _rng.randf_range(0.03, 0.07), MagicSystem.MG, 0.0, 0.8 if int(e["id"]) == BlockCatalog.SAND else 0.35)
				if g != null:
					g.ground = true
					g.stick = true
		"smoke":
			var d: Vector2 = e["dir"]
			for i in 6:
				_g(e["p"], Vector3(d.x * 2.0, 0.6, d.y * 2.0) + _r3() * 0.5, "smoke", 1, 0.6, 0.04, 0.0, 0.8, 0.5)
		"embers":
			var d: Vector2 = e["dir"]
			for i in 8:
				var g := _g(e["p"], Vector3(d.x * 3.5, _rng.randf_range(0.6, 1.4), d.y * 3.5) + _r3() * 0.8, "fire", 0, _rng.randf_range(0.2, 0.8), 0.024, 0.0, 1.5, 0.9)
				if g != null:
					g.ground = true
		"ash":
			for i in 5:
				_g(e["p"] + Vector3(_rng.randf_range(-.4, .4), 0, _rng.randf_range(-.4, .4)), Vector3(0, 0.1, 0), "fire", 0, _rng.randf_range(1.0, 2.5), 0.02, 0.0, 0.0, 0.55)


# ---------------------------------------------------------------- magie del libro (D-027)

## Cerchio ai piedi durante la raccolta: raggio con l'Output, grani che girano.
func _circle(dt: float, s: SpellDefinition, player: Vector3, w: float) -> void:
	var r := 0.55 + 0.9 * clampf(s.output / 250.0, 0.0, 1.0)
	var y := player.y + 0.04
	if world != null:
		y = VoxelQuery.field_height(world, player.x, player.z, player.y + 0.5) + 0.04
	for i in _emit("circle", 160.0 + 160.0 * w, dt, 16):
		var a := _rng.randf() * TAU
		var rr := r * (1.0 if _rng.randf() < 0.7 else 0.62)
		var g := _g(Vector3(player.x + cos(a) * rr, y, player.z + sin(a) * rr), Vector3(-sin(a), 0, cos(a)) * (0.8 + w),
			s.el, 0, _rng.randf_range(0.25, 0.45), 0.04 + 0.02 * w, 0.0, 0.0, 0.85 + 0.15 * w)
		if g != null:
			g.length = 0.14


func _beam(e: Dictionary) -> void:
	var a: Vector3 = e["from"]
	var b: Vector3 = e["to"]
	var el: String = e["el"]
	var d := b - a
	var l := d.length()
	if l < 0.05:
		return
	var dir := d / l
	var r := maxf(0.03, float(e["r"]))
	var n := mini(120, int(l * 7.0))
	for i in n:
		var u := float(i) / n
		var g := _g(a + d * u + _r3() * r * 0.6, dir * 2.0 + _r3() * 0.4, el, 0, _rng.randf_range(0.12, 0.26), r * 0.9 + 0.012, 0.0, 2.0, 1.0)
		if g != null:
			g.length = 0.22
	burst(el, b, -dir, 0.5)
	_flashes.append({"p": a + dir * 0.4, "col": FLASH.get(el, Vector3.ONE), "r": 2.0, "t": 0.0, "life": 0.12})
	_flashes.append({"p": b, "col": FLASH.get(el, Vector3.ONE), "r": 1.6, "t": 0.0, "life": 0.18})


func _area_start(e: Dictionary) -> void:
	var p: Vector3 = e["p"]
	var r := float(e["r"])
	var el: String = e["el"]
	_ring(el, p, maxf(0.6, r))
	if e["kind"] == "spikes":
		for i in 10:
			var a := _rng.randf() * TAU
			var q := p + Vector3(cos(a), 0, sin(a)) * _rng.randf() * r
			for k in 5:
				var g := _g(q + Vector3(0, k * 0.18, 0), Vector3(0, 2.5, 0), "earth", 1, 0.5, 0.07 - k * 0.01, 0.0, 4.0, 0.4)
				if g != null:
					g.ground = true


## Anello di grani che si allarga a terra (scoppi, faglie del sisma).
func _ring(el: String, p: Vector3, r: float) -> void:
	var n := int(clampf(r * 22.0, 12.0, 70.0))
	for i in n:
		var a := TAU * i / n
		var dir := Vector3(cos(a), 0, sin(a))
		var g := _g(p + dir * r * 0.3 + Vector3(0, 0.08, 0), dir * r * 2.4 + Vector3(0, _rng.randf_range(0.3, 1.2), 0), el,
			1 if el == "earth" or el == "water" else 0, _rng.randf_range(0.3, 0.5), 0.04, MagicSystem.MG * 0.3, 3.0, 0.9)
		if g != null and el == "air":
			g.length = 0.15


func _close(e: Dictionary) -> void:
	var p: Vector3 = e["p"]
	var f: Vector3 = e["dir"]
	var r := float(e["r"])
	var half := 0.14 if e["kind"] == "lash" else (0.95 if e["kind"] == "slash" else 0.66)
	for i in 50:
		var a := _rng.randf_range(-half, half)
		var d := f.rotated(Vector3.UP, a)
		var g := _g(p + d * _rng.randf_range(0.3, 1.0), d * r * _rng.randf_range(2.0, 3.2), "air", 0, _rng.randf_range(0.15, 0.3), 0.016, 0.0, 3.0, 0.9)
		if g != null:
			g.length = 0.3


func _wave(e: Dictionary) -> void:
	var p: Vector3 = e["p"]
	var f: Vector3 = e["dir"]
	var side := Vector3(-f.z, 0, f.x)
	var w := float(e["w"])
	for i in 26:
		var q := p + side * _rng.randf_range(-0.5, 0.5) * w
		if world != null:
			q.y = VoxelQuery.field_height(world, q.x, q.z, q.y + 1.0)
		var g := _g(q + Vector3(0, _rng.randf_range(0.0, float(e["h"])), 0), f * 3.0 + Vector3(0, _rng.randf_range(0.5, 2.0), 0), "water", 1,
			_rng.randf_range(0.3, 0.6), _rng.randf_range(0.03, 0.06), MagicSystem.MG, 0.5, 0.8)
		if g != null:
			g.ground = true


## Arco della conduzione: zig-zag di grani viola.
func _arc(a: Vector3, b: Vector3) -> void:
	var prev := a
	for k in range(1, 9):
		var q := a.lerp(b, k / 8.0) + (_r3() * 0.25 if k < 8 else Vector3.ZERO)
		for i in 5:
			var g := _g(prev.lerp(q, i / 5.0), Vector3.ZERO, "karma", 0, 0.14, 0.03, 0.0, 0.0, 1.0)
			if g != null:
				g.length = 0.08
		prev = q


## Segno di materia (K122): bruciatura, pozza, cratere. Fuso con uno vicino.
func _mark(kind: String, p: Vector3, r: float) -> void:
	for mk in _marks:
		if mk["kind"] == kind and (mk["p"] as Vector3).distance_to(p) < float(mk["r"]) * 0.5:
			mk["t"] = 0.0
			return
	if _marks.size() >= MARK_MAX:
		_marks.pop_front()
	_marks.append({"kind": kind, "p": p, "r": r, "t": 0.0})
	var life: float = MARK_LIFE[kind]
	var n := int(clampf(r * r * 10.0, 10.0, 60.0))
	for i in n:
		var a := _rng.randf() * TAU
		var dd := sqrt(_rng.randf()) * r
		var q := p + Vector3(cos(a) * dd, 0, sin(a) * dd)
		if world != null:
			q.y = VoxelQuery.field_height(world, q.x, q.z, p.y + 1.0)
		q.y += 0.02
		match kind:
			"scorch":
				_g(q, Vector3.ZERO, "smoke", 1, _rng.randf_range(life * 0.6, life), _rng.randf_range(0.06, 0.12), 0.0, 0.0, 0.05)
				if _rng.randf() < 0.2:
					_g(q, Vector3.ZERO, "fire", 0, _rng.randf_range(0.8, 2.5), 0.02, 0.0, 0.0, 0.6)
			"puddle":
				_g(q, Vector3.ZERO, "water", 1, _rng.randf_range(life * 0.6, life), _rng.randf_range(0.06, 0.12), 0.0, 0.0, 0.3)
			_:
				_g(q, Vector3.ZERO, "earth", 1, _rng.randf_range(life * 0.6, life), _rng.randf_range(0.05, 0.1), 0.0, 0.0, 0.08)


## Effetti che durano (getti, colonne, pioggia, cicloni...): grani a ogni frame.
func _effect(dt: float, e: SpellRuntime.Effect, hand: Vector3) -> void:
	var s := e.spell
	var key := "fx%d" % e.get_instance_id()
	var fade := 1.0 - clampf(e.t / maxf(e.dur, 0.01), 0.0, 1.0)
	match s.kind:
		"jet":
			for i in _emit(key, 320.0, dt, 26):
				var d := (e.dir + _r3() * (0.03 + s.width * 0.08)).normalized()
				var g := _g(hand + d * 0.1, d * (s.reach / 0.32) * _rng.randf_range(0.85, 1.05), s.el, 0 if s.el == "fire" else 1,
					_rng.randf_range(0.26, 0.34), 0.04 + s.area * 0.07, MagicSystem.MG * (0.0 if s.el == "fire" else 0.25), 0.0, 1.0)
				if g != null:
					g.length = 0.15
					g.ground = s.el == "water"
		"column":
			for i in _emit(key, 160.0 * fade + 20.0, dt, 16):
				var a := _rng.randf() * TAU
				var q := e.p + Vector3(cos(a), 0, sin(a)) * sqrt(_rng.randf()) * s.area * 0.7
				var g := _g(q, Vector3(0, s.height * _rng.randf_range(1.8, 2.8), 0) + _r3() * 0.4, s.el, 0 if s.el == "fire" else 1,
					_rng.randf_range(0.3, 0.6), _rng.randf_range(0.04, 0.08), MagicSystem.MG * (0.0 if s.el == "fire" else 0.6), 0.6, 1.0)
				if g != null:
					g.length = 0.2
					g.ground = s.el == "water"
		"rain":
			for i in _emit(key, 180.0, dt, 18):
				var a := _rng.randf() * TAU
				var q := e.p + Vector3(cos(a), 0, sin(a)) * sqrt(_rng.randf()) * s.area + Vector3(0, s.height, 0)
				var g := _g(q, Vector3(0, -9.0, 0), "water", 1, 0.8, 0.025, MagicSystem.MG, 0.0, 0.85)
				if g != null:
					g.length = 0.25
					g.ground = true
		"cyclone", "updraft", "vacuum":
			for i in _emit(key, 150.0, dt, 16):
				var a := _rng.randf() * TAU
				var rr := s.area * (1.6 if s.kind == "vacuum" else _rng.randf_range(0.3, 1.0))
				var q := e.p + Vector3(cos(a) * rr, _rng.randf_range(0.0, maxf(0.6, s.height * 0.8 if s.kind != "vacuum" else 0.6)), sin(a) * rr)
				var tan := Vector3(-sin(a), 0, cos(a))
				var v := tan * 5.0 + Vector3(0, 2.5, 0)
				if s.kind == "vacuum":
					v = (e.p - q) * 2.2
				elif s.kind == "updraft":
					v = Vector3(0, 6.0, 0) + tan * 1.2
				var g := _g(q, v, "air", 0, _rng.randf_range(0.25, 0.45), 0.028, 0.0, 0.5, 1.0)
				if g != null:
					g.length = 0.4
		"spray":
			for i in _emit(key, 100.0 * fade, dt, 10):
				var a := _rng.randf() * TAU
				var d := Vector3(cos(a), 0, sin(a))
				var g := _g(hand + d * 0.3, d * s.area * 2.5 + Vector3(0, 0.6, 0), "fire", 0, _rng.randf_range(0.3, 0.55), 0.03, -0.3, 1.0, 1.0)
				if g != null:
					g.ground = true
