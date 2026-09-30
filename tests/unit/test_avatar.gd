extends TestCase
## Eroe (M4, D-028): ricetta CHARGEN, scheletro con IK della mano sinistra, animazione.


func test_ricetta_andata_e_ritorno() -> void:
	var r := AvatarRecipe.random(77)
	var back := AvatarRecipe.from_dict(r.to_dict())
	check_eq(back.to_dict(), r.to_dict(), "stessa ricetta")
	var lab := r.cycle("hat")
	check(lab.begins_with("Cappello: "), "etichetta dell'editor (%s)" % lab)
	check_eq(AvatarRecipe.from_dict({"v": 99, "hat": "elmo"}).dna["hat"], "none", "versione sconosciuta ignorata")
	check_eq(AvatarRecipe.from_dict({"v": 2, "hat": "razzo"}).dna["hat"], "none", "scelta non valida ignorata")
	check_eq(AvatarRecipe.from_dict({"v": 2, "skin": "blu"}).dna["skin"], HeroChargen.BASE["skin"], "colore non valido ignorato")
	check_eq(AvatarRecipe.from_dict({"v": 1, "skin": 3}).to_dict(), AvatarRecipe.new().to_dict(), "ricetta della v1 -> Eroe 1")


func test_generatore_del_prototipo() -> void:
	# Stesso seme -> stesso eroe (Mulberry32 come il prototipo).
	check_eq(HeroChargen.random_dna(5), HeroChargen.random_dna(5), "deterministico")
	check(HeroChargen.random_dna(5) != HeroChargen.random_dna(6), "semi diversi")
	var parts := HeroChargen.build(HeroChargen.preset(0), HeroChargen.hair_lib())
	var bones := {}
	for p: Dictionary in parts:
		bones[p["bone"]] = true
	check_eq(bones.size(), 10, "testa, busto e otto mezzi arti")
	check(not HeroChargen.hair_lib().is_empty(), "capelli originali caricati")
	# Ogni scelta dell'editor costruisce senza errori.
	for k: String in HeroChargen.OPTIONS:
		for o: Array in HeroChargen.OPTIONS[k]:
			var d := HeroChargen.preset(0)
			d[k] = o[0]
			check(HeroChargen.build(d, HeroChargen.hair_lib()).size() >= 10, "%s = %s" % [k, o[0]])


func test_scheletro_e_altezza() -> void:
	var rig := AvatarRig.new()
	rig.sync_ao = true
	rig.build(AvatarRecipe.new())
	check_eq(rig.bones.size(), AvatarRig.BONES.size(), "ossa")
	rig.set_weapon(WeaponLibrary.by_id(&"sword"))
	check(rig.instance_count() >= 11, "mesh create: testa, busto, otto mezzi arti, arma")
	var aabb := AABB()
	var first := true
	for gi: GeometryInstance3D in rig._instances:
		var mi := gi as MeshInstance3D
		if mi.get_parent() == rig.socket:
			continue
		var b := rig.rig_xf(mi) * mi.mesh.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	check(absf(aabb.position.y) < 0.03, "piedi a terra (%f)" % aabb.position.y)
	check(aabb.end.y > AvatarRig.HEIGHT - 0.02 and aabb.end.y < 1.56, "altezza col ciuffo %f" % aabb.end.y)
	# Testa grande come nel prototipo: dal collo in su ~40% dell'altezza.
	check(absf(rig.rig_xf(rig.bones[&"head"]).origin.y - 0.80) < 0.01, "collo a .80")
	rig.free()


func test_animazione_finita_e_nuoto_prono() -> void:
	var an := AvatarAnimator.new()
	var s := AvatarAnimator.State.new()
	s.weapon = WeaponLibrary.by_id(&"sword")
	s.speed = 5.5
	for i in 120:
		an.update(1.0 / 60.0, s)
	for k: StringName in an.pose:
		var v: Vector3 = an.pose[k]
		check(v.is_finite(), "osso %s finito" % k)
	check(absf((an.pose[&"leg_l"] as Vector3).x) > 0.05 or absf((an.pose[&"leg_r"] as Vector3).x) > 0.05, "gambe in movimento")
	s.speed = 0.0
	s.swimming = true
	for i in 90:
		an.update(1.0 / 60.0, s)
	check((an.pose[&"body"] as Vector3).x < deg_to_rad(-55.0), "corpo prono nel nuoto (%f)" % (an.pose[&"body"] as Vector3).x)


func test_il_colpo_segue_le_pose_chiave() -> void:
	var w := WeaponLibrary.by_id(&"sword")
	var a := w.attack(&"slash")
	var an := AvatarAnimator.new()
	var s := AvatarAnimator.State.new()
	s.weapon = w
	s.attack = a
	s.phase = 1
	s.u = 1.0
	var p := an.target_pose(0.0, s)
	check(p[&"arm_r"].is_equal_approx(a.key_strike[&"arm_r"]), "fine colpo = posa del colpo")
	s.phase = 0
	s.u = 1.0
	p = an.target_pose(0.0, s)
	check(p[&"chest"].is_equal_approx(a.key_wind[&"chest"]), "fine carica = posa di carica")
	# Capriola: a meta' il corpo e' capovolto.
	var s2 := AvatarAnimator.State.new()
	s2.dodge = 0.5
	var p2 := an.target_pose(0.0, s2)
	check(absf(absf((p2[&"body"] as Vector3).x) - PI) < 0.01, "capriola a meta': mezzo giro")


func _tris(parts: Array, bone: String, name: String = "") -> int:
	var n := 0
	for p: Dictionary in parts:
		if p["bone"] == bone and (name == "" or p["name"] == name):
			n += (p["geo"]["index"] as PackedInt32Array).size() / 3
	return n


func test_facce_sotto_l_armatura_tolte() -> void:
	var r := AvatarRecipe.new()
	var none := AvatarRig.body_parts(r, {})
	var iron := Color(0.78, 0.66, 0.58)
	var worn := AvatarRig.body_parts(r, {"head": iron, "chest": iron, "legs": iron, "feet": iron})
	check(_tris(worn, "torso", "busto") < _tris(none, "torso", "busto"), "busto coperto dalla corazza")
	check(_tris(worn, "head", "capelli") < _tris(none, "head", "capelli"), "capelli sotto l'elmo")
	check_eq(_tris(worn, "head", "orecchio"), 0, "niente orecchie che bucano l'elmo")
	check(_tris(worn, "head", "testa") > 0, "il viso resta")
	# Nessun triangolo rimasto tutto dentro un volume dell'armatura.
	var boxes := AvatarRig.armor_boxes({"chest": iron})
	var inside := 0
	for p: Dictionary in AvatarRig.body_parts(r, {"chest": iron}):
		for b: AABB in boxes.get(p["bone"], []):
			var P: PackedVector3Array = p["geo"]["position"]
			var I: PackedInt32Array = p["geo"]["index"]
			for j in range(0, I.size(), 3):
				if b.has_point(P[I[j]]) and b.has_point(P[I[j + 1]]) and b.has_point(P[I[j + 2]]):
					inside += 1
	check_eq(inside, 0, "niente facce dentro la corazza")
