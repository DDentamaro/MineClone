class_name BlockCatalog
extends Resource
## Catalogo dei blocchi indicizzato per ID. Generato da
## tools/godot/gen_block_catalog.gd a partire dal manifest della fixture.

const DEFAULT_PATH := "res://data/blocks/block_catalog.tres"

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const COPPER := 5
const IRON := 6
const GOLD := 7
const BEDROCK := 8
const LAVA := 9
const TORCH := 10
const WOOD := 11
const LEAVES := 12
const SANDSTONE := 13
const DARKSTONE := 14
const WATER := 15
## D-054: marmo bianco a piastrelle dell'arena (indistruttibile: non e' in `Harvest.INFO`).
const MARBLE := 16

@export var blocks: Array[BlockDefinition] = []

var _solid_cache := PackedByteArray()
var _opaque_cache := PackedByteArray()


static func load_default() -> BlockCatalog:
	return load(DEFAULT_PATH) as BlockCatalog


func count() -> int:
	return blocks.size()


func get_def(id: int) -> BlockDefinition:
	if id < 0 or id >= blocks.size():
		return null
	return blocks[id]


func is_solid(id: int) -> bool:
	_ensure_caches()
	return id >= 0 and id < _solid_cache.size() and _solid_cache[id] == 1


func is_opaque(id: int) -> bool:
	_ensure_caches()
	return id >= 0 and id < _opaque_cache.size() and _opaque_cache[id] == 1


## Tabella 0/1 per ID, utile nei loop caldi (meshing, collisioni).
func solid_table() -> PackedByteArray:
	_ensure_caches()
	return _solid_cache


func opaque_table() -> PackedByteArray:
	_ensure_caches()
	return _opaque_cache


func _ensure_caches() -> void:
	if _solid_cache.size() == blocks.size() and not blocks.is_empty():
		return
	_solid_cache.resize(blocks.size())
	_opaque_cache.resize(blocks.size())
	for i in blocks.size():
		var def := blocks[i]
		_solid_cache[i] = 1 if def != null and def.solid else 0
		_opaque_cache[i] = 1 if def != null and def.opaque else 0
