class_name FluidRuntime
extends Node3D
## Acqua in gioco: simulazione a tick di 0,25 s (FluidSystem.step_fluid, come il
## frame loop del prototipo) e mesh per tile 16x16 ricostruite solo dove i
## fluidi cambiano, al massimo ogni 100 ms (View.setWater). Le mesh si calcolano
## sui thread di lavoro a partire da una finestra 18x48x18 della tile; i
## risultati di una sessione o versione precedente vengono scartati.
## Tiene anche gli impulsi dello shader (anelli sulla superficie) e i piedi
## delle cascate per gli effetti.

const REBUILD_MS := 100
@export var apply_budget_ms := 2.0
@export var max_jobs := 6
@export var paused := false

var world: WorldData
var material: ShaderMaterial
## Orologio dell'acqua (game.waterClock del prototipo) usato dallo shader.
var water_time := 0.0
## Piedi delle cascate di tutte le tile: [x, y, z, altezza, corpo] ripetuti.
var falls := PackedFloat64Array()

var _session := 0
var _tiles := {} # Vector2i -> MeshInstance3D
var _tile_falls := {} # Vector2i -> PackedFloat64Array
var _dirty := {} # Vector2i -> true
var _version := {} # Vector2i -> int
var _jobs := {} # Vector2i -> task id
var _done := {} # Vector2i -> FluidMesher.MeshData
var _mutex := Mutex.new()
var _next_rebuild := 0
var _impulses := PackedVector4Array()
var _impulse_meta := PackedVector2Array()
var _impulse_cursor := 0
var stats := {"ticks": 0, "updates": 0, "rebuilt": 0, "discarded": 0}


func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://src/presentation/shaders/water.gdshader")
	material.render_priority = 5
	_impulses.resize(16)
	_impulse_meta.resize(16)
	material.set_shader_parameter(&"impulses", _impulses)
	material.set_shader_parameter(&"impulse_meta", _impulse_meta)


## Il mondo deve avere i fluidi inizializzati (FluidSystem.init_fluid).
func setup(w: WorldData) -> void:
	_clear()
	_session += 1
	world = w
	water_time = 0.0
	clear_impulses()
	for cz in ceili(w.size_z / 16.0):
		for cx in ceili(w.size_x / 16.0):
			_dirty[Vector2i(cx, cz)] = true
	w.fluid_dirty.clear()


func is_idle() -> bool:
	return _dirty.is_empty() and _jobs.is_empty() and (world == null or world.fluid_dirty.is_empty())


func _process(dt: float) -> void:
	if world == null:
		return
	if not paused:
		water_time += dt
		world.fluid_clock += dt
		if world.fluid_clock >= FluidSystem.TICK:
			world.fluid_clock -= FluidSystem.TICK
			var up := FluidSystem.step_fluid(world)
			stats["ticks"] += 1
			stats["updates"] += up.size() / 2
	RenderingServer.global_shader_parameter_set(&"water_time", water_time)
	var now := Time.get_ticks_msec()
	if not world.fluid_dirty.is_empty() and now >= _next_rebuild:
		for key: Vector2i in world.fluid_dirty:
			_dirty[key] = true
			_version[key] = int(_version.get(key, 0)) + 1
		world.fluid_dirty.clear()
		_next_rebuild = now + REBUILD_MS
	_work(apply_budget_ms, false)


## Costruisce tutto quello che e' in coda (test e screenshot).
func flush() -> void:
	for key: Vector2i in world.fluid_dirty:
		_dirty[key] = true
		_version[key] = int(_version.get(key, 0)) + 1
	world.fluid_dirty.clear()
	while not _dirty.is_empty() or not _jobs.is_empty():
		_work(1e9, true)


func _work(budget_ms: float, wait: bool) -> void:
	var t0 := Time.get_ticks_usec()
	var tx := ceili(world.size_x / 16.0)
	var tz := ceili(world.size_z / 16.0)
	for key: Vector2i in _dirty.keys():
		if _jobs.size() >= max_jobs:
			break
		if _jobs.has(key):
			continue
		_dirty.erase(key)
		if key.x < 0 or key.y < 0 or key.x >= tx or key.y >= tz:
			continue
		var win := FluidMesher.window(world, key.x, key.y)
		_jobs[key] = WorkerThreadPool.add_task(_job.bind(key, int(_version.get(key, 0)), _session, win, world.size_x, world.size_z))
	for key: Vector2i in _jobs.keys():
		var task: int = _jobs[key]
		if not wait and not WorkerThreadPool.is_task_completed(task):
			continue
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			break
		WorkerThreadPool.wait_for_task_completion(task)
		_jobs.erase(key)
		_mutex.lock()
		var m: FluidMesher.MeshData = _done.get(key)
		_done.erase(key)
		_mutex.unlock()
		if m == null or m.session != _session or m.version != int(_version.get(key, 0)):
			stats["discarded"] += 1
			if m != null and m.session == _session:
				_dirty[key] = true
			continue
		_apply(key, m)


func _job(key: Vector2i, version: int, session: int, win: WorldData, wx: int, wz: int) -> void:
	var m := FluidMesher.build_window(win, key.x, key.y, wx, wz)
	m.version = version
	m.session = session
	_mutex.lock()
	_done[key] = m
	_mutex.unlock()


func _apply(key: Vector2i, m: FluidMesher.MeshData) -> void:
	stats["rebuilt"] += 1
	var old: MeshInstance3D = _tiles.get(key)
	if old != null:
		old.queue_free()
		_tiles.erase(key)
	_tile_falls[key] = m.falls
	_rebuild_falls()
	if m.indices.is_empty():
		return
	var inst := MeshInstance3D.new()
	inst.mesh = FluidMesher.to_array_mesh(m, material)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	_tiles[key] = inst


func _rebuild_falls() -> void:
	falls = PackedFloat64Array()
	for f: PackedFloat64Array in _tile_falls.values():
		falls.append_array(f)


func tile_count() -> int:
	return _tiles.size()


## Anello sulla superficie (waterImpulse del prototipo): 16 slot a rotazione.
func add_impulse(x: float, y: float, z: float, power: float, body: int) -> void:
	var n := _impulse_cursor % 16
	_impulse_cursor += 1
	_impulses[n] = Vector4(x, z, water_time, power)
	_impulse_meta[n] = Vector2(y, body)
	material.set_shader_parameter(&"impulses", _impulses)
	material.set_shader_parameter(&"impulse_meta", _impulse_meta)


func clear_impulses() -> void:
	_impulses.fill(Vector4.ZERO)
	_impulse_meta.fill(Vector2.ZERO)
	_impulse_cursor = 0
	material.set_shader_parameter(&"impulses", _impulses)
	material.set_shader_parameter(&"impulse_meta", _impulse_meta)


func _clear() -> void:
	for key: Vector2i in _jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_jobs[key])
	_jobs.clear()
	_done.clear()
	_dirty.clear()
	_version.clear()
	for inst: MeshInstance3D in _tiles.values():
		inst.queue_free()
	_tiles.clear()
	_tile_falls.clear()
	falls = PackedFloat64Array()


func _exit_tree() -> void:
	_clear()
