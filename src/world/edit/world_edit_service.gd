class_name WorldEditService
extends RefCounted
## Unico percorso per modificare i blocchi (costruzione, scavo, magia, debug).
## Un edit riuscito scrive i dati una volta, aggiorna la colonna `surface`,
## incrementa la versione di ogni chunk toccato (compresi i vicini entro una
## cella, per facce e AO) e notifica i chunk sporchi.

signal chunks_changed(chunks: Array[Vector3i])

enum Status { OK, REJECTED_OUTSIDE, REJECTED_INVALID_ID, REJECTED_CONFLICT, REJECTED_EMPTY }


class Edit:
	extends RefCounted
	var cell: Vector3i
	var id: int

	func _init(c: Vector3i, block_id: int) -> void:
		cell = c
		id = block_id


class EditResult:
	extends RefCounted
	var status: Status = Status.OK
	var chunks: Array[Vector3i] = []
	var previous: PackedByteArray = []

	func ok() -> bool:
		return status == Status.OK


var world: WorldData
var catalog: BlockCatalog
## Se presente, la luce viene aggiornata localmente a ogni edit e i chunk con
## luce cambiata vengono rimeshati.
var light: LightEngine


func _init(w: WorldData, cat: BlockCatalog) -> void:
	world = w
	catalog = cat


## Applica tutti gli edit o nessuno. `expected_versions` (chunk_index -> versione)
## rifiuta l'operazione se nel frattempo un chunk e' cambiato.
func try_apply(edits: Array[Edit], _source: StringName = &"", expected_versions: Dictionary = {}) -> EditResult:
	var res := EditResult.new()
	if edits.is_empty():
		res.status = Status.REJECTED_EMPTY
		return res
	for e in edits:
		if not world.inside(e.cell.x, e.cell.y, e.cell.z):
			res.status = Status.REJECTED_OUTSIDE
			return res
		if e.id < 0 or e.id >= catalog.count():
			res.status = Status.REJECTED_INVALID_ID
			return res
	for ci: int in expected_versions:
		if world.chunk_versions[ci] != int(expected_versions[ci]):
			res.status = Status.REJECTED_CONFLICT
			return res
	var touched := {}
	var columns := {}
	res.previous.resize(edits.size())
	for k in edits.size():
		var e := edits[k]
		var i := world.index(e.cell.x, e.cell.y, e.cell.z)
		res.previous[k] = world.blocks[i]
		world.blocks[i] = e.id
		columns[Vector2i(e.cell.x, e.cell.z)] = true
		for c in chunks_around(e.cell):
			touched[c] = true
	for col: Vector2i in columns:
		_refresh_surface(col.x, col.y)
	if light != null:
		var cells: Array[Vector3i] = []
		for e in edits:
			cells.append(e.cell)
		light.update_cells(cells)
		for c in light.changed_chunks():
			touched[c] = true
	for c: Vector3i in touched:
		world.chunk_versions[world.chunk_index(c)] += 1
		res.chunks.append(c)
	world.revision += 1
	chunks_changed.emit(res.chunks)
	return res


func set_block(cell: Vector3i, id: int, source: StringName = &"") -> EditResult:
	var list: Array[Edit] = [Edit.new(cell, id)]
	return try_apply(list, source)


## Porting di ISO_CORE.canPlaceBlock: si posa in aria, o in acqua con solido sotto.
func can_place(cell: Vector3i, id: int) -> bool:
	if not world.inside(cell.x, cell.y, cell.z) or id <= BlockCatalog.AIR or id > BlockCatalog.WATER:
		return false
	var target := world.get_block(cell)
	return target == BlockCatalog.AIR or (target == BlockCatalog.WATER and cell.y > 0 and world.is_solid_at(cell.x, cell.y - 1, cell.z))


## Chunk che contengono la cella o una sua vicina (anche diagonale).
func chunks_around(cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cs := WorldData.CHUNK_SIZE
	for dy in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var p := cell + Vector3i(dx, dy, dz)
				if not world.inside(p.x, p.y, p.z):
					continue
				var c := Vector3i(p.x / cs, p.y / cs, p.z / cs)
				if not out.has(c):
					out.append(c)
	return out


func _refresh_surface(x: int, z: int) -> void:
	var top := 0
	for y in range(world.size_y - 1, -1, -1):
		if world.is_solid_at(x, y, z):
			top = y
			break
	world.surface[z * world.size_x + x] = top
