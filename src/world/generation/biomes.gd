class_name Biomes
extends RefCounted
## Tabelle BIOME/BIOMES e spline del prototipo (core.js r.43-51).

const PRATO := 0
const FORESTA := 1
const SAVANA := 2
const DESERTO := 3
const TUNDRA := 4
const VETTA := 5

## Un record per bioma, stessi campi e valori di ISO_CORE.BIOMES.
const BIOMES: Array[Dictionary] = [
	{"id": 0, "name": "Prato", "top": 1, "fill": 2, "fillDepth": 4, "trees": [0.13, 0.025, 0.005], "kinds": [0, 1, 2], "treeScale": 1.0, "grassKeep": 1.0, "grassH": 1.0},
	{"id": 1, "name": "Foresta", "top": 1, "fill": 2, "fillDepth": 4, "trees": [0.20, 0.090, 0.030], "kinds": [0, 1, 2], "treeScale": 1.12, "grassKeep": 1.0, "grassH": 1.1},
	{"id": 2, "name": "Savana", "top": 1, "fill": 2, "fillDepth": 3, "trees": [0.020, 0.006, 0.002], "kinds": [2], "treeScale": 1.25, "grassKeep": 0.9, "grassH": 1.35},
	{"id": 3, "name": "Deserto", "top": 4, "fill": 13, "fillDepth": 5, "trees": [0.0, 0.0, 0.0], "kinds": [0], "treeScale": 1.0, "grassKeep": 0.0, "grassH": 1.0},
	{"id": 4, "name": "Tundra", "top": 1, "fill": 2, "fillDepth": 2, "trees": [0.030, 0.010, 0.003], "kinds": [1], "treeScale": 0.85, "grassKeep": 0.5, "grassH": 0.7},
	{"id": 5, "name": "Vetta", "top": 3, "fill": 3, "fillDepth": 1, "trees": [0.0, 0.0, 0.0], "kinds": [1], "treeScale": 0.8, "grassKeep": 0.0, "grassH": 1.0},
]

## Colonne della tabella per gli accessi caldi del generatore (indice = id bioma).
const TOP := [1, 1, 1, 4, 1, 3]
const FILL := [2, 2, 2, 13, 2, 3]
const FILL_DEPTH := [4, 4, 3, 5, 2, 1]


static func count() -> int:
	return BIOMES.size()


## spline(pts, x) del prototipo. `pts` e' appiattito: [x0, y0, x1, y1, ...]
## (i Vector2 di Godot sono a 32 bit e perderebbero precisione).
static func spline(pts: PackedFloat64Array, x: float) -> float:
	if x <= pts[0]:
		return pts[1]
	var n := pts.size() >> 1
	for i in range(1, n):
		if x <= pts[i * 2]:
			var ax := pts[i * 2 - 2]
			var ay := pts[i * 2 - 1]
			var t := (x - ax) / (pts[i * 2] - ax)
			t = t * t * (3.0 - 2.0 * t)
			return ay + (pts[i * 2 + 1] - ay) * t
	return pts[pts.size() - 1]
