extends SceneTree
## Prova end-to-end con finestra (xvfb-run): carica la scena principale, inietta
## tocchi reali (stick + tap di costruzione) tramite Input.parse_input_event e
## salva uno screenshot. Uso:
##   xvfb-run -a godot --path . --script res://tools/e2e_touch.gd -- --out=/tmp/e2e.png

var _game: GameRoot
var _frame := 0
var _phase := 0
var _start_pos := Vector3.ZERO
var _out := "user://e2e.png"
var _ok := true


func _initialize() -> void:
	# Impostazioni proprie, per non toccare quelle del giocatore.
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)


func _touch(i: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	Input.parse_input_event(e)


func _process(_dt: float) -> bool:
	_frame += 1
	var size := root.get_visible_rect().size
	match _phase:
		0:
			if _game._runtime.is_idle() and _game._build_ms > 0 and _game._vegetation.is_idle():
				_start_pos = _game.motor.position
				_touch(0, Vector2(size.x * 0.15, size.y * 0.8), true)
				_drag(0, Vector2(size.x * 0.15, size.y * 0.8 - 60))
				_phase = 1
				_frame = 0
		1:
			if _frame == 60:
				_touch(0, Vector2(size.x * 0.15, size.y * 0.8 - 60), false)
				var moved := _game.motor.position.distance_to(_start_pos)
				print("stick: spostamento %.2f in 60 frame (posizione %s)" % [moved, _game.motor.position])
				_ok = _ok and moved > 1.0
				# Pietra nella barra rapida, scelta col suo pulsante.
				_game.items.inv.set_slot(2, ItemStack.new(&"stone", 8))
				_touch(2, _game._touch.button_rect(&"hot2").get_center(), true)
				_touch(2, _game._touch.button_rect(&"hot2").get_center(), false)
				_phase = 2
				_frame = 0
		2:
			if _frame == 10:
				# Tap poco a destra del giocatore sullo schermo.
				var cam := _game._camera_rig.camera
				var target := _game.view_to_screen(cam.unproject_position(_game.motor.position + Vector3(0, 0.2, 0)))
				_start_pos = Vector3(_game.world.revision, 0, 0)
				var p := target + Vector2(120, 20)
				_touch(1, p, true)
				_touch(1, p, false)
			if _frame == 12:
				var edited := _game.world.revision > int(_start_pos.x)
				print("tap costruzione: %s (%s)" % ["OK" if edited else "nessun edit", _game.last_edit])
				_ok = _ok and edited
			if _frame == 40:
				root.get_texture().get_image().save_png(_out)
				# Muro alto 4 tra la camera e il giocatore: deve scattare il raggio X.
				var p := _game.motor.position
				var d := _game._camera_rig.view_dir()
				var list: Array[WorldEditService.Edit] = []
				var base := Vector3i(floori(p.x + d.x * 2.2), floori(p.y), floori(p.z + d.z * 2.2))
				for dy in 4:
					for k in range(-2, 3):
						var c := base + Vector3i(k, dy, -k)
						if _game.world.get_block(c) == BlockCatalog.AIR:
							list.append(WorldEditService.Edit.new(c, BlockCatalog.STONE))
				_game.edits.try_apply(list, &"e2e")
				_phase = 3
				_frame = 0
		3:
			if _frame == 40:
				var cov := _game.coverage(_game.motor.position)
				print("copertura dietro il muro: %.2f" % cov)
				_ok = _ok and cov > 0.3
				root.get_texture().get_image().save_png(_out.replace(".png", "_xray.png"))
				print("screenshot %s · e2e %s" % [_out, "OK" if _ok else "FALLITO"])
				quit(0 if _ok else 1)
	return false
