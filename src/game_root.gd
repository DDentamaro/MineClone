class_name GameRoot
extends Node3D
## Radice della sessione: possiede mondo, attori e sessione (docs/DECISIONS.md).
## M0: carica e verifica la fixture del seme 1931 e mostra lo stato.
## M1 aggiungera' qui WorldRuntime (chunk/mesh/collider), player e CameraRig.

@onready var _status: Label = %Status

var world: WorldData


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var catalog := BlockCatalog.load_default()
	var fx := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, catalog)
	var ms := Time.get_ticks_msec() - t0
	if not fx.ok():
		_status.text = "Fixture NON valida:\n" + "\n".join(fx.errors)
		push_error(_status.text)
		return
	world = fx.world
	var spawn := world.spawn_point()
	_status.text = "IsoTerra M0 — Godot %s\nMondo %dx%dx%d, %d chunk, seme %d (%s)\nFixture verificata (SHA-256) in %d ms\nSpawn %s" % [
		Engine.get_version_info()["string"], world.size_x, world.size_y, world.size_z,
		world.chunk_count(), world.world_seed, world.generator_version, ms, spawn]
	print(_status.text)
