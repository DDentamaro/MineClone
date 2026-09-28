class_name MagicFx
extends RefCounted
## Effetti della magia con il pool di grani. Magie del libro come RMNDWN K122
## (D-031): nessun cerchio a terra, nessuna luce puntiforme, nessun lampo di
## rilascio; il segno del lancio e' il glifo davanti al palmo (figura per
## elemento disegnata dal 6% al 72% della raccolta, carica a spirale e massa al
## centro, sfaldamento alla fine); il Karma e' una testa che viaggia con il
## colore della coerenza (raggio acceso dal glifo alla testa, fascio, sfera) e
## si spegne verso il punto d'arrivo; la fiamma ha il colore di corpo nero;
## all'impatto la firma dell'elemento (braci, gocce, anello, zolle). I dardi del
## prototipo IsoTerra (gate R) tengono la raccolta a spirale di allora.

const FLAME_CELLS := 26
## Lato minimo dei grani del libro: il render target di RMNDWN e' alto 424 px
## e i suoi grani da 1 cm sono gia' un pixel; qui la vista e' piu' larga.
const GRAIN_MIN := 0.022

var grains: Grains
var world: WorldData
var _rng := RandomNumberGenerator.new()
var _acc := {}
var _clock := 0.0
var _spin := 0.0
## Segni di materia (K122): al massimo 16, fusi se vicini; vita per tipo.
const MARK_MAX := 16
const MARK_LIFE := {"scorch": 12.0, "puddle": 7.5, "crater": 10.0}
var _marks: Array[Dictionary] = []
## Rotazione della figura del glifo per elemento (spin × elemento).
const GLYPH_SPIN := {"fire": 1.0, "water": 0.62, "air": 1.45, "earth": 0.42, "karma": 0.52}
## Impatto del Karma per magia: [tagli, durata, anello da, anello a, ejecta, taglio].
const KARMA_HIT := {"ago": [1, .30, .05, .38, 4, .38], "zoltraak": [3, .42, .10, .90, 5, .62], "dardo": [3, .44, .10, .85, 9, .48],
	"tridente": [2, .42, .08, .70, 8, .46], "spina": [3, .46, .09, .86, 11, .84], "orbe": [0, .56, .14, 1.60, 20, 0.0],
	"giudizio": [6, .66, .16, 1.55, 18, 1.30], "nova": [0, .66, .18, 2.60, 24, 0.0]}


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
## Il tetto per frame vale a 60 FPS e cresce col passo, cosi' a pochi FPS il
## flusso al secondo resta quello voluto.
func _emit(key: String, rate: float, dt: float, cap: int = 12) -> int:
	var a: float = float(_acc.get(key, 0.0)) + rate * dt
	var n := mini(int(a), int(cap * maxf(1.0, dt * 60.0)))
	_acc[key] = a - int(a)
	return n


func _r3() -> Vector3:
	return Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))


## Direzione a caso nella sfera unitaria (volume).
func _ball() -> Vector3:
	var v := _r3()
	while v.length_squared() > 1.0:
		v = _r3()
	return v


static func _sm5(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func update(dt: float, m: MagicSystem, hand: Vector3, player: Vector3) -> void:
	var s := m.spell()
	_clock += dt
	# Raccolta dei dardi del prototipo: l'elemento arriva a spirale sulla mano.
	if m.phase == MagicSystem.Phase.GATHER and s.is_legacy():
		_legacy_gather(dt, s, hand, m.w)
	# Glifo delle magie del libro (resta per il recupero e gli effetti sostenuti).
	var cs := m.cast_spell if m.cast_spell != null else s
	if not cs.is_legacy() and m.arm_w > 0.0 and m.glyph > 0.0 and m.glyph_shed < 1.0:
		_glyph(dt, m, cs, hand)
	for d in m.darts:
		if d.spell.is_legacy():
			_dart(dt, d)
		else:
			_book_dart(dt, d)
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
	for tg: CombatTarget in m.statuses:
		_status_fx(dt, tg, m.statuses[tg])
	for e in m.runtime.effects:
		_effect(dt, e, hand)
	for i in range(_marks.size() - 1, -1, -1):
		_marks[i]["t"] = float(_marks[i]["t"]) + dt
		if float(_marks[i]["t"]) >= float(MARK_LIFE[_marks[i]["kind"]]):
			_marks.remove_at(i)
	for e in m.events:
		_event(e, hand)


# ---------------------------------------------------------------- dardi del prototipo

func _legacy_gather(dt: float, s: SpellDefinition, hand: Vector3, w: float) -> void:
	var n := _emit("gather", 90.0 + 160.0 * w, dt)
	for i in n:
		var a := _rng.randf() * TAU
		var rad := _rng.randf_range(0.5, 0.9) * (1.0 - w * 0.5)
		var p := hand + Vector3(cos(a) * rad, _rng.randf_range(-0.4, 0.3), sin(a) * rad)
		if s.el == "earth" and world != null:
			p.y = VoxelQuery.field_height(world, p.x, p.z, hand.y) + 0.05
		var to := hand - p
		var tang := Vector3(-to.z, 0, to.x).normalized() * 1.2
		var life := _rng.randf_range(0.18, 0.3)
		var g := _g(p, to / life + tang, s.el, 1 if s.el == "earth" else 0, life, 0.035 if s.el != "air" else 0.022, 0.0, 0.0, 0.8)
		if g != null and s.el == "air":
			g.length = 0.1
	for i in 3:
		_g(hand + _r3() * 0.05 * (0.5 + w), Vector3.ZERO, s.el, 1 if s.el == "earth" else 0, 0.05,
			(0.09 + 0.12 * w) * [1.0, 0.7, 0.45][i], 0.0, 0.0, [0.75, 0.9, 1.0][i] * (0.8 + 0.2 * w))


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


## Luci puntiformi (magicRender del prototipo, HTML 8294–8300): solo le 3 celle
## in fiamme piu' vicine. Le magie di RMNDWN non hanno luci: brillano solo per
## mescola additiva.
func lights(m: MagicSystem, _hand: Vector3, player: Vector3) -> Array:
	var out := []
	if not m.fire.is_empty():
		var cells: Array = m.fire.keys()
		cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return Vector2(a.x - player.x, a.z - player.z).length_squared() < Vector2(b.x - player.x, b.z - player.z).length_squared())
		for i in mini(3, cells.size()):
			var c: Vector3i = cells[i]
			var fl := 0.8 + 0.2 * sin(_clock * 17.0 + c.x * 3.0 + c.z * 5.0)
			out.append([Vector3(c.x + 0.5, c.y + 1.3, c.z + 0.5), Vector3(1.0, 0.55, 0.2) * fl, 3.0])
	return out


# ---------------------------------------------------------------- glifo (RMNDWN §2.0)

## Base del piano del glifo, perpendicolare alla mira.
static func _plane(dir: Vector3) -> Array[Vector3]:
	var right := dir.cross(Vector3.UP)
	right = right.normalized() if right.length() > 1e-3 else Vector3.RIGHT
	return [right, right.cross(dir).normalized()]


## Punto della figura dell'elemento nel piano (unita' di R), da `a` in 0..TAU.
func _glyph_point(el: String, q: float, a: float, poly: int, ticks: int) -> Vector2:
	var sp := _spin * float(GLYPH_SPIN.get(el, 1.0))
	if q < 0.34:
		var r := 1.0 + 0.02 * sin(_clock * 9.0)
		return Vector2(cos(a + sp), sin(a + sp)) * r
	if q < 0.58:
		match el:
			"fire":
				var r := 0.26 + 0.30 * absf(sin(2.5 * a))
				return Vector2(cos(a + sp), sin(a + sp)) * r
			"water":
				var ring := 0.34 if _rng.randf() < 0.5 else 0.50
				var dirn := 1.0 if ring < 0.4 else -1.0
				var r := ring * (1.0 + 0.06 * sin(_clock * 3.1))
				return Vector2(cos(a + sp * dirn), sin(a + sp * dirn)) * r
			"air":
				var k := floorf(_rng.randf() * 3.0)
				var u := a / TAU
				var ang := k * TAU / 3.0 + u * 2.2 + sp + _clock * 0.25
				return Vector2(cos(ang), sin(ang)) * (0.16 + 0.40 * u)
			"earth":
				var seg := a / TAU * 6.0
				if seg - floorf(seg) > 0.8:
					a -= 0.2 * TAU / 6.0
				return Vector2(cos(a + sp), sin(a + sp)) * 0.52
			_:
				# Karma: rosa a tre petali e cerchio interno che gira al contrario.
				if _rng.randf() < 0.72:
					var r := absf(sin(3.0 * a))
					return Vector2(cos(a + sp), sin(a + sp)) * r
				return Vector2(cos(a - sp * 1.5), sin(a - sp * 1.5)) * 0.30
	if q < 0.78:
		var k := floorf(a / TAU * ticks)
		var ang := k / ticks * TAU + sp * 0.5
		return Vector2(cos(ang), sin(ang)) * _rng.randf_range(0.64, 0.96)
	# Poligono inscritto a .86 R.
	var side := floorf(a / TAU * poly)
	var f := a / TAU * poly - side
	var a0 := side / poly * TAU + sp
	var a1 := (side + 1.0) / poly * TAU + sp
	return Vector2(cos(a0), sin(a0)).lerp(Vector2(cos(a1), sin(a1)), f) * 0.86


func _glyph(dt: float, m: MagicSystem, s: SpellDefinition, hand: Vector3) -> void:
	var dir := m.aim - hand
	dir = dir.normalized() if dir.length() > 0.05 else MagicSystem._fwd(m.face)
	var R := s.glyph_r
	var c := hand + dir * s.glyph_off
	var pl := _plane(dir)
	var right := pl[0]
	var up := pl[1]
	var gathering := m.phase == MagicSystem.Phase.GATHER
	_spin += dt * lerpf(1.0, 1.7 + (s.tier - 1) * 0.18, _sm5(m.w if gathering else 1.0))
	var draw := minf(m.glyph, 1.0 - m.glyph_shed)
	var el := s.el
	var size_k := {"earth": 1.45, "water": 1.15, "air": 0.78}.get(el, 1.0) as float
	var n := _emit("glyph", 900.0 * (0.35 + 0.65 * draw), dt, 22)
	for i in n:
		var a := _rng.randf() * TAU
		if a > TAU * draw:
			continue
		var q := _rng.randf()
		var p2 := _glyph_point(el, q, a, s.glyph_poly, s.glyph_ticks) * R
		var p := c + right * p2.x + up * p2.y
		var t0 := _rng.randf_range(0.55, 0.9) if el == "karma" else 0.64 + 0.34 * _rng.randf()
		var g := _g(p, dir * 0.05, el, 0, _rng.randf_range(0.16, 0.28), GRAIN_MIN * size_k * (1.15 if q < 0.34 else 1.0), 0.0, 0.0, t0)
		if g != null:
			g.cool = 3.0
			if el == "air":
				g.v = (right * -p2.y + up * p2.x).normalized() * 0.6
				g.length = 0.03
	if not gathering:
		return
	var ch := clampf((m.glyph - 0.5) / 0.5, 0.0, 1.0)
	if el == "karma":
		# Grani che arrivano alla mano da una sfera di 12,75 cm.
		for i in _emit("khand", 160.0 * (0.22 + 0.78 * m.w), dt, 8):
			var o := _ball().normalized() * 0.1275
			var g := _g(hand + o, -o / 0.12 * 0.3 + dir * 0.1, "karma", 0, 0.14, GRAIN_MIN, 0.0, 0.0, _rng.randf_range(0.55, 0.9))
			if g != null:
				g.cool = 2.0
		return
	if m.glyph < 0.5:
		return
	# Carica: spirale verso il centro da R·(1,05..1,5) a .09 R.
	var wind := {"air": -3.6, "earth": 0.7}.get(el, 2.2) as float
	for i in _emit("gcharge", 200.0 * (0.35 + 0.65 * ch) * (0.6 + 0.4 * m.cast_commit), dt, 8):
		var a := _rng.randf() * TAU
		var r0 := R * _rng.randf_range(1.05, 1.5)
		var dur := ({"earth": 0.55, "air": 0.28}.get(el, 0.40) as float) * _rng.randf_range(0.8, 1.3)
		var p0 := c + (right * cos(a) + up * sin(a)) * r0
		var p1 := c + (right * cos(a + wind) + up * sin(a + wind)) * R * 0.09
		var g := _g(p0, (p1 - p0) / dur, "flame" if el == "fire" else el, 1 if el == "earth" else 0, dur, GRAIN_MIN * size_k, 0.0, 0.0, 0.85)
		if g != null:
			g.cool = 0.6
	# Massa al centro: fiamma che sale, sfera d'acqua, anello d'aria, blocchi di terra.
	var rc := R * 0.34 * (0.55 + 0.45 * ch) * (1.0 + 0.30 * _sm5((m.cast_commit - 0.7) / 0.3))
	for i in _emit("gmass", 160.0 * (0.25 + 0.75 * ch), dt, 8):
		match el:
			"fire":
				var g := _g(c + _ball() * rc, up * 0.6 + Vector3(0, 0.5, 0), "flame", 0, _rng.randf_range(0.12, 0.22), rc * 0.5, -0.8, 0.0, _rng.randf_range(0.7, 1.0))
				if g != null:
					g.cool = 1.4
			"water":
				_g(c + _ball().normalized() * rc, Vector3.ZERO, "water", 1, 0.08, rc * 0.35, 0.0, 0.0, _rng.randf_range(0.5, 0.9))
			"air":
				var a := _rng.randf() * TAU
				var g := _g(c + (right * cos(a) + up * sin(a)) * rc, (right * -sin(a) + up * cos(a)) * 3.0, "air", 0, 0.1, 0.012, 0.0, 0.0, 0.9)
				if g != null:
					g.length = 0.05
			_:
				_g(c + _ball() * rc * 0.8, Vector3.ZERO, "earth", 1, 0.08, rc * 0.45, 0.0, 0.0, _rng.randf_range(0.3, 0.6))


# ---------------------------------------------------------------- magie del libro in volo

## Karma (RMNDWN L30133–L30224): raggio acceso dal glifo alla testa (piu' denso
## verso la testa), fascio lungo `body_len`, sfera di grani con la scia. Colore
## per coerenza; dopo il contatto il raggio si spegne verso il punto d'arrivo.
func _karma_dart(dt: float, d: MagicSystem.Dart) -> void:
	var S := d.spell
	var run := d.origin.distance_to(d.p)
	if run < 1e-3:
		return
	var dir := (d.p - d.origin) / run
	var pl := _plane(dir)
	var coh := exp(-S.decoh * d.t)
	var u0 := 0.0
	var mul := 1.0
	if d.fade > 0.0:
		var u := 1.0 - d.fade / maxf(d.fade_life, 1e-3)
		u0 = u
		mul = pow(1.0 - u, 2.8)
	var key := "k%d" % d.get_instance_id()
	var rate := {"beam": 2600.0, "shaft": 1800.0, "orb": 1300.0}.get(S.kind, 1500.0) as float
	for i in _emit(key, rate * mul * (0.6 + S.r * 4.0), dt, 50):
		var dd: float
		var off: Vector3
		var rn := sqrt(_rng.randf())
		var tip := false
		match S.kind:
			"orb":
				dd = run
				off = _ball() * S.r
				rn = off.length() / maxf(S.r, 1e-3)
			"shaft":
				dd = maxf(0.0, run - S.body_len * sqrt(_rng.randf()))
				var a := _rng.randf() * TAU
				off = (pl[0] * cos(a) + pl[1] * sin(a)) * S.r * rn
			_:
				tip = _rng.randf() < 0.2
				dd = run * (_rng.randf_range(0.955, 1.0) if tip else sqrt(_rng.randf()))
				var a := _rng.randf() * TAU
				var taper := 1.0 - 0.55 * dd / run
				off = (pl[0] * cos(a) + pl[1] * sin(a)) * S.r * rn * taper * (0.5 if tip else 1.0)
		dd = maxf(dd, run * u0)
		var c_birth := (1.0 - pow(rn, 2.0) * 0.86) * maxf(S.coh_floor, exp(-S.decoh * dd / maxf(S.speed, 1.0)))
		var v := dir * 8.0 + off.normalized() * 0.3 if S.kind != "orb" else dir * S.speed * 0.9 + off.normalized() * 0.55
		var g := _g(d.origin + dir * dd + off, v, "karma", 0, _rng.randf_range(0.10, 0.2), (GRAIN_MIN + S.r * 0.25) * (1.35 if tip else 1.0), 0.0, 0.0, c_birth)
		if g != null:
			g.cool = 1.0 + S.decoh * 0.3
			if S.kind != "orb":
				g.length = g.s * (1.0 + 6.0 * c_birth)
	# Testa brillante mentre vola.
	if d.fade <= 0.0 and S.kind != "orb":
		_g(d.p, Vector3.ZERO, "karma", 0, 0.03, S.r * 2.4, 0.0, 0.0, maxf(0.9, coh))


func _book_dart(dt: float, d: MagicSystem.Dart) -> void:
	var S := d.spell
	if S.el == "karma":
		_karma_dart(dt, d)
		return
	var key := "d%d" % d.get_instance_id()
	var sp := maxf(d.v.length(), 1e-4)
	var dir := d.v / sp
	match S.el:
		"fire":
			# Testa trattenuta (hold/shell) e scia di fiamma che sale (v78 fire bolt).
			var hr := S.r * (0.75 if S.kind != "meteor" else 1.6)
			for i in _emit(key, 260.0 + 900.0 * S.r, dt, 30):
				var g := _g(d.p + _ball() * hr, -dir * sp * 0.25 + Vector3(0, 0.55, 0) + _r3() * 0.4, "flame", 0,
					_rng.randf_range(0.14, 0.34) * (1.0 + S.r), _rng.randf_range(0.04, 0.06) * (1.0 + S.r * 2.0), -1.2, 1.8, _rng.randf_range(0.8, 1.0))
				if g != null:
					g.cool = 1.5
			for i in _emit(key + "s", 12.0 + 40.0 * S.r, dt, 4):
				_g(d.p, _r3() * 0.3 + Vector3(0, 0.6, 0), "smoke", 1, _rng.randf_range(0.5, 1.0), 0.03 + S.r * 0.1, -0.2, 1.0, 0.5)
		"water":
			for i in _emit(key, 160.0 + 500.0 * S.r, dt, 24):
				var g := _g(d.p + _ball() * S.r * 0.8, d.v * 0.85 + _r3() * 0.6, "water", 1, _rng.randf_range(0.10, 0.25), 0.024 + S.r * 0.05,
					MagicSystem.MG * 0.6, 0.0, _rng.randf_range(0.3, 0.8))
				if g != null:
					g.length = 0.06
					g.ground = true
		"earth":
			# Il masso: palla di zolle che si compone davanti alla mano e gira.
			var grow := 1.0 if d.hold <= 0.0 else lerpf(0.35, 1.0, 1.0 - d.hold / maxf(0.05, S.hit_at * 0.5))
			for i in _emit(key, 220.0, dt, 20):
				var o := _ball() * 0.28 * grow
				o *= 1.0 + 0.24 * sin(o.x * 17.0 + o.y * 11.0)
				_g(d.p + o, Vector3.ZERO, "earth", 1, 0.06, 0.05 * grow, 0.0, 0.0, _rng.randf_range(0.15, 0.45))
			if d.hold <= 0.0:
				for i in _emit(key + "d", 30.0, dt, 4):
					var g := _g(d.p + _r3() * 0.2, Vector3(0, -0.4, 0) + _r3() * 0.4, "earth", 1, 0.6, 0.03, MagicSystem.MG * 0.5, 0.0, 0.5)
					if g != null:
						g.ground = true
		_:
			for i in _emit(key, 140.0, dt, 20):
				var g := _g(d.p + _r3() * 0.2, dir * sp * 0.3 + _r3() * 1.2, "air", 0, _rng.randf_range(0.12, 0.28), 0.016, 0.0, 2.0, 0.8)
				if g != null:
					g.length = 0.26


# ---------------------------------------------------------------- impatti

## Firma d'impatto per elemento (spawnImpactSignature, RMNDWN L18533): braci che
## salgono, gocce che cadono, anello d'aria, zolle; il Karma due anelli.
func signature(el: String, p: Vector3, heavy: bool, axis: Vector3) -> void:
	var k := 1.35 if heavy else 1.0
	match el:
		"fire":
			for i in (22 if heavy else 14):
				_puff(p, axis, 1.1 * k, 1.9, "fire", 0, 0.62, -1.4, 0.03)
			for i in 6:
				_puff(p, axis, 0.8, 1.2, "smoke", 1, 0.8, -0.6, 0.03)
		"water":
			for i in (26 if heavy else 16):
				_puff(p, axis, 1.5 * k, 1.7, "water", 1, 0.5, 8.5, 0.02)
			for i in 8:
				_puff(p, axis, 1.2, 1.4, "steam", 1, 0.4, 8.5, 0.016)
		"air":
			_line_ring(p, 0.10, 0.55, 0.22, "air", false, 20)
			for i in 6:
				_puff(p, axis, 1.9, 0.0, "air", 0, 0.3, 0.0, 0.016)
		"earth":
			for i in (18 if heavy else 11):
				_puff(p, axis, 1.3 * k, 2.6, "earth", 1, 0.75, 13.0, 0.04 if heavy else 0.03)
			for i in 6:
				_puff(p, axis, 1.0, 2.0, "smoke", 1, 0.75, 13.0, 0.03)
		_:
			_line_ring(p, 0.05, 0.24, 0.11, "karma", false, 14, 0.98)
			_line_ring(p, 0.10, 0.42, 0.16, "karma", false, 18, 0.7)


func _puff(p: Vector3, axis: Vector3, spd: float, up: float, el: String, mode: int, dur: float, grav: float, size: float) -> void:
	var a := _rng.randf() * TAU
	var h := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.45, 1.25) * spd + axis * spd * 0.35
	var g := _g(p, h + Vector3(0, up * _rng.randf_range(0.6, 1.4), 0), el, mode, dur * _rng.randf_range(0.7, 1.2), size, grav,
		2.4 if el == "fire" else (1.6 if mode == 1 else 0.8), _rng.randf_range(0.7, 1.0))
	if g != null:
		g.ground = mode == 1
		if el == "air":
			g.length = 0.08


## Anello di grani che si allarga (le linee di 1 px di RMNDWN): piatto a terra
## oppure verticale con un orientamento a caso.
func _line_ring(p: Vector3, r0: float, r1: float, dur: float, el: String, flat: bool, seg: int, t0: float = 0.9) -> void:
	var tilt := _rng.randf() * TAU
	for i in seg:
		var a := TAU * i / seg
		var d := Vector3(cos(a), 0, sin(a)) if flat else Vector3(cos(a) * cos(tilt), sin(a), cos(a) * sin(tilt))
		var g := _g(p + d * r0, d * (r1 - r0) / dur, el, 0 if el != "earth" and el != "water" else 1, dur, 0.016, 0.0, 0.0, t0)
		if g != null:
			g.length = 0.04


## Impatto di un proiettile elementale (v78 bloom/splash/crater/gust).
func element_impact(S: SpellDefinition, p: Vector3, n: Vector3) -> void:
	var el := S.el
	var big := clampf(maxf(S.r, S.area * 0.3) / 0.15, 1.0, 4.0)
	var ring := int(18 * sqrt(big))
	var ejecta := int(9 * sqrt(big))
	match el:
		"fire":
			for i in ring:
				var a := TAU * i / ring
				var d := Vector3(cos(a), 0.15, sin(a))
				var g := _g(p - n * 0.15 + d * 0.1, d * 6.0 * _rng.randf_range(0.8, 1.25) * sqrt(big), "flame", 0, _rng.randf_range(0.25, 0.4), 0.03 * sqrt(big), -1.0, 4.0, 0.95)
				if g != null:
					g.cool = 1.4
			for i in ejecta * 3:
				var d := (_r3() + n + Vector3(0, 1.0, 0)).normalized()
				var g := _g(p + _ball() * 0.2 * big, d * _rng.randf_range(1.1, 2.6) * sqrt(big) + Vector3(0, 1.5, 0), "flame", 0,
					_rng.randf_range(0.3, 0.6), 0.035 * sqrt(big), -2.0, 2.2, _rng.randf_range(0.75, 1.0))
				if g != null:
					g.cool = 1.2
			for i in int(6 * big):
				_g(p + _r3() * 0.3 * big, Vector3(0, 0.8, 0) + _r3() * 0.3, "smoke", 1, _rng.randf_range(0.8, 1.6), 0.05 * sqrt(big), -0.4, 1.0, 0.45)
			# Residuo: braci a terra che ardono ancora un poco.
			for i in int(7 * big):
				var q := p + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * 0.55 * sqrt(big)
				if world != null:
					q.y = VoxelQuery.field_height(world, q.x, q.z, p.y + 1.0) + 0.03
				var g := _g(q, Vector3(0, 0.25, 0), "flame", 0, _rng.randf_range(0.5, 1.2), 0.03, -0.2, 2.0, _rng.randf_range(0.6, 0.85))
				if g != null:
					g.cool = 0.8
		"water":
			for i in ring:
				var a := TAU * i / ring
				var d := Vector3(cos(a), 0, sin(a))
				var g := _g(p + d * 0.1, d * _rng.randf_range(1.2, 2.2) * sqrt(big) + Vector3(0, _rng.randf_range(1.4, 2.9), 0), "water", 1,
					_rng.randf_range(0.5, 0.9), 0.028, MagicSystem.MG * 0.55, 0.0, 0.7)
				if g != null:
					g.ground = true
					g.stick = true
			for i in ejecta:
				var g := _g(p + _r3() * 0.1, Vector3(_rng.randf_range(-.5, .5), _rng.randf_range(6.5, 10.0) * 0.5 * sqrt(big), _rng.randf_range(-.5, .5)), "water", 1,
					_rng.randf_range(0.5, 0.9), 0.03, MagicSystem.MG * 0.55, 0.0, 0.85)
				if g != null:
					g.length = 0.08
					g.ground = true
			_line_ring(p, 0.1, 0.7 * sqrt(big), 0.4, "water", true, 20, 0.8)
		"earth":
			for i in ejecta * 2:
				var d := (_r3() + Vector3(0, 1.2, 0)).normalized()
				var g := _g(p + _r3() * 0.15, d * _rng.randf_range(2.0, 4.5) * sqrt(big), "earth", 1, _rng.randf_range(0.6, 1.2), _rng.randf_range(0.03, 0.06),
					MagicSystem.MG, 0.3, _rng.randf_range(0.25, 0.6))
				if g != null:
					g.ground = true
					g.stick = true
			for i in 8:
				_g(p + _r3() * 0.4, Vector3(0, 0.5, 0) + _r3() * 0.5, "smoke", 1, _rng.randf_range(0.8, 1.6), 0.07, -0.2, 1.0, 0.7)
			_line_ring(p, 0.2, 1.2, 0.5, "earth", true, 22, 0.6)
		_:
			_line_ring(p, 0.1, 0.9, 0.3, "air", false, 20)
			_line_ring(p, 0.1, 0.6, 0.3, "air", true, 16)


## Impatto del Karma (buildKarmaImpact L29840): nucleo, anello di quad, ejecta a
## cono all'indietro e tagli perpendicolari al raggio.
func karma_impact(S: SpellDefinition, p: Vector3, dir: Vector3, k: float) -> void:
	var h: Array = KARMA_HIT.get(String(S.id), KARMA_HIT["zoltraak"])
	var heavy := S.heavy
	var dur := float(h[1])
	var r0 := S.r
	_g(p, Vector3.ZERO, "karma", 0, dur * 0.30, r0 * (7.0 if heavy else 5.0), 0.0, 0.0, 1.0)
	_g(p, Vector3.ZERO, "karma", 0, dur * 0.5, r0 * 3.0, 0.0, 0.0, 0.8)
	var pl := _plane(dir)
	var ring0 := float(h[2])
	var ring1 := float(h[3])
	for i in 22:
		var a := TAU * i / 22.0
		var d := pl[0] * cos(a) + pl[1] * sin(a)
		var g := _g(p + d * ring0, d * (ring1 - ring0) / dur, "karma", 0, dur, r0 * 1.5 * (1.25 if heavy else 1.0), 0.0, 0.0, 0.72)
		if g != null:
			g.cool = 1.0
	for i in int(round(float(h[4]) * (1.6 if heavy else 1.0))):
		var d := (-dir * _rng.randf_range(0.5, 1.5) + _r3() * 0.9) * _rng.randf_range(0.35, 1.5) * (1.4 if heavy else 1.0)
		_g(p, d * 3.0, "karma", 0, dur + 0.3, r0 * _rng.randf_range(0.6, 1.2) * (1.0 + (1.0 - k) * 2.2), 0.0, 3.4, _rng.randf_range(0.5, 0.9))
	var cuts := int(h[0])
	var gash := float(h[5]) * (1.5 if heavy else 1.0)
	for c in cuts:
		var ang := float(c) / cuts * PI + 0.35
		var d := pl[0] * cos(ang) + pl[1] * sin(ang)
		for j in 7:
			var u := (j / 6.0) * 2.0 - 1.0
			var g := _g(p + d * u * gash * 0.5, d * u * 0.4, "karma", 0, dur * 0.6, r0 * 1.1 * (1.0 - u * u * 0.6), 0.0, 0.0, 0.95 - 0.4 * absf(u))
			if g != null:
				g.length = gash * 0.12


# ---------------------------------------------------------------- stati (RMNDWN §7)

func _status_fx(dt: float, tg: CombatTarget, st: Dictionary) -> void:
	var id := tg.get_instance_id()
	var mid := tg.position + Vector3(0, tg.height * 0.5, 0)
	if st.has("burn"):
		# Fumo grigio dalla testa ogni .30 s; la fiamma cresce con le pile.
		for i in _emit("b%d" % id, 1.0 / 0.30, dt, 2):
			_g(tg.position + Vector3(0, tg.height, 0), Vector3(_rng.randf_range(-.1, .1), 0.7, _rng.randf_range(-.1, .1)), "smoke", 1, 0.9, 0.035, -0.3, 0.5, 0.5)
		for i in _emit("bf%d" % id, 10.0 * int(st["burn"]["st"]), dt, 3):
			var p := tg.position + Vector3(_rng.randf_range(-1, 1) * tg.radius, _rng.randf_range(0.2, tg.height * 0.9), _rng.randf_range(-1, 1) * tg.radius)
			var g := _g(p, Vector3(_rng.randf_range(-.3, .3), _rng.randf_range(0.6, 1.4), _rng.randf_range(-.3, .3)), "flame", 0, _rng.randf_range(0.25, 0.5), 0.03, -1.4, 1.5, 0.9)
			if g != null:
				g.cool = 1.4
	if st.has("wet"):
		# Due gocce ogni .20 s, un anello piatto ai piedi ogni .9 s.
		for i in _emit("w%d" % id, 2.0 / 0.20, dt, 3):
			var a := _rng.randf() * TAU
			var p := tg.position + Vector3(cos(a) * tg.radius, _rng.randf_range(0.3, tg.height * 0.8), sin(a) * tg.radius)
			var g := _g(p, Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3), "water", 1, 0.45, 0.02, 8.0, 0.0, 0.75)
			if g != null:
				g.ground = true
		for i in _emit("wr%d" % id, 1.0 / 0.9, dt, 1):
			_line_ring(tg.position + Vector3(0, 0.03, 0), tg.radius * 0.6, tg.radius * 1.6, 0.5, "water", true, 14, 0.7)
	if st.has("slow"):
		for i in _emit("sl%d" % id, 1.0 / 0.28, dt, 1):
			var g := _g(mid + _r3() * tg.radius, Vector3(0, -0.2, 0), "earth", 1, 0.7, 0.03, 13.0, 0.0, 0.4)
			if g != null:
				g.ground = true
		for i in _emit("slr%d" % id, 1.0 / 0.6, dt, 1):
			_line_ring(tg.position + Vector3(0, 0.03, 0), tg.radius * 0.8, tg.radius * 1.8, 0.4, "earth", true, 14, 0.5)


# ---------------------------------------------------------------- eventi

func _event(e: Dictionary, hand: Vector3) -> void:
	match String(e["type"]):
		"area":
			_area_start(e)
		"wave":
			_wave(e)
		"burst_ring", "ring":
			_line_ring(e["p"], 0.1, maxf(0.4, float(e["r"])), 0.35, e["el"], true, 24)
		"arc":
			_arc(e["from"], e["to"])
		"conduct":
			_line_ring(e["p"], 0.06, 0.8, 0.16, "water", false, 16, 0.9)
		"fan_ring":
			_line_ring(e["p"], 0.2, 3.0, 0.3, "fire", true, 22)
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
			var S: SpellDefinition = e["spell"]
			if S.is_legacy():
				burst(e["el"], e["p"], e["n"], 1.0)
			elif S.el == "karma":
				karma_impact(S, e["p"], -(e["n"] as Vector3), 1.0)
			else:
				element_impact(S, e["p"], e["n"])
		"contact":
			var S2: SpellDefinition = e["spell"]
			if S2.kind in ["lash", "slash", "push"]:
				_line_ring(e["p"], 0.1, maxf(0.5, float(e["r"])), 0.25, "air", false, 20)
		"hit":
			var S3: SpellDefinition = e["spell"]
			if not e.get("quiet", false) and not S3.is_legacy():
				var d: Vector2 = e["dir"]
				signature(S3.el, e["p"], S3.heavy, Vector3(d.x, 0, d.y))
		"burst":
			burst(e["el"], e["p"], e["n"], float(e.get("k", 1.0)))
		"release":
			var S4: SpellDefinition = e["spell"]
			if S4.is_legacy():
				burst(e["el"], e["p"], e["dir"], 0.35)
			elif S4.el == "karma":
				# Bocca del Karma: due quad additivi al centro del glifo.
				var c: Vector3 = hand + (e["dir"] as Vector3) * S4.glyph_off
				_g(c, Vector3.ZERO, "karma", 0, 0.14, S4.r * 7.0 * 0.6, 0.0, 0.0, 0.66)
				_g(c, Vector3.ZERO, "karma", 0, 0.14, S4.r * 3.0 * 0.6, 0.0, 0.0, 0.97)
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


# ---------------------------------------------------------------- forme ad area

func _area_start(e: Dictionary) -> void:
	if e["kind"] == "spikes":
		# Sei coni su un anello di 1 m attorno alla mira, su dal suolo in .4 s.
		var p: Vector3 = e["p"]
		for i in 6:
			var a := TAU * i / 6.0 + _rng.randf_range(-0.3, 0.3)
			var q := p + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.7, 1.3)
			if world != null:
				q.y = VoxelQuery.field_height(world, q.x, q.z, p.y + 1.0)
			for k in 8:
				var h := k / 7.0 * 1.5
				_g(q + Vector3(0, -0.2, 0), Vector3(0, (h + 0.2) / 0.4, 0), "earth", 1, 0.9, 0.26 * (1.0 - h / 1.5) * 0.5 + 0.02, 0.0, 0.0, 0.2 + 0.2 * (k % 2))


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


func _wave(e: Dictionary) -> void:
	var p: Vector3 = e["p"]
	var f: Vector3 = e["dir"]
	var side := Vector3(-f.z, 0, f.x)
	var w := float(e["w"])
	for i in 30:
		var u := _rng.randf_range(-0.5, 0.5)
		var q := p + side * u * w
		if world != null:
			q.y = VoxelQuery.field_height(world, q.x, q.z, q.y + 1.0)
		var bulge := pow(1.0 - absf(2.0 * u), 1.5)
		var g := _g(q + Vector3(0, _rng.randf_range(0.0, 0.86 * bulge + 0.1) * float(e["h"]) / 0.9, 0), f * 5.6 + Vector3(0, _rng.randf_range(0.2, 1.4), 0), "water", 1,
			_rng.randf_range(0.25, 0.45), _rng.randf_range(0.04, 0.06), MagicSystem.MG * 0.7, 0.3, _rng.randf_range(0.3, 0.8))
		if g != null:
			g.ground = true
			g.length = 0.08


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
					var g := _g(q, Vector3.ZERO, "flame", 0, _rng.randf_range(0.8, 2.6), 0.02, 0.0, 0.0, 0.7)
					if g != null:
						g.cool = 0.7
			"puddle":
				_g(q, Vector3.ZERO, "water", 1, _rng.randf_range(life * 0.6, life), _rng.randf_range(0.06, 0.12), 0.0, 0.0, 0.3)
			_:
				_g(q, Vector3.ZERO, "earth", 1, _rng.randf_range(life * 0.6, life), _rng.randf_range(0.05, 0.1), 0.0, 0.0, 0.08)


## Effetti che durano (getti, colonne, pioggia, correnti d'aria, colpi d'aria).
func _effect(dt: float, e: SpellRuntime.Effect, hand: Vector3) -> void:
	var s := e.spell
	var key := "fx%d" % e.get_instance_id()
	var fade := 1.0 - clampf(e.t / maxf(e.dur, 0.01), 0.0, 1.0)
	match s.kind:
		"jet":
			if e.t < 0.08 or e.t > s.emit:
				return
			if s.el == "fire":
				# Fiamma che esce a 17 m/s, sale e fuma (lunghezza ×2,8).
				for i in _emit(key, 900.0, dt, 30):
					var d := (e.dir + _r3() * 0.08).normalized()
					var g := _g(hand + d * 0.12, d * 17.0 * _rng.randf_range(0.7, 1.3), "flame", 0, _rng.randf_range(0.3, 0.5),
						_rng.randf_range(0.05, 0.09), -3.0, 3.1, _rng.randf_range(0.85, 1.0))
					if g != null:
						g.cool = 1.2
				for i in _emit(key + "s", 30.0, dt, 4):
					var sm := _g(hand + e.dir * _rng.randf_range(2.0, 5.0), Vector3(0, 0.9, 0) + _r3() * 0.4, "smoke", 1, _rng.randf_range(0.8, 1.4), 0.07, -0.3, 1.0, 0.45)
					if sm != null:
						sm.al = 0.45
			else:
				# Colonna d'acqua opaca (idrante 14 m/s, pressione 34 m/s).
				var sp := 34.0 if s.id == &"water_pressure" else 14.0
				for i in _emit(key, 420.0, dt, 26):
					var d := (e.dir + _r3() * (0.01 if sp > 20.0 else 0.03)).normalized()
					var g := _g(hand + d * 0.12, d * sp * _rng.randf_range(0.92, 1.05), "water", 1, s.reach / sp * _rng.randf_range(0.9, 1.1),
						s.r0 * 0.5 + 0.015, MagicSystem.MG * 0.25, 0.0, _rng.randf_range(0.2, 0.55))
					if g != null:
						g.length = 0.12
						g.ground = true
		"column":
			if s.el == "fire":
				# Sei colonne su una linea perpendicolare alla mira, in sequenza.
				var side := Vector3(-e.dir.z, 0, e.dir.x)
				for k in 6:
					var lead := k * 0.09 * 1.9
					if e.t < lead or e.t > lead + 1.9:
						continue
					var cc := e.p + side * (k - 2.5) / 5.0 * minf(8.2, s.area * 2.6)
					for i in _emit(key + str(k), 70.0 * fade + 10.0, dt, 6):
						var a := _rng.randf() * TAU
						var rr := sqrt(_rng.randf()) * 0.74 * 0.5
						var q := cc + Vector3(cos(a) * rr, 0.05, sin(a) * rr)
						var g := _g(q, Vector3(-sin(a), 0, cos(a)) * 2.6 * rr + Vector3(0, 7.2 * _rng.randf_range(0.7, 1.3), 0), "flame", 0,
							_rng.randf_range(0.35, 0.6), _rng.randf_range(0.04, 0.07), -1.0, 3.0, _rng.randf_range(0.85, 1.0))
						if g != null:
							g.cool = 1.1
			else:
				# Geyser: quattro getti su un anello di 1,5 m, uno ogni .09 s.
				for k in 4:
					var t0 := k * 0.09
					if e.t < t0 or e.t > t0 + 1.25:
						continue
					var a0 := TAU * k / 4.0
					var cc := e.p + Vector3(cos(a0), 0, sin(a0)) * 1.5
					for i in _emit(key + str(k), 90.0, dt, 8):
						var g := _g(cc + _r3() * 0.12, Vector3(_rng.randf_range(-.6, .6), 15.0 * _rng.randf_range(0.7, 1.3) * 0.6, _rng.randf_range(-.6, .6)), "water", 1,
							_rng.randf_range(0.9, 1.4), 0.03, MagicSystem.MG * 0.75, 0.0, _rng.randf_range(0.3, 0.8))
						if g != null:
							g.length = 0.1
							g.ground = true
		"rain":
			if e.t > s.emit:
				return
			var ramp := minf(1.0, e.t / 0.5)
			for i in _emit(key, 420.0 * ramp, dt, 24):
				var a := _rng.randf() * TAU
				var q := e.p + Vector3(cos(a), 0, sin(a)) * sqrt(_rng.randf()) * s.area + Vector3(0, 8.4, 0)
				var g := _g(q, Vector3(0, -20.0 * _rng.randf_range(0.8, 1.2), 0), "water", 1, 0.5, 0.012, 0.0, 0.0, 0.8)
				if g != null:
					g.length = 0.35
					g.ground = true
		"cyclone", "updraft", "vacuum":
			for i in _emit(key, 150.0 * fade + 20.0, dt, 16):
				var a := _rng.randf() * TAU
				var y := _rng.randf_range(0.0, maxf(0.6, s.height * 0.8 if s.kind != "vacuum" else 0.6))
				var rr := s.area * (1.6 if s.kind == "vacuum" else _rng.randf_range(0.3, 1.0) * (1.0 - 0.45 * y / maxf(1.0, s.height)))
				var q := e.p + Vector3(cos(a) * rr, y, sin(a) * rr)
				var tan := Vector3(-sin(a), 0, cos(a))
				var v := tan * 6.0 + Vector3(0, 2.5, 0)
				if s.kind == "vacuum":
					var turn := e.t > 0.62 * 1.25
					v = (e.p + Vector3(0, 0.7, 0) - q) * (2.2 if not turn else -1.9) + tan * 2.6
				elif s.kind == "updraft":
					v = Vector3(0, 6.0 if e.t < 0.6 * 2.3 else -9.0, 0) + tan * 1.2
				var g := _g(q, v, "air", 0, _rng.randf_range(0.25, 0.45), 0.02, 0.0, 0.5, 0.95)
				if g != null:
					g.length = 0.35
			# Detriti del suolo sollevati dal campo.
			for i in _emit(key + "d", 24.0 * fade, dt, 3):
				var a := _rng.randf() * TAU
				var q := e.p + Vector3(cos(a), 0.05, sin(a)) * s.area * _rng.randf()
				var g := _g(q, Vector3(-sin(a), 0, cos(a)) * 2.0 + Vector3(0, 2.2, 0), "earth", 1, 0.8, 0.03, 4.0, 0.3, 0.35)
				if g != null:
					g.ground = true
		"spray":
			# Braci lanciate tutt'attorno che ricadono e ardono a terra.
			if e.t > 1.0:
				return
			for i in _emit(key, 90.0, dt, 8):
				var a := _rng.randf() * TAU
				var d := Vector3(cos(a), 0, sin(a))
				var g := _g(hand + d * 0.2, d * 4.4 * _rng.randf_range(0.55, 1.4) + Vector3(0, 2.8 * _rng.randf_range(0.55, 1.45), 0), "flame", 0,
					_rng.randf_range(1.5, 2.6), 0.035, MagicSystem.MG * 0.5, 0.0, _rng.randf_range(0.8, 1.0))
				if g != null:
					g.ground = true
					g.stick = true
					g.cool = 0.6
		"lash":
			# Tre fili dalla mano alla mira che si srotolano.
			var u := clampf(e.t / maxf(e.hit_at, 0.05), 0.0, 1.0)
			var seg := e.aim - e.o
			for i in _emit(key, 260.0 * fade, dt, 18):
				var v := _rng.randf() * u
				var k := float(_rng.randi() % 3)
				var lat := Vector3(-seg.z, 0, seg.x).normalized() * sin((v - u) * 11.0 + k * 2.1) * 0.5 * (1.0 - v) * 0.3
				var g := _g(e.o + seg * v + lat + Vector3(0, sin(k * 1.7) * 0.05, 0), seg.normalized() * 3.0, "air", 0, 0.12, 0.014, 0.0, 0.0, 0.95)
				if g != null:
					g.length = 0.18
		"slash":
			# Mezzaluna sul bersaglio che scende di traverso (raggio 1,3, arco 3 rad).
			if e.t > 0.3:
				return
			var right := Vector3(-e.dir.z, 0, e.dir.x).normalized()
			for i in _emit(key, 700.0, dt, 30):
				var a := _rng.randf_range(-1.5, 1.5) + e.t * 1.7 / 0.3
				var r := 1.3 * (1.0 + 0.34 * e.t / 0.3) * 0.6
				var q := e.aim + (right * cos(a) + Vector3(0, 1, 0) * sin(a) * 0.8 - e.dir * 0.2 * sin(a)) * r
				var g := _g(q, (right * -sin(a) + Vector3(0, 1, 0) * cos(a)) * 6.0, "air", 0, 0.12, 0.016, 0.0, 0.0, 0.95)
				if g != null:
					g.length = 0.22
		"push":
			# Guscio di compressione che va dalla mano alla mira.
			var u := clampf(e.t / maxf(e.hit_at, 0.05), 0.0, 1.0)
			if e.t > e.hit_at + 0.2:
				return
			var c := e.o.lerp(e.aim, u)
			var pl := _plane(e.dir)
			for i in _emit(key, 400.0, dt, 20):
				var a := _rng.randf() * TAU
				var d := pl[0] * cos(a) + pl[1] * sin(a)
				var g := _g(c + d * 0.6, e.dir * 13.0 * 0.4 + d * 3.8 * 0.4, "air", 0, 0.1, 0.016, 0.0, 0.0, 0.9)
				if g != null:
					g.length = 0.16
		"quake":
			# Anelli di lastre che si sollevano: l'onda va fuori a 5,5 m/s.
			var front := 5.5 * e.t
			if front > s.area + 1.0:
				return
			for i in _emit(key, 260.0, dt, 20):
				var a := _rng.randf() * TAU
				var rr := front + _rng.randf_range(-0.3, 0.3)
				var q := e.p + Vector3(cos(a) * rr, 0, sin(a) * rr)
				if world != null:
					q.y = VoxelQuery.field_height(world, q.x, q.z, e.p.y + 1.0)
				var g := _g(q, Vector3(0, 2.0, 0) + Vector3(cos(a), 0, sin(a)) * 0.6, "earth", 1, 0.5, _rng.randf_range(0.05, 0.09), 8.0, 0.0, 0.25)
				if g != null:
					g.ground = true
