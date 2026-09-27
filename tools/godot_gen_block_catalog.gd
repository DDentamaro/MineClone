extends SceneTree
## Rigenera res://data/blocks/block_catalog.tres dal manifest della fixture.
## Uso: godot --headless --path . --script res://tools/godot_gen_block_catalog.gd
## (tools/ ha .gdignore: lo script si passa per percorso, non viene importato.)

const MANIFEST := "res://tests/fixtures/seed1931_v064/manifest.json"


func _initialize() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var ids: Dictionary = m["block_ids"]
	var names: Array = m["names"]
	var opaque: Array = m["opaque"]
	var solid: Array = m["solid"]
	var emit: Array = m["emit"]
	var by_id: Array[BlockDefinition] = []
	by_id.resize(ids.size())
	for key: String in ids:
		var id := int(ids[key])
		var def := BlockDefinition.new()
		def.id = id
		def.key = StringName(key.to_lower())
		def.display_name = str(names[id])
		def.opaque = int(opaque[id]) == 1
		def.solid = int(solid[id]) == 1
		def.emit = int(emit[id])
		by_id[id] = def
	var cat := BlockCatalog.new()
	cat.blocks = by_id
	var err := ResourceSaver.save(cat, BlockCatalog.DEFAULT_PATH)
	print("block_catalog.tres: %d blocchi, errore=%d" % [by_id.size(), err])
	quit(err)
