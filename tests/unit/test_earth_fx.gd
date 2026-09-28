extends TestCase
## Zolle vere della terra (D-032): costrutti che si compongono, si rompono,
## cadono a terra e spariscono.

const DT := 1.0 / 60.0


func _fx(world: WorldData) -> EarthFx:
	var fx := EarthFx.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fx)
	fx.world = world
	fx.set_process(false)
	return fx


func test_masso_si_compone_e_si_rompe() -> void:
	var world := TestWorlds.flat(4, 32, 16, 32)
	TestWorlds.fill(world, Vector3i(0, 3, 0), Vector3i(31, 3, 31), BlockCatalog.STONE)
	var fx := _fx(world)
	var slots := EarthFx.ball_slots(0.34, 0.09)
	check(slots.size() > 60 and slots.size() < 500, "palla di zolle (%d)" % slots.size())
	var center := Vector3(16, 6, 16)
	var c := fx.build("m", slots, Transform3D(Basis.IDENTITY, center), Vector3(14, 4, 16), 1.0, 0.5, 0.12)
	check_eq(c.chunks.size(), slots.size(), "una zolla per posto")
	check(c.chunks[0].p.y < 4.2, "le zolle partono dal suolo")
	for i in int(0.7 / DT):
		fx.step(DT)
	var locked := 0
	for ch in c.chunks:
		if ch.locked:
			locked += 1
	check_eq(locked, c.chunks.size(), "tutte incastrate nel masso")
	check(c.chunks[0].p.distance_to(center) < 0.5, "attorno al centro")
	fx.release("m", Vector3(3, 0, 0), 3.0)
	check(not fx.has("m"), "costrutto rotto")
	for i in int(1.5 / DT):
		fx.step(DT)
	var resting := 0
	for ch in fx.chunks:
		if ch.resting:
			resting += 1
		check(ch.p.y >= 4.0 - 0.01, "nessuna zolla sotto il suolo")
	check(resting > fx.chunks.size() / 2, "a terra ferme (%d/%d)" % [resting, fx.chunks.size()])
	for i in int(4.0 / DT):
		fx.step(DT)
	check_eq(fx.count(), 0, "sparite dopo qualche secondo")
	fx.queue_free()


func test_cono_con_la_punta_avanti() -> void:
	var slots := EarthFx.cone_slots(0.30, 1.25, 0.11)
	var tip := Vector3.ZERO
	for p in slots:
		if p.z < tip.z:
			tip = p
	check(tip.z < -0.8 and Vector2(tip.x, tip.y).length() < 0.05, "punta su -Z (%s)" % tip)
	var base_r := 0.0
	for p in slots:
		if p.z > 0.2:
			base_r = maxf(base_r, Vector2(p.x, p.y).length())
	check(absf(base_r - 0.30) < 0.02, "base larga R (%f)" % base_r)


func test_lastre_si_sbriciolano() -> void:
	var world := TestWorlds.flat(4, 32, 16, 32)
	TestWorlds.fill(world, Vector3i(0, 3, 0), Vector3i(31, 3, 31), BlockCatalog.STONE)
	var fx := _fx(world)
	var sizes: Array[Vector3] = [Vector3(1.5, 0.62, 0.68), Vector3(1.5, 0.62, 0.68)]
	fx.build_manual("q", sizes)
	fx.set_chunk("q", 0, Vector3(10, 4.3, 10), Quaternion.IDENTITY)
	fx.set_chunk("q", 1, Vector3(12, 4.3, 10), Quaternion.IDENTITY)
	fx.crumble("q", 0.13)
	check(not fx.has("q"), "lastre sbriciolate")
	check(fx.count() > 4, "in tante zolle piccole (%d)" % fx.count())
	for ch in fx.chunks:
		check(ch.s.x < 0.3, "zolle piccole")
	fx.queue_free()
