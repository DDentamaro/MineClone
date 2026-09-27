class_name VoxelQuery
extends RefCounted
## Query autorevoli sui voxel: raycast (porting di ISO_CORE.raycast) e quote del
## suolo (porting di fieldHeight/fieldSupport). Leggono sempre i dati correnti,
## quindi non hanno ritardi rispetto agli edit.

const SUPPORT_RING: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071),
]


class VoxelHit:
	extends RefCounted
	var cell: Vector3i
	## Normale della faccia colpita (verso l'esterno del blocco).
	var normal: Vector3i
	var distance: float
	var id: int


## DDA come nel prototipo: colpisce blocchi opachi e torce; include la cella di
## partenza. `direction` deve essere normalizzata.
static func raycast(world: WorldData, opaque: PackedByteArray, origin: Vector3, direction: Vector3, max_distance: float) -> VoxelHit:
	var x := floori(origin.x)
	var y := floori(origin.y)
	var z := floori(origin.z)
	var dx := direction.x
	var dy := direction.y
	var dz := direction.z
	var sx := 1 if dx > 0 else -1
	var sy := 1 if dy > 0 else -1
	var sz := 1 if dz > 0 else -1
	var tdx := absf(1.0 / (dx if dx != 0.0 else 1e-9))
	var tdy := absf(1.0 / (dy if dy != 0.0 else 1e-9))
	var tdz := absf(1.0 / (dz if dz != 0.0 else 1e-9))
	var tx := ((x + 1 - origin.x) if sx > 0 else (origin.x - x)) * tdx
	var ty := ((y + 1 - origin.y) if sy > 0 else (origin.y - y)) * tdy
	var tz := ((z + 1 - origin.z) if sz > 0 else (origin.z - z)) * tdz
	var n := Vector3i.ZERO
	var t := 0.0
	for _i in 600:
		if t >= max_distance:
			break
		if world.inside(x, y, z):
			var id := world.blocks[world.index(x, y, z)]
			if opaque[id] == 1 or id == BlockCatalog.TORCH:
				var hit := VoxelHit.new()
				hit.cell = Vector3i(x, y, z)
				hit.normal = n
				hit.distance = t
				hit.id = id
				return hit
		if tx < ty and tx < tz:
			x += sx
			t = tx
			tx += tdx
			n = Vector3i(-sx, 0, 0)
		elif ty < tz:
			y += sy
			t = ty
			ty += tdy
			n = Vector3i(0, -sy, 0)
		else:
			z += sz
			t = tz
			tz += tdz
			n = Vector3i(0, 0, -sz)
	return null


## Quota della faccia superiore del blocco solido piu' alto della colonna che
## contiene (x, z), cercando da floor(y_ref + 1.08) in giu' (ISO_CORE.fieldHeight).
static func field_height(world: WorldData, x: float, z: float, y_ref: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	if ix < 0 or iz < 0 or ix >= world.size_x or iz >= world.size_z:
		return 0.0
	var y := mini(world.size_y - 1, floori(y_ref + 1.08))
	while y >= 0:
		if world.is_solid_at(ix, y, iz):
			return y + 1.0
		y -= 1
	return 0.0


## Massimo di field_height sul centro e su 8 punti a distanza r (ISO_CORE.fieldSupport).
static func field_support(world: WorldData, x: float, z: float, r: float, y_ref: float) -> float:
	var y := field_height(world, x, z, y_ref)
	for q in SUPPORT_RING:
		y = maxf(y, field_height(world, x + q.x * r, z + q.y * r, y_ref))
	return y


## Vero se qualche cella solida interseca le righe [y_from, y_to] (indici di cella)
## sotto il centro o sugli 8 punti a distanza r.
static func solid_in_rows(world: WorldData, x: float, z: float, r: float, y_from: int, y_to: int) -> bool:
	if y_to < y_from:
		return false
	var pts: Array[Vector2] = [Vector2.ZERO]
	pts.append_array(SUPPORT_RING)
	for q in pts:
		var ix := floori(x + q.x * r)
		var iz := floori(z + q.y * r)
		for y in range(maxi(y_from, 0), mini(y_to, world.size_y - 1) + 1):
			if world.is_solid_at(ix, y, iz):
				return true
	return false
