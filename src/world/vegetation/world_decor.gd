class_name WorldDecor
extends RefCounted
## Oggetti di scena del mondo fuori dall'arena (D-065, piano grafico F6 esteso):
## sassi, massi muschiosi, cespugli, macchie di fiori, felci, funghi, tronchi
## caduti, cespugli secchi del deserto. Solo grafica, come gli alberi: niente
## collisioni, spariscono se il blocco sotto viene tolto o la cella occupata.
## Vanno nelle stesse mesh dei gruppi di alberi (stesso materiale, nessuna
## chiamata di disegno in piu').
##
## Formato dei modelli: 11 float per vertice [pos3, normale3, colore3, vento,
## materiale]. Materiale (alfa del colore nello shader degli alberi):
## 1 = come gli alberi (foglie/corteccia), 0.8 = pietra, 0.6 = liscio (petali,
## funghi). Triangoli in senso antiorario visti da fuori, come i modelli degli
## alberi (il gruppo li gira per Godot).

const STRIDE := 11
const ROCK := 0
const BOULDER := 1
const BUSH := 2
const FLOWERS := 3
const FERN := 4
const MUSHROOM := 5
const LOG := 6
const DRY := 7
const KINDS := 8
const VARIANTS := 3

const MAT_TREE := 1.0
const MAT_STONE := 0.8
const MAT_PLAIN := 0.6

## Probabilita' per colonna e per bioma (Prato, Foresta, Savana, Deserto,
## Tundra, Vetta): [sasso, masso, cespuglio, fiori, felce, fungo, tronco, secco].
const DENSITY := [
	[0.012, 0.0030, 0.016, 0.060, 0.006, 0.000, 0.0008, 0.000],
	[0.010, 0.0035, 0.026, 0.014, 0.080, 0.024, 0.0050, 0.000],
	[0.006, 0.0015, 0.006, 0.006, 0.000, 0.000, 0.0000, 0.012],
	[0.008, 0.0020, 0.000, 0.000, 0.000, 0.000, 0.0000, 0.010],
	[0.020, 0.0050, 0.004, 0.006, 0.006, 0.000, 0.0010, 0.004],
	[0.022, 0.0070, 0.000, 0.000, 0.000, 0.000, 0.0000, 0.000],
]
## Margine attorno al centro dell'arena senza oggetti di scena.
const ARENA_CLEAR := 18


class Spot:
	extends RefCounted
	var x: float
	var y: float
	var z: float
	var kind: int
	var variant: int
	var rot: float
	var scale: float
	var seed_value: float
	var cell: Vector3i
	var dead := false


## Posti degli oggetti di scena: suolo d'erba, sabbia o pietra con aria sopra,
## lontano dall'arena e dai tronchi degli alberi.
static func spots(w: WorldData, opaque: PackedByteArray, seed_value: int, trees: Array, arena: Vector3i) -> Array:
	var rng := Mulberry32.new(seed_value + 4242)
	var out: Array = []
	var sx := w.size_x
	var sz := w.size_z
	var near_tree := PackedByteArray()
	near_tree.resize(sx * sz)
	for t: Vegetation.TreeSpot in trees:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var tx := floori(t.x) + dx
				var tz := floori(t.z) + dz
				if tx >= 0 and tz >= 0 and tx < sx and tz < sz:
					near_tree[tz * sx + tx] = 1 if dx == 0 and dz == 0 else maxi(near_tree[tz * sx + tx], 2)
	for z in range(2, sz - 2):
		for x in range(2, sx - 2):
			if arena.x >= 0 and absi(x - arena.x) <= ARENA_CLEAR and absi(z - arena.z) <= ARENA_CLEAR:
				continue
			if near_tree[z * sx + x] == 1:
				continue
			var h := w.surface[z * sx + x]
			var top := w.get_block_xyz(x, h, z)
			if top != BlockCatalog.GRASS and top != BlockCatalog.SAND and top != BlockCatalog.STONE:
				continue
			if w.get_block_xyz(x, h + 1, z) != BlockCatalog.AIR:
				continue
			var b := w.biome[z * sx + x] if not w.biome.is_empty() else 0
			var dens: Array = DENSITY[clampi(b, 0, DENSITY.size() - 1)]
			var r := rng.next()
			var kind := -1
			var acc := 0.0
			for k in KINDS:
				acc += float(dens[k])
				if r < acc:
					kind = k
					break
			if kind < 0:
				continue
			# Funghi solo all'ombra degli alberi; fiori e felci non sulla pietra.
			if kind == MUSHROOM and near_tree[z * sx + x] != 2:
				continue
			if top == BlockCatalog.STONE and kind != ROCK and kind != BOULDER:
				continue
			var s := Spot.new()
			s.x = x + 0.5 + (rng.next() - 0.5) * 0.4
			s.z = z + 0.5 + (rng.next() - 0.5) * 0.4
			s.y = h + 1.0
			s.kind = kind
			s.variant = floori(rng.next() * VARIANTS)
			s.rot = rng.next() * TAU
			s.scale = 0.85 + rng.next() * 0.35
			s.seed_value = 2.0 + rng.next()
			s.cell = Vector3i(x, h + 1, z)
			out.append(s)
	return out


## Ancora a posto: blocco pieno sotto, cella libera.
static func valid(w: WorldData, opaque: PackedByteArray, s: Spot) -> bool:
	var c := s.cell
	if not w.inside(c.x, c.y - 1, c.z):
		return false
	return opaque[w.get_block_xyz(c.x, c.y - 1, c.z)] == 1 and w.get_block_xyz(c.x, c.y, c.z) == BlockCatalog.AIR


## Modelli: KINDS x VARIANTS, indice kind * VARIANTS + variante.
static func templates(seed_value: int) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	for k in KINDS:
		for v in VARIANTS:
			var rng := Mulberry32.new((seed_value * 31 + k * 977 + v * 131) & 0x7FFFFFFF | 1)
			var d := PackedFloat32Array()
			match k:
				ROCK:
					_rock(d, rng, 0.30 + v * 0.07, 1 + v % 2)
				BOULDER:
					_rock(d, rng, 0.62 + v * 0.14, 2 + v % 2, true)
				BUSH:
					_bush(d, rng, 0.55 + v * 0.10)
				FLOWERS:
					_flowers(d, rng, v)
				FERN:
					_fern(d, rng)
				MUSHROOM:
					_mushrooms(d, rng, v)
				LOG:
					_log(d, rng, 1.3 + v * 0.35)
				DRY:
					_dry(d, rng)
			out.append(d)
	return out


# ------------------------------------------------------------------ modelli

## Scatola orientata: centro, mezze misure, rotazione attorno a Y e
## inclinazione attorno a X (prima l'inclinazione).
static func _box(d: PackedFloat32Array, c: Vector3, hs: Vector3, col: Color, wind: float, mat: float, yaw: float = 0.0, tilt: float = 0.0, top_col: Color = Color(0, 0, 0, 0)) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3(n.y, n.z, n.x)
		var v := n.cross(u)
		var ne := (n.abs() * hs)
		var fc := n * (ne.x + ne.y + ne.z)
		var ua := u.abs() * hs
		var va := v.abs() * hs
		var ue := ua.x + ua.y + ua.z
		var ve := va.x + va.y + va.z
		var pts := [fc + (-u * ue - v * ve), fc + (u * ue - v * ve), fc + (u * ue + v * ve), fc + (-u * ue + v * ve)]
		var wn := b * n
		var fcol := top_col if n == Vector3.UP and top_col.a > 0.0 else col
		if n == Vector3.DOWN:
			fcol = col.darkened(0.3)
		for i in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = c + b * (pts[i] as Vector3)
			d.append_array(PackedFloat32Array([p.x, p.y, p.z, wn.x, wn.y, wn.z, fcol.r, fcol.g, fcol.b, wind, mat]))


static func _tone(c: Color, rng: Mulberry32, amt: float) -> Color:
	var k := 1.0 + (rng.next() - 0.5) * amt
	return Color(c.r * k, c.g * k, c.b * k)


static func _rock(d: PackedFloat32Array, rng: Mulberry32, size: float, pieces: int, moss: bool = false) -> void:
	var base := Color(0.46, 0.44, 0.40)
	for i in pieces:
		var s := size * (1.0 - i * 0.28)
		var off := Vector3((rng.next() - 0.5) * size * 1.2, 0, (rng.next() - 0.5) * size * 1.2) if i > 0 else Vector3.ZERO
		var hs := Vector3(s * (0.8 + rng.next() * 0.4), s * (0.45 + rng.next() * 0.25), s * (0.7 + rng.next() * 0.4))
		var col := _tone(base, rng, 0.18)
		var top := col.lerp(Color(0.33, 0.45, 0.17), 0.65) if moss else col.lightened(0.08)
		# Affondato nel suolo, appena inclinato.
		_box(d, off + Vector3(0, hs.y * 0.6, 0), hs, col, 0.0, MAT_STONE, rng.next() * TAU, (rng.next() - 0.5) * 0.12, top)


static func _bush(d: PackedFloat32Array, rng: Mulberry32, r: float) -> void:
	var pal := [Color(0.20, 0.36, 0.11), Color(0.25, 0.42, 0.13), Color(0.30, 0.46, 0.15)]
	var n := 11 + int(rng.next() * 4)
	for i in n:
		var a := rng.next() * TAU
		var rr := r * sqrt(rng.next()) * 0.8
		var y := r * (0.25 + rng.next() * 0.6) * (1.0 - 0.4 * rr / r)
		var s := r * (0.20 + rng.next() * 0.14)
		var col: Color = pal[i % 3]
		col = col.lightened(0.12 * y / r)
		_box(d, Vector3(cos(a) * rr, y, sin(a) * rr), Vector3(s, s, s), col, 0.35 + 0.3 * y / r, MAT_TREE, rng.next())
	if rng.next() < 0.5:
		# Bacche rosse.
		for i in 4:
			var a := rng.next() * TAU
			_box(d, Vector3(cos(a) * r * 0.55, r * (0.5 + rng.next() * 0.4), sin(a) * r * 0.55), Vector3.ONE * 0.04, Color(0.78, 0.14, 0.12), 0.5, MAT_PLAIN)


static func _flowers(d: PackedFloat32Array, rng: Mulberry32, v: int) -> void:
	var petals := [Color(0.96, 0.94, 0.86), Color(0.98, 0.80, 0.24), Color(0.80, 0.46, 0.84), Color(0.92, 0.32, 0.28), Color(0.44, 0.58, 0.95)]
	var main: Color = petals[(v * 2) % petals.size()]
	var n := 5 + int(rng.next() * 4)
	for i in n:
		var p := Vector3((rng.next() - 0.5) * 0.7, 0, (rng.next() - 0.5) * 0.7)
		var h := 0.22 + rng.next() * 0.22
		_box(d, p + Vector3(0, h * 0.5, 0), Vector3(0.018, h * 0.5, 0.018), Color(0.26, 0.44, 0.14), 0.8, MAT_TREE)
		_box(d, p + Vector3(0.04, h * 0.35, 0), Vector3(0.04, 0.008, 0.02), Color(0.30, 0.50, 0.16), 0.7, MAT_TREE, rng.next() * TAU)
		var pc: Color = main if rng.next() < 0.7 else petals[int(rng.next() * petals.size())]
		_box(d, p + Vector3(0, h + 0.02, 0), Vector3(0.08, 0.03, 0.08), _tone(pc, rng, 0.1), 1.0, MAT_PLAIN, rng.next(), 0.0, pc.lightened(0.05))
		_box(d, p + Vector3(0, h + 0.055, 0), Vector3(0.03, 0.015, 0.03), Color(0.95, 0.75, 0.20), 1.0, MAT_PLAIN)


static func _fern(d: PackedFloat32Array, rng: Mulberry32) -> void:
	var n := 5 + int(rng.next() * 3)
	for i in n:
		var a := i * TAU / n + rng.next() * 0.5
		var l := 0.42 + rng.next() * 0.22
		var col := _tone(Color(0.22, 0.42, 0.13), rng, 0.2)
		var dir := Vector3(cos(a), 0, sin(a))
		# Fronda: tre segmenti che si piegano verso terra.
		var p := Vector3(0, 0.05, 0)
		for sgm in 3:
			var tilt := 0.5 + sgm * 0.35
			var q := p + dir * l * 0.33 * sin(tilt) + Vector3(0, l * 0.33 * cos(tilt), 0)
			var mid := (p + q) * 0.5
			_box(d, mid, Vector3(0.07 - sgm * 0.015, 0.008, l * 0.18), col.lightened(sgm * 0.06), 0.5 + sgm * 0.2, MAT_TREE, -a + PI * 0.5, -(PI * 0.5 - tilt))
			p = q


static func _mushrooms(d: PackedFloat32Array, rng: Mulberry32, v: int) -> void:
	var cap := Color(0.78, 0.18, 0.12) if v != 1 else Color(0.62, 0.42, 0.24)
	for i in 1 + int(rng.next() * 3):
		var p := Vector3((rng.next() - 0.5) * 0.4, 0, (rng.next() - 0.5) * 0.4)
		var h := 0.10 + rng.next() * 0.12
		var r := 0.07 + rng.next() * 0.06
		_box(d, p + Vector3(0, h * 0.5, 0), Vector3(r * 0.35, h * 0.5, r * 0.35), Color(0.90, 0.86, 0.76), 0.0, MAT_PLAIN)
		_box(d, p + Vector3(0, h + r * 0.3, 0), Vector3(r, r * 0.4, r), cap, 0.0, MAT_PLAIN, rng.next())
		if v != 1:
			_box(d, p + Vector3(r * 0.4, h + r * 0.72, 0), Vector3(0.015, 0.006, 0.015), Color(0.98, 0.96, 0.9), 0.0, MAT_PLAIN)
			_box(d, p + Vector3(-r * 0.3, h + r * 0.72, r * 0.4), Vector3(0.012, 0.006, 0.012), Color(0.98, 0.96, 0.9), 0.0, MAT_PLAIN)


static func _log(d: PackedFloat32Array, rng: Mulberry32, l: float) -> void:
	var bark := Color(0.30, 0.21, 0.13)
	var r := 0.17 + rng.next() * 0.05
	# Tronco a ottagono steso lungo X, con le facce di taglio chiare.
	for i in 8:
		var a := i * TAU / 8.0
		var c := Vector3(0, r + sin(a) * r * 0.78, cos(a) * r * 0.78)
		_box(d, c, Vector3(l * 0.5, r * 0.36, 0.02 + r * 0.2), _tone(bark, rng, 0.2), 0.0, MAT_TREE, 0.0, -a)
	_box(d, Vector3(l * 0.5, r, 0), Vector3(0.015, r * 0.85, r * 0.85), Color(0.66, 0.52, 0.34), 0.0, MAT_PLAIN)
	_box(d, Vector3(-l * 0.5, r, 0), Vector3(0.015, r * 0.85, r * 0.85), Color(0.66, 0.52, 0.34), 0.0, MAT_PLAIN)
	# Muschio e un ramo spezzato.
	_box(d, Vector3(l * 0.1, r * 1.85, 0), Vector3(l * 0.25, 0.03, r * 0.5), Color(0.30, 0.44, 0.16), 0.0, MAT_TREE)
	_box(d, Vector3(-l * 0.2, r * 1.7, r * 0.5), Vector3(0.03, 0.18, 0.03), bark, 0.0, MAT_TREE, 0.0, 0.6)


static func _dry(d: PackedFloat32Array, rng: Mulberry32) -> void:
	var col := Color(0.55, 0.43, 0.26)
	for i in 6:
		var a := rng.next() * TAU
		var l := 0.18 + rng.next() * 0.16
		var t := 0.35 + rng.next() * 0.5
		var dir := Vector3(cos(a), 0, sin(a))
		_box(d, dir * sin(t) * l * 0.5 + Vector3(0, cos(t) * l * 0.5, 0), Vector3(0.012, l * 0.5, 0.012), _tone(col, rng, 0.2), 0.4, MAT_TREE, -a + PI * 0.5, t)


## Triangoli di un oggetto nel gruppo (stessi array degli alberi).
static func append(s: Spot, tpl: PackedFloat32Array, light: float, pos: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, cus: PackedFloat32Array) -> void:
	var c := cos(s.rot)
	var sn := sin(s.rot)
	var n := tpl.size() / STRIDE
	for tri in range(0, n, 3):
		for k in [0, 2, 1]:
			var o: int = (tri + k) * STRIDE
			var px := tpl[o] * s.scale
			var py := tpl[o + 1] * s.scale
			var pz := tpl[o + 2] * s.scale
			pos.append(Vector3(c * px - sn * pz + s.x, py + s.y, sn * px + c * pz + s.z))
			nrm.append(Vector3(c * tpl[o + 3] - sn * tpl[o + 5], tpl[o + 4], sn * tpl[o + 3] + c * tpl[o + 5]))
			col.append(Color(tpl[o + 6], tpl[o + 7], tpl[o + 8], tpl[o + 10]))
			cus.append_array(PackedFloat32Array([tpl[o + 9], s.seed_value, s.y, light]))
