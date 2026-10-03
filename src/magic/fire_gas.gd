class_name FireGas
extends Node3D
## Fuoco fatto solo di grani di gas caldo (D-056), come in RMNDWN (K112, "GAS
## CALDO", HTML ~25330 e ~26000-26470): niente mesh, niente silhouette. Ogni
## grano e' gas che sale perche' e' caldo e smette di salire quando si
## raffredda; la lingua di fiamma non e' disegnata, viene da qui.
## - Temperatura: profilo lungo l'asse del pennacchio (piatto vicino alla
##   sorgente, poi cala) per un decadimento con l'eta'.
## - Colore: rampa di corpo nero a isoterme (bianco-oro nuovo, rosso vecchio,
##   quasi nero quando si spegne: la coda fa da fumo).
## - Moto: spinta proporzionale alla temperatura, turbolenza che cresce salendo
##   (laminare alla base), attrito; i grani si allargano salendo (vortici).
## - Modi: LIBERO (pennacchio), LEGATO (testa del proiettile: il grano gira
##   attorno all'ancora per `hold` secondi, poi si stacca ereditando solo una
##   parte della corsa, ed e' cosi' che nasce la scia), BRACE (fiammelle di una
##   sorgente ferma: gemma, bruciatura, braci a terra, grana fissa), SEGNO (il
##   cerchio di rune, punti fermi su stazioni che vengono riaccesi di continuo).

enum { FREE, HELD, EMBER, GLYPH }

const CAP := 1300
## Isoterme della fiamma (RMNDWN RAMP, HTML 22154).
const RAMP := [[0.0, Color("#0c0b09")], [0.12, Color("#1e0c04")], [0.26, Color("#451003")], [0.42, Color("#6d1d05")],
	[0.58, Color("#93300a")], [0.72, Color("#ad4a12")], [0.84, Color("#c06a1c")], [0.93, Color("#cf9038")], [1.0, Color("#dcb96e")]]
const STEPS := 6.0
const LUM := 5.5
## Stazioni del cerchio: i grani si riaccendono sempre negli stessi punti, cosi'
## la figura si legge come un tracciato e non come una nuvola.
const GLYPH_STATIONS := 72


class Anchor:
	extends RefCounted
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var alive := true
	var spin := 2.0
	var r := 0.2
	var retain := 0.2


class Glyph:
	extends RefCounted
	var c := Vector3.ZERO
	var n := Vector3.FORWARD
	var r := 0.24
	var poly := 3
	var ticks := 8
	var spin := 1.0
	var rate := 1100.0
	var size := 0.016
	var life := 0.3
	var prog := 0.0
	var lvl := 1.0
	var shed := 0.5
	var burst := 3.0
	var max_n := 360
	var n_alive := 0
	var acc := 0.0
	var t := 0.0
	var dead := false


class Grain:
	extends RefCounted
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var o := Vector3.ZERO
	var a := 0.0
	var T := 1.0
	var T0 := 1.0
	var ph := 0.0
	var s := 0.03
	var s0 := 0.03
	var L := 0.6
	var m := 0
	var hold := 0.0
	var off := Vector3.ZERO
	var anchor: Anchor
	var glyph: Glyph
	var gk := 0
	var gu := 0.0
	var buoy := 7.0
	var turb := 1.6
	var drag := 2.0
	var cool := 1.0
	var eddy := 0.9
	var floor_y := -1e9
	var max_a := 2.6


var world: WorldData
var list: Array[Grain] = []
var glyphs: Array[Glyph] = []
var _t := 0.0
var _opaque: MeshInstance3D
var _glow: MeshInstance3D


func _ready() -> void:
	_opaque = _instance(preload("res://src/presentation/shaders/particle.gdshader"), 8, false)
	_glow = _instance(preload("res://src/presentation/shaders/particle_add.gdshader"), 9, true)


func _instance(shader: Shader, priority: int, additive: bool) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = priority
	mat.set_shader_parameter(&"additive", 1.0 if additive else 0.0)
	var inst := MeshInstance3D.new()
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 16384.0
	add_child(inst)
	return inst


func clear() -> void:
	list.clear()
	glyphs.clear()
	_build()


func count() -> int:
	return list.size()


## Temperatura lungo l'asse (Zukoski): piena fino a .35 L, poi cala.
static func plume_t(zr: float) -> float:
	return 1.0 if zr <= 0.35 else clampf(1.0 - 0.82 * pow((zr - 0.35) / 1.25, 1.15), 0.0, 1.0)


## Sfarfallio: distacco dei vortici, f = 1,5 / sqrt(D). Un falo' pulsa lento,
## una torcia veloce. Restituisce il fattore dell'emissione (0,26..1).
func gate(diameter: float, phase: float) -> float:
	var f := 1.5 / sqrt(maxf(0.02, diameter))
	var k := pow(maxf(0.0, sin(TAU * f * _t + phase)), 1.6)
	return 0.26 + 0.74 * k


## Le isoterme sono solo STEPS + 1: i colori si calcolano una volta.
static var _iso: PackedColorArray = PackedColorArray()


## Colore della fiamma per temperatura: isoterme della rampa e luminosita'.
static func flame(t: float) -> Color:
	if _iso.is_empty():
		for k in int(STEPS) + 1:
			_iso.append(_flame_at(k / STEPS))
	return _iso[roundi(clampf(t, 0.0, 1.0) * STEPS)]


static func _flame_at(tb: float) -> Color:
	var c: Color = RAMP[0][1]
	for i in range(1, RAMP.size()):
		var a: Array = RAMP[i - 1]
		var b: Array = RAMP[i]
		if tb <= float(b[0]):
			c = (a[1] as Color).lerp(b[1], (tb - float(a[0])) / (float(b[0]) - float(a[0])))
			break
	var e := pow(tb, LUM * 0.55) * 0.55 + 0.45 * tb
	return c * (0.75 + 0.5 * e)


func _new(p: Vector3, m: int) -> Grain:
	if list.size() >= CAP:
		return null
	var g := Grain.new()
	g.p = p
	g.o = p
	g.m = m
	g.ph = randf() * TAU
	list.append(g)
	return g


## Grano libero del pennacchio con i parametri del fuoco `f`
## (buoy, turb, drag, cool, eddy, size, L).
func puff(p: Vector3, v: Vector3, f: Dictionary, size_k: float = 1.0) -> Grain:
	var g := _new(p, FREE)
	if g == null:
		return null
	g.v = v
	_apply(g, f)
	g.s0 = float(f["size"]) * size_k * randf_range(0.65, 1.45)
	g.s = g.s0
	return g


func _apply(g: Grain, f: Dictionary) -> void:
	g.buoy = f["buoy"]
	g.turb = f["turb"]
	g.drag = f["drag"]
	g.cool = f["cool"]
	g.eddy = f["eddy"]
	g.L = f["L"]
	g.T0 = f.get("T0", 1.0)
	g.T = g.T0
	g.floor_y = f.get("floor", -1e9)


## Grano legato all'ancora: nasce nel volume della testa (guscio `shell`).
func held(an: Anchor, f: Dictionary, hold: float, shell: float) -> Grain:
	var d := _rand_dir()
	var rr := an.r * pow(randf(), 1.0 - shell * 0.75)
	var off := Vector3(d.x * rr, d.y * rr * 0.85, d.z * rr)
	var g := _new(an.p + off, HELD)
	if g == null:
		return null
	_apply(g, f)
	g.anchor = an
	g.off = off
	g.hold = hold * randf_range(0.55, 1.45)
	g.s0 = float(f["size"]) * randf_range(0.65, 1.45)
	g.s = g.s0
	return g


## Fiammella di una sorgente ferma (gemma, bruciatura, brace a terra). La
## grana resta quella: si legge la densita', non la taglia.
func ember(p: Vector3, f: Dictionary, spread: float) -> Grain:
	var g := _new(p, EMBER)
	if g == null:
		return null
	_apply(g, f)
	g.v = Vector3(randf_range(-spread, spread), randf_range(0.45, 1.2), randf_range(-spread, spread))
	g.T0 = randf_range(0.78, 1.0)
	g.T = g.T0
	g.s0 = f["size"]
	g.s = g.s0
	g.max_a = 3.2
	return g


func glyph_new(c: Vector3, n: Vector3, r: float, poly: int, ticks: int, spin: float) -> Glyph:
	var y := Glyph.new()
	y.c = c
	y.n = n.normalized() if n.length() > 1e-4 else Vector3.FORWARD
	y.r = r
	y.poly = poly
	y.ticks = ticks
	y.spin = spin
	glyphs.append(y)
	return y


## Il cerchio si sfalda: i suoi grani partono verso l'esterno (e un poco in avanti).
func glyph_end(y: Glyph) -> void:
	if y.dead:
		return
	y.dead = true
	for g in list:
		if g.m == GLYPH and g.glyph == y:
			_shed(g, y.burst)


func _shed(g: Grain, k: float) -> void:
	var y := g.glyph
	var rel := g.p - y.c
	var rl := maxf(rel.length(), 1e-4)
	g.m = FREE
	g.o = g.p
	g.a = 0.0
	g.v = rel / rl * k + y.n * k * 0.5
	g.L = 0.35
	g.buoy = 4.0
	g.turb = 1.2
	g.drag = 3.0
	g.cool = 1.6
	g.eddy = 0.4
	g.max_a = 0.8
	y.n_alive -= 1
	g.glyph = null


static func _glyph_point(y: Glyph, gk: int, gu: float) -> Vector3:
	var R := y.r
	var rad: float
	var ang: float
	match gk:
		0:
			rad = R
			ang = gu * TAU + y.t * y.spin
		1:
			rad = R * 0.6
			ang = gu * TAU - y.t * y.spin * 1.7
		2:
			var k := floorf(gu * y.ticks)
			var f := fmod(gu * y.ticks, 1.0)
			rad = R * (0.64 + 0.32 * f)
			ang = k / y.ticks * TAU + y.t * y.spin
		_:
			var m := y.poly
			var sg := floorf(gu * m)
			var f := fmod(gu * m, 1.0)
			var a0 := sg / m * TAU - y.t * y.spin * 0.8
			var a1 := (sg + 1.0) / m * TAU - y.t * y.spin * 0.8
			var q := Vector2(cos(a0), sin(a0)).lerp(Vector2(cos(a1), sin(a1)), f) * R * 0.86
			rad = q.length()
			ang = atan2(q.y, q.x)
	var b := _basis(y.n)
	return y.c + b[0] * cos(ang) * rad + b[1] * sin(ang) * rad


static func _basis(n: Vector3) -> Array[Vector3]:
	var r := n.cross(Vector3.UP)
	r = r.normalized() if r.length() > 1e-3 else Vector3.RIGHT
	return [r, r.cross(n).normalized()]


func step(dt: float) -> void:
	_t += dt
	_step_glyphs(dt)
	var i := list.size() - 1
	while i >= 0:
		var g := list[i]
		g.a += dt
		if not _step_grain(g, dt):
			if g.m == GLYPH and g.glyph != null:
				g.glyph.n_alive -= 1
			list.remove_at(i)
		i -= 1
	_build()


func _step_glyphs(dt: float) -> void:
	for k in range(glyphs.size() - 1, -1, -1):
		var y := glyphs[k]
		y.t += dt
		if y.dead:
			if y.n_alive <= 0:
				glyphs.remove_at(k)
			continue
		y.acc = minf(y.acc + dt * y.rate * y.lvl, 2.0 + dt * y.rate)
		while y.acc >= 1.0 and y.n_alive < y.max_n:
			y.acc -= 1.0
			var q := randf()
			var gk := 0 if q < 0.36 else (1 if q < 0.6 else (2 if q < 0.8 else 3))
			var gu := randf() * y.prog
			gu = (floorf(gu * GLYPH_STATIONS) + 0.5) / GLYPH_STATIONS
			var g := _new(_glyph_point(y, gk, gu), GLYPH)
			if g == null:
				break
			g.glyph = y
			g.gk = gk
			g.gu = gu
			g.hold = y.life * randf_range(0.7, 1.3)
			g.s0 = y.size * (1.15 if gk == 0 else 1.0)
			g.s = g.s0
			y.n_alive += 1


## Un passo del grano; false se va tolto.
func _step_grain(g: Grain, dt: float) -> bool:
	match g.m:
		GLYPH:
			var y := g.glyph
			g.hold -= dt
			if g.hold <= 0.0:
				# Ricambio: quasi tutti finiscono e basta, qualcuno si stacca.
				if randf() < 0.75:
					return false
				_shed(g, y.shed)
				return true
			g.p = _glyph_point(y, g.gk, g.gu)
			g.T = 0.85 + 0.15 * sin(_t * 9.0 + g.ph)
			return true
		HELD:
			var an := g.anchor
			if not an.alive:
				# Liberati dove sono, con una frazione della corsa della testa.
				g.m = FREE
				g.o = g.p
				g.a = 0.0
				g.v = an.v * an.retain + Vector3(randf_range(-0.5, 0.5), 0.4, randf_range(-0.5, 0.5))
				return true
			var w := an.spin * dt
			g.off = Vector3(g.off.x * cos(w) - g.off.z * sin(w), g.off.y + sin(_t * 7.0 + g.ph) * an.r * 0.35 * dt, g.off.x * sin(w) + g.off.z * cos(w))
			g.p = an.p + g.off
			g.v = an.v
			g.o = g.p
			g.T = g.T0 * (0.9 + 0.1 * sin(_t * 11.0 + g.ph))
			g.hold -= dt
			if g.hold <= 0.0:
				# Rilascio: resta indietro rispetto alla testa, e nasce la scia.
				g.m = FREE
				g.v = an.v * an.retain + Vector3(randf_range(-0.4, 0.4), 0.35, randf_range(-0.4, 0.4))
				g.o = g.p
				g.a = 0.0
			return true
	var zr := g.p.distance_to(g.o) / maxf(g.L, 0.05)
	if zr > 2.3 or g.a > g.max_a:
		return false
	g.T = g.T0 * plume_t(zr) * exp(-g.cool * g.a * 0.45)
	g.v.y += g.buoy * maxf(g.T, 0.12) * dt
	var tb := g.turb * (0.35 + zr) * (0.6 if g.m == EMBER else 1.0)
	g.v.x += sin(_t * 9.1 + g.ph) * tb * dt
	g.v.z += cos(_t * 7.7 + g.ph * 1.7) * tb * dt
	var dr := exp(-g.drag * dt)
	g.v.x *= dr
	g.v.z *= dr
	g.v.y *= exp(-g.drag * 0.45 * dt)
	g.p += g.v * dt
	if g.p.y < g.floor_y + 0.02:
		g.p.y = g.floor_y + 0.02
		g.v.y *= -0.12
	if g.m == FREE:
		# I vortici crescono salendo, ma non oltre il doppio.
		g.s = minf(g.s + g.eddy * g.s0 * dt * (1.0 + zr), g.s0 * 2.0)
	return true


func _build() -> void:
	if _opaque == null:
		return
	for layer in 2:
		# Prima chi si disegna e con che colore, poi gli array gia' della
		# misura giusta: niente array creati grano per grano (telefono).
		var sel: Array[Grain] = []
		var cl := PackedColorArray()
		var sz := PackedFloat32Array()
		for g in list:
			var col := flame(g.T)
			var al: float
			var size := g.s
			if layer == 0:
				# Corpo: grani pieni col colore della temperatura. In RMNDWN la
				# fusione e' MAX, quindi il gas che si spegne sparisce da solo
				# (non c'e' fumo nero): qui lo si fa sfumare con la temperatura.
				al = clampf((g.T - 0.28) / 0.3, 0.0, 1.0) * clampf(1.0 - (g.a / g.max_a - 0.8) / 0.2, 0.0, 1.0)
			else:
				# Bagliore: solo i grani piu' caldi, poco piu' grandi e tenui
				# (sul marmo bianco l'additivo sbianca tutto).
				if g.T < 0.7:
					continue
				al = (g.T - 0.7) * 0.8
				size = g.s * 1.7
				col = col * 0.45
			if al <= 0.02:
				continue
			col.a = al
			sel.append(g)
			cl.append(col)
			sz.append(size)
		var inst := _opaque if layer == 0 else _glow
		var n := sel.size()
		if n == 0:
			inst.mesh = null
			continue
		var pos := PackedVector3Array()
		pos.resize(n * 4)
		var cols := PackedColorArray()
		cols.resize(n * 4)
		var c0 := PackedFloat32Array()
		c0.resize(n * 16)
		var c1 := PackedFloat32Array()
		c1.resize(n * 16)
		var idx := PackedInt32Array()
		idx.resize(n * 6)
		for k in n:
			var p := sel[k].p
			var b := k * 4
			var q := k * 16
			var w := sz[k]
			for v in 4:
				pos[b + v] = p
				cols[b + v] = cl[k]
			c0[q] = -1.0; c0[q + 1] = -1.0; c0[q + 2] = w; c0[q + 3] = w
			c0[q + 4] = 1.0; c0[q + 5] = -1.0; c0[q + 6] = w; c0[q + 7] = w
			c0[q + 8] = 1.0; c0[q + 9] = 1.0; c0[q + 10] = w; c0[q + 11] = w
			c0[q + 12] = -1.0; c0[q + 13] = 1.0; c0[q + 14] = w; c0[q + 15] = w
			var e := k * 6
			idx[e] = b; idx[e + 1] = b + 2; idx[e + 2] = b + 1
			idx[e + 3] = b; idx[e + 4] = b + 3; idx[e + 5] = b + 2
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_CUSTOM0] = c0
		arr[Mesh.ARRAY_CUSTOM1] = c1
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
		inst.mesh = mesh


static func _rand_dir() -> Vector3:
	var v := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	while v.length_squared() > 1.0 or v.length_squared() < 1e-4:
		v = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized()
