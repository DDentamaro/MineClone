class_name Fbm2Lattice
extends RefCounted
## fbm2 accelerato per le passate su tutte le colonne (Campi, Quote, Strati): i valori di
## hash3 (y = 0) di ogni ottava stanno in una griglia calcolata una volta. Ottave,
## trasformazioni delle coordinate (x*2.03+11.7, z*2.03+5.1) e interpolazioni sono quelle
## di IsoNoise.fbm2/noise2 nello stesso ordine: risultato identico bit a bit.
## Fuori dalla griglia si ripiega su IsoNoise.noise2.

var seed_value: int
var octaves: int
var ox := PackedInt32Array()
var oz := PackedInt32Array()
var onx := PackedInt32Array()
var onz := PackedInt32Array()
## Una griglia per ottava, indice (zi - oz) * onx + (xi - ox).
var grids: Array[PackedFloat64Array] = []


## Griglie per coordinate d'ingresso x in [x_lo, x_hi], z in [z_lo, z_hi].
func _init(seed_v: int, oct: int, x_lo: float, x_hi: float, z_lo: float, z_hi: float) -> void:
	seed_value = seed_v
	octaves = oct
	var xa := x_lo
	var xb := x_hi
	var za := z_lo
	var zb := z_hi
	for i in oct:
		var gx := floori(xa)
		var gz := floori(za)
		var w := floori(xb) - gx + 2
		var h := floori(zb) - gz + 2
		ox.append(gx)
		oz.append(gz)
		onx.append(w)
		onz.append(h)
		var g := PackedFloat64Array()
		g.resize(w * h)
		var s := seed_v + i * 77
		for zi in h:
			for xi in w:
				g[zi * w + xi] = IsoNoise.hash3(gx + xi, 0, gz + zi, s)
		grids.append(g)
		xa = xa * 2.03 + 11.7
		xb = xb * 2.03 + 11.7
		za = za * 2.03 + 5.1
		zb = zb * 2.03 + 5.1


func fbm2(x: float, z: float) -> float:
	var f := 0.0
	var a := 0.5
	var s := 0.0
	for i in octaves:
		var xf := floorf(x)
		var zf := floorf(z)
		var w := onx[i]
		var xi := int(xf) - ox[i]
		var zi := int(zf) - oz[i]
		var n := 0.0
		if xi >= 0 and zi >= 0 and xi + 1 < w and zi + 1 < onz[i]:
			var g := grids[i]
			var fx := x - xf
			var fz := z - zf
			fx = fx * fx * (3.0 - 2.0 * fx)
			fz = fz * fz * (3.0 - 2.0 * fz)
			var k := zi * w + xi
			var ha := g[k]
			var hb := g[k + 1]
			var hc := g[k + w]
			var hd := g[k + w + 1]
			n = (ha + (hb - ha) * fx) * (1.0 - fz) + (hc + (hd - hc) * fx) * fz
		else:
			n = IsoNoise.noise2(x, z, seed_value + i * 77)
		f += a * n
		s += a
		x = x * 2.03 + 11.7
		z = z * 2.03 + 5.1
		a *= 0.5
	return f / s


## fbm2 su tutta la griglia xs x zs (risultato indice iz * xs.size() + ix). Le coordinate
## di ogni ottava dipendono solo da x o solo da z, quindi frazioni e indici si calcolano
## per asse; per cella restano le stesse operazioni di fbm2(), nello stesso ordine.
func field(xs: PackedFloat64Array, zs: PackedFloat64Array) -> PackedFloat64Array:
	var nxs := xs.size()
	var nzs := zs.size()
	var out := PackedFloat64Array()
	out.resize(nxs * nzs)
	var ok := true
	var ax: Array[PackedInt32Array] = []
	var afx: Array[PackedFloat64Array] = []
	var az: Array[PackedInt32Array] = []
	var afz: Array[PackedFloat64Array] = []
	var cx := xs.duplicate()
	var cz := zs.duplicate()
	for i in octaves:
		var ki := PackedInt32Array()
		var kf := PackedFloat64Array()
		ki.resize(nxs)
		kf.resize(nxs)
		for j in nxs:
			var x := cx[j]
			var xf := floorf(x)
			var t := x - xf
			ki[j] = int(xf) - ox[i]
			kf[j] = t * t * (3.0 - 2.0 * t)
			if ki[j] < 0 or ki[j] + 1 >= onx[i]:
				ok = false
			cx[j] = x * 2.03 + 11.7
		ax.append(ki)
		afx.append(kf)
		var zi := PackedInt32Array()
		var zf2 := PackedFloat64Array()
		zi.resize(nzs)
		zf2.resize(nzs)
		for j in nzs:
			var z := cz[j]
			var zf := floorf(z)
			var t := z - zf
			zi[j] = int(zf) - oz[i]
			zf2[j] = t * t * (3.0 - 2.0 * t)
			if zi[j] < 0 or zi[j] + 1 >= onz[i]:
				ok = false
			cz[j] = z * 2.03 + 5.1
		az.append(zi)
		afz.append(zf2)
	if not ok:
		for jz in nzs:
			for jx in nxs:
				out[jz * nxs + jx] = fbm2(xs[jx], zs[jz])
		return out
	# Somma dei pesi: identica per tutte le celle (stessa sequenza di a).
	var s := 0.0
	var a := 0.5
	for i in octaves:
		s += a
		a *= 0.5
	a = 0.5
	for i in octaves:
		var g := grids[i]
		var w := onx[i]
		var ki := ax[i]
		var kf := afx[i]
		var zi := az[i]
		var zf := afz[i]
		for jz in nzs:
			var row := zi[jz] * w
			var fz := zf[jz]
			var gz := 1.0 - fz
			var o := jz * nxs
			for jx in nxs:
				var k := row + ki[jx]
				var fx := kf[jx]
				var ha := g[k]
				var hc := g[k + w]
				out[o + jx] += a * ((ha + (g[k + 1] - ha) * fx) * gz + (hc + (g[k + w + 1] - hc) * fx) * fz)
		a *= 0.5
	for k in out.size():
		out[k] = out[k] / s
	return out


## Coordinate k * scala + scarto per k = 0..n-1 (come x/scala+scarto in JS: divisione, poi somma).
static func axis(n: int, divisor: float, offset: float) -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(n)
	for k in n:
		a[k] = k / divisor + offset
	return a
