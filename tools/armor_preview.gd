extends SceneTree
## Anteprima nel gioco vero (D-051): l'eroe allo spawn con un set d'armatura,
## con la luce del mondo, girato davanti, di lato e dietro. Serve a giudicare
## un set prima di metterlo tra gli oggetti.
## Uso: xvfb-run -a godot --path . --script res://tools/armor_preview.gd -- --out=/tmp/anteprima.png [--iso] [--set=leather|iron]
## Salva un'immagine per set e vista: _casco_davanti, _cappuccio_dietro, ...

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://anteprima.png"
var _iso := false
var _i := 0
var _face0 := 0.0

## [nome, colore, forma della testa, forma del resto] per ogni set.
const SETS := {
	"leather": [["casco", Color(0.55, 0.33, 0.19), "leather_cap", "leather"], ["cappuccio", Color(0.55, 0.33, 0.19), "leather_hood", "leather"]],
	"iron": [["ferro", Color(0.56, 0.57, 0.59), "iron", "iron"]],
}
var _sets: Array = SETS["leather"]
const VIEWS := [["davanti", 0.45], ["lato", PI * 0.5], ["dietro", PI + 0.45]]


func _initialize() -> void:
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--iso":
			_iso = true
		elif a.begins_with("--set="):
			_sets = SETS[a.substr(6)]
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)


func _process(_dt: float) -> bool:
	_frame += 1
	var g := _game
	match _phase:
		0:
			if g._runtime.is_idle() and g._build_ms > 0 and g._vegetation.is_idle() and g._water.is_idle():
				g._day.time = 0.4
				g._day.paused = true
				if not _iso:
					g._camera_rig.set_mode(CameraRig.Mode.TPS)
					g._camera_rig.set_zoom(1.6)
					g._camera_rig.tps_user_pitch = 0.22
				else:
					g._camera_rig.set_zoom(2.4)
				# Niente interfaccia sopra l'eroe.
				for n: Node in root.find_children("*", "CanvasLayer", true, false):
					(n as CanvasLayer).visible = false
				# L'eroe guarda la camera: da qui si misurano le viste.
				var f := g._camera_rig.ground_forward()
				_face0 = CombatController.heading(Vector2(-f.x, -f.z))
				_phase = 1
				_frame = 0
		1:
			var set_i := _i / VIEWS.size()
			var view_i := _i % VIEWS.size()
			if _frame == 1:
				var e: Array = _sets[set_i]
				var st := {"head": e[2], "chest": e[3], "legs": e[3], "feet": e[3]}
				g._avatar.rig.set_weapon(WeaponLibrary.by_id(&"fists"))
				g._avatar.rig.set_armor_all({"head": e[1], "chest": e[1], "legs": e[1], "feet": e[1]}, st)
				g._avatar.facing = _face0 + float(VIEWS[view_i][1])
				g._avatar.rotation.y = g._avatar.facing
			if _frame == 40:
				var path := _out.replace(".png", "_%s_%s.png" % [_sets[set_i][0], VIEWS[view_i][0]])
				var img := root.get_texture().get_image()
				img.save_png(path)
				print("anteprima " + path)
				_i += 1
				_frame = 0
				if _i >= _sets.size() * VIEWS.size():
					return true
	return false
