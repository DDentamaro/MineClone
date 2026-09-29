extends SceneTree
## Headless-compatible session-flow regression. Optional --out=/path captures
## the pause menu when run with a real display/rendering driver.

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
	# Coordinates are in the stretched viewport, not physical window pixels.
	root.push_input(event, true)


func _tap(id: StringName) -> void:
	for button: Dictionary in _game._session._buttons:
		if button["id"] == id:
			var point: Vector2 = (button["rect"] as Rect2).get_center()
			_touch(point, true)
			_touch(point, false)
			return
	_check(false, "button exists: " + String(id))


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
	_check(_game.paused and paused, "touch opens and pauses the game")
	_check(_game._session._buttons.size() == 7, "pause menu has seven actions")
	var before := _game.motor.position
	await _frames()
	_check(_game.motor.position == before, "world is frozen in menu")
	for page in ["pause", "journal", "settings", "help"]:
		_game._session.open(page)
		await _frames()
		var bounds := Rect2(Vector2.ZERO, _game._session.size)
		for button: Dictionary in _game._session._buttons:
			_check(bounds.encloses(button["rect"]), "%s / %s inside viewport" % [page, button["id"]])
	_game._session.open("settings")
	await _frames()
	_tap(&"motion")
	_check(_game._camera_rig.reduced_motion, "motion setting applied")
	_check(Settings.load_value("accessibility", "reduced_motion", false), "motion setting persisted")
	_tap(&"handed")
	_check(_game._touch.left_handed, "left-handed controls applied")
	# Canceled contacts must never activate a button.
	for button: Dictionary in _game._session._buttons:
		if button["id"] == &"hints":
			var point: Vector2 = (button["rect"] as Rect2).get_center()
			_touch(point, true)
			_touch(point, false, true)
	_check(_game._session.hints, "canceled touch does not toggle settings")
	_game._session.open("pause")
	await _frames()
	_tap(&"save")
	_check(SaveService.exists(), "save from pause menu")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.substr(6))
	_tap(&"resume")
	await _frames()
	_check(not paused and not _game._touch.blocked, "resume releases input gate")
	_check(_game._session.page == "", "overlay returns to HUD")
	_game.open_bag()
	await _frames()
	_check(paused and not _game._session.hud_visible, "inventory owns the screen")
	_game._bag.close()
	_check(not paused, "inventory resumes the world")
	# Simulate the same density used by the existing phone touch-control tests.
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
			_check(bounds.encloses(rect), "phone / %s / %s inside screen" % [page, button["id"]])
			_check(rect.size.y >= 48 * 1.83 - .1, "phone / %s touch height >= 48 dp" % button["id"])
			for other in rects:
				_check(not other.intersects(rect), "phone buttons do not overlap")
			rects.append(rect)
	_game.set_paused(false)
	var atlas := IconAtlas.new()
	root.add_child(atlas)
	await _frames()
	_check(atlas.drawn, "all inventory icon categories draw")
	atlas.free()
	_game.free()
	print("Session flow: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)
