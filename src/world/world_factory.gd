class_name WorldFactory
extends RefCounted
## Crea i mondi di gioco: dalla fixture verificata del seme 1931 (avvio veloce)
## o dal generatore v0_64 per un seme qualsiasi, con la luce gia' calcolata.

const SIZE := Vector3i(192, 48, 192)
const RENDER_FIXTURE_DIR := "res://tests/fixtures/seed1931_v064_render"


## Mondo del seme 1931 dalla fixture; il clima viene dalla fixture di resa.
static func from_fixture(catalog: BlockCatalog) -> WorldData:
	var fx := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, catalog)
	if not fx.ok():
		push_error("fixture non valida: %s" % [fx.errors])
		return null
	var w := fx.world
	var cols := w.size_x * w.size_z
	w.climate = _load(RENDER_FIXTURE_DIR.path_join("climate.u8.gz"), cols * 4)
	# Campi del generatore usati dall'acqua (guide dei fiumi, cascate).
	w.water_guide = _load(RENDER_FIXTURE_DIR.path_join("water_guide.i8.gz"), cols * 2)
	w.river_mask = _load(RENDER_FIXTURE_DIR.path_join("river_mask.u8.gz"), cols)
	w.waterfall_mask = _load(RENDER_FIXTURE_DIR.path_join("waterfall_mask.u8.gz"), cols)
	w.waterfall_base = _load(RENDER_FIXTURE_DIR.path_join("waterfall_base.u8.gz"), cols)
	w.waterfall_top = _load(RENDER_FIXTURE_DIR.path_join("waterfall_top.u8.gz"), cols)
	w.water_flow = _load(RENDER_FIXTURE_DIR.path_join("water_flow.f32.gz"), cols * 8).to_float32_array()
	return w


static func _load(path: String, size: int) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path).decompress(size, FileAccess.COMPRESSION_GZIP)


## Genera un mondo come il bootstrap del prototipo (caves:false) e ne calcola la luce.
## Pensato per girare su un thread di lavoro.
static func generate(seed_value: int, catalog: BlockCatalog, caves := false) -> WorldData:
	var w := WorldData.new(SIZE.x, SIZE.y, SIZE.z, catalog.solid_table())
	WorldGenerator.generate(w, seed_value, {"caves": caves})
	w.world_seed = seed_value
	w.generator_version = "v0_64"
	LightEngine.new(w, catalog).compute_all()
	return w


static func climate_texture(w: WorldData) -> ImageTexture:
	if w.climate.size() != w.size_x * w.size_z * 4:
		return null
	return ImageTexture.create_from_image(Image.create_from_data(w.size_x, w.size_z, false, Image.FORMAT_RGBA8, w.climate))
