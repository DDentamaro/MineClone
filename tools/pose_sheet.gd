extends SceneTree
## Tavola delle pose (M4): un eroe per casella, righe = armi, colonne =
## guardia + carica/colpo dei primi attacchi; con --moves locomozione, salto,
## nuoto e capriola. Serve a controllare a occhio le pose chiave.
## Uso: xvfb-run -a godot --path . --script res://tools/pose_sheet.gd -- --out=/tmp/poses.png [--moves] [--view=iso]

var _out := "user://poses.png"
var _moves := false
var _iso := false
var _frames := 0
var _only := ""
## --cast: solo le pose di lancio; --dir=x,y,z sceglie da dove guarda la camera.
var _cast := false
var _dir := Vector3.ZERO


func _initialize() -> void:
	pass


func _setup() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--moves":
			_moves = true
		elif a == "--view=iso":
			_iso = true
		elif a.begins_with("--weapon="):
			_only = a.substr(9)
		elif a == "--cast":
			_cast = true
		elif a.begins_with("--dir="):
			var v := a.substr(6).split(",")
			_dir = Vector3(float(v[0]), float(v[1]), float(v[2])).normalized()
	root.size = Vector2i(1500, 2600) if _only != "" else Vector2i(1800, 1100)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.44, 0.40)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.look_at_from_position(Vector3.ZERO, -Vector3(-0.3, 0.93, 0.22), Vector3.UP)
	sun.shadow_enabled = true
	root.add_child(sun)
	var cells: Array = _move_cells() if _moves else _attack_cells()
	if _cast:
		cells = [_move_cells()[3]]
		root.size = Vector2i(1500, 420)
	var cols := 0
	for row: Array in cells:
		cols = maxi(cols, row.size())
	var sx := 1.9
	var sy := 2.2
	var dir := Vector3(0.5, 0.6, 0.5).normalized() if _iso else Vector3(0.62, 0.32, -0.72).normalized()
	if _dir != Vector3.ZERO:
		dir = _dir
	var right := Vector3(dir.z, 0, -dir.x).normalized()
	for r in cells.size():
		var row: Array = cells[r]
		for c in row.size():
			var cell: Dictionary = row[c]
			var rig := AvatarRig.new()
			rig.sync_ao = true
			root.add_child(rig)
			rig.build(AvatarRecipe.new())
			rig.set_weapon(cell.get("weapon"))
			rig.position = right * c * sx - Vector3(0, r * sy, 0)
			rig.rotation.y = float(cell.get("yaw", 0.0))
			rig.ik_enabled = not (String(cell["label"]).begins_with("lancio"))
			rig.apply_pose(cell["pose"])
			var l := Label3D.new()
			l.text = cell["label"]
			l.font_size = 22
			l.pixel_size = 0.0045
			l.modulate = Color.WHITE
			l.outline_size = 6
			l.position = rig.position + Vector3(0, -0.2, 0) + dir * 1.0
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			root.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var center := right * (cols - 1) * sx * 0.5 - Vector3(0, (cells.size() - 1) * sy * 0.5 - 0.7, 0)
	var vs := Vector2(root.size)
	cam.size = maxf(cells.size() * sy * 0.97 + 0.4, cols * sx * vs.y / vs.x)
	root.add_child(cam)
	cam.look_at_from_position(center + dir * 30.0, center, Vector3.UP)
	cam.current = true


func _state(w: WeaponDefinition) -> AvatarAnimator.State:
	var s := AvatarAnimator.State.new()
	s.weapon = w
	return s


func _pose(s: AvatarAnimator.State, prep: Callable = Callable()) -> Dictionary:
	var an := AvatarAnimator.new()
	if prep.is_valid():
		prep.call(an)
	return an.target_pose(0.0, s)


func _attack_cells() -> Array:
	var rows := []
	for w in WeaponLibrary.all():
		if _only != "" and String(w.id) != _only:
			continue
		var row := []
		row.append({"weapon": w, "pose": _pose(_state(w)), "label": "%s guardia" % w.display_name})
		var ids: Array[StringName] = []
		var id := w.light_start
		while id != &"" and not ids.has(id) and ids.size() < 4:
			ids.append(id)
			id = w.attack(id).next_light
		if not ids.has(w.heavy_start):
			ids.append(w.heavy_start)
		if _only != "":
			for k: StringName in w.attacks:
				if not ids.has(k):
					ids.append(k)
		for aid in ids:
			var a := w.attack(aid)
			if _only != "":
				row = []
				row.append({"weapon": w, "pose": _pose(_state(w)), "label": "guardia"})
			for ph in [[0, 1.0, "carica"], [1, 0.5, "colpo 50%"], [1, 1.0, "colpo"], [2, 0.4, "seguito"]]:
				if _only == "" and ph[2] in ["colpo 50%", "seguito"]:
					continue
				var s := _state(w)
				s.attack = a
				s.phase = ph[0]
				s.u = ph[1]
				row.append({"weapon": w, "pose": _pose(s), "label": "%s %s" % [aid, ph[2]]})
			if _only != "":
				rows.append(row)
		if _only == "":
			rows.append(row)
	return rows


func _move_cells() -> Array:
	var w := WeaponLibrary.by_id(&"sword")
	var rows := []
	var row := []
	for i in 6:
		var s := _state(w)
		s.speed = 5.5
		var ph := TAU * i / 6.0
		row.append({"weapon": w, "pose": _pose(s, func(an: AvatarAnimator) -> void:
			an._w_run = 1.0
			an.stride_phase = ph - 5.5 * 0.0), "label": "corsa %d" % i, "yaw": -PI * 0.5})
	rows.append(row)
	row = []
	for v in [[8.0, "salita"], [0.0, "apice"], [-8.0, "caduta"]]:
		var s := _state(w)
		s.on_ground = false
		s.vy = v[0]
		row.append({"weapon": w, "pose": _pose(s, func(an: AvatarAnimator) -> void:
			an._w_air = 1.0
			an._up = clampf(float(v[0]) / 8.0, -1.0, 1.0)), "label": v[1], "yaw": -PI * 0.5})
	var sl := _state(w)
	sl.land = 1.0
	row.append({"weapon": w, "pose": _pose(sl), "label": "atterraggio", "yaw": -PI * 0.5})
	var sw := _state(w)
	sw.wade = 0.6
	row.append({"weapon": w, "pose": _pose(sw, func(an: AvatarAnimator) -> void: an._w_wade = 1.0), "label": "guado"})
	rows.append(row)
	row = []
	for i in 3:
		var s := _state(w)
		s.swimming = true
		s.swim_phase = TAU * i / 3.0
		row.append({"weapon": w, "pose": _pose(s, func(an: AvatarAnimator) -> void: an._w_swim = 1.0), "label": "nuoto %d" % i, "yaw": -PI * 0.5})
	for i in 4:
		var s := _state(w)
		s.dodge = (i + 1) / 5.0
		row.append({"weapon": w, "pose": _pose(s), "label": "capriola %.1f" % s.dodge, "yaw": -PI * 0.5})
	rows.append(row)
	return rows


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 1:
		_setup()
	if _frames == 5:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		# Tavole di una sola arma: anche in tre parti per vederle ingrandite.
		if _only != "":
			var h := img.get_height() / 3
			for i in 3:
				img.get_region(Rect2i(0, i * h, img.get_width(), h)).save_png(_out.get_basename() + "_%d.png" % (i + 1))
		print("Tavola %s (%dx%d)" % [_out, img.get_width(), img.get_height()])
		return true
	return false
