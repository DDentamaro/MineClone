extends TestCase
## Terra come il reticolo di RMNDWN (D-032): granelli che volano nelle celle e si
## bloccano scuri, costrutti che si rompono e si sgretolano in un mucchio.

const DT := 1.0 / 60.0


func _fx(world: WorldData) -> EarthFx:
	var fx := EarthFx.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fx)
	fx.world = world
	fx.set_process(false)
	return fx


func _flat() -> WorldData:
	var world := TestWorlds.flat(4, 32, 16, 32)
	TestWorlds.fill(world, Vector3i(0, 3, 0), Vector3i(31, 3, 31), BlockCatalog.STONE)
	return world


func test_masso_si_compone_e_si_rompe() -> void:
	var fx := _fx(_flat())
	var slots := EarthFx.ball_slots(0.28, 0.062)
	check(slots.size() > 200 and slots.size() < 700, "palla piena di granelli (%d)" % slots.size())
	var center := Vector3(16, 6, 16)
	var c := fx.build("m", slots, Transform3D(Basis.IDENTITY, center), Vector3(14, 4, 16), 1.0, 0.75, 0.06, 7.0)
	check_eq(c.bricks.size(), slots.size(), "un granello per cella")
	check(c.bricks[0].p.y < 4.2 and c.bricks[0].T > 0.7, "partono dal suolo come polvere chiara")
	for i in int(0.8 / DT):
		fx.step(DT)
	var locked := 0
	var dark := 0
	for b in c.bricks:
		if b.locked:
			locked += 1
		if b.T <= EarthFx.PACKED_IN + 1e-4:
			dark += 1
	check_eq(locked, c.bricks.size(), "tutti bloccati entro lockBy")
	check_eq(dark, c.bricks.size(), "terra compatta scura (T <= .14)")
	fx.release("m", Vector3(3, 0, 0), 3.0)
	check(not fx.has("m"), "costrutto rotto")
	for i in int(2.5 / DT):
		fx.step(DT)
	var settled := 0
	for b in fx.bricks:
		if b.settled:
			settled += 1
		check(b.p.y >= 4.0 - 0.01, "nessun granello sotto il suolo")
	check(settled > fx.bricks.size() * 0.8, "mucchio fermo (%d/%d)" % [settled, fx.bricks.size()])
	for i in int(5.0 / DT):
		fx.step(DT)
	check_eq(fx.count(), 0, "spariti dopo il tempo del mucchio")
	fx.queue_free()


func test_cono_con_la_punta_avanti() -> void:
	var slots := EarthFx.cone_slots(0.30, 1.25, 0.07)
	var tip := Vector3.ZERO
	for p in slots:
		if p.z < tip.z:
			tip = p
	check(tip.z < -0.8 and Vector2(tip.x, tip.y).length() < 0.05, "punta su -Z (%s)" % tip)
	var base_r := 0.0
	for p in slots:
		if p.z > 0.2:
			base_r = maxf(base_r, Vector2(p.x, p.y).length())
	check(absf(base_r - 0.30) < 0.05, "base larga R (%f)" % base_r)


func test_sgretolamento() -> void:
	var fx := _fx(_flat())
	var slots := EarthFx.box_slots(Vector3(1.5, 0.62, 0.68), 0.22)
	fx.build("q", slots, Transform3D(Basis.IDENTITY, Vector3(10, 4.4, 10)), Vector3(10, 4, 10), 0.5, 0.2, 0.15)
	for i in 20:
		fx.step(DT)
	fx.crumble("q")
	check(not fx.has("q"), "celle lasciate andare")
	var up := 0
	for b in fx.bricks:
		if b.v.y >= 0.6 and absf(b.v.x) <= 1.4 and absf(b.v.z) <= 1.4:
			up += 1
	check_eq(up, fx.bricks.size(), "v = (±1,4, .6–2,0, ±1,4)")
	fx.queue_free()


func test_rampa_della_terra() -> void:
	check(EarthFx.ramp(0.0).is_equal_approx(Color8(0x33, 0x26, 0x1a)), "scura in basso")
	check(EarthFx.ramp(1.0).is_equal_approx(Color8(0xdc, 0xc5, 0x9f)), "chiara in alto")
