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


## D-048: girando in corsa (analogico a destra o sinistra) il corpo non si inclina di lato.
func test_nessuna_inclinazione_in_curva() -> void:
	var rolls := []
	for turn in [0.0, 4.0, -4.0]:
		var an := AvatarAnimator.new()
		var s := AvatarAnimator.State.new()
		s.weapon = WeaponLibrary.by_id(&"sword")
		s.speed = 5.5
		s.turn = turn
		for i in 60:
			an.update(1.0 / 60.0, s)
		rolls.append((an.pose[&"body"] as Vector3).z)
	check(is_equal_approx(rolls[0], rolls[1]) and is_equal_approx(rolls[0], rolls[2]), "corpo dritto in curva %s" % [rolls])


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


## D-041: in terza persona la lancia affonda dritta (non spazza) e ferisce solo
## con la punta di ferro.
func test_lancia_affonda_dritta_e_ferisce_di_punta() -> void:
	var w := WeaponLibrary.by_id(&"spear")
	var rig := AvatarRig.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	rig.build(AvatarRecipe.new())
	rig.set_weapon(w)
	for aid in [&"thrust", &"thrust2", &"rise", &"impale", &"drive", &"charge", &"dash_thrust"]:
		var a := w.attack(aid)
		var worst := 0.0
		var tip0 := 0.0
		var tip1 := 0.0
		for k in 7:
			var s := AvatarAnimator.State.new()
			s.weapon = w
			s.attack = a
			s.phase = 0 if k == 0 else 1
			s.u = 1.0 if k == 0 else float(k) / 6.0
			rig.apply_pose(AvatarAnimator.new().target_pose(0.0, s))
			var g := rig.socket.global_transform
			var d := g * Vector3(0, w.trail_to, 0) - g.origin
			worst = maxf(worst, absf(rad_to_deg(atan2(d.x, -d.z))))
			var f := -(g * Vector3(0, w.trail_to, 0)).z
			if k == 0:
				tip0 = f
			tip1 = f
		check(worst < 12.0, "%s: la lancia resta dritta davanti (scarto massimo %.0f°)" % [aid, worst])
		check(tip1 - tip0 > 0.5, "%s: la punta va avanti (%.2f m)" % [aid, tip1 - tip0])
	# Le sfere che feriscono stanno tutte sulla testa della lancia.
	var g := rig.socket.global_transform
	for hb: Array in rig.hitboxes():
		var local: Vector3 = g.affine_inverse() * (hb[0] as Vector3)
		check(local.y >= 1.19, "sfera sulla punta (%.2f)" % local.y)
	rig.free()


## D-053: con l'elmo nessun pezzo di capelli resta, per nessuna acconciatura
## (prima le ciocche laterali di alcune uscivano dai lati dell'elmo).
func test_capelli_sotto_l_elmo() -> void:
	var iron := Color(0.78, 0.80, 0.84)
	for hs: Array in HeroChargen.OPTIONS["hairStyle"]:
		var r := AvatarRecipe.preset(0)
		r.dna["hairStyle"] = hs[0]
		var hair := 0
		for p: Dictionary in AvatarRig.body_parts(r, {"head": iron}):
			if p["name"] == "capelli" or p["name"] == "laccio":
				hair += 1
		check_eq(hair, 0, "%s: niente capelli sotto l'elmo" % hs[0])
	var bare := AvatarRecipe.preset(0)
	bare.dna["hairStyle"] = "lungo"
	var n := 0
	for p: Dictionary in AvatarRig.body_parts(bare, {}):
		n += 1 if p["name"] == "capelli" else 0
	check(n > 0, "senza elmo i capelli ci sono")



func test_armature_modulari() -> void:
	# D-065: un set e' una lista di moduli; i moduli si mescolano per nome.
	check_eq(Array(ArmorKit.modules_for("chest", "iron")).size(), 6, "busto di ferro in sei moduli")
	check(ArmorKit.knows("head", "chain"), "set di maglia")
	var mix := ArmorKit.boxes("chest", Color(0.6, 0.6, 0.6), "iron_cuirass+leather_bracers@leather")
	var mats := {}
	for b: Array in mix:
		mats[snappedf((b[5] as Color).a, 0.01)] = true
	check(mats.has(ArmorKit.PLATE) and mats.has(ArmorKit.LEATHER) and mats.has(ArmorKit.BRASS), "piastra, cuoio e ottone: %s" % [mats.keys()])
	# Il ferro di prima e' lo stesso, ma diviso in moduli.
	check_eq(ArmorKit.boxes("chest", Color(0.6, 0.6, 0.6), "iron").size(), IronArmor.boxes("chest", Color(0.6, 0.6, 0.6)).size(), "stessi pezzi del set di ferro")
	var rig := AvatarRig.new()
	rig.sync_ao = true
	rig.build(AvatarRecipe.new())
	var c := ArmorKit.PALETTE["mail"]
	rig.set_armor_all({"head": c, "chest": c, "legs": c, "feet": c}, {"head": "chain", "chest": "chain", "legs": "chain", "feet": "chain"})
	check(rig._armor.size() == 4, "maglia indossata")
	rig.free()
