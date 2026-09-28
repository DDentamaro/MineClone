extends SceneTree
## Tavola del passo (D-028): l'eroe del prototipo di profilo, fotogrammi del
## passo a velocita' diverse (camminata, corsa) e dell'arresto con
## assestamento. Stessa composizione di PlayerAvatar (GaitLegs + animatore).
## Uso: xvfb-run -a godot --path . --script res://tools/gait_sheet.gd -- --out=/tmp/gait.png

const DT := 1.0 / 60.0
const COLS := 8

var _out := "user://gait.png"
var _rig: AvatarRig
var _an := AvatarAnimator.new()
var _gait := GaitLegs.new()
var _cam: Camera3D
var _pos := Vector3.ZERO
var _frame := 0
var _shots: Array[Image] = []
## [velocita', fotogrammi di simulazione, fotogrammi da catturare (ogni k)]
var _plan := [[1.6, 60, 4], [5.5, 60, 3], [0.0, 30, 4]]
var _step := 0
var _t := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	root.size = Vector2i(COLS * 200, 3 * 260)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.44, 0.40)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.4, -0.8, -0.3), Vector3.UP)
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	floor.mesh = pm
	root.add_child(floor)
	_rig = AvatarRig.new()
	_rig.sync_ao = true
	root.add_child(_rig)
	_rig.build(AvatarRecipe.new())
	_rig.set_weapon(WeaponLibrary.by_id(&"sword"))
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 5.2
	root.add_child(_cam)
	_cam.current = true


func _process(_dt: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	if _step >= _plan.size():
		_save()
		return true
	var p: Array = _plan[_step]
	var vel := Vector3(0, 0, -float(p[0]))
	_pos += vel * DT
	_rig.position = _pos
	_gait.update(DT, _rig.transform, vel, true, 5.5, func(_x: float, _z: float) -> float: return 0.0)
	var s := AvatarAnimator.State.new()
	s.weapon = WeaponLibrary.by_id(&"sword")
	s.speed = float(p[0])
	s.relax = 1.0
	_an.gait = true
	_an.stride_phase = _gait.phase * TAU
	var pose := _an.update(DT, s).duplicate()
	pose[&"body_pos"] = (pose.get(&"body_pos", Vector3.ZERO) as Vector3) + Vector3(_gait.sway, _gait.body_y, 0)
	pose[&"hips"] = (pose.get(&"hips", Vector3.ZERO) as Vector3) + Vector3(0, 0, -_gait.sway * 1.6)
	pose[&"spine"] = (pose.get(&"spine", Vector3.ZERO) as Vector3) + Vector3(-_gait.lean, 0, 0)
	_rig.apply_pose(pose)
	_gait.apply(_rig, 1.0)
	_cam.look_at_from_position(_pos + Vector3(6, 0.7, 0), _pos + Vector3(0, 0.7, 0), Vector3.UP)
	_t += 1
	var first := int(p[1]) - COLS * int(p[2])
	if _t > first and (_t - first) % int(p[2]) == 0:
		var img := root.get_texture().get_image()
		var c := img.get_width() / 2
		_shots.append(img.get_region(Rect2i(c - 100, 0, 200, img.get_height())))
	if _t >= int(p[1]):
		_step += 1
		_t = 0
	return false


func _save() -> void:
	var h := 260
	var sheet := Image.create(COLS * 200, h * _plan.size(), false, _shots[0].get_format())
	for i in _shots.size():
		var src := _shots[i]
		var r := Rect2i(0, src.get_height() / 2 - h / 2 - 20, 200, h)
		sheet.blit_rect(src, r, Vector2i((i % COLS) * 200, (i / COLS) * h))
	sheet.save_png(_out)
	print("Tavola del passo %s (%d fotogrammi)" % [_out, _shots.size()])
