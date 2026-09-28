extends SceneTree
## Prova end-to-end (D-029) con tocchi reali: le opzioni si chiudono (pulsante
## Chiudi, tocco sul mondo, tasto indietro); l'armeria vicino allo spawn si
## apre toccandola; si impugna il martello e si indossa il busto dall'armeria;
## si prendono gli stivali e si indossano dalla scheda Equipaggiamento.
## Uso: xvfb-run -a godot --path . --script res://tools/e2e_armory.gd -- --out=/tmp/armory.png

var _game: GameRoot
var _frame := 0
var _phase := 0
var _out := "user://armory.png"
var _ok := true
var _log: Array[String] = []
var _arm: WorldObjects.Obj


func _initialize() -> void:
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)


func _tap_at(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 3
		e.position = p
		e.pressed = pressed
		Input.parse_input_event(e)


func _tap(id: StringName) -> void:
	_tap_at(_game._touch.button_rect(id).get_center())


func _shot(name: String) -> void:
	var path := _out.replace(".png", "_%s.png" % name)
	root.get_texture().get_image().save_png(path)
	_log.append("screenshot " + path)


func _check(cond: bool, what: String) -> void:
	_log.append(("ok   " if cond else "NO   ") + what)
	_ok = _ok and cond


func _chest_slot(id: StringName) -> Vector2:
	for i in _arm.inv.size():
		var s := _arm.inv.get_slot(i)
		if s != null and s.id == id:
			return (_game._bag.chest_rects[i] as Rect2).get_center()
	return Vector2(-1, -1)


func _process(_dt: float) -> bool:
	_frame += 1
	var bag := _game._bag
	match _phase:
		0:
			if _game._runtime.is_idle() and _game._build_ms > 0 and _game._vegetation.is_idle() and _game._water.is_idle():
				_game._day.time = 0.4
				_game._day.paused = true
				for o in _game._objects.list:
					if o.type == "armory":
						_arm = o
				_check(_arm != null, "armeria nel mondo")
				_phase = 1
				_frame = 0
		1:
			# Opzioni: tre modi di chiuderle.
			if _frame == 5:
				_tap(&"dev")
			if _frame == 15:
				_check(_game._touch.dev_open, "opzioni aperte")
				_shot("opzioni")
				_tap(&"dev_close")
			if _frame == 25:
				_check(not _game._touch.dev_open, "chiuse col pulsante Chiudi")
				_tap(&"dev")
			if _frame == 35:
				# Fuori dal pannello modale (D-033): la striscia in basso sotto il pannello.
				_tap_at(Vector2(_game._touch.size.x * 0.5, _game._touch.size.y - 3.0))
			if _frame == 45:
				_check(not _game._touch.dev_open, "chiuse toccando il mondo")
				_tap(&"dev")
			if _frame == 55:
				_game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
			if _frame == 60:
				_check(not _game._touch.dev_open, "chiuse col tasto indietro")
				# Accanto all'armeria (spostamento diretto: lo stick non e' oggetto della prova).
				var c := Vector3(_arm.cell) + Vector3(0.5, 0, 0.5)
				var fw := Vector3(-sin(_arm.rot * PI * 0.5), 0, -cos(_arm.rot * PI * 0.5))
				_game.motor.place_at(c + fw * 1.6)
				_game._camera_rig.set_zoom(2.2)
				_game._camera_rig.zoom = 2.2
			if _frame == 90:
				_shot("rastrelliera")
				var cam := _game._camera_rig.camera
				var sp := _game.view_to_screen(cam.unproject_position(_game._objects.center_of(_arm) + Vector3(0, 0.2, 0)))
				_tap_at(sp)
			if _frame == 105:
				_check(bag.is_open() and bag.tab == "chest" and bag.chest == _arm, "toccando la rastrelliera si apre l'Armeria")
				_tap_at(_chest_slot(&"hammer_iron"))
			if _frame == 112:
				_check(bag.button_rects.has("Impugna"), "pulsante Impugna")
				_shot("armeria_martello")
				_tap_at((bag.button_rects["Impugna"] as Rect2).get_center())
			if _frame == 120:
				_check(_game.items.held() != null and _game.items.held().id == &"hammer_iron", "martello in mano")
				_tap_at(_chest_slot(&"chest_iron"))
			if _frame == 127:
				_tap_at((bag.button_rects["Indossa"] as Rect2).get_center())
			if _frame == 135:
				_check(_game.items.equipment.get_slot("chest") != null, "busto indossato dall'armeria")
				_tap_at(_chest_slot(&"feet_iron"))
			if _frame == 142:
				_tap_at((bag.button_rects["Prendi"] as Rect2).get_center())
			if _frame == 150:
				_check(_game.items.inv.count(&"feet_iron") == 1, "stivali nello zaino")
				_tap_at((bag.tab_rects["bag"] as Rect2).get_center())
			if _frame == 158:
				_check(bag.eq_rects.has("feet") and bag.eq_rects.has("hand"), "inventario con la miniatura e gli slot dell'eroe")
				var at := -1
				for i in _game.items.inv.size():
					var st := _game.items.inv.get_slot(i)
					if st != null and st.id == &"feet_iron":
						at = i
				_tap_at((bag.slot_rects[at] as Rect2).get_center())
			if _frame == 166:
				_shot("equipaggiamento")
				# Come in Minecraft: oggetto scelto, poi lo slot dei piedi sulla miniatura.
				_tap_at((bag.eq_rects["feet"] as Rect2).get_center())
			if _frame == 174:
				_check(_game.items.equipment.get_slot("feet") != null, "stivali indossati toccando lo slot dei piedi")
				_tap_at((bag.eq_rects["hand"] as Rect2).get_center())
			if _frame == 182:
				_shot("mano")
				_tap_at(bag.close_rect.get_center())
			if _frame == 200:
				_check(not bag.is_open(), "zaino chiuso")
				_shot("eroe_armato")
				for l in _log:
					print(l)
				print("e2e armeria %s" % ("OK" if _ok else "FALLITO"))
				quit(0 if _ok else 1)
	return false
