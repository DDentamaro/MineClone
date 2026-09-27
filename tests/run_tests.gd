extends SceneTree
## Runner minimale dei test headless.
## Uso: godot --headless --path . --script res://tests/run_tests.gd
## Esegue ogni metodo test_* degli script in res://tests/unit/ ed esce con
## codice 1 se almeno un'asserzione fallisce.

const UNIT_DIR := "res://tests/unit"


var _started := false


## I test partono al primo frame, quando il root e' gia' nell'albero.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		# Impostazioni separate da quelle del gioco e vuote a ogni esecuzione.
		Settings.path = "user://test_settings.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
		_run_all()
	return false


func _run_all() -> void:
	var failures := 0
	var total := 0
	var files := DirAccess.get_files_at(UNIT_DIR)
	files.sort()
	for f in files:
		if not f.ends_with(".gd"):
			continue
		var script := load(UNIT_DIR.path_join(f)) as GDScript
		if script == null or not script.can_instantiate():
			failures += 1
			total += 1
			print("  FAIL %s (script non caricabile)" % f)
			continue
		var suite: TestCase = script.new()
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			suite.current_failures.clear()
			var t0 := Time.get_ticks_usec()
			suite.call(name)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if suite.current_failures.is_empty():
				print("  PASS %s::%s (%.1f ms)" % [f, name, ms])
			else:
				failures += 1
				print("  FAIL %s::%s" % [f, name])
				for msg in suite.current_failures:
					print("       - " + msg)
	print("%d test, %d falliti" % [total, failures])
	quit(1 if failures > 0 or total == 0 else 0)
