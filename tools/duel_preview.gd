extends SceneTree
## Anteprima dello scontro nell'arena (D-058): partita nuova, il giocatore
## resta fermo in guardia e poi colpisce, il nemico con l'IA combatte. Foto
## durante il conto alla rovescia e lo scontro, riepilogo di vita ed eventi.
## Uso: xvfb-run -a godot --path . --script res://tools/duel_preview.gd -- --out=/tmp/duello.png [--secs=20]

var _game: GameRoot
var _out := "user://duello.png"
var _secs := 20.0
var _t := 0.0
var _ready := false
var _shots := [1.0, 4.0, 6.0, 9.0, 13.0]
var _taken := 0
var _log := {}


func _initialize() -> void:
	Settings.path = "user://e2e_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	SaveService.path = "user://e2e_saves/world.save"
	SaveService.delete_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--secs="):
			_secs = float(a.substr(7))
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)


func _process(dt: float) -> bool:
	var g := _game
	if not _ready:
		if g._runtime.is_idle() and g._build_ms > 0 and g._vegetation.is_idle() and g._water.is_idle():
			_ready = true
			g._day.time = 0.4
			g._day.paused = true
			g._camera_rig.set_mode(CameraRig.Mode.TPS)
			g._camera_rig.set_zoom(1.3)
			g._camera_rig.tps_user_pitch = 0.32
			g.select_weapon(GameRoot.WEAPONS.find(&"sword"))
			g._next_round()
		return false
	_t += dt
	# Il giocatore: guardia a tratti e qualche colpo, per vedere le reazioni.
	g._guard_key = fmod(_t, 4.0) > 2.6
	if fmod(_t, 4.0) < 1.2 and g.combat.buffer == &"":
		g.combat.press_light()
	for e in g.enemy.events:
		var k := String(e["type"])
		_log[k] = int(_log.get(k, 0)) + 1
	if _taken < _shots.size() and _t >= _shots[_taken]:
		root.get_texture().get_image().save_png(_out.replace(".png", "_%d.png" % _taken))
		_taken += 1
	if _t >= _secs:
		print("round %d  tu %.0f/100  avversario %.0f/100 (%s)  esito: %s  vittorie %d sconfitte %d" % [g.duel.round_n, g.player_body.hp,
			g.enemy.body.hp, g.duel.enemy_weapon, g.duel.result, g.duel.wins, g.duel.losses])
		print("eventi del nemico: %s" % _log)
		return true
	return false
