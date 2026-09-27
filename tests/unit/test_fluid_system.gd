extends TestCase
## FluidSystem: parti non coperte dallo scenario registrato in test_world_generator.


func test_maschera_solidi_uguale_al_catalogo() -> void:
	var solid := BlockCatalog.load_default().solid_table()
	for id in 16:
		check_eq(FluidSystem.is_solid_id(id), id < solid.size() and solid[id] == 1, "SOLID[%d]" % id)


func test_sample_water_senza_livelli_fluido() -> void:
	# Ramo di compatibilita' di sampleWater: mondo senza buffer fluid, solo waterLevel.
	var w := TestWorlds.flat(4, 8, 12, 8)
	w.fluid = PackedByteArray()
	w.water_level[3 * 8 + 3] = 6
	var s := FluidSystem.sample_water(w, 3.5, 4.5, 3.5)
	check_eq(s["wet"], true, "bagnato")
	check_eq(s["level"], 6 - 0.2, "livello")
	check_eq(s["depth"], (6 - 0.2) - 4, "profondita'")
	check_eq(s["floor"], 4, "fondo = fieldHeight")
	check_eq(s["immersion"], minf((6 - 0.2) - 4, (6 - 0.2) - 4.5), "immersione")
	check_eq(s["body"], 1, "corpo senza etichette")
	check_eq(FluidSystem.sample_water(w, 5.5, 4.5, 3.5)["wet"], false, "colonna asciutta")


func test_edit_senza_init_non_accoda() -> void:
	var w := TestWorlds.flat(4, 8, 12, 8)
	FluidSystem.edit_fluid(w, 2, 4, 2, BlockCatalog.WATER)
	check_eq(w.fluid[w.index(2, 4, 2)], 24, "sorgente scritta")
	check(w.fluid_queue.is_empty(), "nessuna coda prima di init_fluid")
	check(FluidSystem.step_fluid(w).is_empty(), "step senza init non fa nulla")
