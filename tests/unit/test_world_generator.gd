extends TestCase
## Parita' del generatore v0_64 portato (WorldGenerator) col prototipo, su un mondo
## piccolo con grotte (64x32x64, seme 7): sha per passata, fasi pre-fluidi / sponde /
## initFluid, stato finale, statistiche e scenario dei fluidi (FluidSystem).
## Il mondo 192x48x192 si verifica con tools/verify_generator.gd (vedi docs/DECISIONS.md).

const SMALL := "seed7_64x32x64_caves"

var _parity: GenParity


func _small() -> GenParity:
	if _parity == null:
		_parity = GenParity.new(SMALL)
		_parity.run_generation(BlockCatalog.load_default())
	return _parity


func test_mondo_piccolo_passate_e_fasi_identiche() -> void:
	var p := _small()
	check(p.world != null, "mondo non generato")
	check(p.errors.is_empty(), "differenze: %s" % "\n         ".join(p.errors.slice(0, 12)))


func test_mondo_piccolo_statistiche() -> void:
	var w := _small().world
	check_eq(w.generator_version, "v0_64", "versione generatore")
	check_eq(w.world_seed, 7, "seme")
	check_eq(w.spawn_point(), Vector3(32.5, 20, 32.5), "spawnPoint")
	check_eq(int(w.water_info["lakes"]), 1, "laghi")
	check_eq((w.water_info["rivers"] as Array).size(), 2, "fiumi")
	var names: Array = []
	for e: Array in w.gen_log:
		names.append(e[0])
	check_eq(names.slice(0, 11), Array(WorldGenerator.PASS_NAMES), "ordine delle passate nel log")


func test_scenario_fluidi_dopo_edit() -> void:
	var p := _small()
	var before := p.errors.size()
	p.run_gameplay()
	var new_errors := p.errors.slice(before)
	check(new_errors.is_empty(), "differenze: %s" % "\n         ".join(new_errors.slice(0, 12)))


func test_grotte_disattivabili() -> void:
	var cat := BlockCatalog.load_default()
	var a := WorldData.new(48, 24, 48, cat.solid_table())
	var b := WorldData.new(48, 24, 48, cat.solid_table())
	var c1 := WorldGenerator.run_passes(a, 11, {"caves": false})
	var c2 := WorldGenerator.run_passes(b, 11, {})
	check(c1.caves == false and c2.caves == true, "opzione caves")
	check(a.blocks != b.blocks, "le grotte cambiano i blocchi")
	check_eq(a.surface, b.surface, "le grotte non toccano surface")


func test_determinismo() -> void:
	var cat := BlockCatalog.load_default()
	var a := WorldGenerator.generate(WorldData.new(40, 24, 40, cat.solid_table()), 99)
	var b := WorldGenerator.generate(WorldData.new(40, 24, 40, cat.solid_table()), 99)
	check(a.blocks == b.blocks and a.fluid == b.fluid, "due generazioni identiche")
