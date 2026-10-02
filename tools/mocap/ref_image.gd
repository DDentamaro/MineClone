extends SceneTree
## Immagine di riferimento dell'eroe per i video (D-046): corpo intero, arma
## in guardia, tre quarti davanti, sfondo neutro chiaro, luce morbida.
## Uso: xvfb-run -a godot --path . --script res://tools/mocap/ref_image.gd -- --weapon=sword --out=ref.png [--side]

var _out := "user://ref.png"
var _frames := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_out = String(args.get("out", _out))
	root.size = Vector2i(1280, 720)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.82, 0.82, 0.80)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.75)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.4, -0.8, -0.5), Vector3.UP)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.78, 0.78, 0.76)
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	var w := WeaponLibrary.by_id(StringName(args.get("weapon", "sword")))
	var rig := AvatarRig.new()
	rig.sync_ao = true
	root.add_child(rig)
	rig.build(AvatarRecipe.new())
	rig.set_weapon(w)
	# Arma tenuta avanti di lato, lama in diagonale verso l'alto: arma, mani e
	# viso ben visibili (la guardia copriva il viso, il riposo nascondeva la lama).
	rig.apply_pose(WeaponLibrary.pose({"arm_r": [35, 0, 28], "fore_r": [45, 0, 0], "hand_r": [-55, 0, 0],
		"arm_l": [10, 0, -14], "fore_l": [25, 0, 0], "leg_l": [8, 0, -4], "leg_r": [-6, 0, 4]}))
	# Davanti dell'eroe = -Z; camera di tre quarti davanti (o di lato con --side).
	var dir := Vector3(0.0, 0.18, -1.0) if not args.has("side") else Vector3(1.0, 0.15, 0.0)
	dir = (Basis(Vector3.UP, deg_to_rad(-30.0)) * dir).normalized() if not args.has("side") else dir.normalized()
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	var center := Vector3(0, 0.78, 0)
	cam.look_at_from_position(center + dir * 8.0, center, Vector3.UP)
	cam.current = true


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 30:
		root.get_texture().get_image().save_png(_out)
		quit(0)
	return false
