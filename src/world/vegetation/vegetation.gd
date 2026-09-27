class_name Vegetation
extends RefCounted
## Alberi ed erba del prototipo (HTML ~4893–4957, core.js 258–288 e 410–475):
## densita' del terreno e quota continua del suolo, posizioni degli alberi,
## template degli alberi a tre archetipi, fili d'erba per colonna di chunk.
## Stessi numeri del prototipo (RNG, rumore e trigonometria di V8).

const DENS_C := 16.2
const DENS_N := 10.8 / 26.0
const ISO := 13.5
## Stride dei template: posizione 3, normale 3, colore 3, vento 1.
const STRIDE := 10


class TreeSpot:
	extends RefCounted
	var x: float
	var y: float
	var z: float
	var kind: int
	var rot: float
	var scale: float
	var seed_value: float
	var dead := false


class Template:
	extends RefCounted
	var data := PackedFloat32Array()
	var height: float

	func verts() -> int:
		return data.size() / STRIDE


# ------------------------------------------------------------------ densita'

static func _op(w: WorldData, opaque: PackedByteArray, x: int, y: int, z: int) -> int:
	return opaque[w.blocks[(y * w.size_z + z) * w.size_x + x]]


## Somma 3x3 (x, z) con bordi replicati, come i due passaggi di computeDensity.
static func _a1(w: WorldData, opaque: PackedByteArray, x: int, y: int, z: int) -> int:
	var xm := maxi(x - 1, 0)
	var xp := mini(x + 1, w.size_x - 1)
	var s := 0
	for zz in [maxi(z - 1, 0), z, mini(z + 1, w.size_z - 1)]:
		s += _op(w, opaque, xm, y, zz) + _op(w, opaque, x, y, zz) + _op(w, opaque, xp, y, zz)
	return s


## Valore di computeDensity per la cella (x, y, z) interna al mondo.
static func density_cell(w: WorldData, opaque: PackedByteArray, x: int, y: int, z: int) -> int:
	var lo := _a1(w, opaque, x, y - 1, z) if y > 0 else 9
	var hi := _a1(w, opaque, x, y + 1, z) if y < w.size_y - 1 else 0
	var s27 := lo + _a1(w, opaque, x, y, z) + hi
	var c := _op(w, opaque, x, y, z)
	return JsMath.js_round_i(c * DENS_C + (s27 - c) * DENS_N)


## densAt: sotto il mondo pieno, sopra vuoto, lati replicati.
static func dens_at(w: WorldData, opaque: PackedByteArray, x: int, y: int, z: int) -> int:
	if y < 0:
		return 27
	if y >= w.size_y:
		return 0
	return density_cell(w, opaque, clampi(x, 0, w.size_x - 1), y, clampi(z, 0, w.size_z - 1))


## groundHeight: primo attraversamento dell'isosuperficie dall'alto, bilineare.
static func ground_height(w: WorldData, opaque: PackedByteArray, fx: float, fz: float) -> float:
	var u := fx - 0.5
	var ww := fz - 0.5
	var x0 := floori(u)
	var z0 := floori(ww)
	var tx := u - x0
	var tz := ww - z0
	var c00 := _col(w, opaque, x0, z0)
	var c10 := _col(w, opaque, x0 + 1, z0)
	var c01 := _col(w, opaque, x0, z0 + 1)
	var c11 := _col(w, opaque, x0 + 1, z0 + 1)
	return (c00 * (1.0 - tx) + c10 * tx) * (1.0 - tz) + (c01 * (1.0 - tx) + c11 * tx) * tz


static func _col(w: WorldData, opaque: PackedByteArray, x: int, z: int) -> float:
	x = clampi(x, 0, w.size_x - 1)
	z = clampi(z, 0, w.size_z - 1)
	var prev := 0
	for y in range(w.size_y - 1, -1, -1):
		var d := dens_at(w, opaque, x, y, z)
		if d >= ISO:
			var t := (d - ISO) / maxf(1e-3, d - prev)
			return y + 0.5 + t
		prev = d
	return 0.0


# ------------------------------------------------------------------ alberi

## treeSpots: sull'erba, distanziati, mai sullo spawn.
static func tree_spots(w: WorldData, opaque: PackedByteArray, seed_value: int) -> Array[TreeSpot]:
	var rng := Mulberry32.new(seed_value + 77)
	var out: Array[TreeSpot] = []
	var sx := w.size_x
	var sz := w.size_z
	var cx := sx >> 1
	var cz := sz >> 1
	var taken := PackedByteArray()
	taken.resize(sx * sz)
	for z in range(3, sz - 3):
		for x in range(3, sx - 3):
			var h := w.surface[z * sx + x]
			if w.get_block_xyz(x, h, z) != BlockCatalog.GRASS or w.get_block_xyz(x, h + 1, z) != BlockCatalog.AIR:
				continue
			if absi(x - cx) < 5 and absi(z - cz) < 5:
				continue
			var bm: Dictionary = Biomes.BIOMES[w.biome[z * sx + x] if not w.biome.is_empty() else 0]
			var forest := IsoNoise.fbm2(x / 30.0 + 3.0, z / 30.0 - 1.0, seed_value + 808, 2)
			var trees: Array = bm["trees"]
			var p: float = trees[0] if forest > 0.58 else (trees[1] if forest > 0.50 else trees[2])
			if rng.next() > p:
				continue
			var ok := true
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					if taken[(z + dz) * sx + x + dx] == 1:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			taken[z * sx + x] = 1
			var t := TreeSpot.new()
			t.x = x + 0.5 + (rng.next() - 0.5) * 0.3
			t.z = z + 0.5 + (rng.next() - 0.5) * 0.3
			t.y = ground_height(w, opaque, t.x, t.z) - 0.05
			var kinds: Array = bm["kinds"]
			t.kind = kinds[floori(rng.next() * kinds.size())]
			t.rot = rng.next() * PI * 2.0
			t.scale = (0.85 + rng.next() * 0.35) * float(bm["treeScale"])
			t.seed_value = rng.next()
			out.append(t)
	return out


static func _norm3(v: Vector3) -> PackedFloat64Array:
	return _norm3d(v.x, v.y, v.z)


static func _norm3d(a: float, b: float, c: float) -> PackedFloat64Array:
	var l := JsMath.js_hypot3(a, b, c)
	if l == 0.0:
		l = 1.0
	return PackedFloat64Array([a / l, b / l, c / l])


static func _push_tri(out: PackedFloat64Array, pa: PackedFloat64Array, pb: PackedFloat64Array, pc: PackedFloat64Array,
		na: PackedFloat64Array, nb: PackedFloat64Array, nc: PackedFloat64Array, col: PackedFloat64Array,
		wa: float, wb: float, wc: float) -> void:
	for v in [[pa, na, wa], [pb, nb, wb], [pc, nc, wc]]:
		var p: PackedFloat64Array = v[0]
		var n: PackedFloat64Array = v[1]
		out.append_array(PackedFloat64Array([p[0], p[1], p[2], n[0], n[1], n[2], col[0], col[1], col[2], v[2]]))


static func _cross(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]])


static func _segment(out: PackedFloat64Array, a: PackedFloat64Array, b: PackedFloat64Array, r0: float, r1: float,
		col: PackedFloat64Array, w0: float, w1: float, sides: int) -> void:
	var d := _norm3d(b[0] - a[0], b[1] - a[1], b[2] - a[2])
	var tmp := PackedFloat64Array([1, 0, 0]) if absf(d[1]) > 0.91 else PackedFloat64Array([0, 1, 0])
	var cr := _cross(tmp, d)
	var u := _norm3d(cr[0], cr[1], cr[2])
	var v := _cross(d, u)
	var ra: Array[PackedFloat64Array] = []
	var rb: Array[PackedFloat64Array] = []
	var rn: Array[PackedFloat64Array] = []
	for i in sides:
		var q := i * PI * 2.0 / sides
		var c := JsMath.js_cos(q)
		var s := JsMath.js_sin(q)
		var n := _norm3d(u[0] * c + v[0] * s, u[1] * c + v[1] * s, u[2] * c + v[2] * s)
		ra.append(PackedFloat64Array([a[0] + n[0] * r0, a[1] + n[1] * r0, a[2] + n[2] * r0]))
		rb.append(PackedFloat64Array([b[0] + n[0] * r1, b[1] + n[1] * r1, b[2] + n[2] * r1]))
		rn.append(n)
	for i in sides:
		var j := (i + 1) % sides
		_push_tri(out, ra[i], rb[j], rb[i], rn[i], rn[j], rn[i], col, w0, w1, w1)
		_push_tri(out, ra[i], ra[j], rb[j], rn[i], rn[j], rn[j], col, w0, w0, w1)


static func _clump(out: PackedFloat64Array, c: PackedFloat64Array, rx: float, ry: float, rz: float,
		col: PackedFloat64Array, wind: float, rng: Mulberry32) -> void:
	var ring: Array[PackedFloat64Array] = []
	var n := 8
	for i in n:
		var a := i * PI * 2.0 / n
		var k := 0.82 + rng.next() * 0.32
		var px := c[0] + JsMath.js_cos(a) * rx * k
		var py := c[1] + (rng.next() - 0.5) * ry * 0.18
		var pz := c[2] + JsMath.js_sin(a) * rz * k
		ring.append(PackedFloat64Array([px, py, pz]))
	var t0 := c[0] + (rng.next() - 0.5) * rx * 0.18
	var t1 := c[1] + ry
	var t2 := c[2] + (rng.next() - 0.5) * rz * 0.18
	var top := PackedFloat64Array([t0, t1, t2])
	var b0 := c[0] + (rng.next() - 0.5) * rx * 0.12
	var b1 := c[1] - ry * 0.72
	var b2 := c[2] + (rng.next() - 0.5) * rz * 0.12
	var bot := PackedFloat64Array([b0, b1, b2])
	var nrm := func(p: PackedFloat64Array) -> PackedFloat64Array:
		return _norm3d((p[0] - c[0]) / rx, (p[1] - c[1]) / ry, (p[2] - c[2]) / rz)
	for i in n:
		var j := (i + 1) % n
		_push_tri(out, top, ring[j], ring[i], nrm.call(top), nrm.call(ring[j]), nrm.call(ring[i]), col, wind, wind, wind)
		_push_tri(out, bot, ring[i], ring[j], nrm.call(bot), nrm.call(ring[i]), nrm.call(ring[j]), col, wind * 0.82, wind, wind)


## makeTreeTemplate: 0 latifoglia, 1 alto e stretto, 2 basso e largo.
static func tree_template(kind: int, seed_value: int) -> Template:
	var s := seed_value & 0xFFFFFFFF
	var rng := Mulberry32.new(s if s != 0 else 1)
	var d := PackedFloat64Array()
	var bark := PackedFloat64Array([0.29, 0.205, 0.125])
	var bark2 := PackedFloat64Array([0.22, 0.155, 0.095])
	var leaf_pal: Array[PackedFloat64Array] = [PackedFloat64Array([0.245, 0.345, 0.115]), PackedFloat64Array([0.285, 0.385, 0.135]), PackedFloat64Array([0.34, 0.405, 0.15])]
	var h := 4.5 if kind == 1 else (3.35 if kind == 2 else 3.85)
	var lean_x := (rng.next() - 0.5) * 0.28
	var lean_z := (rng.next() - 0.5) * 0.28
	var p0 := PackedFloat64Array([0, 0, 0])
	var p1 := PackedFloat64Array([lean_x * 0.28, h * 0.38, lean_z * 0.28])
	var p2 := PackedFloat64Array([lean_x * 0.72, h * 0.72, lean_z * 0.72])
	var p3 := PackedFloat64Array([lean_x, h, lean_z])
	_segment(d, p0, p1, 0.22, 0.17, bark2, 0.0, 0.08, 7)
	_segment(d, p1, p2, 0.17, 0.115, bark, 0.08, 0.28, 7)
	_segment(d, p2, p3, 0.115, 0.055, bark, 0.28, 0.65, 6)
	var branch_y := h * (0.48 if kind == 2 else 0.56)
	var nb := 3 if kind == 2 else 2
	for b in nb:
		var a := b * PI * 2.0 / nb + rng.next() * 0.8
		var st := PackedFloat64Array([lean_x * 0.42, branch_y + b * 0.24, lean_z * 0.42])
		var reach := 1.05 if kind == 2 else 0.78
		var e0 := st[0] + JsMath.js_cos(a) * reach
		var e1 := st[1] + 0.55 + rng.next() * 0.28
		var e2 := st[2] + JsMath.js_sin(a) * reach
		_segment(d, st, PackedFloat64Array([e0, e1, e2]), 0.085, 0.035, bark, 0.25, 0.68, 5)
	var base_y := h * 0.68 if kind == 1 else h * 0.62
	var count := 6 if kind == 2 else (4 if kind == 1 else 5)
	for i in count:
		var a := i * PI * 2.0 / count + rng.next() * 0.9
		var rad := 0.62 if kind == 1 else (0.90 if kind == 2 else 0.78)
		var cx := lean_x * 0.72 + JsMath.js_cos(a) * rad * (0.35 + rng.next() * 0.5)
		var cz := lean_z * 0.72 + JsMath.js_sin(a) * rad * (0.35 + rng.next() * 0.5)
		var cy := base_y + (rng.next() - 0.22) * (1.25 if kind == 1 else 1.05)
		var rx := rad * (0.72 + rng.next() * 0.28)
		var ry := 0.62 + rng.next() * 0.30
		var rz := rad * (0.68 + rng.next() * 0.32)
		var wind := 0.72 + rng.next() * 0.28
		_clump(d, PackedFloat64Array([cx, cy, cz]), rx, ry, rz, leaf_pal[(i + kind) % leaf_pal.size()], wind, rng)
	_clump(d, PackedFloat64Array([lean_x, h * 0.91, lean_z]), 0.52 if kind == 1 else 0.72, 0.70,
		0.50 if kind == 1 else 0.68, leaf_pal[kind % 3], 1.0, rng)
	var t := Template.new()
	t.data = PackedFloat32Array(Array(d))
	t.height = h
	return t


# ------------------------------------------------------------------ erba

## grassBlades: 7 valori per filo [x, z, seme, larghezza, altezza, y suolo, luce].
## Altezza negativa = ciuffo pendente sul bordo di un gradino.
static func grass_blades(w: WorldData, cx: int, cz: int, seed_value: int, density: float = 0.34) -> PackedFloat32Array:
	var rng := Mulberry32.new(seed_value * 31 + cx * 131 + cz * 7919)
	var sx := w.size_x
	var sz := w.size_z
	var out := PackedFloat64Array()
	var cell := density
	var cs := WorldData.CHUNK_SIZE
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for z in range(cz * cs, mini(sz, cz * cs + cs)):
		for x in range(cx * cs, mini(sx, cx * cs + cs)):
			var h := w.surface[z * sx + x]
			if w.get_block_xyz(x, h, z) != BlockCatalog.GRASS or w.get_block_xyz(x, h + 1, z) != BlockCatalog.AIR:
				continue
			var s := 15 if h + 1 >= w.size_y else w.sun[w.index(x, h + 1, z)]
			var veg := IsoNoise.fbm2(x * 0.055 + 31.2, z * 0.055 - 12.7, seed_value + 5, 2)
			var bg: Dictionary = Biomes.BIOMES[w.biome[z * sx + x] if not w.biome.is_empty() else 0]
			var keep_k: float = bg["grassKeep"]
			var h_k: float = bg["grassH"]
			var bz := cell * 0.5
			while bz < 1.0:
				var bx := cell * 0.5
				while bx < 1.0:
					var px := x + bx + (rng.next() - 0.5) * cell * 0.72
					var pz := z + bz + (rng.next() - 0.5) * cell * 0.72
					var keep := maxf(0.16, minf(1.0, 0.94 + (veg - 0.5) * 0.25)) * keep_k
					if rng.next() > keep:
						bx += cell
						continue
					var sd := rng.next()
					var bw := 0.38 + rng.next() * 0.10
					var bh := (0.20 + rng.next() * 0.08) * h_k
					out.append_array(PackedFloat64Array([px, pz, sd, bw, bh, h + 1, s / 15.0]))
					bx += cell
				bz += cell
			for dd in dirs:
				var nx := x + dd.x
				var nz := z + dd.y
				if nx < 0 or nz < 0 or nx >= sx or nz >= sz:
					continue
				if w.surface[nz * sx + nx] >= h:
					continue
				for k in 3:
					var t := (k + 0.5) / 3.0 + (rng.next() - 0.5) * 0.2
					var ex := x + 0.5 + dd.x * 0.53 + ((t - 0.5) if dd.y != 0 else 0.0)
					var ez := z + 0.5 + dd.y * 0.53 + ((t - 0.5) if dd.x != 0 else 0.0)
					var sd := rng.next()
					var bw := 0.42 + rng.next() * 0.10
					var bh := -(0.30 + rng.next() * 0.16)
					out.append_array(PackedFloat64Array([ex, ez, sd, bw, bh, h + 1, s / 15.0]))
	return PackedFloat32Array(Array(out))
