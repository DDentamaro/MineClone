class_name WorldData
extends RefCounted
## Fonte autorevole dei dati del mondo: buffer voxel compatti, nessun nodo per
## cella. Layout di memoria identico a ISO_CORE.World del prototipo:
## index = (y * size_z + z) * size_x + x.

const CHUNK_SIZE := 16

var size_x: int
var size_y: int
var size_z: int
## ID blocco per cella (ISO_CORE.World.blocks).
var blocks := PackedByteArray()
## Livelli fluido per cella (ISO_CORE.World.fluid; bit alti = flag, vedi M3).
var fluid := PackedByteArray()
## Luce solare 0..15 per cella (ISO_CORE.World.sun).
var sun := PackedByteArray()
## Luce dei blocchi emissivi 0..15 per cella (ISO_CORE.World.blk).
var blk := PackedByteArray()
## Quota del blocco solido piu' alto per colonna, index = z * size_x + x.
var surface := PackedByteArray()
## Indice bioma per colonna (ordine di ISO_CORE.BIOMES).
var biome := PackedByteArray()
## Livello d'acqua per colonna dopo la generazione.
var water_level := PackedByteArray()

var world_seed: int = 0
## Incrementata a ogni edit riuscito.
var revision: int = 0
var generator_version: String = ""
## Versione per chunk: incrementata da ogni edit (WorldEditService, M1).
var chunk_versions := PackedInt32Array()

var _solid := PackedByteArray()


func _init(sx: int, sy: int, sz: int, solid_table: PackedByteArray = PackedByteArray()) -> void:
	size_x = sx
	size_y = sy
	size_z = sz
	var n := sx * sy * sz
	blocks.resize(n)
	fluid.resize(n)
	sun.resize(n)
	blk.resize(n)
	surface.resize(sx * sz)
	biome.resize(sx * sz)
	water_level.resize(sx * sz)
	chunk_versions.resize(chunks_x() * chunks_y() * chunks_z())
	_solid = solid_table


func cell_count() -> int:
	return size_x * size_y * size_z


func index(x: int, y: int, z: int) -> int:
	return (y * size_z + z) * size_x + x


func inside(x: int, y: int, z: int) -> bool:
	return x >= 0 and y >= 0 and z >= 0 and x < size_x and y < size_y and z < size_z


func get_block(cell: Vector3i) -> int:
	return get_block_xyz(cell.x, cell.y, cell.z)


func get_block_xyz(x: int, y: int, z: int) -> int:
	if not inside(x, y, z):
		return BlockCatalog.AIR
	return blocks[index(x, y, z)]


## Come ISO_CORE.World.isSolidAt: sotto il mondo e' sempre solido.
func is_solid_at(x: int, y: int, z: int) -> bool:
	if y < 0:
		return true
	var id := get_block_xyz(x, y, z)
	return id < _solid.size() and _solid[id] == 1


func surface_height(x: int, z: int) -> int:
	return surface[z * size_x + x]


func chunks_x() -> int:
	return ceili(size_x / float(CHUNK_SIZE))


func chunks_y() -> int:
	return ceili(size_y / float(CHUNK_SIZE))


func chunks_z() -> int:
	return ceili(size_z / float(CHUNK_SIZE))


func chunk_count() -> int:
	return chunks_x() * chunks_y() * chunks_z()


func chunk_index(chunk: Vector3i) -> int:
	return (chunk.y * chunks_z() + chunk.z) * chunks_x() + chunk.x


func chunk_version(chunk: Vector3i) -> int:
	return chunk_versions[chunk_index(chunk)]


## Porting di ISO_CORE.spawnPoint: centro della mappa, primo punto libero
## (due celle d'aria) sopra la superficie. Restituisce il punto dei piedi.
func spawn_point() -> Vector3:
	var x := size_x >> 1
	var z := size_z >> 1
	var y := surface_height(x, z) + 1
	while is_solid_at(x, y, z) or is_solid_at(x, y + 1, z):
		y += 1
	return Vector3(x + 0.5, y, z + 0.5)
