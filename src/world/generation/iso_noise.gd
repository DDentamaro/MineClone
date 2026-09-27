class_name IsoNoise
extends RefCounted
## Rumore del prototipo (core.js r.15-27) con parita' bit a bit: hash3, smooth,
## noise2, noise3, fbm2, subSeed.
##
## hash3 in JS somma i prodotti in double e poi fa `|0`; poi moltiplica un int32 per
## 1274126177 ancora in double (non Math.imul), con arrotondamento sopra 2^53.
## Percorso veloce: se seme e coordinate sono piccoli (|seme| < 2^22, |coord| < 2^20)
## la somma in double e' esatta e coincide con quella intera a 64 bit; altrimenti si
## ripete il calcolo in double come JS. Il secondo prodotto si fa sempre in double.
## Il nome IsoNoise evita il conflitto con la classe Noise di Godot.

const _U32 := 0xFFFFFFFF
const _FAST_SEED := 1 << 22
const _FAST_COORD := 1 << 20


static func mulberry32(seed_value: int) -> Mulberry32:
	return Mulberry32.new(seed_value)


## subSeed(seed, name) (core.js r.52): FNV-like con Math.imul, risultato uint32.
static func sub_seed(seed_value: int, name: String) -> int:
	var h := JsMath.i32(seed_value)
	for i in name.length():
		h = JsMath.imul(JsMath.i32(h) ^ name.unicode_at(i), 0x9E3779B1) & _U32
	return h & _U32


static func hash3(x: int, y: int, z: int, seed_value: int) -> float:
	var h := 0
	if absi(seed_value) < _FAST_SEED and absi(x) < _FAST_COORD and absi(y) < _FAST_COORD and absi(z) < _FAST_COORD:
		h = (x * 374761393 + y * 668265263 + z * 2147483647 + seed_value * 1013904223) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
	else:
		h = JsMath.f_to_i32(float(x) * 374761393.0 + float(y) * 668265263.0 + float(z) * 2147483647.0 + float(seed_value) * 1013904223.0)
	h = h ^ ((h & _U32) >> 13)
	h = int(float(h) * 1274126177.0) & _U32
	return float(h ^ (h >> 16)) / 4294967296.0


static func smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func noise2(x: float, z: float, seed_value: int) -> float:
	var xf := floorf(x)
	var zf := floorf(z)
	var fx := x - xf
	var fz := z - zf
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var xi := int(xf)
	var zi := int(zf)
	var a := 0.0
	var b := 0.0
	var c := 0.0
	var d := 0.0
	if absi(seed_value) < _FAST_SEED and absi(xi) < _FAST_COORD - 1 and absi(zi) < _FAST_COORD - 1:
		# hash3 inline (percorso veloce, y = 0): stesso risultato della funzione.
		var s := seed_value * 1013904223
		var bx := xi * 374761393
		var bz := zi * 2147483647
		var h := (bx + bz + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		a = float(h ^ (h >> 16)) / 4294967296.0
		h = (bx + 374761393 + bz + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		b = float(h ^ (h >> 16)) / 4294967296.0
		h = (bx + bz + 2147483647 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		c = float(h ^ (h >> 16)) / 4294967296.0
		h = (bx + 374761393 + bz + 2147483647 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		d = float(h ^ (h >> 16)) / 4294967296.0
	else:
		a = hash3(xi, 0, zi, seed_value)
		b = hash3(xi + 1, 0, zi, seed_value)
		c = hash3(xi, 0, zi + 1, seed_value)
		d = hash3(xi + 1, 0, zi + 1, seed_value)
	return (a + (b - a) * fx) * (1.0 - fz) + (c + (d - c) * fx) * fz


static func noise3(x: float, y: float, z: float, seed_value: int) -> float:
	var xf := floorf(x)
	var yf := floorf(y)
	var zf := floorf(z)
	var fx := x - xf
	var fy := y - yf
	var fz := z - zf
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var xi := int(xf)
	var yi := int(yf)
	var zi := int(zf)
	if absi(seed_value) < _FAST_SEED and absi(xi) < _FAST_COORD - 1 and absi(yi) < _FAST_COORD - 1 and absi(zi) < _FAST_COORD - 1:
		# 8 hash3 inline sui vertici del cubo (percorso veloce).
		var s := seed_value * 1013904223
		var x0 := xi * 374761393
		var x1 := x0 + 374761393
		var y0 := yi * 668265263
		var y1 := y0 + 668265263
		var z0 := zi * 2147483647
		var z1 := z0 + 2147483647
		var h := (x0 + y0 + z0 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		var h000 := float(h ^ (h >> 16)) / 4294967296.0
		h = (x1 + y0 + z0 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		var h100 := float(h ^ (h >> 16)) / 4294967296.0
		h = (x0 + y1 + z0 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		var h010 := float(h ^ (h >> 16)) / 4294967296.0
		h = (x1 + y1 + z0 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		var h110 := float(h ^ (h >> 16)) / 4294967296.0
		h = (x0 + y0 + z1 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		var h001 := float(h ^ (h >> 16)) / 4294967296.0
		h = (x1 + y0 + z1 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		var h101 := float(h ^ (h >> 16)) / 4294967296.0
		h = (x0 + y1 + z1 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		var h011 := float(h ^ (h >> 16)) / 4294967296.0
		h = (x1 + y1 + z1 + s) & _U32
		if h >= 0x80000000:
			h -= 0x100000000
		h = int(float(h ^ ((h & _U32) >> 13)) * 1274126177.0) & _U32
		var h111 := float(h ^ (h >> 16)) / 4294967296.0
		var q00 := h000 + (h100 - h000) * fx
		var q10 := h010 + (h110 - h010) * fx
		var q01 := h001 + (h101 - h001) * fx
		var q11 := h011 + (h111 - h011) * fx
		var q0 := q00 + (q10 - q00) * fy
		var q1 := q01 + (q11 - q01) * fy
		return q0 + (q1 - q0) * fz
	var c00 := _lerp_h(xi, yi, zi, xi + 1, yi, zi, fx, seed_value)
	var c10 := _lerp_h(xi, yi + 1, zi, xi + 1, yi + 1, zi, fx, seed_value)
	var c01 := _lerp_h(xi, yi, zi + 1, xi + 1, yi, zi + 1, fx, seed_value)
	var c11 := _lerp_h(xi, yi + 1, zi + 1, xi + 1, yi + 1, zi + 1, fx, seed_value)
	var c0 := c00 + (c10 - c00) * fy
	var c1 := c01 + (c11 - c01) * fy
	return c0 + (c1 - c0) * fz


static func _lerp_h(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, f: float, seed_value: int) -> float:
	var a := hash3(x0, y0, z0, seed_value)
	var b := hash3(x1, y1, z1, seed_value)
	return a + (b - a) * f


static func fbm2(x: float, z: float, seed_value: int, octaves: int) -> float:
	var f := 0.0
	var a := 0.5
	var s := 0.0
	for i in octaves:
		f += a * noise2(x, z, seed_value + i * 77)
		s += a
		x = x * 2.03 + 11.7
		z = z * 2.03 + 5.1
		a *= 0.5
	return f / s
