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

## --- Campi scritti dal generatore (WorldGenerator), vuoti finche' non servono. ---
## Un array vuoto equivale a "campo assente" nel prototipo (es. `if(W.waterGuide)`).
## Clima per colonna, 4 byte: temperatura, umidita', neve (255 = vetta), 255.
var climate := PackedByteArray()
## Direzione della corrente per colonna (x, z), float32 come Float32Array.
var water_flow := PackedFloat32Array()
## 1 dove e' passato un fiume.
var river_mask := PackedByteArray()
## Cascate disegnate dal generatore: maschera, quota base (prima cella) e cima (esclusa).
var waterfall_mask := PackedByteArray()
var waterfall_base := PackedByteArray()
var waterfall_top := PackedByteArray()
## Guida della corrente (x, z) in -127..127, int8 in complemento a due (Int8Array in JS):
## leggere con water_guide_at().
var water_guide := PackedByteArray()
## Etichetta del corpo d'acqua per colonna (labelWater), 0 = asciutto.
var water_bodies := PackedInt32Array()

## Statistiche della generazione (ISO_CORE: genLog, biomeShare, massif, waterInfo, bankBlocks).
var gen_log: Array = []
var biome_share := PackedInt32Array()
## Centro del massiccio: {"x": float, "z": float} (double, non Vector2 a 32 bit).
var massif: Dictionary = {}
## {"lakes": int, "rivers": Array[{"len", "falls"}], "cells": int}
var water_info: Dictionary = {}
var bank_blocks: int = 0

## --- Stato della simulazione dei fluidi (FluidSystem). ---
## true dopo FluidSystem.init_fluid (in JS: esistono W.fluid e W.fluidQueue).
var fluid_active: bool = false
## Coda delle celle da aggiornare: Dictionary usato come Set ordinato (chiave = indice
## cella, valore true). Come il Set di JS conserva l'ordine d'inserimento.
var fluid_queue: Dictionary = {}
## Chunk colonna da rimesciare: chiavi Vector2i(cx, cz) (in JS stringhe "cx,cz").
var fluid_dirty: Dictionary = {}
var fluid_clock: float = 0.0
var fluid_renew_sources: bool = true

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


## Copia indipendente dei dati letti da mesher, vegetazione e mesh dell'acqua
## (blocchi, luce, superficie, bioma, fluidi), da passare ai thread di lavoro.
func render_snapshot() -> WorldData:
	var w := WorldData.new(0, 0, 0, _solid)
	w.size_x = size_x
	w.size_y = size_y
	w.size_z = size_z
	w.blocks = blocks.duplicate()
	w.sun = sun.duplicate()
	w.blk = blk.duplicate()
	w.surface = surface.duplicate()
	w.biome = biome.duplicate()
	w.fluid = fluid.duplicate()
	w.water_bodies = water_bodies.duplicate()
	w.water_guide = water_guide.duplicate()
	w.world_seed = world_seed
	return w


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


## Componente con segno di water_guide (k = colonna*2 + asse).
func water_guide_at(k: int) -> int:
	return water_guide.decode_s8(k)


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


## Centro dell'arena di partenza (D-054, `Arena.stamp`), -1 se non c'e'.
var arena := Vector3i(-1, -1, -1)


## Porting di ISO_CORE.spawnPoint: centro della mappa, primo punto libero
## (due celle d'aria) sopra la superficie. Restituisce il punto dei piedi.
## Con l'arena (D-054) si nasce sul ring.
func spawn_point() -> Vector3:
	if arena.x >= 0:
		var p := Arena.spawn_in(self)
		var ay := int(p.y)
		while is_solid_at(int(p.x), ay, int(p.z)) or is_solid_at(int(p.x), ay + 1, int(p.z)):
			ay += 1
		return Vector3(p.x, ay, p.z)
	var x := size_x >> 1
	var z := size_z >> 1
	var y := surface_height(x, z) + 1
	while is_solid_at(x, y, z) or is_solid_at(x, y + 1, z):
		y += 1
	return Vector3(x + 0.5, y, z + 0.5)
