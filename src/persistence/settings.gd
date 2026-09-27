class_name Settings
extends RefCounted
## Preferenze locali (equivalente delle chiavi isoterra.* di localStorage).
## Il salvataggio del mondo e' un'altra cosa (SaveService, M5).

const PATH := "user://settings.cfg"
## File in uso: i test ne usano uno loro, azzerato a ogni esecuzione.
static var path := PATH


static func load_value(section: String, key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return default
	return cfg.get_value(section, key, default)


static func save_value(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(section, key, value)
	cfg.save(path)
