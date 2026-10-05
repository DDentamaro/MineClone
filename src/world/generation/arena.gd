class_name Arena
extends RefCounted
## Arena di partenza (D-054), come il ring del torneo di Cell in Dragon Ball:
## piattaforma quadrata di marmo bianco a piastrelle, rialzata di un blocco
## (si sale col passo automatico), quattro colonne agli angoli, tutt'attorno
## una piana di terra battuta (niente alberi ne' erba sul bordo). Si stampa
## nei mondi da giocare (non nei dati verificati del prototipo: fixture e
## generatore restano identici), vicino al centro della mappa dove c'e' meno
## acqua e il terreno e' piu' piano.
##
## Dentro: l'armeria al centro, gli espositori delle armature, il manichino.

## Mezzo lato del ring (19x19 blocchi) e della zona spianata attorno.
const HALF := 9
const APRON := 6
## Altezza delle colonne sopra il ring.
const PILLAR := 5
## Distanza massima del centro dal centro della mappa, passo della ricerca.
const SEARCH := 40
const STEP := 4


## Stampa l'arena e ricalcola la luce. `w.arena` e' la cella del centro del
## ring (y = primo blocco d'aria sopra il marmo).
static func stamp(w: WorldData, catalog: BlockCatalog) -> void:
	var c := locate(w)
	var r := HALF + APRON
	var base := _median_height(w, c.x, c.y, r)
	for z in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if x < 1 or z < 1 or x >= w.size_x - 1 or z >= w.size_z - 1:
				continue
			var ring := absi(x - c.x) <= HALF and absi(z - c.y) <= HALF
			var corner := absi(x - c.x) == HALF and absi(z - c.y) == HALF
			var top := base + (1 if ring else 0) + (PILLAR if corner else 0)
			for y in range(1, w.size_y):
				var i := w.index(x, y, z)
				var id := BlockCatalog.AIR
				if y <= top:
					if ring and y > base:
						id = BlockCatalog.MARBLE
					elif y == base:
						# Piana brulla attorno al ring (niente alberi ne' erba).
						id = BlockCatalog.DIRT
					elif y >= base - 3:
						id = BlockCatalog.DIRT
					else:
						id = w.blocks[i] if w.blocks[i] != BlockCatalog.AIR and w.blocks[i] != BlockCatalog.WATER else BlockCatalog.STONE
				w.blocks[i] = id
				if w.fluid.size() > i:
					w.fluid[i] = 0
			w.surface[z * w.size_x + x] = top
			if w.water_level.size() > z * w.size_x + x:
				w.water_level[z * w.size_x + x] = 0
	w.arena = Vector3i(c.x, base + 2, c.y)
	LightEngine.new(w, catalog).compute_all()


## Centro (x, z) dell'arena: il piu' asciutto e piano entro SEARCH blocchi
## dal centro della mappa (a parita', il piu' vicino).
static func locate(w: WorldData) -> Vector2i:
	var mx := w.size_x >> 1
	var mz := w.size_z >> 1
	var r := HALF + APRON
	var best := Vector2i(mx, mz)
	var best_score := INF
	for dz in range(-SEARCH, SEARCH + 1, STEP):
		for dx in range(-SEARCH, SEARCH + 1, STEP):
			var cx := mx + dx
			var cz := mz + dz
			if cx - r < 2 or cz - r < 2 or cx + r >= w.size_x - 2 or cz + r >= w.size_z - 2:
				continue
			var med := _median_height(w, cx, cz, r)
			var score := 0.0
			for z in range(cz - r, cz + r + 1, 2):
				for x in range(cx - r, cx + r + 1, 2):
					var h := w.surface_height(x, z)
					score += absf(h - med)
					if _wet(w, x, z):
						score += 40.0
			score += Vector2(dx, dz).length() * 0.5
			if score < best_score:
				best_score = score
				best = Vector2i(cx, cz)
	return best


## Punto dei piedi dove si nasce: sul ring, a nord dell'armeria, dove parte
## anche il duello (D-060: la meta' nord del ring e' libera).
static func spawn_in(w: WorldData) -> Vector3:
	return Vector3(w.arena.x + 0.5, w.arena.y, w.arena.z - 2.0)


static func has(w: WorldData) -> bool:
	return w.arena.x >= 0


static func _median_height(w: WorldData, cx: int, cz: int, r: int) -> int:
	var hs: Array[int] = []
	for z in range(cz - r, cz + r + 1, 3):
		for x in range(cx - r, cx + r + 1, 3):
			if w.inside(x, 0, z):
				hs.append(w.surface_height(x, z))
	hs.sort()
	return hs[hs.size() / 2] if not hs.is_empty() else w.size_y / 2


static func _wet(w: WorldData, x: int, z: int) -> bool:
	var h := w.surface_height(x, z)
	for y in range(h, mini(h + 3, w.size_y)):
		if w.get_block_xyz(x, y, z) == BlockCatalog.WATER:
			return true
	var col := z * w.size_x + x
	return w.water_level.size() > col and int(w.water_level[col]) > h
