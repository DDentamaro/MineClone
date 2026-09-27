extends TestCase
## Parita' della fixture del seme 1931 (caves:false) estratta dal prototipo v0_64.

const REFERENCE_HTML := "res://reference/isoterra_proto_v0_64_humanoids.html"
const REFERENCE_SHA := "2f2f771f3a83af9b016de9e024cc38a3ce8282bb97d289809a4edc9474a5c76a"
# Hash del buffer blocchi riportato anche nel piano (sezione 2).
const BLOCKS_SHA := "ce0d3766deb04bb02b6f3e68d06bd428f1ddadd8101d7947175c15e10a071338"

var _fx: WorldFixture


func _fixture() -> WorldFixture:
	if _fx == null:
		_fx = WorldFixture.load_dir(WorldFixture.SEED1931_DIR, BlockCatalog.load_default())
	return _fx


func test_reference_html_integro() -> void:
	var bytes := FileAccess.get_file_as_bytes(REFERENCE_HTML)
	check_eq(bytes.size(), 2128428, "dimensione HTML")
	check_eq(WorldFixture.sha256_hex(bytes), REFERENCE_SHA, "sha256 HTML")
	check_eq(str(_fixture().manifest["source"]["sha256"]), REFERENCE_SHA, "manifest.source.sha256")


func test_buffer_verificati() -> void:
	var fx := _fixture()
	check(fx.ok(), "errori fixture: %s" % [fx.errors])
	check_eq(str(fx.manifest["files"]["blocks"]["sha256"]), BLOCKS_SHA, "sha256 blocchi")


func test_dimensioni_e_chunk() -> void:
	var w := _fixture().world
	check_eq(Vector3i(w.size_x, w.size_y, w.size_z), Vector3i(192, 48, 192), "dimensioni")
	check_eq(w.cell_count(), 1769472, "celle")
	check_eq(w.chunk_count(), 432, "chunk 16^3")
	check_eq(Vector3i(w.chunks_x(), w.chunks_y(), w.chunks_z()), Vector3i(12, 3, 12), "griglia chunk")


func test_istogramma_blocchi() -> void:
	var w := _fixture().world
	var hist := {}
	for v in w.blocks:
		hist[v] = int(hist.get(v, 0)) + 1
	var expected: Dictionary = _fixture().manifest["stats"]["block_histogram"]
	for k: String in expected:
		check_eq(int(hist.get(int(k), 0)), int(expected[k]), "conteggio blocco %s" % k)
	check_eq(hist.size(), expected.size(), "tipi di blocco presenti")
	check_eq(int(hist.get(BlockCatalog.WATER, 0)), 5875, "celle acqua")


func test_layout_memoria() -> void:
	var w := _fixture().world
	check_eq(w.index(1, 0, 0), 1, "x e' l'asse piu' veloce")
	check_eq(w.index(0, 0, 1), w.size_x, "poi z")
	check_eq(w.index(0, 1, 0), w.size_x * w.size_z, "poi y")
	# y=0 e' interamente roccia madre (36864 = 192*192 celle BEDROCK).
	var bad := 0
	for z in w.size_z:
		for x in w.size_x:
			if w.get_block_xyz(x, 0, z) != BlockCatalog.BEDROCK:
				bad += 1
	check_eq(bad, 0, "colonne senza roccia madre a y=0")
	# surface[z*X+x] = solido piu' alto della colonna, verificato sul prototipo.
	var mismatch := 0
	for z in w.size_z:
		for x in w.size_x:
			var top := -1
			for y in range(w.size_y - 1, -1, -1):
				if w.is_solid_at(x, y, z):
					top = y
					break
			if top != w.surface_height(x, z):
				mismatch += 1
	check_eq(mismatch, 0, "colonne con surface incoerente")


func test_spawn_point() -> void:
	var w := _fixture().world
	check_eq(w.spawn_point(), Vector3(96.5, 28, 96.5), "spawnPoint")
	var s: Dictionary = _fixture().manifest["spawn"]
	check_eq(w.spawn_point(), Vector3(float(s["x"]), float(s["y"]), float(s["z"])), "spawn da manifest")


func test_fuori_dal_mondo() -> void:
	var w := _fixture().world
	check_eq(w.get_block_xyz(-1, 10, 0), BlockCatalog.AIR, "fuori x")
	check_eq(w.get_block_xyz(0, 48, 0), BlockCatalog.AIR, "sopra il mondo")
	check(w.is_solid_at(5, -1, 5), "sotto il mondo e' solido")
