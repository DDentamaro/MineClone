class_name EarthFx
extends Node3D
## Terra fatta di zolle vere (D-032): le magie di terra sono costrutti, agglomerati
## di zolle solide (cubetti con la luce rustica di personaggi e oggetti) che si
## staccano dal suolo, volano nei loro posti e si compattano; poi il costrutto
## segue la magia (masso che vola, coni gemelli, punte che escono dal suolo,
## lastre del sisma, pietra nel palmo). Quando si rompe le zolle diventano
## libere: rimbalzano, rotolano, si fermano a terra e si sbriciolano.
## Una sola MultiMesh ricostruita a ogni frame.

const CAP := 1600
const GRAVITY := 22.0
## Palette: terra compatta (scura) e pietra, con variazione per zolla.
const DIRT := [Color(0.30, 0.22, 0.13), Color(0.36, 0.26, 0.15), Color(0.25, 0.18, 0.11), Color(0.42, 0.32, 0.19)]
const STONE := [Color(0.44, 0.41, 0.37), Color(0.36, 0.34, 0.31), Color(0.52, 0.48, 0.42)]


class Chunk:
	extends RefCounted
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var q := Quaternion.IDENTITY
	var w := Vector3.ZERO
	var s := Vector3.ONE * 0.08
	var col := Color.WHITE
	## Posto nel costrutto (spazio locale) e ritardo prima di partire verso il posto.
	var slot := Vector3.ZERO
	var delay := 0.0
	var fly := 0.0
	var locked := false
	## Libera: vita rimasta (si rimpicciolisce nell'ultimo mezzo secondo).
	var life := 0.0
	var resting := false


class Construct:
	extends RefCounted
	var chunks: Array[Chunk] = []
	var xf := Transform3D.IDENTITY
	## Scala del costrutto (il masso cresce mentre si compone).
	var grow := 1.0
	## Zolle posate una per una dal chiamante (lastre del sisma).
	var manual := false


var world: WorldData
var chunks: Array[Chunk] = []
## chiave -> Construct
var constructs := {}
var _mm: MultiMesh
var _inst: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_mm.mesh = box
	_mm.instance_count = CAP
	_mm.visible_instance_count = 0
	_inst = MultiMeshInstance3D.new()
	_inst.multimesh = _mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/presentation/shaders/actor.gdshader")
	_inst.material_override = mat
	_inst.extra_cull_margin = 16384.0
	add_child(_inst)


## Luce del voxel dove succede (come per gli attori).
func set_light(sun: float, blk: float) -> void:
	if _inst != null:
		_inst.set_instance_shader_parameter(&"sun_here", sun)
		_inst.set_instance_shader_parameter(&"blk_here", blk)


func _color(stone_k: float) -> Color:
	var pal: Array = STONE if _rng.randf() < stone_k else DIRT
	var c: Color = pal[_rng.randi() % pal.size()]
	return c.darkened(_rng.randf_range(-0.08, 0.12))


func _new_chunk(size: float, stone_k: float) -> Chunk:
	var c := Chunk.new()
	c.s = Vector3(size, size, size) * Vector3(_rng.randf_range(0.8, 1.2), _rng.randf_range(0.75, 1.15), _rng.randf_range(0.8, 1.2))
	c.col = _color(stone_k)
	c.q = Quaternion(Vector3(_rng.randf(), _rng.randf(), _rng.randf()).normalized(), _rng.randf() * TAU)
	return c


func _ground(x: float, z: float, y_ref: float) -> float:
	if world == null:
		return 0.0
	return VoxelQuery.field_height(world, x, z, y_ref + 1.0)


# ---------------------------------------------------------------- costrutti

## Posti di un masso: palla bitorzoluta di raggio R (RMNDWN struct throw, bump .24).
static func ball_slots(r: float, pitch: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := int(ceil(r / pitch))
	for x in range(-n, n + 1):
		for y in range(-n, n + 1):
			for z in range(-n, n + 1):
				var p := Vector3(x, y, z) * pitch
				var d := p.length()
				var dir := p / maxf(d, 1e-4)
				var bump := 1.0 + 0.24 * sin(dir.x * 5.0 + dir.y * 3.0) * cos(dir.z * 4.0)
				if d <= r * bump and d >= r * bump - pitch * 1.6:
					out.append(p)
	return out


## Posti di un cono con la punta verso -Z (lunghezza `len`, base R).
static func cone_slots(r: float, length: float, pitch: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var steps := int(ceil(length / pitch))
	for k in steps + 1:
		var u := float(k) / steps
		var z := lerpf(length * 0.25, -length * 0.75, u)
		var rr := r * (1.0 - u)
		var ring := maxi(1, int(TAU * rr / pitch))
		for i in ring:
			var a := TAU * i / ring + k * 0.5
			out.append(Vector3(cos(a) * rr, sin(a) * rr, z))
		if rr > pitch * 1.2:
			out.append(Vector3(0, 0, z))
	return out


## Crea un costrutto: le zolle partono dal suolo attorno a `from` e volano nei
## posti in `assemble` secondi (ritardi sfalsati, prima quelle vicine al centro).
func build(key: String, slots: Array[Vector3], xf: Transform3D, from: Vector3, spread: float, assemble: float, size: float, stone_k: float = 0.25) -> Construct:
	release(key, Vector3.ZERO, 0.0)
	var c := Construct.new()
	c.xf = xf
	for sl in slots:
		if chunks.size() >= CAP:
			break
		var ch := _new_chunk(size, stone_k)
		ch.slot = sl
		var a := _rng.randf() * TAU
		var o := from + Vector3(cos(a), 0, sin(a)) * _rng.randf() * spread
		o.y = _ground(o.x, o.z, from.y) + 0.02
		ch.p = o
		ch.delay = assemble * 0.55 * clampf(sl.length() / 0.6, 0.0, 1.0) * _rng.randf_range(0.6, 1.0)
		ch.fly = maxf(0.05, assemble - ch.delay)
		ch.w = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		c.chunks.append(ch)
		chunks.append(ch)
	constructs[key] = c
	return c


## Costrutto di pezzi grandi mossi uno per uno (lastre): `sizes` = misure.
func build_manual(key: String, sizes: Array[Vector3], stone_k: float = 0.4) -> Construct:
	release(key, Vector3.ZERO, 0.0)
	var c := Construct.new()
	c.manual = true
	for sz in sizes:
		if chunks.size() >= CAP:
			break
		var ch := _new_chunk(1.0, stone_k)
		ch.s = sz
		ch.q = Quaternion.IDENTITY
		ch.locked = true
		ch.p = Vector3(0, -1000, 0)
		c.chunks.append(ch)
		chunks.append(ch)
	constructs[key] = c
	return c


func set_chunk(key: String, i: int, p: Vector3, q: Quaternion) -> void:
	var c: Construct = constructs.get(key)
	if c != null and i < c.chunks.size():
		c.chunks[i].p = p
		c.chunks[i].q = q


func keys() -> Array:
	return constructs.keys()


func has(key: String) -> bool:
	return constructs.has(key)


func set_xf(key: String, xf: Transform3D, grow: float = 1.0) -> void:
	var c: Construct = constructs.get(key)
	if c != null:
		c.xf = xf
		c.grow = grow


## Rompe il costrutto: le zolle diventano libere con una spinta radiale +
## `push` lungo la direzione del colpo.
func release(key: String, push: Vector3, burst: float) -> void:
	var c: Construct = constructs.get(key)
	if c == null:
		return
	constructs.erase(key)
	var center := c.xf.origin
	for ch in c.chunks:
		var out := ch.p - center
		out = out.normalized() if out.length() > 1e-3 else Vector3.UP
		ch.v = out * burst * _rng.randf_range(0.5, 1.3) + push * _rng.randf_range(0.6, 1.1) + Vector3(0, burst * 0.6 * _rng.randf(), 0)
		ch.w = Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9), _rng.randf_range(-9, 9))
		ch.locked = false
		ch.delay = 0.0
		ch.fly = 0.0
		ch.life = _rng.randf_range(2.2, 3.6)


## Il costrutto si sbriciola: ogni pezzo grande diventa zolle piccole (tante
## quante ne entrano nel suo volume, al massimo 14) che cadono dal suo posto.
func crumble(key: String, size: float = 0.12) -> void:
	var c: Construct = constructs.get(key)
	if c == null:
		return
	constructs.erase(key)
	for ch in c.chunks:
		chunks.erase(ch)
		var n := clampi(int(ch.s.x * ch.s.y * ch.s.z / (size * size * size) * 0.25), 2, 14)
		var basis := Basis(ch.q)
		for i in n:
			if chunks.size() >= CAP:
				return
			var d := _new_chunk(size * _rng.randf_range(0.8, 1.3), 0.4)
			d.col = ch.col.darkened(_rng.randf_range(-0.1, 0.1))
			d.p = ch.p + basis * (Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)) * ch.s)
			d.v = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 2.0), _rng.randf_range(-1, 1))
			d.w = Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
			d.life = _rng.randf_range(1.6, 2.8)
			chunks.append(d)


## Zolle sparse (impatti, crolli, sisma): da `p`, velocita' attorno a `n`.
func debris(p: Vector3, n: Vector3, count: int, speed: float, size: float, spread: float = 0.2) -> void:
	for i in count:
		if chunks.size() >= CAP:
			return
		var ch := _new_chunk(size * _rng.randf_range(0.7, 1.3), 0.3)
		ch.p = p + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0, 0.6), _rng.randf_range(-1, 1)) * spread
		var d := (n + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1.2), _rng.randf_range(-1, 1)) * 0.8).normalized()
		ch.v = d * speed * _rng.randf_range(0.5, 1.2)
		ch.w = Vector3(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
		ch.life = _rng.randf_range(1.8, 3.0)
		chunks.append(ch)


# ---------------------------------------------------------------- passo

func _process(dt: float) -> void:
	step(dt)
	_draw()


func step(dt: float) -> void:
	for key: String in constructs:
		var c: Construct = constructs[key]
		if c.manual:
			continue
		for ch in c.chunks:
			var target := c.xf * (ch.slot * c.grow)
			if ch.locked:
				ch.p = target
				continue
			if ch.delay > 0.0:
				ch.delay -= dt
				continue
			# Volo verso il posto: arco che si stringe, poi l'incastro (con un filo di rimbalzo).
			var to := target - ch.p
			var dist := to.length()
			var sp := maxf(dist / maxf(ch.fly, 0.02), 2.0)
			ch.fly = maxf(0.0, ch.fly - dt)
			if dist < sp * dt + 0.01 or ch.fly <= 0.0:
				ch.p = target
				ch.locked = true
				ch.q = Quaternion(c.xf.basis) * Quaternion(Vector3(0.3, 1, 0.2).normalized(), ch.slot.x * 7.0 + ch.slot.y * 5.0)
				continue
			ch.p += to / dist * sp * dt + Vector3(0, sin(PI * clampf(1.0 - ch.fly, 0.0, 1.0)) * 1.2 * dt, 0)
			ch.q = (Quaternion.from_euler(ch.w * dt) * ch.q).normalized()
	var owned := {}
	for key: String in constructs:
		for ch: Chunk in (constructs[key] as Construct).chunks:
			owned[ch] = true
	var i := chunks.size() - 1
	while i >= 0:
		var ch := chunks[i]
		if owned.has(ch):
			i -= 1
			continue
		ch.life -= dt
		if ch.life <= 0.0:
			chunks.remove_at(i)
			i -= 1
			continue
		if not ch.resting:
			ch.v.y -= GRAVITY * dt
			ch.p += ch.v * dt
			ch.q = (Quaternion.from_euler(ch.w * dt) * ch.q).normalized()
			var gy := _ground(ch.p.x, ch.p.z, ch.p.y) + ch.s.y * 0.5
			if ch.p.y < gy:
				ch.p.y = gy
				if absf(ch.v.y) > 2.0:
					# Rimbalzo corto e rotolata.
					ch.v.y = -ch.v.y * 0.22
					ch.v.x *= 0.55
					ch.v.z *= 0.55
					ch.w *= 0.6
				else:
					ch.v = Vector3.ZERO
					ch.w = Vector3.ZERO
					ch.resting = true
		i -= 1


func _draw() -> void:
	if _mm == null:
		return
	var n := mini(chunks.size(), CAP)
	for k in n:
		var ch := chunks[k]
		var sc := ch.s
		if ch.life > 0.0 and ch.life < 0.5:
			sc *= ch.life / 0.5
		_mm.set_instance_transform(k, Transform3D(Basis(ch.q) * Basis.from_scale(sc), ch.p))
		_mm.set_instance_color(k, ch.col)
	_mm.visible_instance_count = n


func count() -> int:
	return chunks.size()


func clear() -> void:
	constructs.clear()
	chunks.clear()
	if _mm != null:
		_mm.visible_instance_count = 0
