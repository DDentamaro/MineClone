extends SceneTree
## Prova del flusso di sessione (D-036), anche headless: menu, tocchi, impostazioni,
## salvataggio, ripresa. Con --out=/percorso e un display vero salva la pausa.

var _game: GameRoot
var _failures := 0


class IconAtlas:
	extends Control
	var drawn := false

	func _draw() -> void:
		var definitions := ItemLibrary.all()
		for i in definitions.size():
			GameIcons.item(self, Rect2((i % 20) * 34, (i / 20) * 34, 30, 30), definitions[i])
		drawn = true


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	print(("PASS " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1


func _frames() -> void:
	await process_frame
	await process_frame
	await process_frame


func _touch(point: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.position = point
	event.pressed = down
	event.canceled = canceled
	# Coordinate del viewport scalato, non pixel fisici della finestra.
	root.push_input(event, true)


func _tap(id: StringName) -> void:
	for button: Dictionary in _game._session._buttons:
		if button["id"] == id:
			var point: Vector2 = (button["rect"] as Rect2).get_center()
			_touch(point, true)
			_touch(point, false)
			return
	_check(false, "pulsante presente: " + String(id))


func _run() -> void:
	Settings.path = "user://e2e_session_settings.cfg"
	SaveService.path = "user://e2e_session/world.save"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.delete_all()
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await _frames()
	var menu := _game._touch.button_rect(&"menu").get_center()
	_touch(menu, true)
	_touch(menu, false)
	await _frames()
	_check(_game.paused and paused, "il tocco su Menu apre la pausa")
	# D-054: piu' "Nuova partita".
	_check(_game._session._buttons.size() == 8, "la pausa ha otto azioni")
	var before := _game.motor.position
	await _frames()
	_check(_game.motor.position == before, "il mondo e' fermo nel menu")
	for page in ["pause", "journal", "settings", "help"]:
		_game._session.open(page)
		await _frames()
		var bounds := Rect2(Vector2.ZERO, _game._session.size)
		for button: Dictionary in _game._session._buttons:
			_check(bounds.encloses(button["rect"]), "%s / %s dentro lo schermo" % [page, button["id"]])
	_game._session.open("settings")
	await _frames()
	_tap(&"motion")
	_check(_game._camera_rig.reduced_motion, "movimento ridotto applicato")
	_check(Settings.load_value("accessibility", "reduced_motion", false), "movimento ridotto salvato")
	_tap(&"handed")
	_check(_game._touch.left_handed, "comandi mancini applicati")
	# Un tocco annullato non deve mai attivare un pulsante.
	for button: Dictionary in _game._session._buttons:
		if button["id"] == &"hints":
			var point: Vector2 = (button["rect"] as Rect2).get_center()
			_touch(point, true)
			_touch(point, false, true)
	_check(_game._session.hints, "un tocco annullato non cambia le impostazioni")
	_game._session.open("pause")
	await _frames()
	_tap(&"save")
	_check(SaveService.exists(), "salvataggio dalla pausa")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.substr(6))
	_tap(&"resume")
	await _frames()
	_check(not paused and not _game._touch.blocked, "Riprendi riattiva i comandi")
	_check(_game._session.page == "", "si torna all'HUD")
	_game.open_bag()
	await _frames()
	_check(paused and not _game._session.hud_visible, "lo zaino occupa lo schermo")
	_game._bag.close()
	_check(not paused, "chiuso lo zaino il mondo riparte")
	# Stessa densita' dei test dei comandi touch sul telefono.
	_game._touch.dp_scale = 1.83
	_game._touch._layout()
	_game.set_paused(true)
	_game._update_session_hud()
	for page in ["pause", "journal", "settings", "help"]:
		_game._session.open(page)
		await _frames()
		var bounds := Rect2(Vector2.ZERO, _game._session.size)
		var rects: Array[Rect2] = []
		for button: Dictionary in _game._session._buttons:
			var rect: Rect2 = button["rect"]
			_check(bounds.encloses(rect), "telefono / %s / %s dentro lo schermo" % [page, button["id"]])
			_check(rect.size.y >= 48 * 1.83 - .1, "telefono / %s alto almeno 48 dp" % button["id"])
			for other in rects:
				_check(not other.intersects(rect), "pulsanti del telefono separati")
			rects.append(rect)
	_game.set_paused(false)
	# L'indicazione dell'oggetto vicino non copre i comandi touch del telefono.
	# D-054: l'armeria e' al centro dell'arena, ci si mette accanto.
	for o: WorldObjects.Obj in _game._objects.list:
		if o.type == "armory":
			_game.motor.place_at(Vector3(o.cell) + Vector3(0.5, 0.0, 1.6))
	_game._session.context_text = "Apri armeria"
	_game._update_session_hud()
	_game._session.context_text = "Apri armeria"
	_game._session.queue_redraw()
	await _frames()
	var shown := false
	for button: Dictionary in _game._session._buttons:
		if button["id"] == &"interact":
			shown = true
			for id: StringName in [&"lock", &"attack", &"heavy", &"dodge", &"jump"]:
				_check(not (button["rect"] as Rect2).intersects(_game._touch.button_rect(id)), "telefono / indicazione non copre %s" % id)
	_check(shown, "telefono / indicazione dell'oggetto vicino visibile")
	var atlas := IconAtlas.new()
	root.add_child(atlas)
	await _frames()
	_check(atlas.drawn, "tutte le categorie di icone si disegnano")
	atlas.free()
	_game.free()
	print("e2e sessione %s (%d errori)" % ["OK" if _failures == 0 else "FALLITO", _failures])
	quit(1 if _failures > 0 else 0)
