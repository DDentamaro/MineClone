extends SceneTree
## Prova end-to-end del ciclo del sandbox (M5) con tocchi reali (xvfb):
## abbattere alberi a mano tenendo premuto -> craft del banco dal pannello ->
## posarlo dalla barra rapida -> bastoni e piccone di legno al banco -> scavare
## col piccone -> salvare -> chiudere e riaprire la scena e ritrovare tutto.
## Uso: xvfb-run -a godot --path . --script res://tools/e2e_sandbox.gd -- --out=/tmp/sandbox.png

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://sandbox.png"
var _ok := true
var _log: Array[String] = []
var _trees := 0
var _tree: Vegetation.TreeSpot
var _bench_cell := Vector3i.ZERO
var _wait := 0
var _dirt0 := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	_spawn()


func _spawn() -> void:
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)


func _touch(i: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(p: Vector2) -> void:
	_touch(2, p, true)
	_touch(2, p, false)


func _button(id: StringName) -> Vector2:
	return _game._touch.button_rect(id).get_center()


func _screen_of(p: Vector3) -> Vector2:
	return _game.view_to_screen(_game._camera_rig.camera.unproject_position(p))


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(_out.replace(".png", "_%s.png" % name))


## Albero vivo piu' vicino al giocatore; il giocatore gli si mette accanto.
func _go_to_tree() -> void:
	var best: Vegetation.TreeSpot = null
	var bd := INF
	for sp in _game._vegetation.spots:
		if sp.dead:
			continue
		var d := Vector2(sp.x - 96.5, sp.z - 96.5).length()
		if d < bd and d > 3.0:
			bd = d
			best = sp
	_tree = best
	var to := Vector3(best.x + 1.3, 0, best.z + 1.3)
	_game.motor.place_at(to)
	_game._avatar.position = _game.motor.position


func _process(_dt: float) -> bool:
	_frame += 1
	var g := _game
	match _phase:
		0:
			if g._runtime.is_idle() and g._build_ms > 0 and g._vegetation.is_idle() and not g._vegetation.spots.is_empty():
				g._day.time = 0.35
				g._day.paused = true
				g._camera_rig.set_zoom(1.8)
				_phase = 1
				_frame = 0
		1:
			# Abbattere tre alberi a mani nude, tenendo premuto sul tronco.
			if _frame == 1:
				_go_to_tree()
			if _frame == 20:
				_touch(0, _screen_of(Vector3(_tree.x, _tree.y + 1.0, _tree.z)), true)
			if _frame > 20 and _tree.dead:
				_touch(0, Vector2.ZERO, false)
				_trees += 1
				_log.append("albero %d abbattuto: legno %d" % [_trees, g.items.inv.count(&"wood")])
				if _trees == 1:
					_shot("chop")
				_frame = 0
				if _trees >= 3:
					_phase = 2
			if _frame > 20 * 60:
				_log.append("albero non abbattuto in tempo")
				_ok = false
				_phase = 99
		2:
			# Zaino -> Craft -> Banco da lavoro (a mano).
			if _frame == 5:
				_tap(_button(&"bag"))
			if _frame == 15:
				_tap(g._bag.tab_rects["craft"].get_center())
			if _frame == 25:
				if g._bag.craft_rects.has(&"workbench"):
					_tap(g._bag.craft_rects[&"workbench"].get_center())
				else:
					_log.append("pulsante del banco assente")
					_ok = false
			if _frame == 35:
				_shot("craft")
				_tap(g._bag.close_rect.get_center())
			if _frame == 45:
				var i := -1
				for k in PlayerItems.HOTBAR:
					var s := g.items.inv.get_slot(k)
					if s != null and s.id == &"workbench":
						i = k
				_log.append("banco nella barra rapida: slot %d" % i)
				_ok = _ok and i >= 0
				if i >= 0:
					_tap(_button(StringName("hot%d" % i)))
			if _frame == 55:
				# Tocco sul terreno davanti al giocatore: il banco si posa li'.
				var p := g.motor.position + Vector3(-1.5, 0, 0)
				var gy := VoxelQuery.field_height(g.world, p.x, p.z, p.y + 1.0)
				_tap(_screen_of(Vector3(floorf(p.x) + 0.5, gy, floorf(p.z) + 0.5)))
			if _frame == 70:
				var bench := g._objects.nearest(g.motor.position, "workbench", 4.0)
				_log.append("banco posato: %s" % (bench != null))
				_ok = _ok and bench != null
				if bench != null:
					_bench_cell = bench.cell
				_phase = 3
				_frame = 0
		3:
			# Al banco: bastoni (a mano) e piccone di legno (al banco), dal pannello.
			if _frame == 5:
				_tap(_button(&"bag"))
			if _frame == 15:
				_tap(g._bag.tab_rects["craft"].get_center())
			if _frame == 25 and g._bag.craft_rects.has(&"stick"):
				_tap(g._bag.craft_rects[&"stick"].get_center())
			if _frame == 35 and g._bag.craft_rects.has(&"pick_wood"):
				_tap(g._bag.craft_rects[&"pick_wood"].get_center())
			if _frame == 45:
				_log.append("piccone di legno: %d · bastoni %d · legno %d" % [g.items.inv.count(&"pick_wood"), g.items.inv.count(&"stick"), g.items.inv.count(&"wood")])
				_ok = _ok and g.items.inv.count(&"pick_wood") == 1
				_tap(g._bag.close_rect.get_center())
			if _frame == 55:
				for k in PlayerItems.HOTBAR:
					var s := g.items.inv.get_slot(k)
					if s != null and s.id == &"pick_wood":
						_tap(_button(StringName("hot%d" % k)))
				_dirt0 = g.items.inv.count(&"dirt")
				# D-054: il ring di marmo non si scava, si scende sulla piana di terra.
				if Arena.has(g.world):
					var ax := g.world.arena.x + Arena.HALF + 3.5
					var az := g.world.arena.z + 0.5
					g.motor.place_at(Vector3(ax, VoxelQuery.field_height(g.world, ax, az, g.world.arena.y + 2.0), az))
			if _frame == 65:
				var p := g.motor.position + Vector3(1.5, 0, 0)
				var gy := VoxelQuery.field_height(g.world, p.x, p.z, p.y + 1.0)
				_touch(0, _screen_of(Vector3(floorf(p.x) + 0.5, gy - 0.02, floorf(p.z) + 0.5)), true)
			if _frame > 65 and g.items.inv.count(&"dirt") > _dirt0:
				_touch(0, Vector2.ZERO, false)
				_log.append("scavato col piccone: +%d terra" % (g.items.inv.count(&"dirt") - _dirt0))
				_shot("dig")
				_phase = 4
				_frame = 0
			if _frame > 65 + 20 * 60:
				_touch(0, Vector2.ZERO, false)
				_log.append("scavo non riuscito")
				_ok = false
				_phase = 99
		4:
			# Salvare, chiudere, riaprire.
			if _frame == 5:
				_ok = _ok and g.save_game()
				_log.append("salvato: %s" % g.last_edit)
				_game.queue_free()
			if _frame == 10:
				_spawn()
				_phase = 5
				_frame = 0
		5:
			if _frame == 5:
				var bench := g._objects.at(_bench_cell)
				_log.append("dopo la riapertura: banco %s · piccone %d · terra %d" % [bench != null, g.items.inv.count(&"pick_wood"), g.items.inv.count(&"dirt")])
				_ok = _ok and bench != null and g.items.inv.count(&"pick_wood") == 1 and g.items.inv.count(&"dirt") > _dirt0
			if _frame == 40:
				_phase = 99
		99:
			_shot("end")
			for l in _log:
				print(l)
			print("e2e sandbox %s" % ("OK" if _ok else "FALLITO"))
			SaveService.delete_all()
			quit(0 if _ok else 1)
	return false
