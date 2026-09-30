extends SceneTree
## Sonda della lancia (D-041): per ogni colpo e fase, direzione della lancia
## (gradi rispetto all'avanti dell'eroe, -Z) e posizione della punta.
## Uso: godot --headless --path . --script res://tools/spear_probe.gd [-- --weapon=spear]

var _done := false


func _process(_dt: float) -> bool:
	if _done:
		return true
	_done = true
	var wid := &"spear"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weapon="):
			wid = StringName(a.substr(9))
	var w := WeaponLibrary.by_id(wid)
	var rig := AvatarRig.new()
	root.add_child(rig)
	rig.build(AvatarRecipe.new())
	rig.set_weapon(w)
	for aid: StringName in w.attacks:
		var a := w.attack(aid)
		var line := "%-12s" % aid
		for ph in [[0, 0.0], [0, 1.0], [1, 0.33], [1, 0.66], [1, 1.0], [2, 0.5]]:
			var s := AvatarAnimator.State.new()
			s.weapon = w
			s.attack = a
			s.phase = ph[0]
			s.u = ph[1]
			var an := AvatarAnimator.new()
			rig.apply_pose(an.target_pose(0.0, s))
			var g := rig.socket.global_transform
			var base := g * Vector3(0, 0, 0)
			var tip := g * Vector3(0, w.trail_to, 0)
			var d := tip - base
			var az := rad_to_deg(atan2(d.x, -d.z))
			var el := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
			line += " | %d/%.2f az%+4.0f el%+4.0f tip(%+.2f,%.2f,%+.2f)" % [ph[0], ph[1], az, el, tip.x, tip.y, -tip.z]
		print(line)
	quit(0)
	return true
