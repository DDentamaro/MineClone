class_name FluidSystem
extends RefCounted
## Simulazione voxel dei fluidi v0_64 (core.js r.482-599, senza meshFluid): livelli 1..8,
## SOURCE = 16, FALLING = 32. Modello deterministico alimentato dalle sorgenti.
##
## Funzioni statiche su WorldData. Lo stato per mondo (coda, chunk sporchi, orologio)
## sta in WorldData (fluid_active, fluid_queue, fluid_dirty, fluid_clock,
## fluid_renew_sources): i Set di JS diventano Dictionary con valore true, che in Godot 4
## conservano l'ordine d'inserimento come i Set/Map di JS (anche dopo erase + reinserimento).
## Da quest'ordine dipende il determinismo di step_fluid.
## Differenze di forma: fluid_velocity restituisce PackedFloat64Array [x, y, z] (i
## Vector3 di Godot sono a 32 bit); step_fluid restituisce le coppie [i, val] appiattite.

const SOURCE := 16
const FALLING := 32
const MAX := 8
const TICK := 0.25
const SEARCH := 4
const FALL_LIP_HEIGHT := 0.5

const AIR := 0
const WATER := 15
## ISO_CORE.SOLID come maschera di bit (id 1-8 e 11-14); indipendente dal catalogo.
const SOLID_BITS := 0x79FE

const DIR_X: Array[int] = [1, -1, 0, 0]
const DIR_Z: Array[int] = [0, 0, 1, -1]
const _WAKE: Array[Vector3i] = [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
	Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]
const _DIRTY: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(-1, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1)]
const _CORNER: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]
const _INF_SCORE := 1 << 30


static func is_solid_id(id: int) -> bool:
	return (SOLID_BITS >> id) & 1 == 1


## World.isSolidAt: sotto il mondo e' solido, fuori e' aria.
static func is_solid_at(w: WorldData, x: int, y: int, z: int) -> bool:
	if y < 0:
		return true
	if x < 0 or z < 0 or x >= w.size_x or y >= w.size_y or z >= w.size_z:
		return false
	return (SOLID_BITS >> w.blocks[(y * w.size_z + z) * w.size_x + x]) & 1 == 1


static func fluid_at(w: WorldData, x: int, y: int, z: int) -> int:
	if x < 0 or y < 0 or z < 0 or x >= w.size_x or y >= w.size_y or z >= w.size_z or w.fluid.is_empty():
		return 0
	return w.fluid[(y * w.size_z + z) * w.size_x + x]


static func fluid_pass(w: WorldData, x: int, y: int, z: int) -> bool:
	if x < 0 or y < 0 or z < 0 or x >= w.size_x or y >= w.size_y or z >= w.size_z:
		return false
	var b := w.blocks[(y * w.size_z + z) * w.size_x + x]
	return b == AIR or b == WATER


static func authored_fall(w: WorldData, x: int, y: int, z: int) -> bool:
	if w.waterfall_mask.is_empty() or x < 0 or z < 0 or x >= w.size_x or z >= w.size_z:
		return false
	var c := z * w.size_x + x
	var b := w.waterfall_base[c]
	var t := w.waterfall_top[c]
	return w.waterfall_mask[c] != 0 and b > 0 and t > 0 and y >= b and y < t


## fluidDirty(W, x, z): segna i chunk colonna (16x16) attorno a (x, z).
static func mark_dirty(w: WorldData, x: int, z: int) -> void:
	for d in _DIRTY:
		var xx := x + d.x
		var zz := z + d.y
		if xx >= 0 and zz >= 0 and xx < w.size_x and zz < w.size_z:
			w.fluid_dirty[Vector2i(xx >> 4, zz >> 4)] = true


static func wake_fluid(w: WorldData, x: int, y: int, z: int) -> void:
	if not w.fluid_active:
		return
	var q := w.fluid_queue
	var sx := w.size_x
	var sy := w.size_y
	var sz := w.size_z
	for d in _WAKE:
		var xx := x + d.x
		var yy := y + d.y
		var zz := z + d.z
		if xx >= 0 and yy >= 0 and zz >= 0 and xx < sx and yy < sy and zz < sz:
			q[(yy * sz + zz) * sx + xx] = true


static func fluid_height(w: WorldData, x: int, y: int, z: int) -> float:
	var f := fluid_at(w, x, y, z)
	if f == 0:
		return 0.0
	if fluid_at(w, x, y + 1, z) != 0:
		return 1.0
	if f & FALLING:
		return FALL_LIP_HEIGHT
	return float(f & 15) / 9.0


## Altezza condivisa dello spigolo (x, z) di una cella a quota y.
static func fluid_corner(w: WorldData, x: int, y: int, z: int) -> float:
	var sum := 0.0
	var weight := 0.0
	var air := 0
	var fall := false
	for d in _CORNER:
		var xx := x + d.x
		var zz := z + d.y
		var f := fluid_at(w, xx, y, zz)
		if f != 0:
			var h := fluid_height(w, xx, y, zz)
			if h == 1.0:
				return 1.0
			var wt := 10.0 if (f & 15) >= 8 else 1.0
			sum += h * wt
			weight += wt
			if f & FALLING:
				fall = true
		elif fluid_pass(w, xx, y, zz):
			air += 1
	if not fall:
		weight += air
	if weight == 0.0:
		return 0.0
	return maxf(FALL_LIP_HEIGHT if fall else 0.0, sum / weight)


static func fluid_surface(w: WorldData, x: float, y: int, z: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var u := x - ix
	var v := z - iz
	var a := fluid_corner(w, ix, y, iz)
	var b := fluid_corner(w, ix + 1, y, iz)
	var c := fluid_corner(w, ix + 1, y, iz + 1)
	var d := fluid_corner(w, ix, y, iz + 1)
	if v <= u:
		return y + (a + (b - a) * u + (c - b) * v)
	return y + (a + (c - d) * u + (d - a) * v)


## Velocita' della corrente [x, y, z] (double).
static func fluid_velocity(w: WorldData, x: int, y: int, z: int) -> PackedFloat64Array:
	var f := fluid_at(w, x, y, z)
	if f == 0:
		return PackedFloat64Array([0.0, 0.0, 0.0])
	var vy := -2.5 if f & FALLING else 0.0
	var vx := 0.0
	var vz := 0.0
	var h := float(f & 15) / 9.0
	if not w.water_guide.is_empty():
		var c := (z * w.size_x + x) * 2
		var gx := w.water_guide.decode_s8(c) / 127.0
		var gz := w.water_guide.decode_s8(c + 1) / 127.0
		if JsMath.js_hypot(gx, gz) > 0.1:
			return PackedFloat64Array([gx * 0.72, vy, gz * 0.72])
	for d in 4:
		var dx := DIR_X[d]
		var dz := DIR_Z[d]
		var n := fluid_at(w, x + dx, y, z + dz)
		var dh := 0.0
		if n != 0:
			dh = h - float(n & 15) / 9.0
		elif fluid_pass(w, x + dx, y, z + dz):
			var below := fluid_at(w, x + dx, y - 1, z + dz)
			if below != 0:
				dh = h + 1.0 - float(below & 15) / 9.0
			elif fluid_pass(w, x + dx, y - 1, z + dz):
				dh = h + 1.0
			else:
				dh = h
		vx += dx * dh
		vz += dz * dh
	var ln := JsMath.js_hypot(vx, vz)
	if ln > 1e-6:
		return PackedFloat64Array([vx / ln * 0.72, vy, vz / ln * 0.72])
	return PackedFloat64Array([0.0, vy, 0.0])


static func refresh_water_column(w: WorldData, x: int, z: int) -> void:
	if w.water_level.is_empty():
		return
	var sx := w.size_x
	var plane := sx * w.size_z
	var col := z * sx + x
	var lv := 0
	for y in range(w.size_y - 1, -1, -1):
		if w.blocks[y * plane + col] == WATER:
			lv = y + 1
			break
	_apply_column(w, x, z, lv)


## refreshWaterColumn su tutte le colonne (ordine z, x come initFluid). Le quote dell'acqua
## si ricavano scorrendo solo le celle d'acqua (find nativo, indici crescenti = y crescente).
@warning_ignore("integer_division")
static func refresh_all_columns(w: WorldData) -> void:
	if w.water_level.is_empty():
		return
	var sx := w.size_x
	var plane := sx * w.size_z
	var top := PackedInt32Array()
	top.resize(plane)
	var bl := w.blocks
	var i := bl.find(WATER)
	while i != -1:
		top[i % plane] = i / plane + 1
		i = bl.find(WATER, i + 1)
	for z in w.size_z:
		for x in sx:
			_apply_column(w, x, z, top[z * sx + x])


static func _apply_column(w: WorldData, x: int, z: int, lv: int) -> void:
	var sx := w.size_x
	var col := z * sx + x
	w.water_level[col] = lv
	if not w.water_flow.is_empty():
		var vx := 0.0
		var vz := 0.0
		if lv != 0 and not w.fluid.is_empty():
			var v := fluid_velocity(w, x, lv - 1, z)
			vx = v[0]
			vz = v[2]
		w.water_flow[col * 2] = vx
		w.water_flow[col * 2 + 1] = vz
	if not w.water_bodies.is_empty():
		if lv == 0:
			w.water_bodies[col] = 0
		elif w.water_bodies[col] == 0:
			var id := 0
			for d in 4:
				var xx := x + DIR_X[d]
				var zz := z + DIR_Z[d]
				if xx >= 0 and zz >= 0 and xx < sx and zz < w.size_z:
					var q := w.water_bodies[zz * sx + xx]
					if q != 0 and (id == 0 or q < id):
						id = q
			w.water_bodies[col] = id if id != 0 else 1


## Etichetta le componenti connesse (4-vicinato) delle colonne bagnate.
@warning_ignore("integer_division")
static func label_water(w: WorldData) -> void:
	var sx := w.size_x
	var sz := w.size_z
	var n := sx * sz
	var ids := PackedInt32Array()
	ids.resize(n)
	w.water_bodies = ids
	var wl := w.water_level
	if wl.is_empty():
		return
	var q := PackedInt32Array()
	q.resize(n)
	var id := 0
	for i in n:
		if wl[i] == 0 or ids[i] != 0:
			continue
		var a := 0
		var b := 0
		q[b] = i
		b += 1
		id += 1
		ids[i] = id
		while a < b:
			var c := q[a]
			a += 1
			var x := c % sx
			var z := c / sx
			var nb: Array[int] = [
				c - 1 if x != 0 else -1, c + 1 if x < sx - 1 else -1,
				c - sx if z != 0 else -1, c + sx if z < sz - 1 else -1]
			for j in nb:
				if j >= 0 and wl[j] != 0 and ids[j] == 0:
					ids[j] = id
					q[b] = j
					b += 1


## fieldHeight(world, x, z) senza yRef: faccia superiore del solido piu' alto (core.js r.301).
static func field_height(w: WorldData, x: float, z: float) -> int:
	var ix := floori(x)
	var iz := floori(z)
	if ix < 0 or iz < 0 or ix >= w.size_x or iz >= w.size_z:
		return 0
	for y in range(w.size_y - 1, -1, -1):
		if is_solid_id(w.blocks[(y * w.size_z + iz) * w.size_x + ix]):
			return y + 1
	return 0


## Campiona l'acqua nel punto (x, y, z): chiavi come l'oggetto JS (wet, level, depth,
## floor, immersion, flowX, flowY, flowZ, body, falling).
static func sample_water(w: WorldData, x: float, y: float, z: float) -> Dictionary:
	var xi := floori(x)
	var zi := floori(z)
	var dry := {"wet": false, "level": 0.0, "depth": 0.0, "immersion": 0.0, "flowX": 0.0,
		"flowY": 0.0, "flowZ": 0.0, "body": 0, "falling": false}
	if xi < 0 or zi < 0 or xi >= w.size_x or zi >= w.size_z or w.water_level.is_empty():
		return dry
	var col := zi * w.size_x + xi
	if w.fluid.is_empty():
		# Compatibilita' con mondi senza metadati dei fluidi.
		var lv := w.water_level[col]
		if lv == 0:
			return dry
		var fl := field_height(w, x, z)
		var level := lv - 0.2
		var depth := maxf(0.0, level - fl)
		if depth <= 0.02 or y + 1.4 < fl:
			return dry
		dry["wet"] = true
		dry["level"] = level
		dry["depth"] = depth
		dry["floor"] = fl
		dry["immersion"] = maxf(0.0, minf(depth, level - y))
		dry["body"] = w.water_bodies[col] if not w.water_bodies.is_empty() else 1
		return dry
	var hit := -1
	var cy := maxi(0, mini(w.size_y - 1, floori(y + 0.65)))
	if fluid_at(w, xi, cy, zi) != 0:
		hit = cy
	else:
		var yy := cy
		while yy >= maxi(0, floori(y - 2.0)):
			if is_solid_at(w, xi, yy, zi):
				break
			if fluid_at(w, xi, yy, zi) != 0:
				hit = yy
				break
			yy -= 1
		if hit < 0:
			yy = cy + 1
			while yy <= mini(w.size_y - 1, floori(y + 1.35)):
				if is_solid_at(w, xi, yy, zi):
					break
				if fluid_at(w, xi, yy, zi) != 0:
					hit = yy
					break
				yy += 1
	if hit < 0:
		return dry
	var lo := hit
	var hi := hit
	while lo > 0 and fluid_at(w, xi, lo - 1, zi) != 0:
		lo -= 1
	while hi < w.size_y - 1 and fluid_at(w, xi, hi + 1, zi) != 0:
		hi += 1
	var surf := fluid_surface(w, x, hi, z)
	var dep := surf - lo
	var v := fluid_velocity(w, xi, hit, zi)
	var body := 1
	if not w.water_bodies.is_empty() and w.water_bodies[col] != 0:
		body = w.water_bodies[col]
	return {"wet": true, "level": surf, "depth": dep, "floor": lo,
		"immersion": maxf(0.0, minf(dep, surf - y)), "flowX": v[0], "flowY": v[1], "flowZ": v[2],
		"body": body, "falling": (fluid_at(w, xi, hit, zi) & FALLING) != 0}


@warning_ignore("integer_division")
## initFluid(W, data): con `data` vuoto crea i livelli dai blocchi d'acqua (sorgente 24,
## cascata disegnata 40), sveglia le celle, ricalcola le colonne ed etichetta i corpi.
static func init_fluid(w: WorldData, data: PackedByteArray = PackedByteArray()) -> void:
	var sx := w.size_x
	var sy := w.size_y
	var sz := w.size_z
	var fresh := data.is_empty()
	if fresh:
		var f := PackedByteArray()
		f.resize(sx * sy * sz)
		w.fluid = f
	else:
		w.fluid = data
	w.fluid_queue = {}
	w.fluid_dirty = {}
	w.fluid_clock = 0.0
	w.fluid_renew_sources = true
	w.fluid_active = true
	if w.water_level.is_empty():
		w.water_level.resize(sx * sz)
	if w.water_flow.is_empty():
		w.water_flow.resize(sx * sz * 2)
	var fl := w.fluid
	var bl := w.blocks
	var plane := sx * sz
	if fresh:
		# Solo le celle d'acqua possono ricevere un livello: find nativo in ordine d'indice
		# (lo stesso ordine y, z, x del ciclo del prototipo).
		var i := bl.find(WATER)
		while i != -1:
			var y := i / plane
			var r := i - y * plane
			var z := r / sx
			var x := r - z * sx
			fl[i] = 40 if authored_fall(w, x, y, z) else 24
			wake_fluid(w, x, y, z)
			mark_dirty(w, x, z)
			i = bl.find(WATER, i + 1)
	else:
		var i := 0
		for y in sy:
			for z in sz:
				for x in sx:
					if fl[i] != 0:
						wake_fluid(w, x, y, z)
						mark_dirty(w, x, z)
					i += 1
	refresh_all_columns(w)
	label_water(w)


## editFluid: dopo un edit di blocco, rimette o toglie la sorgente e sveglia i dintorni.
static func edit_fluid(w: WorldData, x: int, y: int, z: int, id: int) -> void:
	if w.fluid.is_empty():
		return
	w.fluid[w.index(x, y, z)] = 24 if id == WATER else 0
	wake_fluid(w, x, y, z)
	mark_dirty(w, x, z)
	for yy in range(y - 1, y + 2):
		for dz in range(-5, 6):
			for dx in range(-5, 6):
				if absi(dx) + absi(dz) <= 5 and fluid_at(w, x + dx, yy, z + dz) != 0:
					wake_fluid(w, x + dx, yy, z + dz)


## Direzioni preferite (bit d = WATER_DIRS[d]) verso l'apertura in discesa piu' vicina
## entro SEARCH celle. `cache` e' la Map del tick (chiave indice cella).
static func fluid_spread(w: WorldData, x: int, y: int, z: int, cache: Dictionary) -> int:
	var key := w.index(x, y, z)
	if cache.has(key):
		return int(cache[key])
	var scores: Array[int] = [0, 0, 0, 0]
	for d in 4:
		var nx := x + DIR_X[d]
		var nz := z + DIR_Z[d]
		if not fluid_pass(w, nx, y, nz) or (fluid_at(w, nx, y, nz) & SOURCE):
			scores[d] = _INF_SCORE
			continue
		var qx: Array[int] = [nx]
		var qz: Array[int] = [nz]
		var qd: Array[int] = [0]
		var seen := {Vector2i(x, z): true, Vector2i(nx, nz): true}
		var score := 99
		var k := 0
		while k < qx.size():
			var xx := qx[k]
			var zz := qz[k]
			var dist := qd[k]
			k += 1
			var down := fluid_at(w, xx, y - 1, zz)
			if fluid_pass(w, xx, y - 1, zz) and not (down & SOURCE):
				score = dist
				break
			if dist >= SEARCH - 1:
				continue
			for e in 4:
				var a := xx + DIR_X[e]
				var b := zz + DIR_Z[e]
				var sk := Vector2i(a, b)
				if not seen.has(sk) and fluid_pass(w, a, y, b) and not (fluid_at(w, a, y, b) & SOURCE):
					seen[sk] = true
					qx.append(a)
					qz.append(b)
					qd.append(dist + 1)
		scores[d] = score
	var mn := mini(mini(scores[0], scores[1]), mini(scores[2], scores[3]))
	var mask := 0
	if mn < _INF_SCORE:
		for d in 4:
			if scores[d] == mn:
				mask |= 1 << d
	cache[key] = mask
	return mask


## Un tick: elabora fino a `budget` celle della coda (in ordine d'inserimento), poi
## applica gli aggiornamenti. Restituisce [i0, v0, i1, v1, ...].
@warning_ignore("integer_division")
static func step_fluid(w: WorldData, budget: int = 6000) -> PackedInt32Array:
	var updates := PackedInt32Array()
	if not w.fluid_active or w.fluid_queue.is_empty():
		return updates
	var work := PackedInt32Array()
	var queue := w.fluid_queue
	for key: int in queue.keys():
		work.append(key)
		queue.erase(key)
		if work.size() >= budget:
			break
	var cache := {}
	var sx := w.size_x
	var xz := sx * w.size_z
	var fl := w.fluid
	var renew := w.fluid_renew_sources
	for i in work:
		var y := i / xz
		var z := (i - y * xz) / sx
		var x := i % sx
		var old := fl[i]
		var val := 0
		if fluid_pass(w, x, y, z):
			if old & SOURCE:
				val = 24
			else:
				var above := fluid_at(w, x, y + 1, z)
				var below := fluid_at(w, x, y - 1, z)
				var sources := 0
				var level := 0
				if authored_fall(w, x, y, z):
					var feed := false
					for d in 4:
						if fluid_at(w, x + DIR_X[d], y, z + DIR_Z[d]) & SOURCE:
							feed = true
							break
					if above != 0 or feed:
						val = 40
				if val == 0:
					for d in 4:
						var nx := x + DIR_X[d]
						var nz := z + DIR_Z[d]
						var f := fluid_at(w, nx, y, nz)
						if f == 0:
							continue
						if f & SOURCE:
							sources += 1
						var under := fluid_at(w, nx, y - 1, nz)
						var supported := is_solid_at(w, nx, y - 1, nz) or ((under & 15) == 8 and not (under & FALLING))
						var guided_impact := (f & FALLING) != 0 and authored_fall(w, nx, y, nz) and under != 0 and not (under & FALLING)
						if supported and not guided_impact and (fluid_spread(w, nx, y, nz, cache) & (1 << (d ^ 1))):
							level = maxi(level, (f & 15) - 1)
					if renew and sources >= 2 and (not fluid_pass(w, x, y - 1, z) or (below & SOURCE)):
						val = 24
					elif above != 0:
						val = 40
					else:
						val = level
		if val != old:
			updates.append(i)
			updates.append(val)
	var columns := {}
	var bl := w.blocks
	for u in range(0, updates.size(), 2):
		var i := updates[u]
		var val := updates[u + 1]
		fl[i] = val
		if bl[i] == AIR or bl[i] == WATER:
			bl[i] = WATER if val != 0 else AIR
		var y := i / xz
		var z := (i - y * xz) / sx
		var x := i % sx
		wake_fluid(w, x, y, z)
		mark_dirty(w, x, z)
		columns[z * sx + x] = true
		# Un cambio di topologia puo' cambiare il percorso preferito delle celle a monte.
		for dz in range(-4, 5):
			for dx in range(-4, 5):
				if absi(dx) + absi(dz) <= 4 and fluid_at(w, x + dx, y, z + dz) != 0:
					wake_fluid(w, x + dx, y, z + dz)
	for c: int in columns:
		refresh_water_column(w, c % sx, c / sx)
	return updates
