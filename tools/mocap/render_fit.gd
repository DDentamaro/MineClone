extends SceneTree
## Tavola delle pose ricavate dai video (D-046): righe = colpi, colonne =
## carica / colpo / seguito, eroe vero con l'arma, visto di tre quarti davanti
## come nei video. Uso: godot --path . --script res://tools/mocap/render_fit.gd -- --in=poses.json --weapon=sword --out=fit.png

var _out := "user://fit.png"
var _frames := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_out = String(args.get("out", _out))
	var w := WeaponLibrary.by_id(StringName(args.get("weapon", "sword")))
	var all: Array = JSON.parse_string(FileAccess.get_file_as_string(String(args["in"])))
	root.size = Vector2i(1200, maxi(400, 330 * all.size()))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.44, 0.40)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.3, -0.9, -0.3), Vector3.UP)
	root.add_child(sun)
	var dir := Vector3(0.5, 0.25, -0.83).normalized()
	var right := Vector3(-dir.z, 0, dir.x).normalized()
	var sx := 2.4
	var sy := 2.6
	for r in all.size():
		var rec: Dictionary = all[r]
		var c := 0
		for key in ["wind", "strike", "follow"]:
			var rig := AvatarRig.new()
			rig.sync_ao = true
			root.add_child(rig)
			rig.build(AvatarRecipe.new())
			rig.set_weapon(w)
			var p: Dictionary = (rec[key] as Dictionary)["pose"].duplicate()
			rig.apply_pose(WeaponLibrary.pose(p))
			rig.position = right * c * sx - Vector3(0, r * sy, 0)
			var l := Label3D.new()
			l.text = "colpo %d %s" % [r + 1, key]
			l.font_size = 22
			l.pixel_size = 0.0045
			l.outline_size = 6
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = rig.position + Vector3(0, -0.25, 0) + dir
			root.add_child(l)
			c += 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var center := right * sx - Vector3(0, (all.size() - 1) * sy * 0.5 - 0.7, 0)
	cam.size = all.size() * sy * 1.0
	root.add_child(cam)
	cam.look_at_from_position(center + dir * 30.0, center, Vector3.UP)
	cam.current = true


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 30:
		root.get_texture().get_image().save_png(_out)
		quit(0)
	return false
