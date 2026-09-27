extends TestCase


func _grains() -> Grains:
	var g := Grains.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	return g


func test_colori_degli_elementi() -> void:
	check_eq(Grains.el_color("water", 1.0), Vector3(.94, .99, 1), "picco")
	check_eq(Grains.el_color("water", 0.0), Vector3(.025, .09, .14), "ombra")
	check_eq(Grains.el_color("sconosciuto", 0.0), Vector3(.08, .035, .018), "ripiego sul fuoco")


func test_pool_limitato_e_vita() -> void:
	var gs := _grains()
	for i in Grains.CAP + 50:
		var g := Grains.Grain.new()
		g.life = 0.5
		gs.add(g)
	check_eq(gs.count(), Grains.CAP, "tetto del pool")
	gs.step(0.6)
	check_eq(gs.count(), 0, "scaduti")
	gs.free()


func test_goccia_sparisce_in_acqua_e_cade() -> void:
	var w := TestWorlds.flat(4, 32, 16, 32)
	TestWorlds.fill(w, Vector3i(8, 4, 8), Vector3i(12, 5, 12), BlockCatalog.WATER)
	FluidSystem.init_fluid(w)
	var gs := _grains()
	gs.world = w
	var drop := Grains.Grain.new()
	drop.p = Vector3(10.5, 7.5, 10.5)
	drop.g = 9.0
	drop.life = 5.0
	drop.water_drop = true
	gs.add(drop)
	var dry := Grains.Grain.new()
	dry.p = Vector3(20.5, 7.5, 20.5)
	dry.g = 9.0
	dry.life = 5.0
	dry.ground = true
	dry.stick = true
	gs.add(dry)
	for i in 120:
		gs.step(1.0 / 60.0)
	check_eq(gs.count(), 1, "la goccia e' entrata in acqua")
	check(absf(dry.p.y - 4.02) < 1e-4, "l'altro grano si appoggia al suolo (y=%f)" % dry.p.y)
	gs.free()
