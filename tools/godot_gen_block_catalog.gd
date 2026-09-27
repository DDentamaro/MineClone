extends SceneTree
## Rigenera res://data/blocks/block_catalog.tres dal manifest della fixture.
## Uso: godot --headless --path . --script res://tools/godot_gen_block_catalog.gd
## (tools/ ha .gdignore: lo script si passa per percorso, non viene importato.)

const MANIFEST := "res://tests/fixtures/seed1931_v064/manifest.json"

# Colori base dell'atlante procedurale del prototipo (makeAtlas, riga ~5704 dell'HTML):
# [faccia superiore, lati]. L'acqua non e' nell'atlante: colore provvisorio (M3).
const COLORS := {
	0: ["#ff00ff", "#ff00ff"],
	1: ["#5aa63b", "#8a6a45"],
	2: ["#8a6a45", "#8a6a45"],
	3: ["#6f7478", "#6f7478"],
	4: ["#d9c47e", "#d9c47e"],
	# Minerali: pietra con puntini colorati -> media pietra/puntino (M2 usera' l'atlante).
	5: ["#d9843a", "#d9843a"],
	6: ["#d8c3a5", "#d8c3a5"],
	7: ["#f2d43a", "#f2d43a"],
	8: ["#2e3236", "#2e3236"],
	9: ["#f0782a", "#f0782a"],
	10: ["#c9973a", "#c9973a"],
	11: ["#a37c4f", "#a37c4f"],
	12: ["#3f7d2f", "#3f7d2f"],
	13: ["#c9a86a", "#c9a86a"],
	14: ["#45484d", "#45484d"],
	15: ["#3d7fc4", "#3d7fc4"],
}


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
		def.top_color = Color(str(COLORS[id][0]))
		def.side_color = Color(str(COLORS[id][1]))
		if id >= 5 and id <= 7:
			def.top_color = Color("#6f7478").lerp(def.top_color, 0.3)
			def.side_color = def.top_color
		by_id[id] = def
	var cat := BlockCatalog.new()
	cat.blocks = by_id
	var err := ResourceSaver.save(cat, BlockCatalog.DEFAULT_PATH)
	print("block_catalog.tres: %d blocchi, errore=%d" % [by_id.size(), err])
	quit(err)
