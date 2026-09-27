extends TestCase
## Eroe (M4): ricetta, scheletro con IK della mano sinistra, animazione.


func test_ricetta_andata_e_ritorno() -> void:
	var r := AvatarRecipe.random(77)
	var back := AvatarRecipe.from_dict(r.to_dict())
	check_eq(back.to_dict(), r.to_dict(), "stessa ricetta")
	var lab := r.cycle("build")
	check(lab != "" and lab != "build", "etichetta dell'editor")
	check_eq(AvatarRecipe.from_dict({"v": 99, "skin": 3}).skin, 0, "versione sconosciuta ignorata")
	check_eq(AvatarRecipe.from_dict({"v": 1, "skin": 999}).skin, AvatarRecipe.SKINS.size() - 1, "valori limitati")


func test_scheletro_e_altezza() -> void:
	var rig := AvatarRig.new()
	rig.build(AvatarRecipe.new())
	check_eq(rig.bones.size(), AvatarRig.BONES.size(), "ossa")
	rig.set_weapon(WeaponLibrary.by_id(&"sword"))
	check(rig.instance_count() >= AvatarRig.BONES.size() - 1, "mesh create")
	var aabb := AABB()
	var first := true
	for gi: GeometryInstance3D in rig._instances:
		var mi := gi as MeshInstance3D
		if mi.get_parent() == rig.socket:
			continue
		var b := rig.rig_xf(mi) * mi.mesh.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	check(absf(aabb.position.y) < 0.02, "piedi a terra (%f)" % aabb.position.y)
	check(absf(aabb.end.y - AvatarRig.HEIGHT) < 0.06, "altezza %f" % aabb.end.y)
	rig.free()


func test_mano_sinistra_sull_impugnatura() -> void:
	for id in [&"spear", &"hammer", &"greatsword"]:
		var w := WeaponLibrary.by_id(id)
		var rig := AvatarRig.new()
		rig.build(AvatarRecipe.new())
		rig.set_weapon(w)
		var an := AvatarAnimator.new()
		var s := AvatarAnimator.State.new()
		s.weapon = w
		var poses: Array[Dictionary] = [an.target_pose(0.0, s)]
		for a: AttackDefinition in w.attacks.values():
			poses.append(a.key_strike)
		var worst := 0.0
		for p in poses:
			rig.apply_pose(p)
			var grip := rig.rig_xf(rig.socket) * Vector3(0, w.off_grip, 0)
			var hand := rig.rig_xf(rig.bones[&"hand_l"]) * Vector3(0, -AvatarRig.HAND, 0)
			var reach := AvatarRig.UPPER_ARM + AvatarRig.FOREARM + AvatarRig.HAND
			var shoulder := rig.rig_xf(rig.bones[&"arm_l"]).origin
			# Se l'impugnatura e' raggiungibile la mano ci arriva.
			if shoulder.distance_to(grip) < reach - 0.01:
				worst = maxf(worst, hand.distance_to(grip))
		check(worst < 0.03, "%s: mano sinistra a %f dall'impugnatura" % [id, worst])
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
