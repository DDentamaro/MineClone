extends TestCase
## Vegetazione: densita', quota del suolo, alberi ed erba uguali al prototipo.

var _cat := BlockCatalog.load_default()
var _w: WorldData


func _world() -> WorldData:
	if _w == null:
		_w = WorldFixture.load_dir(WorldFixture.SEED1931_DIR, _cat, false).world
		var biome := FileAccess.get_file_as_bytes(WorldFixture.SEED1931_DIR.path_join("biome.u8.gz"))
		_w.biome = biome.decompress(192 * 192, FileAccess.COMPRESSION_GZIP)
	return _w


func test_densita_uguale_a_computeDensity() -> void:
	var w := _world()
	var ref := RenderFixture.buffer("density.u8")
	var op := _cat.opaque_table()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad := 0
	var cells: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(191, 47, 191), Vector3i(0, 47, 191), Vector3i(96, 28, 96)]
	for i in 6000:
		cells.append(Vector3i(rng.randi_range(0, 191), rng.randi_range(0, 47), rng.randi_range(0, 191)))
	for c in cells:
		if Vegetation.density_cell(w, op, c.x, c.y, c.z) != ref[w.index(c.x, c.y, c.z)]:
			bad += 1
	check_eq(bad, 0, "celle con densita' diversa")


func test_quota_del_suolo() -> void:
	var w := _world()
	for g: Dictionary in RenderFixture.manifest()["ground"]:
		var h := Vegetation.ground_height(w, _cat.opaque_table(), float(g["x"]), float(g["z"]))
		check_eq(h, float(g["h"]), "groundHeight(%s, %s)" % [g["x"], g["z"]])


func test_posizioni_degli_alberi() -> void:
	var w := _world()
	var spots := Vegetation.tree_spots(w, _cat.opaque_table(), 1931)
	var ref := RenderFixture.buffer("tree_spots.f64").to_float64_array()
	check_eq(spots.size(), ref.size() / 7, "numero di alberi (498)")
	var bad := 0
	for i in mini(spots.size(), ref.size() / 7):
		var s := spots[i]
		var got := [s.x, s.y, s.z, float(s.kind), s.rot, s.scale, s.seed_value]
		for k in 7:
			if float(got[k]) != ref[i * 7 + k]:
				bad += 1
				if bad <= 2:
					current_failures.append("albero %d campo %d: %.17f vs %.17f" % [i, k, got[k], ref[i * 7 + k]])
	check_eq(bad, 0, "alberi diversi")


func test_template_degli_alberi() -> void:
	for t: Dictionary in RenderFixture.manifest()["templates"]:
		var tpl := Vegetation.tree_template(int(t["kind"]), int(t["seed"]))
		var name := "tree_template_%d_%d.f32" % [int(t["kind"]), int(t["variant"])]
		check_eq(tpl.verts(), int(t["verts"]), "%s vertici" % name)
		check_eq(tpl.height, float(t["height"]), "%s altezza" % name)
		check_eq(WorldFixture.sha256_hex(tpl.data.to_byte_array()), str(t["sha256"]), "%s dati" % name)


func test_fili_d_erba_per_colonna() -> void:
	var w := _world()
	var ref: Array = RenderFixture.manifest()["grass"]
	var bad := 0
	var total := 0
	for g: Dictionary in ref:
		var c: Array = g["c"]
		# Un terzo delle colonne per contenere i tempi, piu' la (6,6) completa.
		if (int(c[0]) + int(c[1])) % 3 != 0 and not (int(c[0]) == 6 and int(c[1]) == 6):
			continue
		var b := Vegetation.grass_blades(w, int(c[0]), int(c[1]), 1931, 0.27)
		total += b.size() / 7
		if b.size() / 7 != int(g["blades"]) or WorldFixture.sha256_hex(b.to_byte_array()) != str(g["sha256"]):
			bad += 1
	check_eq(bad, 0, "colonne con fili diversi")
	check(total > 50000, "fili confrontati: %d" % total)
