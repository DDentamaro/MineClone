extends TestCase
## Il catalogo Resource deve coincidere con ISO_CORE.B/NAMES/OPAQUE/SOLID/EMIT.

const MANIFEST := "res://tests/fixtures/seed1931_v064/manifest.json"


func test_catalogo_coincide_con_prototipo() -> void:
	var cat := BlockCatalog.load_default()
	check(cat != null, "catalogo caricabile")
	if cat == null:
		return
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var ids: Dictionary = m["block_ids"]
	check_eq(cat.count(), 16, "numero di blocchi, aria inclusa")
	for key: String in ids:
		var id := int(ids[key])
		var def := cat.get_def(id)
		check(def != null, "definizione %s" % key)
		if def == null:
			continue
		check_eq(def.id, id, "id di %s" % key)
		check_eq(def.key, StringName(key.to_lower()), "chiave di %s" % key)
		check_eq(def.display_name, str(m["names"][id]), "nome di %s" % key)
		check_eq(def.opaque, int(m["opaque"][id]) == 1, "opaque di %s" % key)
		check_eq(def.solid, int(m["solid"][id]) == 1, "solid di %s" % key)
		check_eq(def.emit, int(m["emit"][id]), "emit di %s" % key)


func test_costanti_id() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var ids: Dictionary = m["block_ids"]
	check_eq(BlockCatalog.WATER, int(ids["WATER"]), "WATER")
	check_eq(BlockCatalog.BEDROCK, int(ids["BEDROCK"]), "BEDROCK")
	check_eq(BlockCatalog.TORCH, int(ids["TORCH"]), "TORCH")
	check_eq(BlockCatalog.DARKSTONE, int(ids["DARKSTONE"]), "DARKSTONE")
