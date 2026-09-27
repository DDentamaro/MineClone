class_name Axes
extends RefCounted
## Convenzioni di coordinate condivise (docs/DECISIONS.md, D-004).
##
## Il prototipo (Three.js) e Godot sono entrambi destrorsi con +Y verso l'alto:
## la cella voxel (x, y, z) occupa il cubo [x, x+1) x [y, y+1) x [z, z+1) in
## unita' di mondo Godot, senza scambi ne' inversioni di assi.
## 1 unita' = 1 blocco. La "forward" di camera e nodi Godot e' -Z.

const UP := Vector3.UP
const FORWARD := Vector3.FORWARD # (0, 0, -1)


## Cella voxel che contiene un punto del mondo.
static func world_to_cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x), floori(p.y), floori(p.z))


## Angolo minimo (x, y, z) della cella in coordinate di mondo.
static func cell_origin(cell: Vector3i) -> Vector3:
	return Vector3(cell)


## Centro della cella in coordinate di mondo.
static func cell_center(cell: Vector3i) -> Vector3:
	return Vector3(cell) + Vector3(0.5, 0.5, 0.5)
