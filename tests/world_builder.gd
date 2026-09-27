class_name TestWorlds
extends RefCounted
## Mondi sintetici per i test.


static func empty(sx: int = 32, sy: int = 16, sz: int = 32) -> WorldData:
	return WorldData.new(sx, sy, sz, BlockCatalog.load_default().solid_table())


## Pavimento pieno di pietra fino a y = top - 1 (piedi a quota `top`).
static func flat(top: int = 4, sx: int = 32, sy: int = 16, sz: int = 32) -> WorldData:
	var w := empty(sx, sy, sz)
	for y in top:
		for z in sz:
			for x in sx:
				w.blocks[w.index(x, y, z)] = BlockCatalog.STONE
	for z in sz:
		for x in sx:
			w.surface[z * sx + x] = top - 1
	return w


static func fill(w: WorldData, from: Vector3i, to: Vector3i, id: int) -> void:
	for y in range(from.y, to.y + 1):
		for z in range(from.z, to.z + 1):
			for x in range(from.x, to.x + 1):
				w.blocks[w.index(x, y, z)] = id
