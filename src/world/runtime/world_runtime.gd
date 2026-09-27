class_name WorldRuntime
extends Node3D
## Applica al scene tree le mesh dei chunk. Il meshing gira sul WorkerThreadPool
## usando uno snapshot immutabile dei blocchi; i risultati vengono applicati sul
## main thread entro un budget per frame e scartati se obsoleti (versione del
## chunk cambiata o sessione del mondo diversa).

signal initial_build_finished(ms: int)

## Budget indicativo per applicare mesh sul main thread (piano §9: ~2 ms/frame).
@export var apply_budget_ms := 2.0
## Budget usato finche' il mondo iniziale non e' completo (schermata di caricamento).
@export var initial_budget_ms := 12.0
## Numero massimo di job di meshing in coda nel WorkerThreadPool (0 = 4 per core).
@export var max_jobs := 0

var world: WorldData
var palette: ChunkMesher.Palette
var opaque_material: StandardMaterial3D
var water_material: StandardMaterial3D
## Punto di interesse (player): i chunk vicini vengono costruiti per primi.
var focus := Vector3.ZERO

var _session := 0
var _instances := {} # chunk_index -> MeshInstance3D
var _dirty := {} # chunk_index -> true
var _jobs := {} # chunk_index -> task_id
var _done := {} # chunk_index -> MeshData (scritto dai thread)
var _mutex := Mutex.new()
var _snapshot: ChunkMesher.Snapshot
var _snapshot_revision := -1
var _initial_pending := 0
var _initial_t0 := 0
var stats := {"applied": 0, "discarded": 0, "jobs": 0}


func _init() -> void:
	opaque_material = StandardMaterial3D.new()
	opaque_material.vertex_color_use_as_albedo = true
	opaque_material.vertex_color_is_srgb = true
	opaque_material.roughness = 1.0
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.24, 0.5, 0.77, 0.62)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.2
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func setup(w: WorldData, catalog: BlockCatalog) -> void:
	_clear()
	_session += 1
	world = w
	# Lo snapshot appartiene al mondo precedente anche se la revisione coincide.
	_snapshot = null
	_snapshot_revision = -1
	palette = ChunkMesher.Palette.from_catalog(catalog)
	if max_jobs <= 0:
		max_jobs = maxi(4, OS.get_processor_count() * 4)
	_initial_t0 = Time.get_ticks_msec()
	_initial_pending = world.chunk_count()
	for ci in world.chunk_count():
		_dirty[ci] = true


func mark_dirty(chunks: Array[Vector3i]) -> void:
	for c in chunks:
		_dirty[world.chunk_index(c)] = true


func pending_count() -> int:
	return _dirty.size() + _jobs.size()


func is_idle() -> bool:
	return pending_count() == 0


func chunk_instance(chunk: Vector3i) -> MeshInstance3D:
	return _instances.get(world.chunk_index(chunk)) as MeshInstance3D


func _process(_dt: float) -> void:
	if world == null:
		return
	_collect()
	_launch()


## Completa in modo sincrono tutto il lavoro in coda (test e screenshot).
func flush() -> void:
	while not is_idle():
		_launch()
		_collect(1e9, true)


func _launch() -> void:
	if _dirty.is_empty() or _jobs.size() >= max_jobs:
		return
	if _snapshot_revision != world.revision:
		_snapshot = ChunkMesher.Snapshot.of(world)
		_snapshot_revision = world.revision
	var order: Array = _dirty.keys()
	var cx := world.chunks_x()
	var cz := world.chunks_z()
	var f := focus / WorldData.CHUNK_SIZE
	order.sort_custom(func(a: int, b: int) -> bool:
		return _chunk_of(a, cx, cz).distance_squared_to(f) < _chunk_of(b, cx, cz).distance_squared_to(f))
	for ci: int in order:
		if _jobs.size() >= max_jobs:
			break
		if _jobs.has(ci):
			continue
		_dirty.erase(ci)
		var chunk := Vector3i(_chunk_of(ci, cx, cz))
		var version := world.chunk_versions[ci]
		var task := WorkerThreadPool.add_task(_job.bind(ci, chunk, version, _session, _snapshot, palette))
		_jobs[ci] = task
		stats["jobs"] += 1


static func _chunk_of(ci: int, cx: int, cz: int) -> Vector3:
	var x := ci % cx
	var rest := ci / cx
	return Vector3(x, rest / cz, rest % cz)


func _job(ci: int, chunk: Vector3i, version: int, session: int, snap: ChunkMesher.Snapshot,
		pal: ChunkMesher.Palette) -> void:
	var data := ChunkMesher.build(snap, chunk, pal)
	data.version = version
	data.session = session
	_mutex.lock()
	_done[ci] = data
	_mutex.unlock()


## `wait` = aspetta i job non ancora finiti invece di saltarli.
func _collect(budget_ms: float = -1.0, wait: bool = false) -> void:
	var budget := budget_ms
	if budget < 0.0:
		budget = initial_budget_ms if _initial_pending > 0 else apply_budget_ms
	var t0 := Time.get_ticks_usec()
	for ci: int in _jobs.keys():
		var task: int = _jobs[ci]
		if not wait and not WorkerThreadPool.is_task_completed(task):
			continue
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget:
			break
		WorkerThreadPool.wait_for_task_completion(task)
		_jobs.erase(ci)
		_mutex.lock()
		var data: ChunkMesher.MeshData = _done.get(ci)
		_done.erase(ci)
		_mutex.unlock()
		if data == null or data.session != _session or data.version != world.chunk_versions[ci]:
			stats["discarded"] += 1
			_dirty[ci] = true
			continue
		_apply(ci, data)


func _apply(ci: int, data: ChunkMesher.MeshData) -> void:
	stats["applied"] += 1
	var inst: MeshInstance3D = _instances.get(ci)
	if data.is_empty():
		if inst != null:
			inst.queue_free()
			_instances.erase(ci)
	else:
		if inst == null:
			inst = MeshInstance3D.new()
			inst.name = "Chunk_%d_%d_%d" % [data.chunk.x, data.chunk.y, data.chunk.z]
			add_child(inst)
			_instances[ci] = inst
		inst.mesh = ChunkMesher.to_array_mesh(data, opaque_material, water_material)
	if _initial_pending > 0:
		_initial_pending -= 1
		if _initial_pending == 0:
			initial_build_finished.emit(Time.get_ticks_msec() - _initial_t0)


func _clear() -> void:
	for ci: int in _jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_jobs[ci])
	_jobs.clear()
	_done.clear()
	_dirty.clear()
	for inst: MeshInstance3D in _instances.values():
		inst.queue_free()
	_instances.clear()
	_initial_pending = 0


func _exit_tree() -> void:
	for ci: int in _jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_jobs[ci])
	_jobs.clear()
