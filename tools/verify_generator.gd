extends SceneTree
## Verifica completa del generatore portato contro il prototipo (troppo lenta per la suite):
## mondi 96x40x80 e 192x48x192 delle fixture tests/fixtures/gen_v064, piu' la fixture
## originale seed1931_v064 (sha dei buffer finali, spawn, biomi, laghi, fiumi).
## Stampa i tempi per passata. Esce con codice 1 se qualcosa differisce.
## Uso: godot --headless --path . --script res://tools/verify_generator.gd [-- --only=<nome>]

const WORLDS: Array[String] = ["seed1931_96x40x80_caves", "seed1931_192x48x192", "seed42_192x48x192_caves"]


func _initialize() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var cat := BlockCatalog.load_default()
	var failed := 0
	for name in WORLDS:
		if only != "" and name != only:
			continue
		var p := GenParity.new(name)
		p.run_generation(cat)
		var gen_errors := p.errors.size()
		var js_ms := float((p.manifest["stats"] as Dictionary)["gen_ms"])
		print("%s: generazione %s (%.0f ms GDScript, %.0f ms JS)" % [name, "IDENTICA" if gen_errors == 0 else "DIVERSA", p.gen_ms, js_ms])
		for e: Array in p.world.gen_log:
			var extra := " (%d tick)" % int(e[2]) if e.size() > 2 else ""
			print("    %-16s %9.1f ms%s" % [str(e[0]), float(e[1]), extra])
		var t0 := Time.get_ticks_usec()
		p.run_gameplay()
		if p.manifest.get("gameplay") is Dictionary:
			print("  scenario fluidi: %s (%.0f ms)" % ["IDENTICO" if p.errors.size() == gen_errors else "DIVERSO", (Time.get_ticks_usec() - t0) / 1000.0])
		if name == "seed1931_192x48x192":
			failed += _check_original(p)
		for msg in p.errors.slice(0, 20):
			print("  - " + msg)
		if not p.errors.is_empty():
			failed += 1
	print("verifica generatore: %s" % ("OK" if failed == 0 else "%d FALLITE" % failed))
	quit(1 if failed > 0 else 0)


## Confronto con la fixture M0 (tools/extract_fixture.mjs), rigenerando un mondo pulito.
func _check_original(_p: GenParity) -> int:
	var fx := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, BlockCatalog.load_default(), false)
	var files: Dictionary = fx.manifest["files"]
	var w := WorldData.new(192, 48, 192, BlockCatalog.load_default().solid_table())
	WorldGenerator.generate(w, 1931, {"caves": false})
	var bad := 0
	for js_name: String in ["blocks", "fluid", "surface", "biome", "waterLevel"]:
		var got := GenParity.sha(GenParity.js_bytes(w, js_name))
		var exp := str((files[js_name] as Dictionary)["sha256"])
		print("  seed1931_v064 %-10s %s  %s" % [js_name, "==" if got == exp else "!=", got])
		if got != exp:
			bad += 1
	var st: Dictionary = fx.manifest["stats"]
	var s: Dictionary = fx.manifest["spawn"]
	var spawn_ok := w.spawn_point() == Vector3(float(s["x"]), float(s["y"]), float(s["z"]))
	var share: Array = []
	for v in w.biome_share:
		share.append(v)
	var exp_share: Array = []
	for v: Variant in st["biome_share_pct"]:
		exp_share.append(int(v))
	var lakes_ok := int(w.water_info["lakes"]) == int(st["lakes"])
	var rivers_ok := (w.water_info["rivers"] as Array).size() == int(st["rivers"])
	var cells_ok := int(w.water_info["cells"]) == int(st["water_level_cells"])
	print("  seed1931_v064 spawn %s %s, biomeShare %s %s, laghi %d %s, fiumi %d %s, celle acqua %d %s" % [
		w.spawn_point(), "==" if spawn_ok else "!=", share, "==" if share == exp_share else "!=",
		int(w.water_info["lakes"]), "==" if lakes_ok else "!=", (w.water_info["rivers"] as Array).size(),
		"==" if rivers_ok else "!=", int(w.water_info["cells"]), "==" if cells_ok else "!="])
	if not (spawn_ok and share == exp_share and lakes_ok and rivers_ok and cells_ok):
		bad += 1
	return 1 if bad > 0 else 0
