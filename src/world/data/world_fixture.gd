class_name WorldFixture
extends RefCounted
## Carica una fixture estratta dal prototipo originale
## (tools/extract_fixture.mjs) e ne verifica gli SHA-256.

const SEED1931_DIR := "res://tests/fixtures/seed1931_v064"

## Buffer caricati nella WorldData, con il nome della proprieta' di destinazione.
const BUFFERS := {
	"blocks": "blocks",
	"fluid": "fluid",
	"sun": "sun",
	"blk": "blk",
	"surface": "surface",
	"biome": "biome",
	"waterLevel": "water_level",
}

var world: WorldData
var manifest: Dictionary = {}
var errors: PackedStringArray = []


func ok() -> bool:
	return errors.is_empty() and world != null


static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func load_dir(dir: String, catalog: BlockCatalog, verify: bool = true) -> WorldFixture:
	var fx := WorldFixture.new()
	var manifest_text := FileAccess.get_file_as_string(dir.path_join("manifest.json"))
	if manifest_text.is_empty():
		fx.errors.append("manifest.json mancante in %s" % dir)
		return fx
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not parsed is Dictionary:
		fx.errors.append("manifest.json non valido")
		return fx
	fx.manifest = parsed
	var gen: Dictionary = fx.manifest["generator"]
	var dims: Dictionary = gen["dims"]
	var w := WorldData.new(int(dims["X"]), int(dims["Y"]), int(dims["Z"]), catalog.solid_table())
	w.world_seed = int(gen["seed"])
	w.generator_version = str(gen["version"])
	var files: Dictionary = fx.manifest["files"]
	for name: String in BUFFERS:
		var info: Dictionary = files[name]
		var packed := FileAccess.get_file_as_bytes(dir.path_join(str(info["file"])))
		if packed.is_empty():
			fx.errors.append("%s: file mancante" % name)
			continue
		var expected := int(info["bytes"])
		var raw := packed.decompress(expected, FileAccess.COMPRESSION_GZIP)
		if raw.size() != expected:
			fx.errors.append("%s: %d byte decompressi, attesi %d" % [name, raw.size(), expected])
			continue
		if verify:
			var got := sha256_hex(raw)
			if got != str(info["sha256"]):
				fx.errors.append("%s: sha256 %s != %s" % [name, got, info["sha256"]])
				continue
		w.set(BUFFERS[name], raw)
	if fx.errors.is_empty():
		fx.world = w
	return fx
