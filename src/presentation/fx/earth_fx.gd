class_name EarthFx
extends Node3D
## Terra come il reticolo di RMNDWN (SpellForge v78, D-032): ogni magia di terra
## dichiara una forma, la forma e' divisa in celle a passo fisso e i granelli
## volano dal suolo dentro le celle e ci si BLOCCANO. In aria sono polvere
## chiara, da bloccati sono terra compatta scura (T <= packedIn .14); il
## costrutto bloccato segue la magia (masso che vola, coni gemelli, punte che
## escono dal suolo, lastre del sisma, sasso nel palmo). Allo sgretolamento le
## celle li lasciano andare: cadono con gravita' e attrito, rimbalzano poco
## (.12), si fermano in un mucchio e spariscono. Disegno: quad opachi agganciati
## alla griglia dei pixel (lo shader dei grani), stirati nella direzione del
## moto, colore dalla rampa di sospensione della terra (RAMP_EARTH).

const CAP := 3200
const GRAV := 9.81
const DRAG := 2.4
const BOUNCE := 0.12
const PACKED_IN := 0.14
const SETTLE := 1.6
const STRETCH := 0.14
const STRETCH_MAX := 3.5
const THIN := 0.95
## Passi delle isoterme della rampa (bande visibili come in RMNDWN).
const STEPS := 7.0
## RAMP_EARTH (L23032); ".68" e' "#957murk" → "#95744", letto come rgb(149,116,4).
const RAMP := [[0.0, Color8(0x33, 0x26, 0x1a)], [0.22, Color8(0x4d, 0x3a, 0x25)], [0.45, Color8(0x6d, 0x53, 0x35)],
	[0.68, Color8(149, 116, 4)], [1.0, Color8(0xdc, 0xc5, 0x9f)]]


class Brick:
	extends RefCounted
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var s := 0.05
	var T := 0.85
	## Cella nel costrutto (spazio locale) e ritardo prima di partire.
	var slot := Vector3.ZERO
	var delay := 0.0
	var locked := false
	var settled := false
	## Libero: vita rimasta.
	var life := 0.0


class Construct:
	extends RefCounted
	var bricks: Array[Brick] = []
	var xf := Transform3D.IDENTITY
	var grow := 1.0
	var fly := 7.0
	var snap := 0.06
	## Oltre questo tempo i mattoni in viaggio vanno al loro posto (lockBy).
	var lock_by := 1.0
	var age := 0.0


var world: WorldData
var bricks: Array[Brick] = []
## chiave -> Construct
var constructs := {}
var _inst: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/presentation/shaders/particle.gdshader")
	mat.render_priority = 8
	mat.set_shader_parameter(&"additive", 0.0)
	_inst = MeshInstance3D.new()
	_inst.material_override = mat
	_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_inst.extra_cull_margin = 16384.0
	add_child(_inst)


## (Compatibilita': i grani non usano la luce del voxel.)
func set_light(_sun: float, _blk: float) -> void:
	pass


static func ramp(t: float) -> Color:
	var tb := roundf(clampf(t, 0.0, 1.0) * STEPS) / STEPS
	for i in range(1, RAMP.size()):
		var a: Array = RAMP[i - 1]
		var b: Array = RAMP[i]
		if tb <= float(b[0]):
			return (a[1] as Color).lerp(b[1], (tb - float(a[0])) / (float(b[0]) - float(a[0])))
	return RAMP[RAMP.size() - 1][1]


func _ground(x: float, z: float, y_ref: float) -> float:
	if world == null:
		return 0.0
	return VoxelQuery.field_height(world, x, z, y_ref + 1.0)


# ---------------------------------------------------------------- forme (celle)

## Palla piena bitorzoluta di raggio R (struct throw, bump .24).
static func ball_slots(r: float, pitch: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := int(ceil(r * 1.25 / pitch))
	for x in range(-n, n + 1):
		for y in range(-n, n + 1):
			for z in range(-n, n + 1):
				var p := Vector3(x, y, z) * pitch
				var d := p.length()
				var dir := p / maxf(d, 1e-4)
				var bump := 1.0 + 0.24 * sin(dir.x * 5.0 + dir.y * 3.0) * cos(dir.z * 4.0)
				if d <= r * bump:
					out.append(p)
	return out


## Cono pieno con la punta verso -Z (lunghezza `length`, base R): base a +.25 L.
static func cone_slots(r: float, length: float, pitch: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := int(ceil(r / pitch))
	var steps := int(ceil(length / pitch))
	for k in steps + 1:
		var u := float(k) / steps
		var z := lerpf(length * 0.25, -length * 0.75, u)
		var rr := r * (1.0 - u)
		for x in range(-n, n + 1):
			for y in range(-n, n + 1):
				var q := Vector2(x, y) * pitch
				if q.length() <= rr + pitch * 0.35:
					out.append(Vector3(q.x, q.y, z))
	return out


## Lastra piena (misure `size`), centrata.
static func box_slots(size: Vector3, pitch: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := Vector3i(maxi(1, int(round(size.x / pitch))), maxi(1, int(round(size.y / pitch))), maxi(1, int(round(size.z / pitch))))
	for x in n.x:
		for y in n.y:
			for z in n.z:
				out.append((Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * pitch - Vector3(n) * pitch * 0.5)
	return out


# ---------------------------------------------------------------- costrutti

## Crea un costrutto: i granelli partono dal suolo attorno a `from` (polvere
## chiara), volano verso le celle a `fly`·(1 + .35·distanza) m/s e si bloccano
## entro `snap`; dopo `lock_by` s quelli ancora in viaggio vanno al loro posto.
func build(key: String, slots: Array[Vector3], xf: Transform3D, from: Vector3, spread: float, lock_by: float, size: float,
		fly: float = 7.0) -> Construct:
	release(key, Vector3.ZERO, 0.0)
	var c := Construct.new()
	c.xf = xf
	c.fly = fly
	c.lock_by = lock_by
	c.snap = maxf(0.05, size * 0.9)
	for sl in slots:
		if bricks.size() >= CAP:
			break
		var b := Brick.new()
		b.slot = sl
		b.s = size * _rng.randf_range(0.85, 1.15)
		b.T = _rng.randf_range(0.8, 0.95)
		var a := _rng.randf() * TAU
		var o := from + Vector3(cos(a), 0, sin(a)) * sqrt(_rng.randf()) * spread
		o.y = _ground(o.x, o.z, from.y) + 0.02
		b.p = o
		# Emissione sfalsata: prima le celle basse e vicine al centro.
		b.delay = lock_by * 0.55 * clampf((sl.length() + (sl.y + 1.0) * 0.2) / 1.2, 0.0, 1.0) * _rng.randf()
		c.bricks.append(b)
		bricks.append(b)
	constructs[key] = c
	return c


func has(key: String) -> bool:
	return constructs.has(key)


func keys() -> Array:
	return constructs.keys()


func set_xf(key: String, xf: Transform3D, grow: float = 1.0) -> void:
	var c: Construct = constructs.get(key)
	if c != null:
		c.xf = xf
		c.grow = grow


## Rottura in volo o all'impatto: i mattoni tornano sabbia, spinti via dal
## centro (`burst`) e lungo `push`, piu' chiari (T + .25).
func release(key: String, push: Vector3, burst: float) -> void:
	var c: Construct = constructs.get(key)
	if c == null:
		return
	constructs.erase(key)
	var center := c.xf.origin
	for b in c.bricks:
		var out := b.p - center
		out = out.normalized() if out.length() > 1e-3 else Vector3.UP
		b.v = out * burst * _rng.randf_range(0.4, 1.2) + push * _rng.randf_range(0.6, 1.1) + Vector3(0, burst * 0.5 * _rng.randf(), 0)
		_free(b)


## Sgretolamento (struct crumble): la cella lascia andare il mattone con
## v = (±1,4, .6–2,0, ±1,4), che cade e si ammucchia.
func crumble(key: String) -> void:
	var c: Construct = constructs.get(key)
	if c == null:
		return
	constructs.erase(key)
	for b in c.bricks:
		b.v = Vector3(_rng.randf_range(-1.4, 1.4), _rng.randf_range(0.6, 2.0), _rng.randf_range(-1.4, 1.4))
		_free(b)


func _free(b: Brick) -> void:
	b.locked = false
	b.delay = 0.0
	b.T = minf(1.0, b.T + 0.25)
	b.life = _rng.randf_range(4.0, 6.0)


## Sabbia sparsa (impatti, blocchi che salgono o crollano): da `p` attorno a `n`.
func debris(p: Vector3, n: Vector3, count: int, speed: float, size: float, spread: float = 0.2) -> void:
	for i in count:
		if bricks.size() >= CAP:
			return
		var b := Brick.new()
		b.s = size * _rng.randf_range(0.7, 1.2)
		b.p = p + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0, 0.6), _rng.randf_range(-1, 1)) * spread
		var d := (n + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1.2), _rng.randf_range(-1, 1)) * 0.8).normalized()
		b.v = d * speed * _rng.randf_range(0.5, 1.2)
		b.T = _rng.randf_range(0.35, 0.7)
		b.life = _rng.randf_range(2.5, 4.5)
		bricks.append(b)


# ---------------------------------------------------------------- passo

func _process(dt: float) -> void:
	step(dt)
	_draw()


func step(dt: float) -> void:
	var owned := {}
	for key: String in constructs:
		var c: Construct = constructs[key]
		c.age += dt
		for b in c.bricks:
			owned[b] = true
			var w := c.xf * (b.slot * c.grow)
			if b.locked:
				b.p = w
				b.v = Vector3.ZERO
				continue
			if b.delay > 0.0:
				b.delay -= dt
				continue
			var d := w - b.p
			var dl := d.length()
			if dl < c.snap or c.age >= c.lock_by:
				b.p = w
				b.locked = true
				b.v = Vector3.ZERO
				b.T = minf(b.T, PACKED_IN)
				continue
			var sp := c.fly * (1.0 + dl * 0.35)
			b.v = d / dl * sp
			b.p += b.v * minf(dt, dl / sp)
			b.T = clampf(b.T - SETTLE * dt * 0.5, 0.25, 1.0)
	var i := bricks.size() - 1
	while i >= 0:
		var b := bricks[i]
		if owned.has(b):
			i -= 1
			continue
		b.life -= dt
		if b.life <= 0.0:
			bricks.remove_at(i)
			i -= 1
			continue
		if not b.settled:
			b.v.y -= GRAV * dt
			b.v *= exp(-DRAG * dt)
			b.p += b.v * dt
			var gy := _ground(b.p.x, b.p.z, b.p.y) + b.s * 0.5
			if b.p.y < gy:
				b.p.y = gy
				if absf(b.v.y) > 1.2:
					b.v.y = -b.v.y * BOUNCE
					b.v.x *= 0.5
					b.v.z *= 0.5
				else:
					# Mucchio: fermo e scuro.
					b.v = Vector3.ZERO
					b.settled = true
					b.T = minf(b.T, 0.22)
		i -= 1


func _draw() -> void:
	if _inst == null:
		return
	var n := mini(bricks.size(), CAP)
	if n == 0:
		_inst.mesh = null
		return
	var pos := PackedVector3Array()
	var cols := PackedColorArray()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var idx := PackedInt32Array()
	pos.resize(n * 4)
	cols.resize(n * 4)
	c0.resize(n * 16)
	c1.resize(n * 16)
	idx.resize(n * 6)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for k in n:
		var b := bricks[k]
		var sz := b.s
		if b.life > 0.0 and b.life < 0.6:
			sz *= b.life / 0.6
		var col := ramp(b.T)
		var sp := b.v.length()
		var dir := b.v / sp if sp > 0.05 and not b.settled else Vector3(1, 0, 0)
		var ln := minf(sz * (1.0 + sp * STRETCH), sz * STRETCH_MAX)
		for j in 4:
			var cr: Vector2 = corners[j]
			var vi := k * 4 + j
			pos[vi] = b.p
			cols[vi] = col
			c0[vi * 4] = cr.x
			c0[vi * 4 + 1] = cr.y
			c0[vi * 4 + 2] = sz * THIN * 0.5
			c0[vi * 4 + 3] = ln * 0.5
			c1[vi * 4] = dir.x
			c1[vi * 4 + 1] = dir.y
			c1[vi * 4 + 2] = dir.z
			c1[vi * 4 + 3] = 0.0
		var base := k * 4
		idx[k * 6] = base
		idx[k * 6 + 1] = base + 2
		idx[k * 6 + 2] = base + 1
		idx[k * 6 + 3] = base
		idx[k * 6 + 4] = base + 3
		idx[k * 6 + 5] = base + 2
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = pos
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_CUSTOM0] = c0
	a[Mesh.ARRAY_CUSTOM1] = c1
	a[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	_inst.mesh = mesh


func count() -> int:
	return bricks.size()


func clear() -> void:
	constructs.clear()
	bricks.clear()
	if _inst != null:
		_inst.mesh = null
