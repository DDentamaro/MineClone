class_name LightEngine
extends RefCounted
## Luce voxel: sole (15 dall'alto, scende senza perdite in verticale, -1 per
## passo laterale) e luce dei blocchi emissivi (-1 per passo). Porting di
## ISO_CORE.computeLight (HTML ~4613) piu' un aggiornamento locale per gli edit:
## rimozione a ritroso e ripropagazione, con lo stesso punto fisso del calcolo
## completo (verificato dai test contro computeLight e contro la fixture).

var world: WorldData
var opaque := PackedByteArray()
var emit := PackedByteArray()

## Riquadro delle celle cambiate dall'ultimo update (min/max inclusi).
var changed_min := Vector3i.ZERO
var changed_max := Vector3i(-1, -1, -1)


func _init(w: WorldData, catalog: BlockCatalog) -> void:
	world = w
	opaque = catalog.opaque_table()
	emit.resize(catalog.count())
	for i in catalog.count():
		emit[i] = catalog.get_def(i).emit


## Calcolo completo, identico a computeLight.
func compute_all() -> void:
	var sx := world.size_x
	var sy := world.size_y
	var sz := world.size_z
	var xz := sx * sz
	var bl := world.blocks
	var sun := world.sun
	var blk := world.blk
	sun.fill(0)
	blk.fill(0)
	var queue := PackedInt32Array()
	queue.resize(sx * sy * sz)
	var qt := 0
	for z in sz:
		for x in sx:
			var y := sy - 1
			while y >= 0:
				var i := (y * sz + z) * sx + x
				if opaque[bl[i]] == 1:
					break
				sun[i] = 15
				queue[qt] = i
				qt += 1
				y -= 1
	_flood(queue, qt, sun, true)
	qt = 0
	for i in sx * sy * sz:
		var e := emit[bl[i]]
		if e > 0:
			blk[i] = e
			queue[qt] = i
			qt += 1
	_flood(queue, qt, blk, false)


## Propagazione BFS con coda preallocata (ordine identico al prototipo).
func _flood(queue: PackedInt32Array, count: int, light: PackedByteArray, is_sun: bool) -> void:
	var sx := world.size_x
	var sy := world.size_y
	var sz := world.size_z
	var xz := sx * sz
	var bl := world.blocks
	var qh := 0
	var qt := count
	while qh < qt:
		var i := queue[qh]
		qh += 1
		var l := light[i]
		if l <= 1:
			continue
		var x := i % sx
		var y := i / xz
		var z := (i / sx) % sz
		for k in 6:
			var j := 0
			match k:
				0:
					if x == sx - 1: continue
					j = i + 1
				1:
					if x == 0: continue
					j = i - 1
				2:
					if z == sz - 1: continue
					j = i + sx
				3:
					if z == 0: continue
					j = i - sx
				4:
					if y == sy - 1: continue
					j = i + xz
				5:
					if y == 0: continue
					j = i - xz
			if opaque[bl[j]] == 1:
				continue
			var nl := 15 if (is_sun and k == 5 and l == 15) else l - 1
			if light[j] < nl:
				light[j] = nl
				if qt >= queue.size():
					queue.resize(queue.size() * 2)
				queue[qt] = j
				qt += 1


## Aggiorna la luce dopo che le celle `cells` hanno cambiato blocco (i dati dei
## blocchi sono gia' scritti). Restituisce il numero di celle modificate e
## aggiorna changed_min/changed_max.
func update_cells(cells: Array[Vector3i]) -> int:
	changed_min = Vector3i(world.size_x, world.size_y, world.size_z)
	changed_max = Vector3i(-1, -1, -1)
	var n := _update_channel(cells, world.sun, true)
	n += _update_channel(cells, world.blk, false)
	return n


func _update_channel(cells: Array[Vector3i], light: PackedByteArray, is_sun: bool) -> int:
	var sx := world.size_x
	var sy := world.size_y
	var sz := world.size_z
	var xz := sx * sz
	var bl := world.blocks
	var changed := 0
	var rem := PackedInt32Array() # coppie (indice, valore rimosso)
	var prop := PackedInt32Array()
	# 1. Svuota le celle modificate e avvia la rimozione.
	for c in cells:
		var i := world.index(c.x, c.y, c.z)
		var old := light[i]
		if old > 0:
			light[i] = 0
			rem.append(i)
			rem.append(old)
			changed += 1
			_mark(i)
	# 2. Rimozione a ritroso.
	var h := 0
	while h < rem.size():
		var i := rem[h]
		var old := rem[h + 1]
		h += 2
		var x := i % sx
		var y := i / xz
		var z := (i / sx) % sz
		for k in 6:
			var j := _neighbor(i, x, y, z, k, sx, sy, sz, xz)
			if j < 0 or opaque[bl[j]] == 1:
				continue
			var nv := light[j]
			if nv == 0:
				continue
			var derived := nv < old or (is_sun and k == 5 and old == 15 and nv == 15)
			if derived:
				light[j] = 0
				rem.append(j)
				rem.append(nv)
				changed += 1
				_mark(j)
			else:
				prop.append(j)
	# 3. Sorgenti: emissivi toccati, colonne di cielo, celle modificate.
	for c in cells:
		var i := world.index(c.x, c.y, c.z)
		var id := bl[i]
		if not is_sun and emit[id] > 0:
			light[i] = emit[id]
			prop.append(i)
			_mark(i)
		if opaque[id] == 1:
			continue
		if is_sun and c.y == sy - 1:
			light[i] = 15
			prop.append(i)
			_mark(i)
		# I vicini accesi propagano dentro la cella.
		for k in 6:
			var j := _neighbor(i, c.x, c.y, c.z, k, sx, sy, sz, xz)
			if j >= 0 and light[j] > 0:
				prop.append(j)
	# Emissivi raggiunti dalla rimozione (hanno perso la luce propria).
	if not is_sun:
		for q in range(0, rem.size(), 2):
			var i := rem[q]
			var e := emit[bl[i]]
			if e > 0 and light[i] < e:
				light[i] = e
				prop.append(i)
				_mark(i)
	# 4. Ripropagazione.
	var ph := 0
	while ph < prop.size():
		var i := prop[ph]
		ph += 1
		var l := light[i]
		if l <= 1:
			continue
		var x := i % sx
		var y := i / xz
		var z := (i / sx) % sz
		for k in 6:
			var j := _neighbor(i, x, y, z, k, sx, sy, sz, xz)
			if j < 0 or opaque[bl[j]] == 1:
				continue
			var nl := 15 if (is_sun and k == 5 and l == 15) else l - 1
			if light[j] < nl:
				light[j] = nl
				prop.append(j)
				changed += 1
				_mark(j)
	return changed


static func _neighbor(i: int, x: int, y: int, z: int, k: int, sx: int, sy: int, sz: int, xz: int) -> int:
	match k:
		0:
			return i + 1 if x < sx - 1 else -1
		1:
			return i - 1 if x > 0 else -1
		2:
			return i + sx if z < sz - 1 else -1
		3:
			return i - sx if z > 0 else -1
		4:
			return i + xz if y < sy - 1 else -1
		_:
			return i - xz if y > 0 else -1


func _mark(i: int) -> void:
	var sx := world.size_x
	var sz := world.size_z
	var p := Vector3i(i % sx, i / (sx * sz), (i / sx) % sz)
	changed_min = changed_min.min(p)
	changed_max = changed_max.max(p)


## Chunk che contengono celle cambiate o che le leggono (bordo di una cella).
func changed_chunks() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if changed_max.x < 0:
		return out
	var cs := WorldData.CHUNK_SIZE
	var lo := (changed_min - Vector3i.ONE).max(Vector3i.ZERO) / cs
	var hi := (changed_max + Vector3i.ONE).min(Vector3i(world.size_x - 1, world.size_y - 1, world.size_z - 1)) / cs
	for cy in range(lo.y, hi.y + 1):
		for cz in range(lo.z, hi.z + 1):
			for cx in range(lo.x, hi.x + 1):
				out.append(Vector3i(cx, cy, cz))
	return out
