extends SceneTree
## Banco di prova della grafica (piano grafico, F0): arena all'ora scelta,
## vista isometrica come la reference del proprietario, eroe con l'armatura di
## ferro, interfaccia nascosta. Foto della scena alla risoluzione scelta.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --script res://tools/look_preview.gd --
##        --out=/tmp/look.png [--time=0.30] [--rt=720] [--zoom=1.5] [--yaw=0]

var _game: GameRoot
var _out := "user://look.png"
var _time := 0.30
var _rt := 720
var _zoom := 1.5
var _yaw := 0.0
var _phase := 0
var _frame := 0


func _initialize() -> void:
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--time="):
			_time = float(a.substr(7))
		elif a.begins_with("--rt="):
			_rt = int(a.substr(5))
		elif a.begins_with("--zoom="):
			_zoom = float(a.substr(7))
		elif a.begins_with("--yaw="):
			_yaw = float(a.substr(6))
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)


func _process(_dt: float) -> bool:
	_frame += 1
	var g := _game
	match _phase:
		0:
			if g._runtime.is_idle() and g._build_ms > 0 and g._vegetation.is_idle() and g._water.is_idle():
				g.rt_height = _rt
				g._fit_view()
				g._day.time = _time
				g._day.paused = true
				g._camera_rig.set_zoom(_zoom)
				g._camera_rig.zoom = g._camera_rig.zoom_target
				g._camera_rig.yaw_target += deg_to_rad(_yaw)
				g._camera_rig.yaw = g._camera_rig.yaw_target
				var iron := Color(0.56, 0.57, 0.59)
				g._avatar.rig.set_armor_all({"head": iron, "chest": iron, "legs": iron, "feet": iron},
					{"head": "iron", "chest": "iron", "legs": "iron", "feet": "iron"})
				g.select_weapon(GameRoot.WEAPONS.find(&"sword"))
				for n: Node in root.find_children("*", "CanvasLayer", true, false):
					(n as CanvasLayer).visible = false
				_phase = 1
				_frame = 0
		1:
			if _frame == 50:
				root.get_texture().get_image().save_png(_out)
				print("foto " + _out)
				return true
	return false
