extends SceneTree
## Tavola dell'armatura (D-030): l'eroe senza armatura, con l'armatura intera e
## con elmo e corazza, di tre quarti davanti e dietro. Serve a vedere che
## capelli, busto e gambe non attraversino i pezzi.
## Con --leather (D-051): set di cuoio con cuffia (sopra) e con cappuccio
## (sotto), di tre quarti davanti, di lato e da dietro.
## Uso: xvfb-run -a godot --path . --script res://tools/armor_sheet.gd -- --out=/tmp/armor.png [--preset=1] [--leather]

var _out := "user://armor.png"
var _frames := 0


func _initialize() -> void:
	var preset := 0
	var leather := false
	for a in OS.get_cmdline_user_args():
		if a == "--leather":
			leather = true
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--preset="):
			preset = int(a.substr(9))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.44, 0.40)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.3, -0.8, -0.5), Vector3.UP)
	root.add_child(sun)
	var iron := Color(0.78, 0.66, 0.58)
	var gold := Color(0.95, 0.78, 0.30)
	var sets := [{}, {"head": iron, "chest": iron, "legs": iron, "feet": iron}, {"head": gold, "chest": gold}]
	var r := AvatarRecipe.preset(preset)
	var i := 0
	if leather:
		var cuoio := Color(0.42, 0.22, 0.11)
		var all := {"head": cuoio, "chest": cuoio, "legs": cuoio, "feet": cuoio}
		for head: String in ["leather_cap", "leather_hood"]:
			var st := {"head": head, "chest": "leather", "legs": "leather", "feet": "leather"}
			for yaw in [PI + 0.5, -PI * 0.5, 0.5]:
				var rig := AvatarRig.new()
				rig.sync_ao = true
				root.add_child(rig)
				rig.build(r)
				rig.set_armor_all(all, st)
				rig.position = Vector3((i % 3) * 1.3 - 1.3, -(i / 3) * 1.9, 0)
				rig.rotation.y = yaw
				i += 1
		var cam2 := Camera3D.new()
		cam2.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam2.size = 4.0
		cam2.keep_aspect = Camera3D.KEEP_HEIGHT
		root.add_child(cam2)
		cam2.look_at_from_position(Vector3(0, 0.2, 8), Vector3(0, -0.45, 0), Vector3.UP)
		cam2.current = true
		return
	for yaw in [0.6, PI + 0.6]:
		for arm: Dictionary in sets:
			var rig := AvatarRig.new()
			rig.sync_ao = true
			root.add_child(rig)
			rig.build(r)
			rig.set_armor_all(arm)
			rig.set_weapon(WeaponLibrary.by_id(&"sword"))
			rig.position = Vector3((i % 3) * 1.3 - 1.3, -(i / 3) * 1.8, 0)
			rig.rotation.y = yaw
			i += 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.7
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.6, 8), Vector3(0, -0.1, 0), Vector3.UP)
	cam.current = true


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 4:
		root.get_texture().get_image().save_png(_out)
		print("Tavola %s" % _out)
		return true
	return false
