class_name Noise3Lattice
extends RefCounted
## noise3 accelerato per le passate a colonne (Grotte, Minerali): i valori di hash3 sui
## vertici interi si calcolano una volta sola in una griglia, poi per ogni colonna (x, z)
## si preparano le interpolazioni lungo x e per ogni y restano due lerp su y e uno su z.
## Le operazioni in virgola mobile sono le stesse di IsoNoise.noise3 nello stesso ordine
## (c00 = lerp x, c0 = lerp y, risultato = lerp z), quindi il risultato e' identico bit a bit.
## Fuori dalla griglia si ripiega su IsoNoise.noise3.

var seed_value: int
var x0: int
var y0: int
var z0: int
var nx: int
var ny: int
var nz: int
## hash3 dei vertici, indice ((yi - y0) * nz + (zi - z0)) * nx + (xi - x0).
var hashes := PackedFloat64Array()

## Colonna preparata: interpolazioni lungo x per zi (col_a) e zi + 1 (col_b), per livello yi.
var col_a := PackedFloat64Array()
var col_b := PackedFloat64Array()
var col_x := 0.0
var col_z := 0.0
var col_fz := 0.0
var col_ok := false


## Griglia per coordinate di rumore x in [x_lo, x_hi], y in [y_lo, y_hi], z in [z_lo, z_hi].
func _init(seed_v: int, x_lo: float, x_hi: float, y_lo: float, y_hi: float, z_lo: float, z_hi: float) -> void:
	seed_value = seed_v
	x0 = floori(x_lo)
	y0 = floori(y_lo)
	z0 = floori(z_lo)
	nx = floori(x_hi) - x0 + 2
	ny = floori(y_hi) - y0 + 2
	nz = floori(z_hi) - z0 + 2
	hashes.resize(nx * ny * nz)
	var k := 0
	for yi in ny:
		for zi in nz:
			for xi in nx:
				hashes[k] = IsoNoise.hash3(x0 + xi, y0 + yi, z0 + zi, seed_v)
				k += 1
	col_a.resize(ny)
	col_b.resize(ny)


## Prepara la colonna (x, z): stesse frazioni di noise3.
func prepare_column(x: float, z: float) -> void:
	col_x = x
	col_z = z
	var xf := floorf(x)
	var zf := floorf(z)
	var xi := int(xf) - x0
	var zi := int(zf) - z0
	col_ok = xi >= 0 and zi >= 0 and xi + 1 < nx and zi + 1 < nz
	if not col_ok:
		return
	var fx := x - xf
	fx = fx * fx * (3.0 - 2.0 * fx)
	var fz := z - zf
	col_fz = fz * fz * (3.0 - 2.0 * fz)
	var stride := nz * nx
	var base := zi * nx + xi
	for yi in ny:
		var k := yi * stride + base
		var a := hashes[k]
		col_a[yi] = a + (hashes[k + 1] - a) * fx
		var b := hashes[k + nx]
		col_b[yi] = b + (hashes[k + nx + 1] - b) * fx


## noise3(x, y, z) per la colonna preparata.
func at_y(y: float) -> float:
	var yf := floorf(y)
	var yi := int(yf) - y0
	if not col_ok or yi < 0 or yi + 1 >= ny:
		return IsoNoise.noise3(col_x, y, col_z, seed_value)
	var fy := y - yf
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a0 := col_a[yi]
	var b0 := col_b[yi]
	var c0 := a0 + (col_a[yi + 1] - a0) * fy
	var c1 := b0 + (col_b[yi + 1] - b0) * fy
	return c0 + (c1 - c0) * col_fz


## Righe precalcolate per le quote intere: row_k[y] = livello della griglia (-1 se fuori),
## row_f[y] = frazione smussata; ys[y] e' la coordinata di rumore (es. y / 5.0).
var row_k := PackedInt32Array()
var row_f := PackedFloat64Array()
var row_y := PackedFloat64Array()


func set_rows(ys: PackedFloat64Array) -> void:
	row_y = ys
	row_k.resize(ys.size())
	row_f.resize(ys.size())
	for j in ys.size():
		var yf := floorf(ys[j])
		var k := int(yf) - y0
		row_k[j] = k if k >= 0 and k + 1 < ny else -1
		var t := ys[j] - yf
		row_f[j] = t * t * (3.0 - 2.0 * t)


## Valore alla riga j per la colonna preparata (stesse operazioni di at_y).
func at_row(j: int) -> float:
	var k := row_k[j]
	if not col_ok or k < 0:
		return IsoNoise.noise3(col_x, row_y[j], col_z, seed_value)
	var fy := row_f[j]
	var a0 := col_a[k]
	var b0 := col_b[k]
	var c0 := a0 + (col_a[k + 1] - a0) * fy
	var c1 := b0 + (col_b[k + 1] - b0) * fy
	return c0 + (c1 - c0) * col_fz
