extends TestCase
## Passo del prototipo (D-028): piedi piantati senza scivolare, alternanza,
## assestamento da fermi, gradini, gambe raccolte in aria, IK a lunghezza fissa.

const DT := 1.0 / 60.0


class Walker:
	extends RefCounted
	var g := GaitLegs.new()
	var pos := Vector3(10, 4, 10)
	var facing := 0.0
	var ground := func(_x: float, _z: float) -> float: return 4.0

	func step(vel: Vector3, on_ground: bool = true) -> void:
		pos += vel * DT
		g.update(DT, Transform3D(Basis(Vector3.UP, facing), pos), vel, on_ground, 5.5, ground)


func test_ik_lunghezze_fisse_e_ginocchio_avanti() -> void:
	var hip := Vector3(0.1, 0.32, 0)
	var ks := GaitLegs.solve(hip, Vector3(0.1, 0.06, -0.05), 1.0)
	check(absf(ks[0].distance_to(hip) - GaitLegs.L1) < 1e-4, "coscia lunga L1")
	check(absf(ks[1].distance_to(ks[0]) - GaitLegs.L2) < 1e-4, "stinco lungo L2")
	check(ks[0].z < hip.z, "ginocchio in avanti (-Z)")
	var far := GaitLegs.solve(hip, Vector3(0.1, -1.0, 0), 1.0)
	check(far[1].distance_to(hip) <= (GaitLegs.L1 + GaitLegs.L2) + 1e-4, "bersaglio lontano: gamba tesa, non oltre")


func test_fermo_piedi_piantati_sotto_le_anche() -> void:
	var w := Walker.new()
	for i in 30:
		w.step(Vector3.ZERO)
	for l in w.g.legs:
		check(l.planted, "piantato")
		check(absf(l.foot.y - 4.0) < 1e-4, "a terra")
		check(absf(l.foot.x - (10.0 + l.side * GaitLegs.HIP_W)) < 1e-3, "sotto l'anca")
		check(absf(l.ankle.y - GaitLegs.FOOT_H) < 1e-3, "caviglia sopra il piede")


func test_camminando_il_piede_d_appoggio_non_scivola() -> void:
	var w := Walker.new()
	var vel := Vector3(0, 0, -3.0)
	var swings := [0, 0]
	var slide := 0.0
	var prev: Array = [null, null]
	for i in 180:
		w.step(vel)
		for k in 2:
			var l: GaitLegs.Leg = w.g.legs[k]
			if l.planted:
				if prev[k] != null:
					slide = maxf(slide, (prev[k] as Vector3).distance_to(l.foot))
				prev[k] = l.foot
			else:
				if prev[k] != null:
					swings[k] += 1
				prev[k] = null
	check(slide < 1e-5, "piede piantato fermo nel mondo (%f)" % slide)
	check(swings[0] >= 3 and swings[1] >= 3, "passi alternati %s" % [swings])
	# Mai entrambe in volo camminando (appoggio > 50% a 3 m/s? no: 0,43 -> volo breve ammesso).
	check(w.g.legs[0].foot.z < 10.0 - 4.0, "i piedi avanzano col corpo (%f)" % w.g.legs[0].foot.z)


func test_fermandosi_i_piedi_si_assestano() -> void:
	var w := Walker.new()
	for i in 60:
		w.step(Vector3(2.0, 0, 0))
	for i in 60:
		w.step(Vector3.ZERO)
	var right := Vector3(1, 0, 0)
	for l in w.g.legs:
		var home := w.pos + right * (l.side * GaitLegs.HIP_W)
		check(l.planted, "piantato")
		check(Vector2(l.foot.x - home.x, l.foot.z - home.z).length() <= GaitLegs.SETTLE_DIST + 0.01, "vicino a casa dopo l'assestamento")


func test_gradino_e_aria() -> void:
	var w := Walker.new()
	w.ground = func(x: float, _z: float) -> float: return 4.0 if x < 10.0 else 4.3
	for i in 60:
		w.step(Vector3.ZERO)
	var lo := w.g.legs[0]
	var hi := w.g.legs[1]
	check(absf(lo.foot.y - 4.0) < 1e-4 and absf(hi.foot.y - 4.3) < 1e-4, "ogni piede sul suo suolo")
	check(w.g.drop <= GaitLegs.DROP_MAX + 1e-4, "bacino limitato")
	var a := Walker.new()
	for i in 30:
		a.step(Vector3(0, 3.0, 0), false)
	for l in a.g.legs:
		check(not l.planted, "in aria niente appoggio")
		check(l.ankle.y > GaitLegs.FOOT_H + 0.05, "gambe raccolte (%f)" % l.ankle.y)
