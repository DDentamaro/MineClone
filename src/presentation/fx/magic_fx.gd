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
		# Massa nel palmo.
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


func _event(e: Dictionary) -> void:
	match String(e["type"]):
		"impact":
			burst(e["el"], e["p"], e["n"], 1.0)
		"burst":
			burst(e["el"], e["p"], e["n"], float(e.get("k", 1.0)))
		"release":
			burst(e["el"], e["p"], e["dir"], 0.35)
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
